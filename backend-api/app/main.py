# File: D:\nutriplan-ai\backend-api\app\main.py

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import uvicorn
import logging
import time
import platform
from typing import List

# Routers
from app.api import auth, user, medical, chat, feedback, mealplan

# Config and logger
from app.core.config import settings
from app.utils.logger import configure_logger

# App metadata
app = FastAPI(
    title="🥗 NutriPlan AI Backend",
    description=(
        "🌿 Welcome to NutriPlan AI — your intelligent, adaptive, eco-friendly nutrition companion. "
        "Our API serves tailored dietary plans using advanced AI + real medical and lifestyle insights."
    ),
    version="v1.0.0",
    contact={
        "name": "NutriPlan AI Dev Team",
        "url": "https://nutriplan.ai",
        "email": "support@nutriplan.ai",
    },
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# Setup logger
logger = configure_logger()

# ───────────────────────────────
# CORS configuration
# ───────────────────────────────
origins = [
    "http://localhost:3000",  # React dev
    "http://127.0.0.1:3000",
    "http://localhost:8080",  # Vue dev
    "https://nutriplan.ai",   # Production UI
    "*",                      # Allow all (disable in prod)
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ───────────────────────────────
# Middleware to time each request
# ───────────────────────────────
@app.middleware("http")
async def log_request_time(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = round(time.time() - start_time, 4)
    response.headers["X-Process-Time"] = f"{duration}s"
    logger.info(f"{request.method} {request.url.path} -> {response.status_code} in {duration}s")
    return response

# ───────────────────────────────
# Exception Handlers
# ───────────────────────────────
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    logger.warning(f"HTTP error: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail, "path": str(request.url)},
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"Validation error: {exc.errors()}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"error": "Invalid input", "details": exc.errors()},
    )

@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.critical(f"Unhandled error: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal Server Error. Please try again."},
    )

# ───────────────────────────────
# Root & Diagnostic Endpoints
# ───────────────────────────────
@app.get("/", tags=["Health"], response_class=HTMLResponse)
async def root_page():
    html_content = f"""
    <html>
        <head>
            <title>NutriPlan AI 🥗</title>
            <style>
                body {{
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    background: linear-gradient(135deg, #e0f7fa, #ffffff);
                    color: #333;
                    padding: 40px;
                    text-align: center;
                }}
                h1 {{
                    font-size: 2.5rem;
                    color: #00897b;
                }}
                p {{
                    font-size: 1.2rem;
                    color: #555;
                }}
                a {{
                    color: #00796b;
                    text-decoration: none;
                }}
            </style>
        </head>
        <body>
            <h1>🌿 NutriPlan AI Backend is Running</h1>
            <p>Version: <strong>v1.0.0</strong></p>
            <p>Platform: {platform.system()} {platform.release()}</p>
            <p>Visit <a href="/docs">API Docs</a> or <a href="/redoc">Redoc</a> to explore the endpoints.</p>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)

@app.get("/status", tags=["Health"])
async def api_status():
    return {
        "service": "NutriPlan AI API",
        "version": "v1.0.0",
        "status": "🟢 Online",
        "uptime": f"{round(time.time() - settings.START_TIME)}s"
    }

@app.get("/routes", tags=["Debug"])
async def list_routes():
    return [{"path": route.path, "name": route.name} for route in app.router.routes]

@app.get("/ping", tags=["Health"])
async def ping_check():
    return {"ping": "pong 🏓"}

@app.get("/test-font", tags=["Debug"], response_class=HTMLResponse)
async def test_font():
    return HTMLResponse("""
    <html>
        <head>
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;600&display=swap');
                body {
                    font-family: 'Poppins', sans-serif;
                    background-color: #f5f5f5;
                    padding: 40px;
                    color: #222;
                    text-align: center;
                }
            </style>
        </head>
        <body>
            <h1>✅ Stylish Font Test (Poppins)</h1>
            <p>This confirms premium theme integration on UI responses.</p>
        </body>
    </html>
    """)

# ───────────────────────────────
# Router Registrations
# ───────────────────────────────
app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(user.router, prefix="/user", tags=["User"])
app.include_router(medical.router, prefix="/medical", tags=["Medical"])
app.include_router(chat.router, prefix="/chat", tags=["ChatBot"])
app.include_router(feedback.router, prefix="/feedback", tags=["Feedback"])
app.include_router(mealplan.router, prefix="/mealplan", tags=["MealPlan"])

# ───────────────────────────────
# Events
# ───────────────────────────────
@app.on_event("startup")
async def on_startup():
    logger.info("🚀 Starting NutriPlan AI backend service...")

@app.on_event("shutdown")
async def on_shutdown():
    logger.info("🛑 Shutting down NutriPlan AI backend service...")

# ───────────────────────────────
# Dev CLI entrypoint
# ───────────────────────────────
def run_dev():
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)

# ───────────────────────────────
# Optional CLI Launch
# ───────────────────────────────
if __name__ == "__main__":
    run_dev()
