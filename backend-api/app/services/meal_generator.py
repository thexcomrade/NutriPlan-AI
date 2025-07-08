# File: D:\nutriplan-ai\backend-api\app\services\meal_generator.py

import random
from typing import List, Dict, Any
from datetime import datetime

class MealItem:
    def __init__(self, name: str, calories: int, protein: float, carbs: float, fat: float,
                 tags: List[str], eco_score: float):
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.tags = tags  # e.g., ['vegan', 'gluten-free']
        self.eco_score = eco_score  # scale: 0 (low sustainability) to 1 (high sustainability)

    def to_dict(self):
        return {
            "name": self.name,
            "calories": self.calories,
            "protein": self.protein,
            "carbs": self.carbs,
            "fat": self.fat,
            "tags": self.tags,
            "eco_score": self.eco_score
        }

class MealPlan:
    def __init__(self, user_id: str, total_calories: int, preferences: List[str], 
                 medical_conditions: List[str], target_profile: str):
        self.user_id = user_id
        self.total_calories = total_calories
        self.preferences = preferences
        self.medical_conditions = medical_conditions
        self.target_profile = target_profile
        self.timestamp = datetime.now()
        self.meals = {
            "breakfast": [],
            "lunch": [],
            "dinner": [],
            "snacks": []
        }

    def to_dict(self):
        return {
            "user_id": self.user_id,
            "total_calories": self.total_calories,
            "preferences": self.preferences,
            "medical_conditions": self.medical_conditions,
            "target_profile": self.target_profile,
            "timestamp": self.timestamp.isoformat(),
            "meals": {
                k: [m.to_dict() for m in v]
                for k, v in self.meals.items()
            }
        }

class MealGenerator:
    def __init__(self):
        self.master_meal_list = self._load_meals()

    def _load_meals(self) -> List[MealItem]:
        """Load meals from static data (mocked)."""
        meals = [
            MealItem("Oats with Banana", 250, 6, 40, 5, ["vegan", "diabetes"], 0.9),
            MealItem("Grilled Chicken Breast", 300, 35, 0, 5, ["keto", "gluten-free"], 0.8),
            MealItem("Mixed Veg Salad", 180, 5, 20, 8, ["vegetarian", "low-carb"], 0.95),
            MealItem("Paneer Wrap", 400, 20, 35, 18, ["vegetarian", "protein-rich"], 0.7),
            MealItem("Fruit Bowl", 150, 2, 25, 0, ["vegan", "heart"], 0.98),
            MealItem("Quinoa with Chickpeas", 320, 12, 38, 10, ["vegan", "diabetes"], 0.92),
            MealItem("Sprouts Sandwich", 280, 14, 30, 9, ["vegetarian", "fiber"], 0.85),
            MealItem("Tofu Stir Fry", 270, 20, 12, 11, ["vegan", "keto"], 0.9),
            MealItem("Brown Rice & Dal", 360, 14, 45, 12, ["vegetarian", "balanced"], 0.88),
            MealItem("Egg Omelette", 220, 14, 2, 18, ["keto", "high-protein"], 0.75),
        ]
        return meals

    def _filter_meals(self, preferences: List[str], medical_conditions: List[str]) -> List[MealItem]:
        """Filter meals based on user dietary preferences and medical conditions."""
        filtered = []
        for meal in self.master_meal_list:
            if all(tag in meal.tags for tag in preferences):
                if all(cond in meal.tags for cond in medical_conditions):
                    filtered.append(meal)
        return filtered if filtered else self.master_meal_list  # fallback to full list

    def _select_meals_by_calorie(self, meals: List[MealItem], target_calories: int) -> Dict[str, List[MealItem]]:
        """Select meals to match calorie goals, divided across meals of the day."""
        allocation = {
            "breakfast": int(0.25 * target_calories),
            "lunch": int(0.35 * target_calories),
            "dinner": int(0.30 * target_calories),
            "snacks": int(0.10 * target_calories)
        }

        selected = {"breakfast": [], "lunch": [], "dinner": [], "snacks": []}
        for meal_time in selected.keys():
            cal_limit = allocation[meal_time]
            cal_sum = 0
            meal_pool = meals[:]
            random.shuffle(meal_pool)

            for meal in meal_pool:
                if cal_sum + meal.calories <= cal_limit:
                    selected[meal_time].append(meal)
                    cal_sum += meal.calories
        return selected

    def _eco_score_average(self, meals: Dict[str, List[MealItem]]) -> float:
        total_score = 0
        total_items = 0
        for meal_list in meals.values():
            for item in meal_list:
                total_score += item.eco_score
                total_items += 1
        return round(total_score / total_items, 2) if total_items else 0.0

    def generate_meal_plan(self, user_id: str, total_calories: int, preferences: List[str],
                           medical_conditions: List[str], target_profile: str) -> Dict[str, Any]:
        """Public method to generate a meal plan."""
        plan = MealPlan(user_id, total_calories, preferences, medical_conditions, target_profile)
        filtered_meals = self._filter_meals(preferences, medical_conditions)
        selected_meals = self._select_meals_by_calorie(filtered_meals, total_calories)
        plan.meals = selected_meals

        eco_score = self._eco_score_average(selected_meals)
        result = plan.to_dict()
        result["eco_score"] = eco_score
        result["status"] = "success"
        return result

# For testing in local development
if __name__ == "__main__":
    generator = MealGenerator()
    test_plan = generator.generate_meal_plan(
        user_id="user123",
        total_calories=2000,
        preferences=["vegan"],
        medical_conditions=["diabetes"],
        target_profile="gym-goer"
    )
    from pprint import pprint
    pprint(test_plan)
