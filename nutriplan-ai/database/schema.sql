-- ========================================================================
-- NUTRIPLAN AI - DATABASE SCHEMA
-- ========================================================================
-- Core database structure for NutriPlan AI application
-- Includes schema creation, extensions, types, tables, functions, and triggers
-- ========================================================================

-- Create main application schema
CREATE SCHEMA IF NOT EXISTS nutriplan;
SET search_path TO nutriplan, public;

-- ========================================================================
-- EXTENSIONS
-- ========================================================================
-- Enable essential PostgreSQL extensions for advanced functionality
CREATE EXTENSION IF NOT EXISTS "pgcrypto";           -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";            -- Trigram similarity indexing
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- UUID generation
CREATE EXTENSION IF NOT EXISTS "citext";             -- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS "tablefunc";          -- Table functions (crosstab)
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Query statistics

-- ========================================================================
-- DOMAIN DEFINITIONS
-- ========================================================================
-- Reusable domain constraints for data validation
CREATE DOMAIN email_address AS citext 
    CHECK (value ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');

CREATE DOMAIN positive_int AS integer CHECK (value > 0);
CREATE DOMAIN percentage AS numeric(5,2) CHECK (value BETWEEN 0 AND 100);
CREATE DOMAIN bmi_value AS numeric(5,2) CHECK (value BETWEEN 10 AND 60);

-- ========================================================================
-- ENUM TYPES
-- ========================================================================
-- Standardized enumerations for consistent data representation
CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner', 'snack', 'dessert');
CREATE TYPE gender AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending');
CREATE TYPE allergy_severity AS ENUM ('mild', 'moderate', 'severe', 'life_threatening');
CREATE TYPE meal_time AS ENUM ('morning', 'afternoon', 'evening', 'anytime');
CREATE TYPE activity_level AS ENUM ('sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active');
CREATE TYPE goal_type AS ENUM ('weight_loss', 'weight_gain', 'muscle_building', 'maintenance', 'medical_management');

-- ========================================================================
-- SEQUENCES
-- ========================================================================
-- Custom sequences for controlled ID generation
CREATE SEQUENCE user_id_seq START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE meal_plan_id_seq START WITH 5000 INCREMENT BY 1;
CREATE SEQUENCE audit_log_seq START WITH 1 INCREMENT BY 1;

-- ========================================================================
-- CORE TABLES
-- ========================================================================

-- Migration version tracking
CREATE TABLE migration_versions (
    version VARCHAR(50) PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Central audit log for system-wide events
CREATE TABLE audit_log (
    audit_id BIGINT PRIMARY KEY DEFAULT nextval('audit_log_seq'),
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Change history for critical data tracking
CREATE TABLE change_history (
    change_id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    change_type VARCHAR(20) NOT NULL,
    change_description TEXT NOT NULL,
    previous_value JSONB,
    new_value JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ========================================================================
-- UTILITY FUNCTIONS
-- ========================================================================

-- Calculate BMI from weight and height
CREATE OR REPLACE FUNCTION fn_calculate_bmi(weight_kg numeric, height_cm numeric)
RETURNS bmi_value
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF weight_kg IS NULL OR height_cm IS NULL OR height_cm = 0 THEN
        RETURN NULL;
    END IF;
    
    RETURN ROUND(weight_kg / ((height_cm/100) * (height_cm/100)), 2);
END;
$$;

-- Compute user profile completeness score (0-1)
CREATE OR REPLACE FUNCTION fn_compute_profile_score(user_id UUID)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    total_fields CONSTANT integer := 15;
    filled_fields integer := 0;
    user_record record;
BEGIN
    SELECT * INTO user_record FROM users WHERE id = user_id;
    
    IF user_record IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Check each important field
    IF user_record.name IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.age IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.gender IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.weight_kg IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.height_cm IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.goal IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.activity_level IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
    IF user_record.medical_conditions IS NOT NULL AND jsonb_array_length(user_record.medical_conditions) > 0 THEN 
        filled_fields := filled_fields + 1; 
    END IF;
    IF user_record.allergies IS NOT NULL AND jsonb_array_length(user_record.allergies) > 0 THEN 
        filled_fields := filled_fields + 1; 
    END IF;
    IF user_record.medications IS NOT NULL AND jsonb_array_length(user_record.medications) > 0 THEN 
        filled_fields := filled_fields + 1; 
    END IF;
    
    RETURN ROUND(filled_fields::numeric / total_fields, 2);
END;
$$;

-- Aggregate nutrition data from ingredients
CREATE OR REPLACE FUNCTION fn_aggregate_nutrition(ingredients_json JSONB)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    total_calories numeric := 0;
    total_protein numeric := 0;
    total_carbs numeric := 0;
    total_fat numeric := 0;
    total_fiber numeric := 0;
    total_sugar numeric := 0;
    ingredient JSONB;
BEGIN
    FOR ingredient IN SELECT * FROM jsonb_array_elements(ingredients_json)
    LOOP
        total_calories := total_calories + COALESCE((ingredient->>'calories')::numeric, 0);
        total_protein := total_protein + COALESCE((ingredient->>'protein_g')::numeric, 0);
        total_carbs := total_carbs + COALESCE((ingredient->>'carbs_g')::numeric, 0);
        total_fat := total_fat + COALESCE((ingredient->>'fat_g')::numeric, 0);
        total_fiber := total_fiber + COALESCE((ingredient->>'fiber_g')::numeric, 0);
        total_sugar := total_sugar + COALESCE((ingredient->>'sugar_g')::numeric, 0);
    END LOOP;
    
    RETURN jsonb_build_object(
        'calories', total_calories,
        'protein_g', total_protein,
        'carbs_g', total_carbs,
        'fat_g', total_fat,
        'fiber_g', total_fiber,
        'sugar_g', total_sugar
    );
END;
$$;

-- Check medication-food interactions
CREATE OR REPLACE FUNCTION fn_check_medication_food_interaction(
    med_list JSONB, 
    meal_ingredients JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    result JSONB := '[]'::JSONB;
    med_item JSONB;
    ingredient JSONB;
    interaction_record RECORD;
BEGIN
    -- Check each medication against each ingredient
    FOR med_item IN SELECT * FROM jsonb_array_elements(med_list)
    LOOP
        FOR ingredient IN SELECT * FROM jsonb_array_elements(meal_ingredients)
        LOOP
            -- Check against known interactions (simplified example)
            SELECT * INTO interaction_record 
            FROM medication_food_interactions 
            WHERE medication_name = med_item->>'name' 
            AND food_item = ingredient->>'name';
            
            IF FOUND THEN
                result := result || jsonb_build_object(
                    'medication', med_item->>'name',
                    'food', ingredient->>'name',
                    'interaction', interaction_record.interaction_type,
                    'severity', interaction_record.severity,
                    'description', interaction_record.description,
                    'confidence', interaction_record.confidence_score
                );
            END IF;
        END LOOP;
    END LOOP;
    
    RETURN result;
END;
$$;

-- Generate shopping list from meal plan
CREATE OR REPLACE FUNCTION fn_generate_shopping_list(meal_plan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    shopping_list JSONB := '[]'::JSONB;
    meal_record RECORD;
    ingredient JSONB;
    aggregated_items JSONB := '{}'::JSONB;
BEGIN
    -- Aggregate ingredients from all meals in the plan
    FOR meal_record IN 
        SELECT mp.ingredients 
        FROM meal_plans mp 
        WHERE mp.meal_plan_id = meal_plan_id
    LOOP
        FOR ingredient IN SELECT * FROM jsonb_array_elements(meal_record.ingredients)
        LOOP
            -- Aggregate quantities for same ingredients
            aggregated_items := aggregated_items || jsonb_build_object(
                ingredient->>'name',
                COALESCE((aggregated_items->>(ingredient->>'name'))::numeric, 0) + 
                COALESCE((ingredient->>'quantity')::numeric, 0)
            );
        END LOOP;
    END LOOP;
    
    -- Convert to shopping list format
    SELECT jsonb_agg(
        jsonb_build_object(
            'item', key,
            'quantity', value,
            'unit', 'units' -- Simplified; would need actual unit tracking
        )
    ) INTO shopping_list
    FROM jsonb_each_text(aggregated_items);
    
    RETURN shopping_list;
END;
$$;

-- ========================================================================
-- TRIGGER FUNCTIONS
-- ========================================================================

-- Generic timestamp update trigger
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Audit trigger for tracking changes
CREATE OR REPLACE FUNCTION trg_audit_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (table_name, record_id, operation, new_values)
        VALUES (TG_TABLE_NAME, NEW.id::text, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.id::text, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_values)
        VALUES (TG_TABLE_NAME, OLD.id::text, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- User update trigger for profile score calculation
CREATE OR REPLACE FUNCTION trg_after_user_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update profile completeness score
    NEW.profile_score := fn_compute_profile_score(NEW.id);
    
    -- Log significant changes
    IF OLD.medical_conditions IS DISTINCT FROM NEW.medical_conditions OR
       OLD.allergies IS DISTINCT FROM NEW.allergies OR
       OLD.medications IS DISTINCT FROM NEW.medications THEN
       
        INSERT INTO change_history (entity_type, entity_id, change_type, change_description)
        VALUES ('user', NEW.id::text, 'health_update', 'Health information updated');
    END IF;
    
    RETURN NEW;
END;
$$;

-- ========================================================================
-- INDEX TEMPLATES AND PERFORMANCE OPTIMIZATIONS
-- ========================================================================

-- GIN index template for JSONB columns
CREATE INDEX IF NOT EXISTS idx_gin_jsonb_template ON audit_log USING GIN (new_values);

-- Partial index template for soft-deleted records
CREATE INDEX IF NOT EXISTS idx_active_records_template ON users (id) 
WHERE status = 'active';

-- Text search index template
CREATE INDEX IF NOT EXISTS idx_fts_template ON users 
USING GIN (to_tsvector('english', name || ' ' || COALESCE(bio, '')));

-- ========================================================================
-- COMMENTS AND DOCUMENTATION
-- ========================================================================

COMMENT ON SCHEMA nutriplan IS 'Core schema for NutriPlan AI application containing all database objects';

COMMENT ON TABLE audit_log IS 'Centralized audit trail for all data modifications across the system';
COMMENT ON TABLE change_history IS 'Track significant business-level changes for compliance and reporting';
COMMENT ON TABLE migration_versions IS 'Track database schema migration history and versions';

COMMENT ON FUNCTION fn_calculate_bmi IS 'Calculate BMI from weight (kg) and height (cm) inputs';
COMMENT ON FUNCTION fn_compute_profile_score IS 'Compute user profile completeness score based on filled health information';
COMMENT ON FUNCTION fn_aggregate_nutrition IS 'Aggregate nutritional values from meal ingredients JSON array';
COMMENT ON FUNCTION fn_check_medication_food_interaction IS 'Check for potential interactions between medications and food ingredients';
COMMENT ON FUNCTION fn_generate_shopping_list IS 'Generate aggregated shopping list from meal plan ingredients';

-- ========================================================================
-- MIGRATION AND BACKUP NOTES
-- ========================================================================

-- Migration tool recommendation: Use Alembic or Flyway for schema migrations
-- Backup recommendation: Use pg_dump with custom format for efficient backups
-- Restore recommendation: Use pg_restore with parallel jobs for large databases

-- Example backup command: 
-- pg_dump -Fc -d nutriplan_db -f nutriplan_backup.dump

-- Example restore command:
-- pg_restore -d nutriplan_db -j 4 nutriplan_backup.dump

-- ========================================================================
-- END OF SCHEMA.SQL
-- ========================================================================
