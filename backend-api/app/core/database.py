# database.py

import os
import uuid
import time
import logging
from contextlib import contextmanager
from dotenv import load_dotenv

from sqlalchemy import create_engine, MetaData
from sqlalchemy.orm import sessionmaker, scoped_session, Session
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.exc import SQLAlchemyError

from rich.console import Console
from rich.text import Text
from rich.panel import Panel
from rich import box

# === Load .env Environment === #
load_dotenv()

# === Themed Terminal Console === #
console = Console()

# === Database Configuration === #
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./nutriplan_ai.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
)

metadata = MetaData()
Base = declarative_base()
SessionLocal = scoped_session(sessionmaker(autocommit=False, autoflush=False, bind=engine))

# === Logging Setup === #
LOGS_DIR = os.path.join(os.getcwd(), "logs")
os.makedirs(LOGS_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="🍀 [%(asctime)s] | [%(levelname)s] | %(message)s",
    handlers=[
        logging.FileHandler(os.path.join(LOGS_DIR, "nutriplan_db.log")),
        logging.StreamHandler()
    ]
)

# === Styled Logging with Animations === #
def fancy_log(msg: str, style: str = "bold green", icon: str = "🍀", delay: float = 0.01):
    styled = Text(f"{icon} {msg}", style=style)
    console.print(styled)
    time.sleep(delay)

def panel_message(title: str, content: str, style: str = "bold green"):
    panel = Panel(Text(content, justify="center", style=style), title=title, border_style=style, box=box.ROUNDED)
    console.print(panel)

# === Try Connecting to the Database === #
try:
    connection = engine.connect()
    fancy_log("NutriPlan AI database engine connected successfully 🚀", "bold cyan", "✅")
except SQLAlchemyError as e:
    fancy_log("Database connection failed 💥", "bold red", "❌")
    logging.error(str(e))
    raise e

# === Schema Initialization === #
def init_db():
    try:
        from app.models.user_model import UserInDB
        from app.models.feedback_model import Feedback
        from app.models.chat_model import ChatMessage
        from app.models.medical_model import MedicalRecord
        from app.models.mealplan_model import MealPlan

        Base.metadata.create_all(bind=engine)
        fancy_log("All schemas synced successfully 💾", "bold green", "📦")
    except Exception as e:
        logging.error(f"DB Schema Initialization Error: {e}")
        raise

# === Session Context Manager === #
@contextmanager
def get_db():
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        logging.error(f"Transaction rollback: {e}")
        raise
    finally:
        db.close()

# === DB Health Check === #
def health_check():
    try:
        with engine.connect() as conn:
            conn.execute("SELECT 1")
            fancy_log("Database Health: ✅ Healthy", "bold green", "💚")
            return True
    except Exception as e:
        fancy_log("Database Health: ❌ Unhealthy", "bold red", "💀")
        logging.error(f"Health check error: {e}")
        return False

# === Font Banner === #
def display_banner():
    console.rule("[bold yellow]🌱 NutriPlan AI • EcoDB Engine", style="green")
    banner_text = Text("NutriPlan AI - EcoSmart DB Engine", style="bold green")
    console.print(banner_text)
    console.rule("✳️", style="bold green")

# === Seed Sample Admin User (Optional) === #
def seed_sample_users():
    try:
        from app.models.user_model import UserInDB

        session: Session = SessionLocal()

        if session.query(UserInDB).first():
            fancy_log("Admin already exists. Skipping seeding ⚠️", "yellow", "⚠️")
            return

        demo_user = UserInDB(
            id=str(uuid.uuid4()),
            name="Devanarayanan",
            email="admin@nutriplan.ai",
            hashed_password="admin123",  # NOTE: Replace with hashed password in production
            role="admin",
            preferences={"mode": "eco", "font": "serif", "notifications": True}
        )

        session.add(demo_user)
        session.commit()
        fancy_log("Sample admin user seeded 👨‍🌾", "cyan", "🧬")

    except Exception as e:
        session.rollback()
        logging.warning(f"Seeding failed: {e}")
    finally:
        session.close()

# === Auto-Migration Hook (Optional Future Feature) === #
def auto_migrate():
    fancy_log("🚧 Auto-migration is not implemented. Use Alembic if needed.", "bold yellow", "🛠️")

# === Launch Setup from CLI === #
if __name__ == "__main__":
    display_banner()

    if health_check():
        init_db()
        seed_sample_users()
        panel_message("✅ NutriPlan AI DB Ready", "You may now launch your FastAPI service!", "bold green")
    else:
        panel_message("❌ DB Error", "Could not initialize database engine", "bold red")
