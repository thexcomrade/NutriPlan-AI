# medical_filter.py

"""
Medical Filter Service for NutriPlan AI
---------------------------------------
This module filters meals based on a user's medical conditions. 
Each condition comes with specific dietary restrictions (avoid) 
and preferences (prefer). The service provides a way to evaluate 
meals and exclude those that may negatively affect a user's health.
"""

from typing import List, Dict, Any


class MedicalFilterService:
    """
    A service to filter meals based on a user's medical conditions.
    """

    def __init__(self):
        self.medical_conditions_rules: Dict[str, Dict[str, List[str]]] = {
            "diabetes": {
                "avoid": ["sugar", "white bread", "white rice", "soda", "pastries", "fried foods", "honey"],
                "prefer": ["whole grains", "vegetables", "lean proteins", "nuts", "legumes"]
            },
            "hypertension": {
                "avoid": ["salt", "processed foods", "pickles", "fried snacks", "cheese", "canned soup"],
                "prefer": ["fruits", "leafy greens", "low-fat dairy", "whole grains", "beets"]
            },
            "heart": {
                "avoid": ["red meat", "butter", "fried foods", "sweets", "trans fats", "cream"],
                "prefer": ["fish", "oats", "berries", "avocados", "olive oil", "nuts"]
            },
            "pcos": {
                "avoid": ["sugar", "refined carbs", "dairy", "processed meats", "syrups"],
                "prefer": ["lean protein", "fiber", "anti-inflammatory foods", "omega-3", "spearmint tea"]
            },
            "kidney": {
                "avoid": ["salt", "high potassium foods", "phosphorus-rich foods", "processed meats"],
                "prefer": ["apples", "berries", "white rice", "cauliflower", "egg whites"]
            },
            "lactose_intolerance": {
                "avoid": ["milk", "cheese", "butter", "yogurt", "cream"],
                "prefer": ["lactose-free milk", "almond milk", "soy milk", "tofu"]
            },
            "gluten_allergy": {
                "avoid": ["wheat", "barley", "rye", "bread", "pasta"],
                "prefer": ["rice", "quinoa", "corn", "gluten-free oats"]
            }
        }

    def get_conditions(self) -> List[str]:
        """
        Get a list of supported medical conditions.
        """
        return list(self.medical_conditions_rules.keys())

    def get_rules(self, condition: str) -> Dict[str, List[str]]:
        """
        Get dietary rules for a given condition.
        """
        return self.medical_conditions_rules.get(condition, {})

    def filter_meals(
        self,
        meals: List[Dict[str, Any]],
        conditions: List[str]
    ) -> List[Dict[str, Any]]:
        """
        Filter out meals that contain ingredients which conflict with any of the user's conditions.

        :param meals: List of meals (each meal must have a 'name' and 'ingredients' key)
        :param conditions: List of medical conditions
        :return: List of suitable meals
        """
        avoid_ingredients = self._aggregate_avoid_list(conditions)
        return [meal for meal in meals if not self._has_avoid_ingredients(meal, avoid_ingredients)]

    def score_meal(
        self,
        meal: Dict[str, Any],
        condition: str
    ) -> int:
        """
        Score a meal based on how well it aligns with a medical condition.

        :param meal: A single meal
        :param condition: The medical condition to score against
        :return: Score (positive values are good, negative are bad)
        """
        rules = self.get_rules(condition)
        score = 0
        for ing in meal.get("ingredients", []):
            if ing.lower() in rules.get("avoid", []):
                score -= 5
            if ing.lower() in rules.get("prefer", []):
                score += 5
        return score

    def _aggregate_avoid_list(self, conditions: List[str]) -> List[str]:
        """
        Merge avoid lists from all conditions.

        :param conditions: List of conditions
        :return: Flattened list of ingredients to avoid
        """
        avoid_set = set()
        for cond in conditions:
            cond_rules = self.medical_conditions_rules.get(cond, {})
            avoid_set.update([i.lower() for i in cond_rules.get("avoid", [])])
        return list(avoid_set)

    def _has_avoid_ingredients(self, meal: Dict[str, Any], avoid_list: List[str]) -> bool:
        """
        Check if a meal contains any avoidable ingredients.

        :param meal: A meal dictionary
        :param avoid_list: List of ingredients to avoid
        :return: True if any ingredient is in the avoid list
        """
        for ingredient in meal.get("ingredients", []):
            if ingredient.lower() in avoid_list:
                return True
        return False

    def get_reasons_for_rejection(
        self,
        meal: Dict[str, Any],
        conditions: List[str]
    ) -> List[str]:
        """
        Get reasons why a meal is rejected.

        :param meal: Meal to evaluate
        :param conditions: List of medical conditions
        :return: List of problematic ingredients
        """
        reasons = []
        for cond in conditions:
            cond_rules = self.medical_conditions_rules.get(cond, {})
            avoid_set = set(i.lower() for i in cond_rules.get("avoid", []))
            for ing in meal.get("ingredients", []):
                if ing.lower() in avoid_set and ing.lower() not in reasons:
                    reasons.append(ing.lower())
        return reasons


# Example usage (you may remove or wrap under __main__ in production)
if __name__ == "__main__":
    filter_service = MedicalFilterService()

    sample_meals = [
        {"name": "White Rice and Chicken", "ingredients": ["white rice", "chicken", "salt", "pepper"]},
        {"name": "Berry Smoothie", "ingredients": ["berries", "milk", "honey"]},
        {"name": "Oats and Banana", "ingredients": ["oats", "banana", "milk"]},
        {"name": "Grilled Fish with Vegetables", "ingredients": ["fish", "carrot", "olive oil"]},
        {"name": "Cheese Sandwich", "ingredients": ["bread", "cheese", "butter"]},
        {"name": "Avocado Salad", "ingredients": ["avocado", "spinach", "olive oil", "tomato"]},
    ]

    user_conditions = ["diabetes", "heart"]
    suitable_meals = filter_service.filter_meals(sample_meals, user_conditions)

    print("Suitable Meals:")
    for meal in suitable_meals:
        print(f"- {meal['name']}")

    print("\nScoring Example:")
    for meal in sample_meals:
        score = filter_service.score_meal(meal, "heart")
        print(f"{meal['name']}: {score}")

    print("\nRejection Reasons:")
    for meal in sample_meals:
        reasons = filter_service.get_reasons_for_rejection(meal, user_conditions)
        if reasons:
            print(f"{meal['name']} - Avoid: {', '.join(reasons)}")
