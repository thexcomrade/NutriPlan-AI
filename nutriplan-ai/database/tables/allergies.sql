BEGIN;

CREATE TYPE allergy_severity AS ENUM ('mild', 'moderate', 'severe', 'life_threatening');

CREATE TABLE allergies (
    allergy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    canonical_name TEXT NOT NULL,
    synonyms TEXT[] DEFAULT '{}',
    severity allergy_severity NOT NULL DEFAULT 'moderate',
    common_triggers JSONB DEFAULT '[]',
    cross_reactive_with JSONB DEFAULT '[]',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    search_vector TSVECTOR,
    
    CONSTRAINT unique_allergy_name UNIQUE (name),
    CONSTRAINT unique_canonical_name UNIQUE (canonical_name)
);

CREATE INDEX idx_allergies_severity ON allergies (severity);
CREATE INDEX idx_allergies_created_at ON allergies (created_at);
CREATE INDEX idx_allergies_updated_at ON allergies (updated_at);
CREATE INDEX idx_allergies_search_vector ON allergies USING GIN (search_vector);
CREATE INDEX idx_allergies_synonyms ON allergies USING GIN (synonyms);
CREATE INDEX idx_allergies_common_triggers ON allergies USING GIN (common_triggers);
CREATE INDEX idx_allergies_cross_reactive ON allergies USING GIN (cross_reactive_with);
CREATE INDEX idx_allergies_name_trgm ON allergies USING GIN (name gin_trgm_ops);
CREATE INDEX idx_allergies_canonical_trgm ON allergies USING GIN (canonical_name gin_trgm_ops);

CREATE OR REPLACE FUNCTION trg_allergies_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_allergies_update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.canonical_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.synonyms, ' '), '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.notes, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_allergies_invalidate_cache()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('allergy_cache_invalidation', 
        json_build_object('operation', TG_OP, 'allergy_id', COALESCE(NEW.allergy_id, OLD.allergy_id))::text);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_allergies_set_updated_at
    BEFORE UPDATE ON allergies
    FOR EACH ROW
    EXECUTE FUNCTION trg_allergies_set_updated_at();

CREATE TRIGGER trigger_allergies_update_search_vector
    BEFORE INSERT OR UPDATE ON allergies
    FOR EACH ROW
    EXECUTE FUNCTION trg_allergies_update_search_vector();

CREATE TRIGGER trigger_allergies_invalidate_cache
    AFTER INSERT OR UPDATE OR DELETE ON allergies
    FOR EACH ROW
    EXECUTE FUNCTION trg_allergies_invalidate_cache();

CREATE OR REPLACE FUNCTION sp_add_allergy(
    p_name TEXT,
    p_synonyms TEXT[] DEFAULT NULL,
    p_severity allergy_severity DEFAULT 'moderate',
    p_triggers_jsonb JSONB DEFAULT NULL,
    p_cross_reactive JSONB DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_allergy_id UUID;
    v_canonical_name TEXT;
BEGIN
    IF p_name IS NULL OR p_name = '' THEN
        RAISE EXCEPTION 'Allergy name cannot be null or empty';
    END IF;

    IF p_severity IS NULL THEN
        RAISE EXCEPTION 'Severity cannot be null';
    END IF;

    v_canonical_name := lower(trim(p_name));
    
    INSERT INTO allergies (
        name,
        canonical_name,
        synonyms,
        severity,
        common_triggers,
        cross_reactive_with,
        notes
    ) VALUES (
        p_name,
        v_canonical_name,
        COALESCE(p_synonyms, '{}'),
        p_severity,
        COALESCE(p_triggers_jsonb, '[]'),
        COALESCE(p_cross_reactive, '[]'),
        p_notes
    )
    ON CONFLICT (canonical_name) 
    DO UPDATE SET
        synonyms = EXCLUDED.synonyms,
        severity = EXCLUDED.severity,
        common_triggers = EXCLUDED.common_triggers,
        cross_reactive_with = EXCLUDED.cross_reactive_with,
        notes = EXCLUDED.notes,
        updated_at = CURRENT_TIMESTAMP
    RETURNING allergy_id INTO v_allergy_id;

    RETURN v_allergy_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_get_allergy_by_name(p_search_text TEXT)
RETURNS SETOF allergies AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM allergies
    WHERE 
        name ILIKE '%' || p_search_text || '%' OR
        canonical_name ILIKE '%' || p_search_text || '%' OR
        p_search_text ILIKE ANY(synonyms) OR
        search_vector @@ plainto_tsquery('english', p_search_text)
    ORDER BY
        CASE 
            WHEN name ILIKE p_search_text THEN 1
            WHEN canonical_name ILIKE p_search_text THEN 2
            WHEN p_search_text ILIKE ANY(synonyms) THEN 3
            ELSE 4
        END,
        similarity(name, p_search_text) DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_map_allergies_to_ingredients(p_allergy_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_allergy_record allergies;
BEGIN
    SELECT * INTO v_allergy_record FROM allergies WHERE allergy_id = p_allergy_id;
    
    IF v_allergy_record IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    v_result := v_allergy_record.common_triggers;

    IF v_allergy_record.cross_reactive_with IS NOT NULL AND jsonb_array_length(v_allergy_record.cross_reactive_with) > 0 THEN
        SELECT jsonb_agg(DISTINCT trigger)
        INTO v_result
        FROM (
            SELECT jsonb_array_elements_text(v_allergy_record.common_triggers) AS trigger
            UNION ALL
            SELECT jsonb_array_elements_text(cross_triggers) AS trigger
            FROM allergies 
            WHERE allergy_id IN (
                SELECT jsonb_array_elements_text(v_allergy_record.cross_reactive_with)
            )
        ) AS combined_triggers;
    END IF;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_find_allergies_by_ingredient(p_ingredient_name TEXT)
RETURNS TABLE(
    allergy_id UUID,
    name TEXT,
    canonical_name TEXT,
    severity allergy_severity,
    match_type TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.allergy_id,
        a.name,
        a.canonical_name,
        a.severity,
        CASE 
            WHEN p_ingredient_name ILIKE ANY(a.synonyms) THEN 'synonym_match'
            WHEN EXISTS (
                SELECT 1 
                FROM jsonb_array_elements_text(a.common_triggers) AS trigger 
                WHERE trigger ILIKE '%' || p_ingredient_name || '%'
            ) THEN 'trigger_match'
            ELSE 'fuzzy_match'
        END AS match_type
    FROM allergies a
    WHERE 
        p_ingredient_name ILIKE ANY(a.synonyms) OR
        EXISTS (
            SELECT 1 
            FROM jsonb_array_elements_text(a.common_triggers) AS trigger 
            WHERE trigger ILIKE '%' || p_ingredient_name || '%'
        ) OR
        a.search_vector @@ plainto_tsquery('english', p_ingredient_name)
    ORDER BY 
        severity DESC,
        CASE match_type
            WHEN 'synonym_match' THEN 1
            WHEN 'trigger_match' THEN 2
            ELSE 3
        END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_get_high_severity_allergens()
RETURNS SETOF allergies AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM allergies
    WHERE severity IN ('severe', 'life_threatening')
    ORDER BY severity DESC, name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_validate_allergy_input(p_name TEXT, p_severity TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_name IS NULL OR trim(p_name) = '' THEN
        RETURN FALSE;
    END IF;

    IF p_severity IS NOT NULL AND p_severity NOT IN ('mild', 'moderate', 'severe', 'life_threatening') THEN
        RETURN FALSE;
    END IF;

    IF length(p_name) > 255 THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Peanuts', 'peanuts', '{"groundnuts", "arachis hypogaea"}', 'severe', 
 '["peanut", "peanut oil", "peanut butter", "peanut flour", "mixed nuts"]',
 '["tree nuts", "soy", "lupin"]',
 'Severe allergic reactions including anaphylaxis possible. Cross-reactive with other legumes.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Shellfish', 'shellfish', '{"crustaceans", "mollusks", "seafood"}', 'severe',
 '["shrimp", "prawn", "crab", "lobster", "crayfish", "scallop", "oyster", "mussel", "clam", "squid", "octopus"]',
 '["iodine", "mites"]',
 'Can cause severe reactions. Note that shellfish allergy is different from fish allergy.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Dairy', 'dairy', '{"milk", "lactose", "casein", "whey"}', 'moderate',
 '["milk", "cheese", "yogurt", "butter", "cream", "ice cream", "whey", "casein", "lactose"]',
 '["goat milk", "sheep milk"]',
 'Includes milk from all mammals. Lactose intolerance is different from milk allergy.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Eggs', 'eggs', '{"egg white", "egg yolk", "ovalbumin"}', 'moderate',
 '["egg", "mayonnaise", "meringue", "custard", "baked goods", "pasta", "ovalbumin", "ovomucoid"]',
 '["vaccines", "feathers"]',
 'Most reactions are to egg whites. Some vaccines contain egg proteins.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Soy', 'soy', '{"soya", "soybean", "glycine max"}', 'moderate',
 '["soy", "soybean", "tofu", "tempeh", "soy sauce", "edamame", "soy milk", "soy protein"]',
 '["peanuts", "other legumes"]',
 'Common in children but often outgrown. Cross-reactivity with other legumes possible.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Wheat', 'wheat', '{"gluten", "triticum"}', 'moderate',
 '["wheat", "bread", "pasta", "cereal", "flour", "seitan", "wheat germ", "wheat bran"]',
 '["rye", "barley", "oats"]',
 'Different from celiac disease and gluten intolerance. Note: wheat-free is not necessarily gluten-free.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Tree Nuts', 'tree nuts', '{"nuts", "almonds", "walnuts", "cashews"}', 'severe',
 '["almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "brazil nut", "macadamia", "nut butters", "nut oils"]',
 '["peanuts", "seeds"]',
 'Distinct from peanut allergy. Individuals may be allergic to one or multiple tree nuts.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Fish', 'fish', '{"seafood", "fin fish"}', 'severe',
 '["salmon", "tuna", "cod", "halibut", "tilapia", "fish sauce", "fish oil", "anchovy"]',
 '["shellfish", "iodine"]',
 'Different from shellfish allergy. Cooking may not destroy the allergen.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Sesame', 'sesame', '{"sesame seeds", "til", "gingelly"}', 'moderate',
 '["sesame seeds", "tahini", "sesame oil", "halva", "hummus", "bread toppings"]',
 '["other seeds", "nuts"]',
 'Becoming more common. Often found in Middle Eastern and Asian cuisine.');

INSERT INTO allergies (name, canonical_name, synonyms, severity, common_triggers, cross_reactive_with, notes) VALUES
('Sulfites', 'sulfites', '{"sulphites", "sulfur dioxide"}', 'mild',
 '["dried fruits", "wine", "processed foods", "potato products", "shrimp"]',
 '[]',
 'Common preservative. Reactions are typically respiratory rather than anaphylactic.');

COMMIT;
