# D:\nutriplan-ai\ml-engine\scripts\disease_filter.py

import pandas as pd
import json
import os
from typing import List, Dict
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import track

# === Console Setup ===
console = Console()

# === Paths ===
BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
PROCESSED_DIR = os.path.join(DATA_DIR, "processed")

# Ensure processed dir exists
os.makedirs(PROCESSED_DIR, exist_ok=True)

# === Utility Loaders ===

def load_json(path: str, label: str = "file") -> dict:
    try:
        with open(path, 'r') as f:
            data = json.load(f)
        console.print(f"✅ Loaded {label} from [green]{os.path.basename(path)}[/green]")
        return data
    except Exception as e:
        console.print(f"[red]❌ Failed to load {label}: {e}")
        return {}

def load_csv(path: str) -> pd.DataFrame:
    try:
        df = pd.read_csv(path)
        df.columns = [col.strip().lower().replace(" ", "_") for col in df.columns]
        return df
    except Exception as e:
        console.print(f"[red]❌ Failed to load CSV: {e}")
        return pd.DataFrame()

# === Filter Logic ===

def apply_disease_filter(df: pd.DataFrame, condition: str, restriction_map: dict) -> pd.DataFrame:
    if condition not in restriction_map:
        console.print(f"[yellow]⚠️ Condition '{condition}' not mapped. Skipping disease filter.")
        return df
    restricted = restriction_map[condition]
    return df[~df['food_item'].str.lower().apply(lambda item: any(restr in item for restr in restricted))]

def apply_allergy_filter(df: pd.DataFrame, allergies: List[str]) -> pd.DataFrame:
    return df[~df['food_item'].str.lower().apply(lambda item: any(allg in item for allg in allergies))]

def apply_age_group_filter(df: pd.DataFrame, age: int) -> pd.DataFrame:
    if age < 2:
        return df[df['calories'] <= 150]  # infant meals
    elif age <= 12:
        return df[df['calories'] <= 350]
    elif age <= 50:
        return df[df['calories'] <= 700]
    else:
        return df[df['fat_g'] <= 20]  # limit fat for elderly

# === Display Preview ===

def show_preview(df: pd.DataFrame, title: str):
    table = Table(title=f"🍽️ {title}", show_lines=False)
    for col in df.columns[:5]:
        table.add_column(col.title(), style="cyan", overflow="fold")
    for _, row in df.head(10).iterrows():
        table.add_row(*[str(row[col]) for col in df.columns[:5]])
    console.print(table)

# === Save Filtered File ===

def save_result(df: pd.DataFrame, name: str):
    filename = f"safe_meals_{name.replace(' ', '_').lower()}.csv"
    filepath = os.path.join(PROCESSED_DIR, filename)
    try:
        df.to_csv(filepath, index=False)
        console.print(f"💾 Saved filtered file: [green]{filepath}[/green]")
    except Exception as e:
        console.print(f"[red]❌ Save failed: {e}")

# === Master Pipeline ===

def generate_safe_meals_for_user(user_profile: dict, food_df: pd.DataFrame,
                                 disease_map: dict, allergy_map: dict):
    name = user_profile.get("name", "User")
    age = user_profile.get("age", 30)
    condition = user_profile.get("condition", "").lower()
    allergies = [a.lower() for a in user_profile.get("allergies", [])]

    df = food_df.copy()

    # Filters applied
    if condition:
        df = apply_disease_filter(df, condition, disease_map)

    if allergies:
        allergy_terms = []
        for allergen in allergies:
            allergy_terms.extend(allergy_map.get(allergen, [allergen]))
        df = apply_allergy_filter(df, allergy_terms)

    df = apply_age_group_filter(df, age)

    # Results
    label = f"{name}_{condition or 'healthy'}"
    show_preview(df, f"Meal Plan for {name} (Age {age}, {condition or 'No condition'})")
    save_result(df, label)

# === Main Runner ===

def run_multi_user_filter():
    console.rule("[bold green]🧠 Personalized Disease + Allergy Meal Filter")

    # Load everything
    food_df = load_csv(os.path.join(PROCESSED_DIR, "food_nutrition_scaled.csv"))
    disease_map = load_json(os.path.join(PROCESSED_DIR, "disease_food_map.json"), "Disease Map")
    allergy_map = load_json(os.path.join(PROCESSED_DIR, "allergy_food_map.json"), "Allergy Map")

    if food_df.empty or not disease_map:
        console.print("[red]🚫 Cannot proceed — missing core data.")
        return

    # Sample family profiles
    user_profiles = [
        {"name": "Aarav", "age": 1, "condition": "", "allergies": ["dairy"]},
        {"name": "Priya", "age": 34, "condition": "diabetes", "allergies": []},
        {"name": "Dadi", "age": 71, "condition": "hypertension", "allergies": ["nuts", "gluten"]},
        {"name": "Anya", "age": 15, "condition": "pcos", "allergies": ["soy"]}
    ]

    for user in track(user_profiles, description="Processing Family Meal Plans..."):
        generate_safe_meals_for_user(user, food_df, disease_map, allergy_map)

    console.print(Panel.fit("[bold green]✅ All meal plans generated and saved.", title="Complete"))

# === CLI Entrypoint ===
if __name__ == "__main__":
    run_multi_user_filter()
