from datetime import datetime, timedelta
from typing import Optional, List

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
    Response,
    Cookie,
)
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr, validator
from jose import JWTError, jwt # type: ignore
from passlib.context import CryptContext # type: ignore

# In-memory "database"
fake_users_db = {}

SECRET_KEY = "supersecretkeythatshouldbereplaced"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION_MINUTES = 15

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

router = APIRouter(prefix="/auth", tags=["Authentication"])


class UserRole:
    USER = "user"
    ADMIN = "admin"


class UserInDB(BaseModel):
    email: EmailStr
    hashed_password: str
    full_name: Optional[str] = None
    is_active: bool = True
    is_email_verified: bool = False
    role: str = UserRole.USER
    failed_login_attempts: int = 0
    locked_until: Optional[datetime] = None


class UserCreate(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    hashed_password: str


class UserRead(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    is_active: bool
    is_email_verified: bool
    role: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    email: Optional[str] = None
    scopes: List[str] = []


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str  # Use plain str here to avoid Pylance type error
    full_name: Optional[str] = None

    @validator("password")
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password too short")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one digit")
        return v


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_user(email: str) -> Optional[UserInDB]:
    user = fake_users_db.get(email)
    if user:
        return UserInDB(**user)
    return None


async def create_user(user: UserCreate) -> UserRead:
    if user.email in fake_users_db:
        raise HTTPException(status_code=400, detail="Email already registered")
    fake_users_db[user.email] = {
        "email": user.email,
        "hashed_password": user.hashed_password,
        "full_name": user.full_name,
        "is_active": True,
        "is_email_verified": False,
        "role": UserRole.USER,
        "failed_login_attempts": 0,
        "locked_until": None,
    }
    return UserRead(
        email=user.email,
        full_name=user.full_name,
        is_active=True,
        is_email_verified=False,
        role=UserRole.USER,
    )


async def authenticate_user(email: str, password: str) -> Optional[UserInDB]:
    user = await get_user(email)
    if not user:
        return None

    if user.locked_until and user.locked_until > datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=f"Account locked until {user.locked_until.isoformat()}",
        )

    if not verify_password(password, user.hashed_password):
        # Update failed attempts
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= MAX_FAILED_ATTEMPTS:
            user.locked_until = datetime.utcnow() + timedelta(minutes=LOCKOUT_DURATION_MINUTES)
            user.failed_login_attempts = 0  # reset after locking
        fake_users_db[email] = user.dict()
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    # Reset failed attempts after success
    user.failed_login_attempts = 0
    user.locked_until = None
    fake_users_db[email] = user.dict()

    if not user.is_email_verified:
        raise HTTPException(status_code=403, detail="Email not verified")

    return user


async def get_current_user(token: str = Depends(oauth2_scheme)) -> UserInDB:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        token_data = TokenData(email=email)
    except JWTError:
        raise credentials_exception
    user = await get_user(token_data.email)
    if user is None:
        raise credentials_exception
    return user


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest):
    hashed_password = get_password_hash(request.password)
    user_create = UserCreate(email=request.email, full_name=request.full_name, hashed_password=hashed_password)
    return await create_user(user_create)


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), response: Response = None):
    user = await authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token = create_refresh_token(data={"sub": user.email}, expires_delta=refresh_token_expires)

    if response:
        response.set_cookie(
            key="refresh_token",
            value=refresh_token,
            httponly=True,
            max_age=int(refresh_token_expires.total_seconds()),
            secure=False,  # Set True in production HTTPS
            samesite="lax",
            path="/auth/refresh-token",
        )

    return Token(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh-token", response_model=Token)
async def refresh_token(refresh_token: Optional[str] = Cookie(None), response: Response = None):
    if not refresh_token:
        raise HTTPException(status_code=401, detail="Missing refresh token")
    try:
        payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = await get_user(email)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    new_refresh_token = create_refresh_token(data={"sub": user.email}, expires_delta=refresh_token_expires)

    if response:
        response.set_cookie(
            key="refresh_token",
            value=new_refresh_token,
            httponly=True,
            max_age=int(refresh_token_expires.total_seconds()),
            secure=False,
            samesite="lax",
            path="/auth/refresh-token",
        )
    return Token(access_token=access_token, refresh_token=new_refresh_token)


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie("refresh_token", path="/auth/refresh-token")
    return {"message": "Logged out successfully"}


@router.get("/me", response_model=UserRead)
async def read_users_me(current_user: UserInDB = Depends(get_current_user)):
    return UserRead(
        email=current_user.email,
        full_name=current_user.full_name,
        is_active=current_user.is_active,
        is_email_verified=current_user.is_email_verified,
        role=current_user.role,
    )
