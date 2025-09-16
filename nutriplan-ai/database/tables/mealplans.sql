BEGIN;

CREATE TYPE meal_plan_frequency AS ENUM ('daily', 'weekly', 'custom');
CREATE TYPE meal_plan_status AS ENUM ('draft', 'active', 'completed', 'archived');
CREATE TYPE meal_time_type AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');
CREATE TYPE recommendation_source AS ENUM ('model', 'manual', 'community', 'professional');

CREATE TABLE meal_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    frequency meal_plan_frequency NOT NULL DEFAULT 'weekly',
    budget_level VARCHAR(20) CHECK (budget_level IN ('low', 'medium', 'high', 'premium')),
    status meal_plan_status NOT NULL DEFAULT 'draft',
    created_by VARCHAR(100) NOT NULL,
    total_calories NUMERIC(8,2),
    total_protein_g NUMERIC(8,2),
    total_carbs_g NUMERIC(8,2),
    total_fat_g NUMERIC(8,2),
    total_cost_estimate NUMERIC(10,2),
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT valid_date_range CHECK (end_date >= start_date),
    CONSTRAINT reasonable_calories CHECK (total_calories BETWEEN 0 AND 10000)
);

CREATE TABLE meal_plan_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES meal_plans(plan_id) ON DELETE CASCADE,
    day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
    meal_date DATE,
    meal_time meal_time_type NOT NULL,
    recipe_id UUID REFERENCES recipes(recipe_id),
    recipe_data JSONB,
    serving_size NUMERIC(6,2) NOT NULL DEFAULT 1.0,
    calories_est NUMERIC(8,2),
    protein_g NUMERIC(8,2),
    carbs_g NUMERIC(8,2),
    fat_g NUMERIC(8,2),
    cost_estimate NUMERIC(8,2),
    is_safe BOOLEAN DEFAULT true,
    safety_notes TEXT,
    recommended_by recommendation_source DEFAULT 'model',
    user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
    user_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT either_day_or_date CHECK (
        (day_of_week IS NOT NULL AND meal_date IS NULL) OR 
        (day_of_week IS NULL AND meal_date IS NOT NULL) OR
        (frequency = 'daily' AND meal_date IS NOT NULL)
    )
);

CREATE INDEX idx_meal_plans_user_date ON meal_plans(user_id, start_date);
CREATE INDEX idx_meal_plans_status ON meal_plans(status);
CREATE INDEX idx_meal_plans_metadata ON meal_plans USING GIN (metadata);
CREATE INDEX idx_meal_plans_budget ON meal_plans(budget_level);
CREATE INDEX idx_meal_plans_search ON meal_plans USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')));

CREATE INDEX idx_meal_plan_items_plan ON meal_plan_items(plan_id);
CREATE INDEX idx_meal_plan_items_date ON meal_plan_items(meal_date);
CREATE INDEX idx_meal_plan_items_day_time ON meal_plan_items(day_of_week, meal_time);
CREATE INDEX idx_meal_plan_items_recipe ON meal_plan_items(recipe_id);
CREATE INDEX idx_meal_plan_items_safety ON meal_plan_items(is_safe);
CREATE INDEX idx_meal_plan_items_macros ON meal_plan_items USING GIN (
    jsonb_build_object('calories', calories_est, 'protein', protein_g, 'carbs', carbs_g, 'fat', fat_g)
);

CREATE OR REPLACE FUNCTION trg_meal_plans_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_meal_plan_items_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_meal_plan_completed_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        NEW.completed_at = CURRENT_TIMESTAMP;
    ELSIF NEW.status != 'completed' THEN
        NEW.completed_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_meal_plans_updated_at
    BEFORE UPDATE ON meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION trg_meal_plans_set_updated_at();

CREATE TRIGGER trigger_meal_plan_items_updated_at
    BEFORE UPDATE ON meal_plan_items
    FOR EACH ROW
    EXECUTE FUNCTION trg_meal_plan_items_set_updated_at();

CREATE TRIGGER trigger_meal_plan_completed
    BEFORE UPDATE ON meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION trg_meal_plan_completed_date();

CREATE OR REPLACE FUNCTION sp_create_meal_plan(
    p_user_id UUID,
    p_title TEXT,
    p_start_date DATE,
    p_end_date DATE,
    p_frequency meal_plan_frequency,
    p_budget_level VARCHAR(20),
    p_created_by VARCHAR(100),
    p_metadata JSONB DEFAULT '{}',
    p_plan_items JSONB DEFAULT '[]'
)
RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
    v_item JSONB;
    v_recipe_record RECORD;
    v_total_calories NUMERIC := 0;
    v_total_protein NUMERIC := 0;
    v_total_carbs NUMERIC := 0;
    v_total_fat NUMERIC := 0;
    v_total_cost NUMERIC := 0;
BEGIN
    INSERT INTO meal_plans (
        user_id, title, start_date, end_date, frequency, 
        budget_level, created_by, metadata
    ) VALUES (
        p_user_id, p_title, p_start_date, p_end_date, p_frequency,
        p_budget_level, p_created_by, p_metadata
    ) RETURNING plan_id INTO v_plan_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_plan_items)
    LOOP
        IF v_item->>'recipe_id' IS NOT NULL THEN
            SELECT * INTO v_recipe_record 
            FROM recipes 
            WHERE recipe_id = (v_item->>'recipe_id')::UUID;
            
            IF v_recipe_record IS NULL THEN
                RAISE EXCEPTION 'Recipe not found: %', v_item->>'recipe_id';
            END IF;
        END IF;

        INSERT INTO meal_plan_items (
            plan_id, day_of_week, meal_date, meal_time, recipe_id,
            recipe_data, serving_size, calories_est, protein_g,
            carbs_g, fat_g, cost_estimate, recommended_by
        ) VALUES (
            v_plan_id,
            (v_item->>'day_of_week')::INTEGER,
            (v_item->>'meal_date')::DATE,
            (v_item->>'meal_time')::meal_time_type,
            (v_item->>'recipe_id')::UUID,
            COALESCE(v_item->'recipe_data', '{}'::JSONB),
            COALESCE((v_item->>'serving_size')::NUMERIC, 1.0),
            COALESCE((v_item->>'calories_est')::NUMERIC, v_recipe_record.calories_per_serving),
            COALESCE((v_item->>'protein_g')::NUMERIC, v_recipe_record.protein_g),
            COALESCE((v_item->>'carbs_g')::NUMERIC, v_recipe_record.carbs_g),
            COALESCE((v_item->>'fat_g')::NUMERIC, v_recipe_record.fat_g),
            COALESCE((v_item->>'cost_estimate')::NUMERIC, v_recipe_record.cost_estimate),
            COALESCE((v_item->>'recommended_by')::recommendation_source, 'model')
        );

        v_total_calories := v_total_calories + COALESCE((v_item->>'calories_est')::NUMERIC, v_recipe_record.calories_per_serving, 0);
        v_total_protein := v_total_protein + COALESCE((v_item->>'protein_g')::NUMERIC, v_recipe_record.protein_g, 0);
        v_total_carbs := v_total_carbs + COALESCE((v_item->>'carbs_g')::NUMERIC, v_recipe_record.carbs_g, 0);
        v_total_fat := v_total_fat + COALESCE((v_item->>'fat_g')::NUMERIC, v_recipe_record.fat_g, 0);
        v_total_cost := v_total_cost + COALESCE((v_item->>'cost_estimate')::NUMERIC, v_recipe_record.cost_estimate, 0);
    END LOOP;

    UPDATE meal_plans 
    SET total_calories = v_total_calories,
        total_protein_g = v_total_protein,
        total_carbs_g = v_total_carbs,
        total_fat_g = v_total_fat,
        total_cost_estimate = v_total_cost
    WHERE plan_id = v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_get_weekly_plan(
    p_user_id UUID,
    p_week_start_date DATE
)
RETURNS JSONB AS $$
DECLARE
    v_plan_json JSONB;
BEGIN
    SELECT jsonb_build_object(
        'week_start', p_week_start_date,
        'week_end', p_week_start_date + 6,
        'meal_plan', COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'plan_id', mp.plan_id,
                    'title', mp.title,
                    'status', mp.status,
                    'daily_items', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'day_of_week', d.day,
                                'date', p_week_start_date + d.day,
                                'meals', (
                                    SELECT jsonb_agg(
                                        jsonb_build_object(
                                            'meal_time', mpi.meal_time,
                                            'recipe_id', mpi.recipe_id,
                                            'recipe_title', r.title,
                                            'calories', mpi.calories_est,
                                            'protein_g', mpi.protein_g,
                                            'carbs_g', mpi.carbs_g,
                                            'fat_g', mpi.fat_g,
                                            'is_safe', mpi.is_safe,
                                            'recommended_by', mpi.recommended_by
                                        ) ORDER BY mpi.meal_time
                                    )
                                    FROM meal_plan_items mpi
                                    LEFT JOIN recipes r ON mpi.recipe_id = r.recipe_id
                                    WHERE mpi.plan_id = mp.plan_id
                                    AND mpi.day_of_week = d.day
                                )
                            )
                        )
                        FROM (VALUES (0), (1), (2), (3), (4), (5), (6)) AS d(day)
                    )
                )
            ),
            '[]'::JSONB
        )
    ) INTO v_plan_json
    FROM meal_plans mp
    WHERE mp.user_id = p_user_id
    AND mp.start_date <= p_week_start_date + 6
    AND mp.end_date >= p_week_start_date
    AND mp.status = 'active';

    RETURN v_plan_json;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_toggle_plan_status(
    p_plan_id UUID,
    p_new_status meal_plan_status
)
RETURNS BOOLEAN AS $$
DECLARE
    v_old_status meal_plan_status;
    v_user_id UUID;
BEGIN
    SELECT status, user_id INTO v_old_status, v_user_id
    FROM meal_plans WHERE plan_id = p_plan_id;
    
    IF v_old_status IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE meal_plans SET status = p_new_status WHERE plan_id = p_plan_id;

    IF p_new_status = 'active' AND v_old_status != 'active' THEN
        PERFORM pg_notify('meal_plan_activated', 
            jsonb_build_object('plan_id', p_plan_id, 'user_id', v_user_id)::text);
    ELSIF p_new_status != 'active' AND v_old_status = 'active' THEN
        PERFORM pg_notify('meal_plan_deactivated', 
            jsonb_build_object('plan_id', p_plan_id, 'user_id', v_user_id)::text);
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_generate_shopping_list(p_plan_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_shopping_list JSONB;
BEGIN
    WITH ingredient_aggregates AS (
        SELECT 
            i.ingredient_name,
            i.unit,
            SUM(i.quantity * mpi.serving_size) as total_quantity,
            MIN(i.cost_estimate) as unit_cost_estimate,
            SUM(i.quantity * mpi.serving_size * COALESCE(i.cost_estimate, 0)) as total_cost_estimate,
            jsonb_agg(DISTINCT jsonb_build_object(
                'recipe_id', mpi.recipe_id,
                'recipe_title', r.title,
                'meal_time', mpi.meal_time,
                'day', mpi.day_of_week
            )) as usage_details
        FROM meal_plan_items mpi
        JOIN recipes r ON mpi.recipe_id = r.recipe_id
        CROSS JOIN LATERAL jsonb_to_recordset(r.ingredients) AS i(
            ingredient_name TEXT,
            quantity NUMERIC,
            unit TEXT,
            cost_estimate NUMERIC
        )
        WHERE mpi.plan_id = p_plan_id
        GROUP BY i.ingredient_name, i.unit
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'ingredient', ingredient_name,
            'total_quantity', total_quantity,
            'unit', unit,
            'unit_cost_estimate', unit_cost_estimate,
            'total_cost_estimate', total_cost_estimate,
            'usage_details', usage_details
        )
    ) INTO v_shopping_list
    FROM ingredient_aggregates
    ORDER BY ingredient_name;

    RETURN COALESCE(v_shopping_list, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_mark_unsafe_items()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE meal_plan_items mpi
    SET is_safe = FALSE,
        safety_notes = 'Automatically flagged by safety check'
    FROM meal_plans mp
    WHERE mpi.plan_id = mp.plan_id
    AND mp.status = 'active'
    AND mpi.is_safe = TRUE
    AND EXISTS (
        SELECT 1
        FROM user_medical_conditions umc
        JOIN disease_contraindications dc ON umc.condition_id = dc.disease_id
        WHERE umc.user_id = mp.user_id
        AND dc.contraindicated_ingredient IN (
            SELECT jsonb_array_elements_text(r.ingredients->'ingredient_names')
            FROM recipes r
            WHERE r.recipe_id = mpi.recipe_id
        )
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_annotate_recommendation_source()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.recommended_by IS NULL THEN
        NEW.recommended_by := 'model';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_annotate_recommendation_source
    BEFORE INSERT ON meal_plan_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_annotate_recommendation_source();

INSERT INTO meal_plans (
    user_id, title, start_date, end_date, frequency, 
    budget_level, created_by, status, total_calories,
    total_protein_g, total_carbs_g, total_fat_g, total_cost_estimate
) VALUES (
    (SELECT user_id FROM users WHERE username = 'fitness_enthusiast' LIMIT 1),
    'High Protein Weekly Plan',
    CURRENT_DATE,
    CURRENT_DATE + 6,
    'weekly',
    'medium',
    'model',
    'active',
    12500,
    650,
    1200,
    280,
    85.50
);

INSERT INTO meal_plan_items (
    plan_id, day_of_week, meal_time, recipe_id, serving_size,
    calories_est, protein_g, carbs_g, fat_g, is_safe, recommended_by
) VALUES
(
    (SELECT plan_id FROM meal_plans WHERE title = 'High Protein Weekly Plan' LIMIT 1),
    0, 'breakfast', (SELECT recipe_id FROM recipes WHERE title LIKE '%Protein Oatmeal%' LIMIT 1),
    1.0, 380, 28.0, 45.0, 10.0, true, 'model'
),
(
    (SELECT plan_id FROM meal_plans WHERE title = 'High Protein Weekly Plan' LIMIT 1),
    0, 'lunch', (SELECT recipe_id FROM recipes WHERE title LIKE '%Chicken Bowl%' LIMIT 1),
    1.0, 480, 42.0, 35.0, 18.0, true, 'model'
);

COMMIT;
