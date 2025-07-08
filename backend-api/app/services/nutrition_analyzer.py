# File: app/services/nutrition_analyzer.py

import logging
from typing import Dict, List, Tuple, Optional
from decimal import Decimal
from app.models.mealplan_model import MealPlan
from app.models.medical_model import MedicalRecord
from app.models.user_model import UserInDB
from app.utils.Constants import NUTRIENT_RDA, CRITICAL_NUTRIENT_THRESHOLDS

logger = logging.getLogger(__name__)

# === Nutrition Data Types === #
class NutrientProfile:
    def __init__(self, calories=0.0, protein=0.0, fat=0.0, carbs=0.0, fiber=0.0, vitamins=None, minerals=None):
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiber = fiber
        self.vitamins = vitamins or {}
        self.minerals = minerals or {}

    def to_dict(self):
        return {
            "calories": self.calories,
            "protein": self.protein,
            "fat": self.fat,
            "carbs": self.carbs,
            "fiber": self.fiber,
            "vitamins": self.vitamins,
            "minerals": self.minerals,
        }

# === Analyzer Service === #
class NutritionAnalyzerService:

    @staticmethod
    def analyze_meal_nutrients(mealplan: MealPlan) -> NutrientProfile:
        logger.info("Analyzing nutritional data for meal: %s", mealplan.title)
        
        nutrients = NutrientProfile(
            calories=mealplan.total_calories,
            protein=mealplan.total_protein,
            fat=mealplan.total_fat,
            carbs=mealplan.total_carbs,
            fiber=mealplan.total_fiber,
            vitamins=mealplan.vitamins or {},
            minerals=mealplan.minerals or {}
        )
        
        logger.debug("Meal NutrientProfile: %s", nutrients.to_dict())
        return nutrients

    @staticmethod
    def check_against_rda(nutrients: NutrientProfile) -> Dict[str, str]:
        logger.info("Checking nutrients against Recommended Daily Allowance (RDA)")
        feedback = {}

        for nutrient, recommended in NUTRIENT_RDA.items():
            user_value = getattr(nutrients, nutrient, 0.0)
            if user_value < 0.5 * recommended:
                feedback[nutrient] = "⚠️ Significantly below RDA"
            elif user_value > 1.5 * recommended:
                feedback[nutrient] = "❗ Above recommended levels"
            else:
                feedback[nutrient] = "✅ Within healthy range"

        return feedback

    @staticmethod
    def flag_dietary_issues(nutrients: NutrientProfile, medical: Optional[MedicalRecord] = None) -> List[str]:
        logger.info("Flagging potential dietary issues")
        warnings = []

        for nutrient, limit in CRITICAL_NUTRIENT_THRESHOLDS.items():
            value = getattr(nutrients, nutrient, 0.0)
            if value > limit:
                warnings.append(f"⚠️ High {nutrient} detected: {value} > {limit}")

        if medical:
            if medical.conditions.get("diabetes", False):
                if nutrients.carbs > 150:
                    warnings.append("⚠️ Carbohydrate intake too high for diabetic condition")
            if medical.conditions.get("hypertension", False):
                if nutrients.minerals.get("sodium", 0) > 1500:
                    warnings.append("⚠️ High sodium intake not recommended for hypertension")

        return warnings

    @staticmethod
    def score_nutritional_balance(nutrients: NutrientProfile) -> float:
        logger.info("Scoring nutritional balance")
        score = 0.0
        ideal_macros = {"protein": 20, "fat": 25, "carbs": 55}  # Percent of total calories

        try:
            total_cal = nutrients.calories
            actual_ratios = {
                "protein": (nutrients.protein * 4 / total_cal) * 100 if total_cal else 0,
                "fat": (nutrients.fat * 9 / total_cal) * 100 if total_cal else 0,
                "carbs": (nutrients.carbs * 4 / total_cal) * 100 if total_cal else 0,
            }

            for macro, ideal in ideal_macros.items():
                diff = abs(actual_ratios[macro] - ideal)
                score += max(0, 100 - diff * 2)  # Penalize deviation

            return round(score / 3, 2)
        except Exception as e:
            logger.error("Failed to score nutritional balance: %s", e)
            return 0.0

    @staticmethod
    def suggest_nutrient_adjustments(nutrients: NutrientProfile) -> Dict[str, str]:
        logger.info("Suggesting nutrient adjustments")
        suggestions = {}

        if nutrients.protein < 40:
            suggestions["protein"] = "Add lean meats, tofu, or legumes"
        if nutrients.fiber < 20:
            suggestions["fiber"] = "Include more fruits, vegetables, or oats"
        if nutrients.fat > 80:
            suggestions["fat"] = "Reduce oils, cheese, or fried foods"
        if nutrients.carbs > 300:
            suggestions["carbs"] = "Cut back on rice, sugar, or bread"

        return suggestions

    @staticmethod
    def personalized_feedback(user: UserInDB, medical: MedicalRecord, nutrients: NutrientProfile) -> Dict[str, str]:
        logger.info("Generating personalized dietary feedback")

        feedback = {}
        mode = user.preferences.get("mode", "eco")

        if mode == "eco":
            if nutrients.calories > 2500:
                feedback["calories"] = "⚠️ Consider reducing high-calorie ingredients for sustainability"
            if nutrients.fat > 80:
                feedback["eco_fat"] = "Eco tip: Reduce saturated fats to help heart & planet"

        if medical.conditions.get("anemia", False):
            if nutrients.minerals.get("iron", 0) < 10:
                feedback["iron"] = "⚠️ Consider iron-rich foods like spinach, legumes, or red meat"

        return feedback

# === Utility Method (If Needed) === #
def summarize_analysis(user: UserInDB, mealplan: MealPlan, medical: Optional[MedicalRecord] = None) -> Dict[str, any]:
    logger.info("Running full nutrition analysis summary")
    
    analyzer = NutritionAnalyzerService
    nutrients = analyzer.analyze_meal_nutrients(mealplan)
    rda_check = analyzer.check_against_rda(nutrients)
    warnings = analyzer.flag_dietary_issues(nutrients, medical)
    balance_score = analyzer.score_nutritional_balance(nutrients)
    suggestions = analyzer.suggest_nutrient_adjustments(nutrients)
    feedback = analyzer.personalized_feedback(user, medical, nutrients)

    return {
        "nutrients": nutrients.to_dict(),
        "rda_check": rda_check,
        "warnings": warnings,
        "balance_score": balance_score,
        "suggestions": suggestions,
        "personalized_feedback": feedback
    }
