"""
NutriPlan AI • Security Core
Handles password encryption, JWT token creation/validation, and token blacklist logic.
"""

# === SYSTEM IMPORTS === #
import os
import time
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict

# === THIRD PARTY IMPORTS === #
from passlib.context import CryptContext
from jose import JWTError, jwt
from dotenv import load_dotenv
from fastapi import HTTPException, status, Depends
from fastapi.security import OAuth2PasswordBearer
from rich.console import Console
from rich.text import Text

# === INIT === #
load_dotenv()
console = Console()

# === PASSWORD CONTEXT === #
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# === OAUTH2 SCHEME === #
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")

# === ENV SECRETS === #
SECRET_KEY = os.getenv("SECRET_KEY", "super-secret-key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", 7))

# === IN-MEMORY TOKEN BLACKLIST === #
token_blacklist = set()

# === LOGGER SETUP === #
logging.basicConfig(
    level=logging.INFO,
    format="🔐 [%(asctime)s] :: [%(levelname)s] :: %(message)s",
    handlers=[
        logging.FileHandler("logs/nutriplan_security.log"),
        logging.StreamHandler()
    ]
)

def fancy_log(msg: str, style: str = "bold green", icon: str = "🔒", delay: float = 0.005):
    styled = Text(f"{icon} {msg}", style=style)
    console.print(styled)
    time.sleep(delay)


# === PASSWORD HANDLING === #
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Compare plain and hashed password"""
    result = pwd_context.verify(plain_password, hashed_password)
    fancy_log("Password verification attempted ✅" if result else "Password mismatch ❌", "cyan" if result else "red")
    return result

def get_password_hash(password: str) -> str:
    """Hash a password using bcrypt"""
    hash_val = pwd_context.hash(password)
    fancy_log("Password hashed successfully 🔐", "green")
    return hash_val


# === JWT TOKEN CREATION === #
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    fancy_log("Access token generated ✨", "bold green", "🪙")
    return encoded_jwt

def create_refresh_token(data: dict) -> str:
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = data.copy()
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    fancy_log("Refresh token generated 🔁", "bold cyan", "🔁")
    return encoded_jwt


# === JWT TOKEN DECODING === #
def decode_token(token: str) -> dict:
    """Decode and validate a JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        fancy_log("Token decoded successfully 🧬", "bold green", "🧩")
        return payload
    except JWTError as e:
        logging.error(f"JWT decode failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# === TOKEN VALIDATION === #
def validate_token(token: str) -> Dict:
    if token in token_blacklist:
        fancy_log("Token is blacklisted ❌", "red", "🚫")
        raise HTTPException(status_code=403, detail="Token is blacklisted.")
    payload = decode_token(token)
    return payload


# === GET CURRENT USER === #
def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    try:
        payload = validate_token(token)
        user_id = payload.get("sub")
        if user_id is None:
            fancy_log("Token missing user ID ❗", "bold red")
            raise HTTPException(status_code=401, detail="Token invalid: No user ID")
        return {"user_id": user_id}
    except Exception as e:
        logging.error(f"Token validation failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid token")


# === TOKEN BLACKLISTING === #
def blacklist_token(token: str):
    """Blacklist the provided token"""
    token_blacklist.add(token)
    fancy_log("Token added to blacklist 🚫", "yellow", "⛔")


# === AUTH UTILITIES === #
def is_token_expired(token: str) -> bool:
    """Check if a token has expired without raising"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = payload.get("exp")
        if exp and datetime.utcfromtimestamp(exp) < datetime.utcnow():
            return True
        return False
    except JWTError:
        return True


# === DEBUG THEME BANNER === #
def display_security_theme():
    console.rule("🔐 NutriPlan Security Engine")
    console.print(Text("Secure. Smart. Eco-Friendly 🔐", style="bold green"))
    console.rule("🌱 End of Security Banner")


# === CLI DEMO === #
if __name__ == "__main__":
    fancy_log("Launching NutriPlan Security Core...", "bold blue", "🔰")
    display_security_theme()

    sample = {"sub": "admin@nutriplan.ai"}
    token = create_access_token(sample)
    refresh = create_refresh_token(sample)

    fancy_log(f"Access Token:\n{token}", "cyan")
    fancy_log(f"Refresh Token:\n{refresh}", "cyan")

    decoded = decode_token(token)
    print("Decoded:", decoded)
