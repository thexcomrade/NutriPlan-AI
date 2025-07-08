from fastapi import APIRouter, HTTPException, Depends, status, Query
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from uuid import uuid4

from ..services.auth_service import get_current_user
from ..services.mealplan_service import MealPlanService
from ..models.user_model import UserInDB
from ..models.mealplan_model import (
    MealPlanInputModel,
    MealPlanResponseModel,
    MealPlanUpdateModel
)

router = APIRouter(prefix="/mealplan", tags=["Meal Plan"])

# --- Emoji & Theme Enhancers ---
MEAL_EMOJIS = {
    "breakfast": "🍳",
    "lunch": "🥗",
    "dinner": "🍲",
    "snack": "🥜",
    "success": "✅",
    "deleted": "🗑️",
    "updated": "♻️",
    "eco": "🌿",
    "calories": "🔥",
    "protein": "💪",
    "balanced": "⚖️"
}

# --- POST: Create Meal Plan ---
@router.post("/create", response_model=MealPlanResponseModel)
async def create_meal_plan(
    meal_data: MealPlanInputModel,
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Create a new personalized meal plan for the authenticated user.
    """
    if not meal_data.meals:
        raise HTTPException(status_code=400, detail="Meal list cannot be empty 🍽️")

    meal_id = str(uuid4())
    created_at = datetime.utcnow().isoformat()

    meal_plan = MealPlanService.save_meal_plan(
        meal_id=meal_id,
        user_email=current_user.email,
        meals=meal_data.meals,
        goal=meal_data.goal,
        dietary_pref=meal_data.dietary_pref,
        created_at=created_at
    )

    return MealPlanResponseModel(
        mealplan_id=meal_id,
        message=f"{MEAL_EMOJIS['success']} Meal plan created for {current_user.name}. Enjoy your healthy journey!",
        meals=meal_data.meals,
        goal=meal_data.goal,
        dietary_pref=meal_data.dietary_pref,
        timestamp=created_at,
        animation="bounceIn",
        avatar="🥦",
        eco_theme=True
    )

# --- GET: Retrieve User Meal Plan(s) ---
@router.get("/my", response_model=List[MealPlanResponseModel])
async def get_my_mealplans(
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Fetch all saved meal plans for the authenticated user.
    """
    plans = MealPlanService.get_user_mealplans(current_user.email)

    if not plans:
        raise HTTPException(status_code=404, detail="No meal plans found 🙁")

    return plans

# --- GET: Retrieve Specific Meal Plan by ID ---
@router.get("/{mealplan_id}", response_model=MealPlanResponseModel)
async def get_mealplan_by_id(
    mealplan_id: str,
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Retrieve a specific meal plan by its ID.
    """
    plan = MealPlanService.get_mealplan_by_id(mealplan_id, current_user.email)
    if not plan:
        raise HTTPException(status_code=404, detail="Meal plan not found 🧾")

    return plan

# --- PUT: Update Meal Plan ---
@router.put("/update/{mealplan_id}", response_model=MealPlanResponseModel)
async def update_meal_plan(
    mealplan_id: str,
    updated_data: MealPlanUpdateModel,
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Update an existing meal plan with new data.
    """
    existing = MealPlanService.get_mealplan_by_id(mealplan_id, current_user.email)
    if not existing:
        raise HTTPException(status_code=404, detail="Meal plan not found to update 🚫")

    updated_plan = MealPlanService.update_meal_plan(
        mealplan_id=mealplan_id,
        updated_data=updated_data,
        user_email=current_user.email
    )

    return MealPlanResponseModel(
        mealplan_id=mealplan_id,
        message=f"{MEAL_EMOJIS['updated']} Meal plan updated successfully for {current_user.name}",
        meals=updated_plan['meals'],
        goal=updated_plan['goal'],
        dietary_pref=updated_plan['dietary_pref'],
        timestamp=updated_plan['timestamp'],
        animation="flipInX",
        avatar="🥑",
        eco_theme=True
    )

# --- DELETE: Remove Meal Plan ---
@router.delete("/delete/{mealplan_id}", response_model=MealPlanResponseModel)
async def delete_meal_plan(
    mealplan_id: str,
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Delete a meal plan by ID.
    """
    deleted = MealPlanService.delete_meal_plan(mealplan_id, current_user.email)
    if not deleted:
        raise HTTPException(status_code=404, detail="Meal plan not found or already deleted.")

    return MealPlanResponseModel(
        mealplan_id=mealplan_id,
        message=f"{MEAL_EMOJIS['deleted']} Meal plan deleted successfully.",
        meals=[],
        goal="",
        dietary_pref="",
        timestamp=datetime.utcnow().isoformat(),
        animation="zoomOut",
        avatar="🗑️",
        eco_theme=True
    )

# --- GET: Generate Recommended Meal Plan Dynamically ---
@router.get("/generate", response_model=MealPlanResponseModel)
async def generate_dynamic_meal_plan(
    goal: str = Query(..., description="User fitness or health goal"),
    dietary_pref: str = Query(..., description="User's dietary preferences"),
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Dynamically generate a personalized meal plan.
    """
    generated = MealPlanService.generate_mealplan(
        user_email=current_user.email,
        goal=goal,
        dietary_pref=dietary_pref
    )

    return MealPlanResponseModel(
        mealplan_id=str(uuid4()),
        message=f"{MEAL_EMOJIS['balanced']} AI generated your meal plan with love 💚",
        meals=generated["meals"],
        goal=goal,
        dietary_pref=dietary_pref,
        timestamp=generated["timestamp"],
        animation="fadeInUp",
        avatar="🤖",
        eco_theme=True
    )

# --- GET: Meal Plan Goals Available ---
@router.get("/goals", response_model=List[str])
async def get_meal_goals():
    """
    Return a list of supported health goals.
    """
    return ["weight_loss", "muscle_gain", "maintain_weight", "diabetes_control", "eco_friendly"]

# --- GET: Dietary Preferences Supported ---
@router.get("/preferences", response_model=List[str])
async def get_dietary_preferences():
    """
    Return list of dietary preferences for users to choose from.
    """
    return ["vegetarian", "vegan", "keto", "paleo", "gluten_free", "eco_diet"]

# --- GET: Eco-Themed Meal Message ---
@router.get("/eco-message", response_model=MealPlanResponseModel)
async def eco_meal_theme_message():
    msg = (
        "Your food choices impact more than your body 🌱.\n"
        "Let’s build a future where nutrition and the planet go hand in hand 🌍🥦.\n"
        "Choose sustainable meals with NutriPlan AI 💚."
    )
    return MealPlanResponseModel(
        mealplan_id=str(uuid4()),
        message=msg,
        meals=[],
        goal="eco_awareness",
        dietary_pref="eco_diet",
        timestamp=datetime.utcnow().isoformat(),
        animation="rubberBand",
        avatar="🌎",
        eco_theme=True
    )
