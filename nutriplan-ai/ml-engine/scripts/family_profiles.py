# D:\nutriplan-ai\ml-engine\scripts\family_profiles.py

import os
import json
import uuid
import pandas as pd
from datetime import datetime
from pathlib import Path
from rich import print
from rich.console import Console
from rich.table import Table

console = Console()

# =============================================================================
# CONFIGURATION
# =============================================================================
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
PROFILE_FILE = DATA_DIR / "user_profiles.csv"
FAMILY_PROFILE_FILE = DATA_DIR / "family_profiles.json"

# Ensure files exist
DATA_DIR.mkdir(parents=True, exist_ok=True)
if not PROFILE_FILE.exists():
    PROFILE_FILE.write_text("user_id,name,age,gender,bmi,medical_conditions,allergies,dietary_goals,user_profile\n")

if not FAMILY_PROFILE_FILE.exists():
    FAMILY_PROFILE_FILE.write_text(json.dumps({}, indent=2))

# =============================================================================
# FAMILY PROFILE MANAGER
# =============================================================================
class FamilyProfileManager:
    def __init__(self):
        self.family_data = self.load_family_data()

    def load_family_data(self):
        if FAMILY_PROFILE_FILE.exists():
            with open(FAMILY_PROFILE_FILE, 'r') as f:
                return json.load(f)
        return {}

    def save_family_data(self):
        with open(FAMILY_PROFILE_FILE, 'w') as f:
            json.dump(self.family_data, f, indent=2)

    def create_family(self, primary_user_id, primary_user_name):
        if primary_user_id in self.family_data:
            console.print(f"[yellow]Family already exists for user_id: {primary_user_id}[/]")
            return
        self.family_data[primary_user_id] = {
            "primary_user": primary_user_name,
            "members": []
        }
        self.save_family_data()
        console.print(f"[green]✅ Created family record for {primary_user_name}[/]")

    def add_member(self, primary_user_id, name, age, gender, bmi,
                   medical_conditions, allergies, dietary_goals, user_profile):
        if primary_user_id not in self.family_data:
            console.print(f"[red]Primary user {primary_user_id} not found. Please create a family first.[/]")
            return

        member_id = str(uuid.uuid4())
        member_entry = {
            "member_id": member_id,
            "name": name,
            "age": age,
            "gender": gender,
            "bmi": bmi,
            "medical_conditions": medical_conditions,
            "allergies": allergies,
            "dietary_goals": dietary_goals,
            "user_profile": user_profile,
            "created_at": datetime.now().isoformat()
        }

        self.family_data[primary_user_id]["members"].append(member_entry)
        self.save_family_data()

        # Add to user_profiles.csv for model access
        self.append_to_user_profiles_csv(
            member_id, name, age, gender, bmi,
            medical_conditions, allergies, dietary_goals, user_profile
        )

        console.print(f"[blue]👤 Added family member: {name} to {primary_user_id}[/]")

    def append_to_user_profiles_csv(self, user_id, name, age, gender, bmi,
                                    medical_conditions, allergies, dietary_goals, user_profile):
        row = {
            "user_id": user_id,
            "name": name,
            "age": age,
            "gender": gender,
            "bmi": bmi,
            "medical_conditions": medical_conditions,
            "allergies": allergies,
            "dietary_goals": dietary_goals,
            "user_profile": user_profile
        }
        df = pd.DataFrame([row])
        df.to_csv(PROFILE_FILE, mode='a', index=False, header=False)

    def list_families(self):
        table = Table(title="NutriPlan AI - Family Accounts", header_style="bold magenta")
        table.add_column("Primary User ID")
        table.add_column("Primary User Name")
        table.add_column("Members Count")
        for user_id, details in self.family_data.items():
            table.add_row(user_id, details["primary_user"], str(len(details["members"])))
        console.print(table)

    def get_family(self, primary_user_id):
        return self.family_data.get(primary_user_id, None)

    def get_all_members(self, primary_user_id):
        family = self.get_family(primary_user_id)
        return family["members"] if family else []

    def delete_member(self, primary_user_id, member_id):
        if primary_user_id not in self.family_data:
            console.print(f"[red]Primary user {primary_user_id} not found.[/]")
            return
        members = self.family_data[primary_user_id]["members"]
        updated = [m for m in members if m["member_id"] != member_id]
        if len(updated) == len(members):
            console.print(f"[yellow]No member found with ID: {member_id}[/]")
        else:
            self.family_data[primary_user_id]["members"] = updated
            self.save_family_data()
            console.print(f"[green]🗑️ Removed member with ID: {member_id}[/]")

    def export_family_to_csv(self, primary_user_id, output_path=None):
        members = self.get_all_members(primary_user_id)
        if not members:
            console.print(f"[red]No members found for user ID: {primary_user_id}[/]")
            return
        df = pd.DataFrame(members)
        output_path = output_path or (DATA_DIR / f"{primary_user_id}_family_export.csv")
        df.to_csv(output_path, index=False)
        console.print(f"[green]📤 Family members exported to: {output_path}[/]")

# =============================================================================
# TESTING/CLI USAGE
# =============================================================================
def cli_interface():
    manager = FamilyProfileManager()
    console.print("[bold cyan]NutriPlan AI Family Manager CLI[/]\n")

    while True:
        console.print("\n[bold]Select an option:[/]")
        console.print("[1] Create family")
        console.print("[2] Add member")
        console.print("[3] List families")
        console.print("[4] View members")
        console.print("[5] Delete member")
        console.print("[6] Export family CSV")
        console.print("[7] Exit")

        choice = input("Enter choice: ").strip()

        if choice == '1':
            user_id = input("Enter primary user ID: ")
            user_name = input("Enter primary user name: ")
            manager.create_family(user_id, user_name)

        elif choice == '2':
            uid = input("Enter primary user ID: ")
            name = input("Member Name: ")
            age = int(input("Age: "))
            gender = input("Gender [M/F/Other]: ")
            bmi = float(input("BMI: "))
            med = input("Medical conditions (comma-separated): ")
            allergies = input("Allergies (comma-separated): ")
            goals = input("Dietary Goals: ")
            profile = input("User Profile Tag (e.g. gymrat, diabetic): ")
            manager.add_member(uid, name, age, gender, bmi, med, allergies, goals, profile)

        elif choice == '3':
            manager.list_families()

        elif choice == '4':
            uid = input("Enter primary user ID: ")
            members = manager.get_all_members(uid)
            if not members:
                print("[red]No members found.")
            else:
                for i, m in enumerate(members, 1):
                    print(f"[{i}] {m['name']} ({m['age']} yrs) - {m['user_profile']}")

        elif choice == '5':
            uid = input("Enter primary user ID: ")
            mid = input("Enter member ID to delete: ")
            manager.delete_member(uid, mid)

        elif choice == '6':
            uid = input("Enter primary user ID: ")
            manager.export_family_to_csv(uid)

        elif choice == '7':
            print("[bold green]Exiting CLI. Goodbye![/]")
            break

        else:
            print("[red]Invalid option. Try again.[/]")

# =============================================================================
# ENTRY
# =============================================================================
if __name__ == "__main__":
    cli_interface()
