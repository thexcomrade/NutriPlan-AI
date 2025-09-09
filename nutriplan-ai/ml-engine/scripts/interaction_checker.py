"""
NutriPlan AI - Food-Medication Interaction Checker (Kerala/India Focus)
=======================================================================

A specialized system detecting interactions between Indian foods and medications
with cultural sensitivity and regional dietary patterns consideration.
"""

import json
import logging
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
from tensorflow.keras.models import load_model
import matplotlib.pyplot as plt
import seaborn as sns

# Configure premium styling
plt.style.use('seaborn-darkgrid')
sns.set_palette("husl")
logging.basicConfig(
    level=logging.INFO,
    format="\033[1;34m%(asctime)s\033[0m - \033[1;32m%(name)s\033[0m - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("KeralaInteractionChecker")

# Constants
MODEL_PATH = "../models/"
INDIAN_FOOD_DB = "../data/external/indian_foods.csv"
AYURVEDIC_MED_DB = "../data/external/ayurvedic_interactions.json"

SEVERITY = {
    0: "🟢 Safe",
    1: "🟡 Minor - Monitor",
    2: "🟠 Moderate - Avoid",
    3: "🔴 Severe - Danger"
}

@dataclass
class KeralaPatient:
    """Patient profile for Kerala/Indian demographics"""
    name: str
    age: int
    gender: str
    weight: float  # in kg
    height: float  # in cm
    medications: List[str]
    conditions: List[str]
    diet: List[str]  # Typical Kerala/Indian foods
    is_vegetarian: bool
    region: str = "Kerala"

class InteractionChecker:
    def __init__(self):
        """Initialize with Kerala-specific models"""
        try:
            self.food_db = pd.read_csv(INDIAN_FOOD_DB)
            with open(AYURVEDIC_MED_DB) as f:
                self.med_db = json.load(f)
            
            self.model = joblib.load(f"{MODEL_PATH}kerala_interaction_model.pkl")
            self.severity_model = load_model(f"{MODEL_PATH}severity_model.h5")
            
            logger.info("Loaded Kerala-specific interaction models")
        except Exception as e:
            logger.error(f"Initialization failed: {str(e)}")
            raise

    def check_interactions(self, patient: KeralaPatient) -> List[Dict]:
        """Check for food-drug interactions for Kerala patient"""
        results = []
        
        for med in patient.medications:
            for food in patient.diet:
                # Skip vegetarian checks for non-veg meds
                if patient.is_vegetarian and self._is_non_veg_medicine(med):
                    continue
                    
                interaction, severity = self._predict_interaction(med, food)
                
                if interaction:
                    results.append({
                        "medicine": med,
                        "food": food,
                        "severity": severity,
                        "advice": self._generate_advice(med, food, severity, patient)
                    })
        
        return sorted(results, key=lambda x: x["severity"], reverse=True)

    def _predict_interaction(self, medicine: str, food: str) -> Tuple[bool, int]:
        """Predict interaction probability and severity"""
        try:
            # Get features
            med_features = self._get_medicine_features(medicine)
            food_features = self._get_food_features(food)
            
            # Combine features
            features = np.concatenate([
                med_features, 
                food_features,
                [1 if "ayurveda" in medicine.lower() else 0]
            ]).reshape(1, -1)
            
            # Predict
            proba = self.model.predict_proba(features)[0][1]
            if proba > 0.65:  # Interaction threshold
                severity = np.argmax(self.severity_model.predict(features))
                return True, severity
            return False, 0
        except Exception as e:
            logger.warning(f"Prediction error for {medicine}-{food}: {str(e)}")
            return False, 0

    def _get_medicine_features(self, medicine: str) -> np.ndarray:
        """Get pharmacological features for medicine"""
        default = np.zeros(10)
        return np.array(self.med_db.get(medicine.lower(), {}).get("features", default))

    def _get_food_features(self, food: str) -> np.ndarray:
        """Get nutritional features for Kerala food"""
        food_data = self.food_db[self.food_db["name"].str.lower() == food.lower()]
        if food_data.empty:
            return np.zeros(15)
        return food_data.iloc[0, 1:16].to_numpy()

    def _is_non_veg_medicine(self, medicine: str) -> bool:
        """Check if medicine contains non-vegetarian ingredients"""
        return self.med_db.get(medicine.lower(), {}).get("non_veg", False)

    def _generate_advice(self, med: str, food: str, severity: int, patient: KeralaPatient) -> str:
        """Generate culturally appropriate advice"""
        # Kerala-specific advice
        kerala_advice = {
            ("warfarin", "spinach"): "Avoid during Onam festival when leafy greens consumption is high",
            ("diabetes_meds", "banana"): "Limit nendran banana intake to half pieces",
            ("blood_pressure_meds", "coconut"): "Reduce coconut chutney portions"
        }
        
        # General advice templates
        advice_templates = {
            1: f"Monitor when consuming {food} with {med}",
            2: f"Avoid {food} 2 hours before/after {med}",
            3: f"STRICTLY AVOID {food} with {med}. Consult doctor immediately."
        }
        
        # Return specific advice if available
        return kerala_advice.get(
            (med.lower(), food.lower()), 
            advice_templates.get(severity, "No specific advice")
        )

    def generate_report(self, results: List[Dict], patient: KeralaPatient):
        """Generate beautiful visual report"""
        if not results:
            print("\n✅ No dangerous interactions found for", patient.name)
            return
            
        print(f"\n📝 Interaction Report for {patient.name} ({patient.region})")
        print("="*60)
        
        for idx, item in enumerate(results, 1):
            print(f"\n{idx}. {item['medicine']} + {item['food']}")
            print(f"   {SEVERITY[item['severity']]}")
            print(f"   💡 Advice: {item['advice']}")
        
        # Plot severity distribution
        self._plot_severity(results)

    def _plot_severity(self, results: List[Dict]):
        """Create visualization of interaction severities"""
        severities = [r["severity"] for r in results]
        labels = [SEVERITY[s].split("-")[0].strip() for s in severities]
        
        plt.figure(figsize=(10, 6))
        sns.countplot(x=severities, hue=labels, dodge=False)
        plt.title("Food-Medication Interaction Severity", pad=20)
        plt.xlabel("Severity Level")
        plt.ylabel("Count")
        plt.xticks(ticks=[0,1,2,3], labels=["Safe", "Minor", "Moderate", "Severe"])
        plt.tight_layout()
        plt.savefig("interaction_report.png", dpi=300)
        print("\n📊 Report visualization saved to interaction_report.png")

# Example Usage with Kerala Patient
if __name__ == "__main__":
    print("\n" + "="*60)
    print("🇮🇳 NutriPlan AI - Kerala Interaction Checker")
    print("="*60)
    
    # Sample Kerala patient
    rajesh = KeralaPatient(
        name="Rajesh Pillai",
        age=62,
        gender="male",
        weight=78,
        height=168,
        medications=["Warfarin", "Metformin", "Ayurvedic Liver Tonic"],
        conditions=["Diabetes", "Heart Disease"],
        diet=["Rice", "Fish Curry", "Spinach Thoran", "Banana", "Coconut Chutney"],
        is_vegetarian=False
    )
    
    try:
        checker = InteractionChecker()
        print("\n🔍 Analyzing diet for Rajesh Pillai (Kerala)...")
        
        results = checker.check_interactions(rajesh)
        checker.generate_report(results, rajesh)
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")