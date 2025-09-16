BEGIN;

-- Disable foreign key checks for bulk data loading
SET session_replication_role = replica;

-- Food Nutrition Master Table
INSERT INTO food_nutrition (food_id, canonical_name, synonyms, calories, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg, serving_size, serving_unit, micronutrients) VALUES
('F001', 'Brown Rice', '{"whole grain rice", "unpolished rice"}', 111, 2.6, 0.9, 23.0, 1.8, 0.4, 5, 100, 'g', '{"magnesium": "43mg", "phosphorus": "83mg"}')
ON CONFLICT (food_id) DO UPDATE SET
    canonical_name = EXCLUDED.canonical_name,
    synonyms = EXCLUDED.synonyms,
    calories = EXCLUDED.calories,
    protein_g = EXCLUDED.protein_g,
    fat_g = EXCLUDED.fat_g,
    carbs_g = EXCLUDED.carbs_g,
    fiber_g = EXCLUDED.fiber_g,
    sugar_g = EXCLUDED.sugar_g,
    sodium_mg = EXCLUDED.sodium_mg,
    serving_size = EXCLUDED.serving_size,
    serving_unit = EXCLUDED.serving_unit,
    micronutrients = EXCLUDED.micronutrients;

INSERT INTO food_nutrition (food_id, canonical_name, synonyms, calories, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg, serving_size, serving_unit, micronutrients) VALUES
('F002', 'Chicken Breast', '{"chicken fillet", "white meat chicken"}', 165, 31.0, 3.6, 0.0, 0.0, 0.0, 74, 100, 'g', '{"vitamin_b6": "0.5mg", "niacin": "10.6mg"}')
ON CONFLICT (food_id) DO UPDATE SET
    canonical_name = EXCLUDED.canonical_name,
    synonyms = EXCLUDED.synonyms,
    calories = EXCLUDED.calories,
    protein_g = EXCLUDED.protein_g,
    fat_g = EXCLUDED.fat_g,
    carbs_g = EXCLUDED.carbs_g,
    fiber_g = EXCLUDED.fiber_g,
    sugar_g = EXCLUDED.sugar_g,
    sodium_mg = EXCLUDED.sodium_mg,
    serving_size = EXCLUDED.serving_size,
    serving_unit = EXCLUDED.serving_unit,
    micronutrients = EXCLUDED.micronutrients;

-- Medical Diet Mapping Table
INSERT INTO medical_diet_mapping (disease_code, allowed_ingredients, restricted_ingredients, recommendations) VALUES
('E11', '{"brown rice", "leafy greens", "lean proteins", "whole grains"}', '{"sugar", "white bread", "processed foods", "sweetened beverages"}', 'Focus on high-fiber, low-glycemic index foods with balanced macronutrients')
ON CONFLICT (disease_code) DO UPDATE SET
    allowed_ingredients = EXCLUDED.allowed_ingredients,
    restricted_ingredients = EXCLUDED.restricted_ingredients,
    recommendations = EXCLUDED.recommendations;

INSERT INTO medical_diet_mapping (disease_code, allowed_ingredients, restricted_ingredients, recommendations) VALUES
('I10', '{"potassium-rich foods", "leafy greens", "berries", "low-fat dairy"}', '{"high-sodium foods", "processed meats", "canned soups", "pickled foods"}', 'Limit sodium intake to under 1500mg daily and increase potassium-rich foods')
ON CONFLICT (disease_code) DO UPDATE SET
    allowed_ingredients = EXCLUDED.allowed_ingredients,
    restricted_ingredients = EXCLUDED.restricted_ingredients,
    recommendations = EXCLUDED.recommendations;

-- Medications Table
INSERT INTO medications (medication_id, generic_name, brand_names, common_dosages, formulation, food_interactions, contraindications) VALUES
('M001', 'Metformin', '{"Glucophage", "Fortamet", "Glumetza"}', '{"500mg", "850mg", "1000mg"}', 'tablet', '{"Avoid excessive alcohol consumption"}', '{"renal impairment", "metabolic acidosis"}')
ON CONFLICT (medication_id) DO UPDATE SET
    generic_name = EXCLUDED.generic_name,
    brand_names = EXCLUDED.brand_names,
    common_dosages = EXCLUDED.common_dosages,
    formulation = EXCLUDED.formulation,
    food_interactions = EXCLUDED.food_interactions,
    contraindications = EXCLUDED.contraindications;

INSERT INTO medications (medication_id, generic_name, brand_names, common_dosages, formulation, food_interactions, contraindications) VALUES
('M002', 'Warfarin', '{"Coumadin", "Jantoven"}', '{"1mg", "2mg", "5mg"}', 'tablet', '{"Maintain consistent vitamin K intake", "Avoid drastic changes in leafy green consumption"}', '{"bleeding disorders", "pregnancy"}')
ON CONFLICT (medication_id) DO UPDATE SET
    generic_name = EXCLUDED.generic_name,
    brand_names = EXCLUDED.brand_names,
    common_dosages = EXCLUDED.common_dosages,
    formulation = EXCLUDED.formulation,
    food_interactions = EXCLUDED.food_interactions,
    contraindications = EXCLUDED.contraindications;

-- Allergies Catalog
INSERT INTO allergies (allergy_id, allergy_name, severity, synonyms, cross_reactions, management_guidelines) VALUES
('A001', 'Peanut Allergy', 'severe', '{"groundnut allergy", "arachis hypogaea allergy"}', '{"soy", "lupin", "other legumes"}', '{"Carry epinephrine auto-injector", "Read food labels carefully", "Avoid cross-contamination"}')
ON CONFLICT (allergy_id) DO UPDATE SET
    allergy_name = EXCLUDED.allergy_name,
    severity = EXCLUDED.severity,
    synonyms = EXCLUDED.synonyms,
    cross_reactions = EXCLUDED.cross_reactions,
    management_guidelines = EXCLUDED.management_guidelines;

INSERT INTO allergies (allergy_id, allergy_name, severity, synonyms, cross_reactions, management_guidelines) VALUES
('A002', 'Lactose Intolerance', 'moderate', '{"dairy intolerance", "milk sugar intolerance"}', '{}', '{"Limit dairy consumption", "Use lactase supplements", "Choose lactose-free alternatives"}')
ON CONFLICT (allergy_id) DO UPDATE SET
    allergy_name = EXCLUDED.allergy_name,
    severity = EXCLUDED.severity,
    synonyms = EXCLUDED.synonyms,
    cross_reactions = EXCLUDED.cross_reactions,
    management_guidelines = EXCLUDED.management_guidelines;

-- Starter Meal Templates
INSERT INTO meal_templates (template_id, meal_type, meal_name, ingredients, estimated_calories, estimated_protein_g, estimated_carbs_g, estimated_fat_g, preparation_time, difficulty_level) VALUES
('T001', 'breakfast', 'High-Protein Oatmeal', '{"oats": "50g", "whey protein": "30g", "berries": "100g", "almonds": "20g"}', 380, 28.0, 45.0, 10.0, 15, 'easy')
ON CONFLICT (template_id) DO UPDATE SET
    meal_type = EXCLUDED.meal_type,
    meal_name = EXCLUDED.meal_name,
    ingredients = EXCLUDED.ingredients,
    estimated_calories = EXCLUDED.estimated_calories,
    estimated_protein_g = EXCLUDED.estimated_protein_g,
    estimated_carbs_g = EXCLUDED.estimated_carbs_g,
    estimated_fat_g = EXCLUDED.estimated_fat_g,
    preparation_time = EXCLUDED.preparation_time,
    difficulty_level = EXCLUDED.difficulty_level;

INSERT INTO meal_templates (template_id, meal_type, meal_name, ingredients, estimated_calories, estimated_protein_g, estimated_carbs_g, estimated_fat_g, preparation_time, difficulty_level) VALUES
('T002', 'lunch', 'Mediterranean Chicken Bowl', '{"chicken breast": "120g", "quinoa": "100g", "cherry tomatoes": "50g", "cucumber": "50g", "feta cheese": "30g", "olive oil": "10g"}', 480, 42.0, 35.0, 18.0, 25, 'medium')
ON CONFLICT (template_id) DO UPDATE SET
    meal_type = EXCLUDED.meal_type,
    meal_name = EXCLUDED.meal_name,
    ingredients = EXCLUDED.ingredients,
    estimated_calories = EXCLUDED.estimated_calories,
    estimated_protein_g = EXCLUDED.estimated_protein_g,
    estimated_carbs_g = EXCLUDED.estimated_carbs_g,
    estimated_fat_g = EXCLUDED.estimated_fat_g,
    preparation_time = EXCLUDED.preparation_time,
    difficulty_level = EXCLUDED.difficulty_level;

-- Sample User Profiles
INSERT INTO users (user_id, username, email, age, gender, weight_kg, height_cm, activity_level, goal, dietary_preferences, medical_conditions, allergies, medications, budget_tier, cuisine_preferences) VALUES
('U001', 'fitness_enthusiast', 'fitness@example.com', 28, 'male', 78.5, 180.0, 'very_active', 'muscle_building', '{"high_protein", "low_sugar"}', '{}', '{}', '{}', 'medium', '{"mediterranean", "asian"}')
ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    email = EXCLUDED.email,
    age = EXCLUDED.age,
    gender = EXCLUDED.gender,
    weight_kg = EXCLUDED.weight_kg,
    height_cm = EXCLUDED.height_cm,
    activity_level = EXCLUDED.activity_level,
    goal = EXCLUDED.goal,
    dietary_preferences = EXCLUDED.dietary_preferences,
    medical_conditions = EXCLUDED.medical_conditions,
    allergies = EXCLUDED.allergies,
    medications = EXCLUDED.medications,
    budget_tier = EXCLUDED.budget_tier,
    cuisine_preferences = EXCLUDED.cuisine_preferences;

INSERT INTO users (user_id, username, email, age, gender, weight_kg, height_cm, activity_level, goal, dietary_preferences, medical_conditions, allergies, medications, budget_tier, cuisine_preferences) VALUES
('U002', 'diabetic_elderly', 'senior@example.com', 67, 'female', 68.0, 162.0, 'lightly_active', 'medical_management', '{"diabetic_friendly", "low_carb"}', '{"type 2 diabetes"}', '{}', '{"metformin"}', 'low', '{"traditional", "comfort_food"}')
ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    email = EXCLUDED.email,
    age = EXCLUDED.age,
    gender = EXCLUDED.gender,
    weight_kg = EXCLUDED.weight_kg,
    height_cm = EXCLUDED.height_cm,
    activity_level = EXCLUDED.activity_level,
    goal = EXCLUDED.goal,
    dietary_preferences = EXCLUDED.dietary_preferences,
    medical_conditions = EXCLUDED.medical_conditions,
    allergies = EXCLUDED.allergies,
    medications = EXCLUDED.medications,
    budget_tier = EXCLUDED.budget_tier,
    cuisine_preferences = EXCLUDED.cuisine_preferences;

-- Lookup Reference Tables
INSERT INTO meal_tags (tag_id, tag_name, tag_description) VALUES
('TAG001', 'high_protein', 'Meals containing more than 20g of protein per serving')
ON CONFLICT (tag_id) DO UPDATE SET
    tag_name = EXCLUDED.tag_name,
    tag_description = EXCLUDED.tag_description;

INSERT INTO cuisine_types (cuisine_id, cuisine_name, region, characteristics) VALUES
('C001', 'South Indian', 'Southern India', '{"rice_based", "coconut_heavy", "spicy", "fermented_foods"}')
ON CONFLICT (cuisine_id) DO UPDATE SET
    cuisine_name = EXCLUDED.cuisine_name,
    region = EXCLUDED.region,
    characteristics = EXCLUDED.characteristics;

INSERT INTO budget_tiers (tier_id, tier_name, daily_budget_range, description) VALUES
('B001', 'low', '{"min": 3.00, "max": 6.00}', 'Budget-friendly meals using affordable ingredients')
ON CONFLICT (tier_id) DO UPDATE SET
    tier_name = EXCLUDED.tier_name,
    daily_budget_range = EXCLUDED.daily_budget_range,
    description = EXCLUDED.description;

-- Notifications and Reminders
INSERT INTO notifications (notification_id, user_id, notification_type, title, message, scheduled_time, is_recurring) VALUES
('N001', 'U002', 'medication_reminder', 'Medication Time', 'Remember to take your Metformin with food', '2024-01-15 08:00:00', true)
ON CONFLICT (notification_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    notification_type = EXCLUDED.notification_type,
    title = EXCLUDED.title,
    message = EXCLUDED.message,
    scheduled_time = EXCLUDED.scheduled_time,
    is_recurring = EXCLUDED.is_recurring;

-- Sample Family Members
INSERT INTO family_members (family_member_id, user_id, relation, name, age, gender, weight_kg, height_cm, dietary_restrictions, medical_conditions) VALUES
('F001', 'U002', 'spouse', 'Robert Smith', 70, 'male', 82.0, 175.0, '{"low_sodium"}', '{"hypertension"}')
ON CONFLICT (family_member_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    relation = EXCLUDED.relation,
    name = EXCLUDED.name,
    age = EXCLUDED.age,
    gender = EXCLUDED.gender,
    weight_kg = EXCLUDED.weight_kg,
    height_cm = EXCLUDED.height_cm,
    dietary_restrictions = EXCLUDED.dietary_restrictions,
    medical_conditions = EXCLUDED.medical_conditions;

-- Meal Ratings and Reviews
INSERT INTO meal_ratings (rating_id, user_id, meal_id, rating, review_text, created_at) VALUES
('R001', 'U001', 'T001', 4.5, 'Great protein content and easy to prepare. Would add more cinnamon next time.', '2024-01-10 09:30:00')
ON CONFLICT (rating_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    meal_id = EXCLUDED.meal_id,
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    created_at = EXCLUDED.created_at;

INSERT INTO meal_ratings (rating_id, user_id, meal_id, rating, review_text, created_at) VALUES
('R002', 'U002', 'T002', 3.8, 'Tasty but a bit too spicy for my preference. Good portion size.', '2024-01-11 13:45:00')
ON CONFLICT (rating_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    meal_id = EXCLUDED.meal_id,
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    created_at = EXCLUDED.created_at;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Data integrity validation checks
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM food_nutrition) < 2 THEN
        RAISE EXCEPTION 'Food nutrition data failed to load properly';
    END IF;
    
    IF (SELECT COUNT(*) FROM users) < 2 THEN
        RAISE EXCEPTION 'User data failed to load properly';
    END IF;
    
    IF (SELECT COUNT(*) FROM meal_ratings) < 2 THEN
        RAISE EXCEPTION 'Meal ratings failed to load properly';
    END IF;
END $$;

COMMIT;
