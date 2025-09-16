BEGIN;

CREATE TABLE diseases (
    disease_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    icd_code VARCHAR(20),
    name TEXT NOT NULL,
    severity_level INTEGER CHECK (severity_level BETWEEN 1 AND 5),
    dietary_guidelines JSONB NOT NULL DEFAULT '{}',
    contraindicated_ingredients JSONB NOT NULL DEFAULT '[]',
    recommended_meal_tags TEXT[] NOT NULL DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    search_vector TSVECTOR
);

CREATE INDEX idx_diseases_icd_code ON diseases (icd_code);
CREATE INDEX idx_diseases_name ON diseases USING GIN (name gin_trgm_ops);
CREATE INDEX idx_diseases_severity ON diseases (severity_level);
CREATE INDEX idx_diseases_contraindications ON diseases USING GIN (contraindicated_ingredients);
CREATE INDEX idx_diseases_recommended_tags ON diseases USING GIN (recommended_meal_tags);
CREATE INDEX idx_diseases_search_vector ON diseases USING GIN (search_vector);
CREATE INDEX idx_diseases_created_at ON diseases (created_at);
CREATE INDEX idx_diseases_updated_at ON diseases (updated_at);

CREATE OR REPLACE FUNCTION trg_diseases_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_diseases_update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.icd_code, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.notes, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_diseases_set_updated_at
    BEFORE UPDATE ON diseases
    FOR EACH ROW
    EXECUTE FUNCTION trg_diseases_set_updated_at();

CREATE TRIGGER trigger_diseases_update_search_vector
    BEFORE INSERT OR UPDATE ON diseases
    FOR EACH ROW
    EXECUTE FUNCTION trg_diseases_update_search_vector();

CREATE OR REPLACE FUNCTION fn_get_dietary_recommendations(p_disease_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_recommendations JSONB;
    v_disease_record diseases;
BEGIN
    SELECT * INTO v_disease_record FROM diseases WHERE disease_id = p_disease_id;
    
    IF v_disease_record IS NULL THEN
        RETURN '{}'::JSONB;
    END IF;

    v_recommendations := jsonb_build_object(
        'disease_name', v_disease_record.name,
        'icd_code', v_disease_record.icd_code,
        'dietary_guidelines', v_disease_record.dietary_guidelines,
        'contraindicated_ingredients', v_disease_record.contraindicated_ingredients,
        'recommended_meal_tags', v_disease_record.recommended_meal_tags,
        'human_readable_rules', fn_generate_human_readable_rules(v_disease_record)
    );

    RETURN v_recommendations;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_generate_human_readable_rules(p_disease_record diseases)
RETURNS TEXT AS $$
DECLARE
    v_rules TEXT := '';
BEGIN
    v_rules := v_rules || 'Dietary recommendations for ' || p_disease_record.name || E':\n\n';
    
    IF p_disease_record.dietary_guidelines ? 'allowed_foods' THEN
        v_rules := v_rules || 'Recommended foods: ' || 
            array_to_string(ARRAY(SELECT jsonb_array_elements_text(
                p_disease_record.dietary_guidelines->'allowed_foods')), ', ') || E'\n';
    END IF;

    IF p_disease_record.dietary_guidelines ? 'restricted_foods' THEN
        v_rules := v_rules || 'Foods to limit: ' || 
            array_to_string(ARRAY(SELECT jsonb_array_elements_text(
                p_disease_record.dietary_guidelines->'restricted_foods')), ', ') || E'\n';
    END IF;

    IF p_disease_record.dietary_guidelines ? 'nutrient_focus' THEN
        v_rules := v_rules || 'Nutrient focus: ' || 
            array_to_string(ARRAY(SELECT jsonb_array_elements_text(
                p_disease_record.dietary_guidelines->'nutrient_focus')), ', ') || E'\n';
    END IF;

    IF jsonb_array_length(p_disease_record.contraindicated_ingredients) > 0 THEN
        v_rules := v_rules || 'Strictly avoid: ' || 
            array_to_string(ARRAY(SELECT jsonb_array_elements_text(
                p_disease_record.contraindicated_ingredients)), ', ') || E'\n';
    END IF;

    IF array_length(p_disease_record.recommended_meal_tags, 1) > 0 THEN
        v_rules := v_rules || 'Look for meals tagged: ' || 
            array_to_string(p_disease_record.recommended_meal_tags, ', ') || E'\n';
    END IF;

    RETURN v_rules;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_add_disease_with_mappings(
    p_icd_code VARCHAR(20),
    p_name TEXT,
    p_severity_level INTEGER,
    p_dietary_guidelines JSONB DEFAULT '{}',
    p_contraindicated_ingredients JSONB DEFAULT '[]',
    p_recommended_meal_tags TEXT[] DEFAULT '{}',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_disease_id UUID;
BEGIN
    IF p_name IS NULL OR p_name = '' THEN
        RAISE EXCEPTION 'Disease name cannot be null or empty';
    END IF;

    IF p_severity_level NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Severity level must be between 1 and 5';
    END IF;

    INSERT INTO diseases (
        icd_code,
        name,
        severity_level,
        dietary_guidelines,
        contraindicated_ingredients,
        recommended_meal_tags,
        notes
    ) VALUES (
        p_icd_code,
        p_name,
        p_severity_level,
        p_dietary_guidelines,
        p_contraindicated_ingredients,
        p_recommended_meal_tags,
        p_notes
    )
    ON CONFLICT (icd_code) WHERE icd_code IS NOT NULL
    DO UPDATE SET
        name = EXCLUDED.name,
        severity_level = EXCLUDED.severity_level,
        dietary_guidelines = EXCLUDED.dietary_guidelines,
        contraindicated_ingredients = EXCLUDED.contraindicated_ingredients,
        recommended_meal_tags = EXCLUDED.recommended_meal_tags,
        notes = EXCLUDED.notes,
        updated_at = CURRENT_TIMESTAMP
    RETURNING disease_id INTO v_disease_id;

    RETURN v_disease_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_match_diseases_from_text(p_free_text TEXT)
RETURNS TABLE(
    disease_id UUID,
    name TEXT,
    icd_code VARCHAR(20),
    severity_level INTEGER,
    match_confidence NUMERIC,
    match_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.disease_id,
        d.name,
        d.icd_code,
        d.severity_level,
        CASE
            WHEN d.name ILIKE '%' || p_free_text || '%' THEN 1.0
            WHEN d.icd_code = p_free_text THEN 0.9
            WHEN d.search_vector @@ plainto_tsquery('english', p_free_text) THEN 0.8
            WHEN similarity(d.name, p_free_text) > 0.6 THEN similarity(d.name, p_free_text)
            ELSE 0.3
        END AS match_confidence,
        CASE
            WHEN d.name ILIKE '%' || p_free_text || '%' THEN 'exact_name_match'
            WHEN d.icd_code = p_free_text THEN 'icd_code_match'
            WHEN d.search_vector @@ plainto_tsquery('english', p_free_text) THEN 'text_search_match'
            ELSE 'fuzzy_name_match'
        END AS match_reason
    FROM diseases d
    WHERE 
        d.name ILIKE '%' || p_free_text || '%' OR
        d.icd_code = p_free_text OR
        d.search_vector @@ plainto_tsquery('english', p_free_text) OR
        similarity(d.name, p_free_text) > 0.3
    ORDER BY match_confidence DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW vw_disease_nutrition_constraints AS
SELECT 
    d.disease_id,
    d.name AS disease_name,
    d.icd_code,
    constraint_type,
    constraint_value,
    constraint_details
FROM diseases d
CROSS JOIN LATERAL (
    SELECT 'nutrient_focus' AS constraint_type, value AS constraint_value, 
           jsonb_build_object('focus_type', 'recommended') AS constraint_details
    FROM jsonb_array_elements_text(d.dietary_guidelines->'nutrient_focus')
    
    UNION ALL
    
    SELECT 'restricted_nutrient' AS constraint_type, value AS constraint_value,
           jsonb_build_object('restriction_type', 'limit') AS constraint_details
    FROM jsonb_array_elements_text(d.dietary_guidelines->'restricted_nutrients')
    
    UNION ALL
    
    SELECT 'contraindicated_ingredient' AS constraint_type, value AS constraint_value,
           jsonb_build_object('severity', 'strict_avoidance') AS constraint_details
    FROM jsonb_array_elements_text(d.contraindicated_ingredients)
) AS constraints;

CREATE OR REPLACE FUNCTION fn_is_meal_suitable_for_disease(
    p_meal_id UUID,
    p_disease_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_contraindicated_count INTEGER;
    v_disease_record diseases;
BEGIN
    SELECT * INTO v_disease_record FROM diseases WHERE disease_id = p_disease_id;
    
    IF v_disease_record IS NULL THEN
        RETURN TRUE;
    END IF;

    SELECT COUNT(*) INTO v_contraindicated_count
    FROM meal_ingredients mi
    WHERE mi.meal_id = p_meal_id
    AND EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(v_disease_record.contraindicated_ingredients) AS contra_ingredient
        WHERE mi.ingredient_name ILIKE '%' || contra_ingredient || '%'
    );

    RETURN v_contraindicated_count = 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_get_meal_disease_compatibility(
    p_meal_id UUID
)
RETURNS TABLE(
    disease_id UUID,
    disease_name TEXT,
    is_compatible BOOLEAN,
    conflicting_ingredients TEXT[],
    compatibility_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.disease_id,
        d.name AS disease_name,
        fn_is_meal_suitable_for_disease(p_meal_id, d.disease_id) AS is_compatible,
        ARRAY(
            SELECT contra_ingredient
            FROM jsonb_array_elements_text(d.contraindicated_ingredients) AS contra_ingredient
            WHERE EXISTS (
                SELECT 1
                FROM meal_ingredients mi
                WHERE mi.meal_id = p_meal_id
                AND mi.ingredient_name ILIKE '%' || contra_ingredient || '%'
            )
        ) AS conflicting_ingredients,
        CASE 
            WHEN fn_is_meal_suitable_for_disease(p_meal_id, d.disease_id) THEN
                'Meal contains no contraindicated ingredients for ' || d.name
            ELSE
                'Meal contains ingredients that should be avoided for ' || d.name
        END AS compatibility_reason
    FROM diseases d
    WHERE jsonb_array_length(d.contraindicated_ingredients) > 0;
END;
$$ LANGUAGE plpgsql;

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('E11', 'Type 2 Diabetes', 3,
 '{"allowed_foods": ["non-starchy vegetables", "whole grains", "lean proteins", "healthy fats"],
   "restricted_foods": ["sugary beverages", "refined carbohydrates", "processed foods"],
   "nutrient_focus": ["low_glycemic", "high_fiber", "balanced_carbs"]}',
 '["sugar", "high fructose corn syrup", "white flour", "processed sweets"]',
 '{"diabetic_friendly", "low_sugar", "high_fiber"}',
 'Focus on blood sugar management through carbohydrate control and fiber intake');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('I10', 'Hypertension', 3,
 '{"allowed_foods": ["potassium-rich foods", "leafy greens", "berries", "low-fat dairy"],
   "restricted_foods": ["high-sodium foods", "processed meats", "canned soups"],
   "nutrient_focus": ["low_sodium", "high_potassium", "magnesium_rich"]}',
 '["excessive salt", "soy sauce", "processed meats", "pickled foods"]',
 '{"low_sodium", "heart_healthy", "blood_pressure_friendly"}',
 'DASH diet principles: Limit sodium to under 1500mg daily, increase potassium intake');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('E66', 'Obesity', 2,
 '{"allowed_foods": ["high-volume vegetables", "lean proteins", "fiber-rich foods"],
   "restricted_foods": ["high-calorie dense foods", "sugary snacks", "fried foods"],
   "nutrient_focus": ["calorie_controlled", "high_protein", "low_energy_density"]}',
 '["trans fats", "sugary drinks", "deep fried foods", "high-calorie snacks"]',
 '{"weight_management", "low_calorie", "high_protein"}',
 'Focus on calorie deficit while maintaining nutrient density and satiety');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('K90', 'Celiac Disease', 4,
 '{"allowed_foods": ["naturally gluten-free grains", "fruits", "vegetables", "lean meats"],
   "restricted_foods": ["wheat", "barley", "rye", "contaminated oats"],
   "nutrient_focus": ["gluten_free", "whole_foods", "nutrient_dense"]}',
 '["wheat", "barley", "rye", "malt", "brewer''s yeast"]',
 '{"gluten_free", "celiac_safe", "whole_foods"}',
 'Strict gluten-free diet essential. Watch for cross-contamination in processing');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('N18', 'Chronic Kidney Disease', 4,
 '{"allowed_foods": ["low-potassium fruits", "careful protein portions", "low-phosphorus foods"],
   "restricted_foods": ["high-potassium foods", "high-phosphorus foods", "excess protein"],
   "nutrient_focus": ["low_potassium", "low_phosphorus", "controlled_protein"]}',
 '["bananas", "oranges", "potatoes", "tomatoes", "dairy products", "nuts", "beans"]',
 '{"renal_diet", "kidney_friendly", "low_mineral"}',
 'Stage-dependent restrictions on potassium, phosphorus, and protein intake');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('K85', 'Acute Pancreatitis', 5,
 '{"allowed_foods": ["clear liquids initially", "low-fat foods", "easily digestible proteins"],
   "restricted_foods": ["high-fat foods", "alcohol", "fried foods", "spicy foods"],
   "nutrient_focus": ["low_fat", "easily_digestible", "hydration_focus"]}',
 '["alcohol", "fried foods", "high-fat meats", "cream sauces", "spicy seasonings"]',
 '{"low_fat", "pancreas_friendly", "easily_digestible"}',
 'NPO initially, progressing to clear liquids, then low-fat diet as tolerated');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('E55', 'Vitamin D Deficiency', 1,
 '{"allowed_foods": ["fortified dairy", "fatty fish", "egg yolks", "sunlight exposure"],
   "restricted_foods": [],
   "nutrient_focus": ["vitamin_d_rich", "calcium_rich", "magnesium_containing"]}',
 '[]',
 '{"vitamin_d_rich", "bone_health", "calcium_containing"}',
 'Focus on vitamin D and calcium co-consumption for better absorption');

INSERT INTO diseases (icd_code, name, severity_level, dietary_guidelines, contraindicated_ingredients, recommended_meal_tags, notes) VALUES
('K21', 'GERD', 2,
 '{"allowed_foods": ["non-citrus fruits", "lean proteins", "whole grains", "vegetables"],
   "restricted_foods": ["spicy foods", "citrus", "tomatoes", "chocolate", "caffeine
