# D:\nutriplan-ai\ml-engine\scripts\preprocess.py

import os
import pandas as pd
import numpy as np
import json
import re
from datetime import datetime
from typing import List, Dict
from sklearn.preprocessing import LabelEncoder, StandardScaler
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import track

# ========== Global Console ==========
console = Console()

# ========== File Paths ==========
BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
OUTPUT_DIR = os.path.join(DATA_DIR, "processed")

os.makedirs(OUTPUT_DIR, exist_ok=True)

FILES = {
    "food": os.path.join(DATA_DIR, "food_nutrition_db.csv"),
    "medical": os.path.join(DATA_DIR, "medical_diet_db.csv"),
    "interaction": os.path.join(DATA_DIR, "meds_and_diet_interactions.csv"),
    "profiles": os.path.join(DATA_DIR, "user_profiles.csv")
}

# ========== Load CSVs ==========
def load_datasets() -> Dict[str, pd.DataFrame]:
    console.rule("[bold green]📂 Loading Datasets")
    dfs = {}
    for name, path in FILES.items():
        try:
            df = pd.read_csv(path)
            dfs[name] = df
            console.print(f"✅ Loaded [bold]{name}[/bold] — {df.shape[0]} rows, {df.shape[1]} columns.")
        except Exception as e:
            console.print(f"[red]❌ Failed to load {name}: {e}")
    return dfs

# ========== Normalize & Clean ==========
def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    df.columns = [col.strip().lower().replace(" ", "_") for col in df.columns]
    df = df.applymap(lambda x: str(x).strip().lower() if isinstance(x, str) else x)
    df.dropna(how='all', inplace=True)
    df.drop_duplicates(inplace=True)
    return df.reset_index(drop=True)

# ========== Profile Feature Engineering ==========
def encode_profiles(df: pd.DataFrame) -> pd.DataFrame:
    le = LabelEncoder()
    for col in ['gender', 'goal', 'lifestyle']:
        df[f'{col}_encoded'] = le.fit_transform(df[col])
    df['bmi'] = df['weight_kg'] / ((df['height_cm'] / 100) ** 2)
    df['bmi'] = df['bmi'].round(2)
    return df

# ========== Disease-Food Mapping ==========
def generate_disease_food_map(df: pd.DataFrame, output_path: str):
    mapping = {}
    for _, row in df.iterrows():
        disease = row['condition']
        foods = [f.strip() for f in row['restricted_foods'].split(',')]
        mapping[disease] = foods
    with open(output_path, 'w') as f:
        json.dump(mapping, f, indent=2)
    console.print(f"🧬 Saved [bold]disease_food_map.json[/bold] with {len(mapping)} entries.")

# ========== Medication-Food Interaction ==========
def generate_med_interactions(df: pd.DataFrame, output_path: str):
    med_map = {}
    for _, row in df.iterrows():
        med = row['medication']
        foods = [f.strip() for f in row['food_triggers'].split(',')]
        med_map[med] = foods
    with open(output_path, 'w') as f:
        json.dump(med_map, f, indent=2)
    console.print(f"💊 Saved [bold]medication_food_map.json[/bold] with {len(med_map)} entries.")

# ========== Nutrition Scaling ==========
def standardize_nutrition(df: pd.DataFrame, output_path: str):
    scaler = StandardScaler()
    num_cols = ['calories', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g']
    df[num_cols] = scaler.fit_transform(df[num_cols])
    df.to_csv(output_path, index=False)
    console.print(f"📦 Saved [bold]food_nutrition_scaled.csv[/bold] with standardized nutrients.")

# ========== Summary Table ==========
def show_data_summary(dfs: Dict[str, pd.DataFrame]):
    table = Table(title="📊 Dataset Summary", show_lines=True)
    table.add_column("Name", justify="left")
    table.add_column("Rows", justify="center")
    table.add_column("Columns", justify="center")
    table.add_column("Preview", justify="left")
    for name, df in dfs.items():
        table.add_row(
            name,
            str(df.shape[0]),
            str(df.shape[1]),
            ", ".join(list(df.columns[:3])) + "..." if df.shape[1] > 3 else ", ".join(df.columns)
        )
    console.print(table)

# ========== Pipeline Runner ==========
def run_pipeline():
    console.print(Panel.fit("🚀NutriPlan AI Preprocessing Started!", title="ML Engine", subtitle="Version 1.0"))

    dfs = load_datasets()

    # Clean each dataset
    for name in dfs:
        dfs[name] = clean_dataframe(dfs[name])
    console.print("🧹 All datasets cleaned.")

    # Encode profiles
    dfs['profiles'] = encode_profiles(dfs['profiles'])
    console.print("👤 User profiles encoded with BMI.")

    # Disease–Food map
    generate_disease_food_map(dfs['medical'], os.path.join(OUTPUT_DIR, 'disease_food_map.json'))

    # Medication–Food map
    generate_med_interactions(dfs['interaction'], os.path.join(OUTPUT_DIR, 'medication_food_map.json'))

    # Nutrition normalization
    standardize_nutrition(dfs['food'], os.path.join(OUTPUT_DIR, 'food_nutrition_scaled.csv'))

    # Save preprocessed user profiles
    dfs['profiles'].to_csv(os.path.join(OUTPUT_DIR, 'user_profiles_encoded.csv'), index=False)

    # Show summary
    show_data_summary(dfs)

    console.print(Panel.fit("✅ Preprocessing Complete!\nFiles are ready for training.", title="Success", border_style="green"))

# ========== Main ==========
if __name__ == "__main__":
    run_pipeline()
