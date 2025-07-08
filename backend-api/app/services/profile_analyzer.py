# File: app/services/profile_analyzer.py

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

from app.models.user_model import UserInDB
from app.models.medical_model import MedicalRecord
from app.models.mealplan_model import MealPlan
from app.services.medical_filter import MedicalFilter
from app.services.nutrition_analyzer import NutritionAnalyzer
from app.services.meal_generator import MealGenerator

# Logging setup
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(name)s | %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

# Constants
DEFAULT_GOAL = "maintain"
DEFAULT_ACTIVITY_LEVEL = "moderate"
DEFAULT_BUDGET = "medium"
DEFAULT_DIET_TYPE = "balanced"
DEFAULT_CUISINE = "Indian"
DEFAULT_MODE = "eco"

class ProfileAnalyzer:
    """
    Analyze a user's lifestyle, medical, and dietary preferences
    to generate a holistic nutrition profile and personalized meal plan.
    """

    def __init__(self, user: UserInDB, medical_record: Optional[MedicalRecord] = None):
        self.user = user
        self.medical_record = medical_record
        self.profile_summary: Dict[str, Any] = {}
        self.activity_score = 0
        self.recommendation_score = 0.0

    def analyze(self) -> Dict[str, Any]:
        """
        Full profile analysis pipeline. This method runs the complete
        data pipeline to prepare a nutritional profile.
        """
        logger.info(f"🔍 Starting profile analysis for user: {self.user.email}")

        try:
            self._extract_basics()
            self._analyze_preferences()
            self._analyze_medical_data()
            self._compute_activity_score()
            self._generate_profile_summary()
        except Exception as e:
            logger.error(f"❌ Error during analysis: {str(e)}", exc_info=True)
            raise

        logger.info(f"✅ Profile analysis complete for user: {self.user.email}")
        return self.profile_summary

    def _extract_basics(self):
        """
        Extracts basic personal information for the user.
        """
        logger.debug("📌 Extracting basic user details...")
        self.profile_summary["name"] = self.user.name
        self.profile_summary["email"] = self.user.email
        self.profile_summary["gender"] = self.user.gender
        self.profile_summary["age"] = self._calculate_age(self.user.dob)

    def _calculate_age(self, dob: str) -> int:
        """
        Calculate the user's age from their date of birth.
        """
        try:
            birth_date = datetime.strptime(dob, "%Y-%m-%d")
            today = datetime.today()
            age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))
            logger.debug(f"🎂 Calculated age: {age}")
            return age
        except Exception as e:
            logger.error(f"⚠️ Invalid date format for DOB: {dob} | Error: {str(e)}")
            return 0

    def _analyze_preferences(self):
        """
        Analyze user dietary preferences and lifestyle configurations.
        """
        logger.debug("🍽️ Analyzing user dietary and lifestyle preferences...")
        preferences = self.user.preferences or {}

        self.profile_summary["goal"] = preferences.get("goal", DEFAULT_GOAL).lower()
        self.profile_summary["activity_level"] = preferences.get("activity_level", DEFAULT_ACTIVITY_LEVEL).lower()
        self.profile_summary["budget"] = preferences.get("budget", DEFAULT_BUDGET).lower()
        self.profile_summary["diet_type"] = preferences.get("diet_type", DEFAULT_DIET_TYPE).lower()
        self.profile_summary["excluded_items"] = preferences.get("excluded_items", [])
        self.profile_summary["cuisine"] = preferences.get("preferred_cuisine", DEFAULT_CUISINE).lower()
        self.profile_summary["mode"] = preferences.get("mode", DEFAULT_MODE).lower()

    def _analyze_medical_data(self):
        """
        Use medical filters to tag dietary flags.
        """
        logger.debug("🩺 Analyzing medical data...")
        if not self.medical_record:
            logger.warning("⚠️ No medical record found. Skipping medical analysis.")
            self.profile_summary["medical_flags"] = []
            return

        medical_flags = MedicalFilter.filter_conditions(self.medical_record.conditions)
        self.profile_summary["medical_flags"] = medical_flags
        logger.debug(f"📋 Identified medical flags: {medical_flags}")

    def _compute_activity_score(self):
        """
        Derive a normalized activity score from user-defined level.
        """
        logger.debug("💪 Computing activity score...")
        activity_map = {
            "sedentary": 1,
            "light": 2,
            "moderate": 3,
            "active": 4,
            "very active": 5
        }

        level = self.profile_summary.get("activity_level", DEFAULT_ACTIVITY_LEVEL).lower()
        self.activity_score = activity_map.get(level, 3)
        self.profile_summary["activity_score"] = self.activity_score
        logger.debug(f"🏃 Activity level '{level}' mapped to score {self.activity_score}")

    def _generate_profile_summary(self):
        """
        Final computation of risk and recommendation score.
        """
        logger.debug("📊 Generating profile recommendation summary...")

        summary = {
            "recommendation_score": self._calculate_recommendation_score(),
            "risk_level": self._estimate_risk_level(),
            "lifestyle_mode": self.profile_summary.get("mode", DEFAULT_MODE)
        }

        self.profile_summary.update(summary)
        logger.debug(f"✅ Final summary: {summary}")

    def _calculate_recommendation_score(self) -> float:
        """
        Compute a recommendation score based on age, activity, and medical risk.
        """
        base = 50.0
        age_penalty = 0.5 * self.profile_summary["age"]
        activity_bonus = 5 * self.activity_score
        risk_penalty = 0

        if "obesity" in self.profile_summary.get("medical_flags", []):
            risk_penalty += 10
        if "hypertension" in self.profile_summary.get("medical_flags", []):
            risk_penalty += 5
        if "diabetes" in self.profile_summary.get("medical_flags", []):
            risk_penalty += 5

        score = max(0, min(100, base - age_penalty + activity_bonus - risk_penalty))
        self.recommendation_score = round(score, 2)
        logger.debug(f"📈 Recommendation score: {self.recommendation_score}")
        return self.recommendation_score

    def _estimate_risk_level(self) -> str:
        """
        Estimate risk level based on medical conditions.
        """
        flags = self.profile_summary.get("medical_flags", [])
        if "hypertension" in flags and "diabetes" in flags:
            return "high"
        elif "obesity" in flags:
            return "medium"
        return "low"

    def generate_recommendations(self) -> MealPlan:
        """
        Generate a personalized meal plan based on analyzed profile.
        """
        logger.info(f"📦 Generating personalized meal plan for {self.user.email}")

        try:
            nutrition_goals = NutritionAnalyzer.analyze_goals(self.profile_summary)
            meal_plan = MealGenerator.generate(
                preferences=self.user.preferences,
                nutrition_profile=nutrition_goals,
                medical_flags=self.profile_summary.get("medical_flags", [])
            )
            logger.info("🥗 Meal plan generation successful.")
            return meal_plan
        except Exception as e:
            logger.error(f"❌ Meal generation failed: {str(e)}", exc_info=True)
            raise

    def debug_summary(self):
        """
        Pretty-print the profile summary.
        """
        import pprint
        logger.debug("🛠️ Debugging profile summary:")
        pprint.pprint(self.profile_summary)

# ──────────────────────────────────────────────────────────────
# CLI runner for standalone debugging/testing purposes
# ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    from app.models.user_model import UserInDB
    from app.models.medical_model import MedicalRecord

    sample_user = UserInDB(
        id="u123",
        name="Devanarayanan",
        email="dev@nutriplan.ai",
        dob="2000-05-20",
        gender="male",
        hashed_password="testhash",
        role="user",
        preferences={
            "goal": "weight loss",
            "diet_type": "vegan",
            "activity_level": "active",
            "budget": "low",
            "excluded_items": ["sugar", "red meat"],
            "preferred_cuisine": "South Indian",
            "mode": "eco"
        }
    )

    sample_medical = MedicalRecord(
        user_id="u123",
        conditions=["hypertension", "diabetes"],
        allergies=["peanuts"]
    )

    analyzer = ProfileAnalyzer(user=sample_user, medical_record=sample_medical)
    profile = analyzer.analyze()
    analyzer.debug_summary()

    plan = analyzer.generate_recommendations()
    print("\n📦 Final Meal Plan Output:")
    print(plan.json(indent=2))
