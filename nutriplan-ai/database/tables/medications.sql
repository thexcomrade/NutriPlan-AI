BEGIN;

CREATE TABLE medications (
    medication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    generic_name TEXT,
    brand_names TEXT[] DEFAULT '{}',
    common_dosages JSONB DEFAULT '[]',
    food_interactions JSONB DEFAULT '[]',
    drug_interactions JSONB DEFAULT '[]',
    side_effects JSONB DEFAULT '[]',
    contraindications JSONB DEFAULT '[]',
    administration_guidelines JSONB DEFAULT '{}',
    storage_instructions TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    search_vector TSVECTOR,
    
    CONSTRAINT unique_medication_name UNIQUE (name)
);

CREATE TABLE medication_interactions (
    interaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_a_id UUID NOT NULL REFERENCES medications(medication_id) ON DELETE CASCADE,
    medication_b_id UUID NOT NULL REFERENCES medications(medication_id) ON DELETE CASCADE,
    severity VARCHAR(20) CHECK (severity IN ('mild', 'moderate', 'severe', 'contraindicated')),
    description TEXT,
    mechanism TEXT,
    management_guidelines TEXT,
    evidence_level VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(medication_a_id, medication_b_id),
    CONSTRAINT valid_interaction_pair CHECK (medication_a_id != medication_b_id)
);

CREATE INDEX idx_medications_name ON medications USING GIN (name gin_trgm_ops);
CREATE INDEX idx_medications_generic_name ON medications USING GIN (generic_name gin_trgm_ops);
CREATE INDEX idx_medications_brand_names ON medications USING GIN (brand_names);
CREATE INDEX idx_medications_food_interactions ON medications USING GIN (food_interactions);
CREATE INDEX idx_medications_drug_interactions ON medications USING GIN (drug_interactions);
CREATE INDEX idx_medications_search_vector ON medications USING GIN (search_vector);
CREATE INDEX idx_medications_created_at ON medications (created_at);
CREATE INDEX idx_medications_updated_at ON medications (updated_at);

CREATE INDEX idx_medication_interactions_pair ON medication_interactions(medication_a_id, medication_b_id);
CREATE INDEX idx_medication_interactions_severity ON medication_interactions(severity);
CREATE INDEX idx_medication_interactions_created_at ON medication_interactions(created_at);

CREATE OR REPLACE FUNCTION trg_medications_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_medications_update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.generic_name, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.brand_names, ' '), '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.notes, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_medication_interactions_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_medications_set_updated_at
    BEFORE UPDATE ON medications
    FOR EACH ROW
    EXECUTE FUNCTION trg_medications_set_updated_at();

CREATE TRIGGER trigger_medications_update_search_vector
    BEFORE INSERT OR UPDATE ON medications
    FOR EACH ROW
    EXECUTE FUNCTION trg_medications_update_search_vector();

CREATE TRIGGER trigger_medication_interactions_set_updated_at
    BEFORE UPDATE ON medication_interactions
    FOR EACH ROW
    EXECUTE FUNCTION trg_medication_interactions_set_updated_at();

CREATE OR REPLACE FUNCTION fn_find_medication_by_name(p_search_text TEXT)
RETURNS SETOF medications AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM medications
    WHERE 
        name ILIKE '%' || p_search_text || '%' OR
        generic_name ILIKE '%' || p_search_text || '%' OR
        p_search_text ILIKE ANY(brand_names) OR
        search_vector @@ plainto_tsquery('english', p_search_text)
    ORDER BY
        CASE 
            WHEN name ILIKE p_search_text THEN 1
            WHEN generic_name ILIKE p_search_text THEN 2
            WHEN p_search_text ILIKE ANY(brand_names) THEN 3
            ELSE 4
        END,
        similarity(name, p_search_text) DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_check_medication_interactions(p_meds JSONB)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '[]'::JSONB;
    v_med JSONB;
    v_other_med JSONB;
    v_interaction_record RECORD;
BEGIN
    FOR v_med IN SELECT * FROM jsonb_array_elements(p_meds)
    LOOP
        FOR v_other_med IN SELECT * FROM jsonb_array_elements(p_meds)
        LOOP
            IF v_med->>'medication_id' != v_other_med->>'medication_id' THEN
                SELECT * INTO v_interaction_record
                FROM medication_interactions mi
                WHERE (mi.medication_a_id = (v_med->>'medication_id')::UUID AND 
                       mi.medication_b_id = (v_other_med->>'medication_id')::UUID)
                   OR (mi.medication_a_id = (v_other_med->>'medication_id')::UUID AND 
                       mi.medication_b_id = (v_med->>'medication_id')::UUID);
                
                IF FOUND THEN
                    v_result := v_result || jsonb_build_object(
                        'medication_a', v_med->>'name',
                        'medication_b', v_other_med->>'name',
                        'severity', v_interaction_record.severity,
                        'description', v_interaction_record.description,
                        'management_guidelines', v_interaction_record.management_guidelines
                    );
                END IF;
            END IF;
        END LOOP;
        
        FOR v_interaction_record IN
            SELECT * FROM jsonb_to_recordset(
                (SELECT drug_interactions FROM medications 
                 WHERE medication_id = (v_med->>'medication_id')::UUID)
            ) AS x(interacting_med TEXT, interaction_type TEXT, severity TEXT)
        LOOP
            v_result := v_result || jsonb_build_object(
                'medication_a', v_med->>'name',
                'medication_b', v_interaction_record.interacting_med,
                'severity', v_interaction_record.severity,
                'description', v_interaction_record.interaction_type,
                'source', 'embedded_interaction_data'
            );
        END LOOP;
    END LOOP;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_medication_food_warning(
    p_med_list JSONB,
    p_ingredient_tags JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '[]'::JSONB;
    v_med JSONB;
    v_ingredient TEXT;
    v_food_interaction JSONB;
    v_warning_text TEXT;
    v_risk_score NUMERIC;
BEGIN
    FOR v_med IN SELECT * FROM jsonb_array_elements(p_med_list)
    LOOP
        IF v_med->>'medication_id' IS NOT NULL THEN
            SELECT food_interactions INTO v_food_interaction
            FROM medications 
            WHERE medication_id = (v_med->>'medication_id')::UUID;
            
            FOR v_ingredient IN SELECT * FROM jsonb_array_elements_text(p_ingredient_tags)
            LOOP
                IF v_food_interaction ? v_ingredient THEN
                    v_risk_score := CASE v_food_interaction->>v_ingredient
                        WHEN 'avoid' THEN 0.9
                        WHEN 'caution' THEN 0.6
                        WHEN 'monitor' THEN 0.3
                        ELSE 0.1
                    END;
                    
                    v_warning_text := format(
                        '%s may interact with %s. %s',
                        v_med->>'name',
                        v_ingredient,
                        COALESCE(v_food_interaction->v_ingredient->>'advice', 
                                'Consult your healthcare provider.')
                    );
                    
                    v_result := v_result || jsonb_build_object(
                        'medication', v_med->>'name',
                        'ingredient', v_ingredient,
                        'interaction_type', v_food_interaction->>v_ingredient,
                        'warning', v_warning_text,
                        'risk_score', v_risk_score,
                        'severity', CASE 
                            WHEN v_risk_score >= 0.7 THEN 'high'
                            WHEN v_risk_score >= 0.4 THEN 'medium'
                            ELSE 'low'
                        END
                    );
                END IF;
            END LOOP;
        END IF;
    END LOOP;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_upsert_medication_interaction(
    p_med_a_id UUID,
    p_med_b_id UUID,
    p_severity VARCHAR(20),
    p_description TEXT DEFAULT NULL,
    p_mechanism TEXT DEFAULT NULL,
    p_management_guidelines TEXT DEFAULT NULL,
    p_evidence_level VARCHAR(20) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_interaction_id UUID;
BEGIN
    IF p_med_a_id = p_med_b_id THEN
        RAISE EXCEPTION 'Medication cannot interact with itself';
    END IF;

    IF p_severity NOT IN ('mild', 'moderate', 'severe', 'contraindicated') THEN
        RAISE EXCEPTION 'Invalid severity level';
    END IF;

    INSERT INTO medication_interactions (
        medication_a_id,
        medication_b_id,
        severity,
        description,
        mechanism,
        management_guidelines,
        evidence_level
    ) VALUES (
        LEAST(p_med_a_id, p_med_b_id),
        GREATEST(p_med_a_id, p_med_b_id),
        p_severity,
        p_description,
        p_mechanism,
        p_management_guidelines,
        p_evidence_level
    )
    ON CONFLICT (medication_a_id, medication_b_id)
    DO UPDATE SET
        severity = EXCLUDED.severity,
        description = EXCLUDED.description,
        mechanism = EXCLUDED.mechanism,
        management_guidelines = EXCLUDED.management_guidelines,
        evidence_level = EXCLUDED.evidence_level,
        updated_at = CURRENT_TIMESTAMP
    RETURNING interaction_id INTO v_interaction_id;

    RETURN v_interaction_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_get_medication_interactions_for_user(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_meds JSONB;
    v_interactions JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'medication_id', um.medication_id,
            'name', m.name,
            'dosage', um.dosage,
            'frequency', um.frequency
        )
    ) INTO v_user_meds
    FROM user_medications um
    JOIN medications m ON um.medication_id = m.medication_id
    WHERE um.user_id = p_user_id
    AND um.end_date IS NULL OR um.end_date >= CURRENT_DATE;

    IF v_user_meds IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT fn_check_medication_interactions(v_user_meds) INTO v_interactions;

    RETURN v_interactions;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_check_meal_medication_safety(
    p_meal_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_ingredients JSONB;
    v_user_meds JSONB;
    v_warnings JSONB;
BEGIN
    SELECT jsonb_agg(DISTINCT ingredient->>'name')
    INTO v_ingredients
    FROM recipes r
    CROSS JOIN jsonb_array_elements(r.ingredients) AS ingredient
    WHERE r.recipe_id IN (
        SELECT recipe_id FROM meal_plan_items 
        WHERE meal_id = p_meal_id
    );

    SELECT jsonb_agg(
        jsonb_build_object(
            'medication_id', um.medication_id,
            'name', m.name
        )
    ) INTO v_user_meds
    FROM user_medications um
    JOIN medications m ON um.medication_id = m.medication_id
    WHERE um.user_id = p_user_id
    AND (um.end_date IS NULL OR um.end_date >= CURRENT_DATE);

    IF v_ingredients IS NULL OR v_user_meds IS NULL THEN
        RETURN jsonb_build_object('is_safe', true, 'warnings', '[]');
    END IF;

    SELECT fn_medication_food_warning(v_user_meds, v_ingredients) INTO v_warnings;

    RETURN jsonb_build_object(
        'is_safe', jsonb_array_length(v_warnings) = 0,
        'warnings', v_warnings,
        'risk_level', CASE 
            WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(v_warnings) 
                        WHERE value->>'severity' = 'high') THEN 'high'
            WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(v_warnings) 
                        WHERE value->>'severity' = 'medium') THEN 'medium'
            ELSE 'low'
        END
    );
END;
$$ LANGUAGE plpgsql;

INSERT INTO medications (
    name, generic_name, brand_names, common_dosages, 
    food_interactions, drug_interactions, side_effects, contraindications
) VALUES (
    'Metformin', 'Metformin Hydrochloride', 
    ARRAY['Glucophage', 'Fortamet', 'Glumetza'],
    '[{"dose": 500, "unit": "mg", "frequency": "twice daily"}, 
      {"dose": 850, "unit": "mg", "frequency": "once daily"},
      {"dose": 1000, "unit": "mg", "frequency": "once daily"}]'::JSONB,
    '{"alcohol": {"interaction": "avoid", "advice": "Risk of lactic acidosis"}, 
      "grapefruit": {"interaction": "caution", "advice": "May affect metabolism"}}'::JSONB,
    '[]'::JSONB,
    '["nausea", "diarrhea", "abdominal discomfort", "loss of appetite"]'::JSONB,
    '["renal impairment", "metabolic acidosis", "hypersensitivity"]'::JSONB
);

INSERT INTO medications (
    name, generic_name, brand_names, common_dosages, 
    food_interactions, drug_interactions, side_effects, contraindications
) VALUES (
    'Warfarin', 'Warfarin Sodium', 
    ARRAY['Coumadin', 'Jantoven'],
    '[{"dose": 1, "unit": "mg", "frequency": "once daily"}, 
      {"dose": 2, "unit": "mg", "frequency": "once daily"},
      {"dose": 5, "unit": "mg", "frequency": "once daily"}]'::JSONB,
    '{"vitamin_k_rich_foods": {"interaction": "monitor", "advice": "Maintain consistent intake"}, 
      "cranberry": {"interaction": "avoid", "advice": "May increase bleeding risk"},
      "alcohol": {"interaction": "caution", "advice": "May affect INR levels"}}'::JSONB,
    '[{"interacting_med": "Aspirin", "interaction_type": "increased_bleeding_risk", "severity": "severe"},
      {"interacting_med": "NSAIDs", "interaction_type": "increased_bleeding_risk", "severity": "severe"}]'::JSONB,
    '["bleeding", "bruising", "hair loss", "skin necrosis"]'::JSONB,
    '["bleeding disorders", "pregnancy", "recent_surgery"]'::JSONB
);

INSERT INTO medications (
    name, generic_name, brand_names, common_dosages, 
    food_interactions, drug_interactions, side_effects, contraindications
) VALUES (
    'Levothyroxine', 'Levothyroxine Sodium', 
    ARRAY['Synthroid', 'Levoxyl', 'Unithroid'],
    '[{"dose": 25, "unit": "mcg", "frequency": "once daily"}, 
      {"dose": 50, "unit": "mcg", "frequency": "once daily"},
      {"dose": 100, "unit": "mcg", "frequency": "once daily"}]'::JSONB,
    '{"calcium_supplements": {"interaction": "avoid", "advice": "Take 4 hours apart"}, 
      "iron_supplements": {"interaction": "avoid", "advice": "Take 4 hours apart"},
      "soy": {"interaction": "caution", "advice": "May decrease absorption"},
      "fiber": {"interaction": "caution", "advice": "May decrease absorption"}}'::JSONB,
    '[]'::JSONB,
    '["palpitations", "tremors", "insomnia", "weight_loss"]'::JSONB,
    '["hyperthyroidism", "uncorrected_adrenal_insufficiency"]'::JSONB
);

SELECT sp_upsert_medication_interaction(
    (SELECT medication_id FROM medications WHERE name = 'Warfarin'),
    (SELECT medication_id FROM medications WHERE name = 'Aspirin'),
    'severe',
    'Increased risk of bleeding',
    'Both medications affect platelet function and coagulation',
    'Avoid concurrent use. Monitor for signs of bleeding if used together.',
    'established'
);

SELECT sp_upsert_medication_interaction(
    (SELECT medication_id FROM medications WHERE name = 'Warfarin'),
    (SELECT medication_id FROM medications WHERE name = 'Metformin'),
    'moderate',
    'Potential interaction affecting INR levels',
    'Metformin may affect warfarin metabolism in some patients',
    'Monitor INR closely when starting or stopping metformin',
    'potential'
);

COMMIT;
