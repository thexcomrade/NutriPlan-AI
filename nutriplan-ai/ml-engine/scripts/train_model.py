import os
import json
import pickle
import time
import re
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import LabelEncoder, StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, accuracy_score, f1_score
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.base import BaseEstimator, TransformerMixin
from rich import print
from rich.panel import Panel
import warnings
warnings.filterwarnings('ignore')

# =================================================================================
# CONFIGURATION
# =================================================================================
BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"
DATA_DIR = BASE_DIR / "data" / "processed"
EHR_DIR = BASE_DIR / "data" / "ehr"

MODEL_CONFIG = {
    "profile_classifier": {
        "data_file": "user_profiles.csv",
        "ehr_fields": ["age", "gender", "bmi", "medical_conditions", "allergies", "dietary_goals"],
        "target_col": "user_profile",
        "output_model": "profile_classifier.pkl",
        "output_metadata": "profile_classifier_encoders.json",
        "gymrat_params": {"protein_min": 1.6, "calorie_range": (2500, 3000)}
    },
    "meal_recommender": {
        "data_file": "meal_ratings.csv",
        "ehr_fields": ["user_profile", "medical_conditions", "allergies", "budget"],
        "target_col": "meal_rating",
        "output_model": "meal_recommender.pkl",
        "output_metadata": "meal_recommender_encoders.json",
        "gymrat_params": {"protein_boost": 1.3}
    },
    "medsafe_meal_filter": {
        "data_file": "meal_safety.csv",
        "ehr_fields": ["medical_conditions", "allergies", "medications"],
        "target_col": "is_safe",
        "output_model": "medsafe_meal_filter.pkl",
        "output_metadata": "medsafe_meal_filter_encoders.json",
        "contraindication_threshold": 0.85
    }
}

# =================================================================================
# EHR PROCESSING CLASSES
# =================================================================================
class EHRProcessor:
    @staticmethod
    def extract_from_prescription(text):
        conditions = re.findall(r"diagnos(?:e|is):?\s*([\w\s,]+)", text, re.I)
        medications = re.findall(r"medicat(?:ion|e):?\s*([\w\s,]+)", text, re.I)
        allergies = re.findall(r"allerg(?:y|ies):?\s*([\w\s,]+)", text, re.I)
        return {
            "medical_conditions": [c.strip() for c in conditions[0].split(",")] if conditions else [],
            "medications": [m.strip() for m in medications[0].split(",")] if medications else [],
            "allergies": [a.strip() for a in allergies[0].split(",")] if allergies else []
        }

class MultilingualEncoder:
    SUPPORTED_LANGUAGES = ['en', 'hi', 'ta', 'ml']
    def __init__(self):
        self.language_encoders = {lang: CountVectorizer() for lang in self.SUPPORTED_LANGUAGES}

    def detect_language(self, text):
        if any(char in text for char in ['ं', 'ो', '्', 'ा']):
            return 'hi'
        elif any(char in text for char in ['ா', 'ி', 'ீ', 'ு']):
            return 'ta'
        elif any(char in text for char in ['ാ', 'ി', 'ീ', 'ു']):
            return 'ml'
        return 'en'

    def fit(self, texts):
        for text in texts:
            lang = self.detect_language(text)
            self.language_encoders[lang].fit([text])

    def transform(self, texts):
        features = []
        for text in texts:
            lang = self.detect_language(text)
            vector = self.language_encoders[lang].transform([text])
            features.append(vector.toarray().flatten())
        return np.vstack(features)

# =================================================================================
# NUTRITIONIST FEEDBACK INTEGRATION
# =================================================================================
class FeedbackIntegrator:
    def __init__(self, model_name, config):
        self.model_name = model_name
        self.config = config
        self.feedback_dir = BASE_DIR / "feedback" / model_name
        self.feedback_dir.mkdir(parents=True, exist_ok=True)

    def load_feedback(self):
        feedback_data = []
        for fb_file in self.feedback_dir.glob("*.json"):
            with open(fb_file, 'r') as f:
                feedback_data.append(json.load(f))
        return feedback_data

    def apply_feedback(self, X, y):
        feedback = self.load_feedback()
        for fb in feedback:
            if fb['action'] == 'correction':
                new_row = fb['corrected_features']
                new_row[self.config['target_col']] = fb['corrected_label']
                X = pd.concat([X, pd.DataFrame([new_row])], ignore_index=True)
                y = pd.concat([y, pd.Series([fb['corrected_label']])], ignore_index=True)
            elif fb['action'] == 'constraint' and self.model_name == "medsafe_meal_filter":
                unsafe_idx = X[
                    (X[fb['feature']] == fb['value']) &
                    (y == 1)
                ].index
                y.loc[unsafe_idx] = 0
        return X, y

# =================================================================================
# GYMRAT OPTIMIZER
# =================================================================================
class GymratOptimizer(BaseEstimator, TransformerMixin):
    def __init__(self, protein_boost=1.2, calorie_range=(2500, 3000)):
        self.protein_boost = protein_boost
        self.calorie_range = calorie_range

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        X = X.copy()
        if 'user_profile' in X.columns:
            gymrat_mask = X['user_profile'].str.contains('gymrat|bodybuilder', case=False)
            if 'protein_grams' in X.columns:
                X.loc[gymrat_mask, 'protein_grams'] *= self.protein_boost
            if 'calorie_target' in X.columns:
                X.loc[gymrat_mask, 'calorie_target'] = X.loc[gymrat_mask, 'calorie_target'].apply(
                    lambda x: min(max(x, self.calorie_range[0]), self.calorie_range[1])
                )
        return X

# =================================================================================
# CONTRADICTION FILTER
# =================================================================================
class ContradictionThreshold(BaseEstimator, TransformerMixin):
    def __init__(self, threshold=0.85):
        self.threshold = threshold
        self.contraindications = {
            'diabetes': ['high_sugar', 'simple_carbs'],
            'hypertension': ['high_sodium'],
            'celiac': ['gluten'],
            'lactose_intolerant': ['dairy'],
            'nut_allergy': ['nuts', 'peanuts']
        }

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        for condition, triggers in self.contraindications.items():
            if condition in X.columns:
                for trigger in triggers:
                    if trigger in X.columns:
                        contraindicated = (X[condition] > 0.5) & (X[trigger] > self.threshold)
                        X.loc[contraindicated, trigger] = 0
        return X

# =================================================================================
# HELPERS
# =================================================================================
def load_and_validate_data(data_path, ehr_dir, target_col, ehr_fields):
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"Data file not found: {data_path}")
    df = pd.read_csv(data_path)
    ehr_data = []
    for ehr_file in ehr_dir.glob("*.json"):
        with open(ehr_file, 'r') as f:
            ehr_data.append(json.load(f))
    if ehr_data:
        ehr_df = pd.DataFrame(ehr_data)
        df = df.merge(ehr_df[ehr_fields + ['user_id']], on='user_id', how='left')
    if target_col not in df.columns:
        raise ValueError(f"Target column '{target_col}' missing in dataset")
    return df

def get_preprocessor(X):
    numeric_features = X.select_dtypes(include=np.number).columns.tolist()
    categorical_features = X.select_dtypes(exclude=np.number).columns.tolist()
    text_features = [col for col in categorical_features if X[col].apply(lambda x: isinstance(x, str) and len(x) > 20).any()]
    categorical_features = list(set(categorical_features) - set(text_features))
    preprocessor = ColumnTransformer([
        ('num', StandardScaler(), numeric_features),
        ('cat', OneHotEncoder(handle_unknown='ignore'), categorical_features),
        ('text', MultilingualEncoder(), text_features)
    ])
    return preprocessor, numeric_features, categorical_features, text_features

def save_metadata(encoders, file_path):
    metadata = {}
    for col, encoder in encoders.items():
        if hasattr(encoder, 'classes_'):
            metadata[col] = {
                'type': 'LabelEncoder',
                'mapping': {i: cls for i, cls in enumerate(encoder.classes_)}
            }
    with open(file_path, 'w') as f:
        json.dump(metadata, f, indent=2)

# =================================================================================
# TRAINING FUNCTION
# =================================================================================
def train_model(model_name, config):
    print(Panel.fit(f"🚀 Training [bold cyan]{model_name.replace('_', ' ').title()}[/]", border_style="cyan"))
    start = time.time()

    df = load_and_validate_data(DATA_DIR / config['data_file'], EHR_DIR, config['target_col'], config.get('ehr_fields', []))
    if "feedback" in config:
        feedback = FeedbackIntegrator(model_name, config)
        X, y = feedback.apply_feedback(df.drop(columns=[config['target_col']]), df[config['target_col']])
    else:
        y = df[config['target_col']]
        X = df.drop(columns=[config['target_col']])

    if model_name == "meal_recommender":
        gym = GymratOptimizer(**config.get('gymrat_params', {}))
        X = gym.transform(X)

    target_encoder = LabelEncoder()
    y_encoded = target_encoder.fit_transform(y)
    preprocessor, num_cols, cat_cols, text_cols = get_preprocessor(X)

    pipeline_steps = [('preprocessor', preprocessor), ('classifier', RandomForestClassifier(random_state=42, class_weight='balanced', n_jobs=-1))]
    if model_name == "medsafe_meal_filter":
        pipeline_steps.insert(1, ('safety_filter', ContradictionThreshold(config.get('contraindication_threshold', 0.85))))
    pipeline = Pipeline(pipeline_steps)

    param_grid = {
        'classifier__n_estimators': [100],
        'classifier__max_depth': [None, 10],
        'classifier__min_samples_split': [2],
        'classifier__min_samples_leaf': [1]
    }

    X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42)
    grid_search = GridSearchCV(pipeline, param_grid, cv=5, scoring='f1_weighted', n_jobs=-1, verbose=1)
    grid_search.fit(X_train, y_train)

    best_model = grid_search.best_estimator_
    y_pred = best_model.predict(X_test)

    print(f"Accuracy: {accuracy_score(y_test, y_pred):.4f} | F1 Score: {f1_score(y_test, y_pred, average='weighted'):.4f}")
    print(classification_report(y_test, y_pred, target_names=target_encoder.classes_))

    model_path = MODELS_DIR / config['output_model']
    metadata_path = MODELS_DIR / config['output_metadata']

    with open(model_path, 'wb') as f:
        pickle.dump({'model': best_model, 'metadata': {'features': {'numeric': num_cols, 'categorical': cat_cols, 'text': text_cols}, 'target_encoder': target_encoder}}, f)
    save_metadata({config['target_col']: target_encoder}, metadata_path)

    print(f"Saved: [green]{model_path}[/] + metadata")

# =================================================================================
# MAIN
# =================================================================================
if __name__ == "__main__":
    print(Panel.fit("🧠 [bold magenta]NutriPlan AI - Model Trainer[/]", border_style="magenta"))
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    EHR_DIR.mkdir(parents=True, exist_ok=True)
    for model_name, config in MODEL_CONFIG.items():
        try:
            train_model(model_name, config)
            print("\n" + "="*80 + "\n")
        except Exception as e:
            print(f"[bold red]❌ Error training {model_name}: {e}[/]")
            import traceback
            traceback.print_exc()
