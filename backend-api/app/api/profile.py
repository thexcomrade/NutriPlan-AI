from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional
from datetime import datetime
from uuid import uuid4

from ..services.auth_service import get_current_user
from ..services.firebase_service import FirebaseService
from ..models.user_model import UserInDB, UserProfileUpdate, UserProfileResponse

router = APIRouter(prefix="/profile", tags=["User Profile"])

# 🎨 Emojis & UI Styling
PROFILE_ICONS = {
    "updated": "🔄",
    "view": "👤",
    "delete": "🗑️",
    "warning": "⚠️",
    "success": "✅",
    "green": "🌱",
    "info": "ℹ️",
    "lock": "🔒"
}


# ------------------------------
# GET: Retrieve Current Profile
# ------------------------------
@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: UserInDB = Depends(get_current_user)):
    """
    Retrieve authenticated user’s profile information.
    """
    return UserProfileResponse(
        user_id=current_user.user_id,
        name=current_user.name,
        email=current_user.email,
        age=current_user.age,
        gender=current_user.gender,
        dietary_preference=current_user.dietary_preference,
        goal=current_user.goal,
        lifestyle=current_user.lifestyle,
        profile_created=current_user.profile_created,
        theme="cleanProfile",
        message=f"{PROFILE_ICONS['view']} Profile fetched successfully!",
        avatar="👩‍⚕️",
        animation="fadeInRight"
    )


# -----------------------------
# PUT: Update User Profile Data
# -----------------------------
@router.put("/update", response_model=UserProfileResponse)
async def update_user_profile(
    update_data: UserProfileUpdate,
    current_user: UserInDB = Depends(get_current_user)
):
    """
    Update user profile information like age, gender, dietary needs, and lifestyle.
    """
    updated_user = FirebaseService.update_user_profile(
        user_id=current_user.user_id,
        updates=update_data.dict(exclude_unset=True)
    )

    return UserProfileResponse(
        user_id=updated_user.user_id,
        name=updated_user.name,
        email=updated_user.email,
        age=updated_user.age,
        gender=updated_user.gender,
        dietary_preference=updated_user.dietary_preference,
        goal=updated_user.goal,
        lifestyle=updated_user.lifestyle,
        profile_created=updated_user.profile_created,
        theme="ecoUpdate",
        message=f"{PROFILE_ICONS['updated']} Profile updated successfully!",
        avatar="🧑‍💼",
        animation="bounceIn"
    )


# ------------------------------
# DELETE: Delete User Profile
# ------------------------------
@router.delete("/delete", response_model=UserProfileResponse)
async def delete_my_profile(current_user: UserInDB = Depends(get_current_user)):
    """
    Permanently delete the user's profile from the system.
    """
    deleted = FirebaseService.delete_user_profile(current_user.user_id)
    if not deleted:
        raise HTTPException(status_code=400, detail="Unable to delete profile.")

    return UserProfileResponse(
        user_id=current_user.user_id,
        name=current_user.name,
        email=current_user.email,
        age=None,
        gender=None,
        dietary_preference=None,
        goal=None,
        lifestyle=None,
        profile_created=current_user.profile_created,
        theme="profileDeleted",
        message=f"{PROFILE_ICONS['delete']} Your profile has been deleted permanently.",
        avatar="💀",
        animation="zoomOutDown"
    )


# ---------------------------------------
# GET: Lifestyle Tips Based on Preference
# ---------------------------------------
@router.get("/lifestyle-tip", response_model=UserProfileResponse)
async def get_lifestyle_tip(current_user: UserInDB = Depends(get_current_user)):
    """
    Return a healthy tip based on the user’s lifestyle or dietary goal.
    """
    goal = current_user.goal or "balanced"
    lifestyle = current_user.lifestyle or "moderate"

    tip = ""
    if goal.lower() == "weight loss":
        tip = "Try intermittent fasting and increase protein intake. 🥦💪"
    elif goal.lower() == "muscle gain":
        tip = "Add healthy carbs and train with progressive overload. 🏋️‍♂️🍠"
    elif goal.lower() == "maintenance":
        tip = "Stay hydrated and keep moving daily. 🚶‍♂️💧"
    else:
        tip = "Eat more greens, sleep well, and smile often. 🌿😊"

    return UserProfileResponse(
        user_id=current_user.user_id,
        name=current_user.name,
        email=current_user.email,
        age=current_user.age,
        gender=current_user.gender,
        dietary_preference=current_user.dietary_preference,
        goal=current_user.goal,
        lifestyle=current_user.lifestyle,
        profile_created=current_user.profile_created,
        theme="greenMotivation",
        message=f"{PROFILE_ICONS['green']} {tip}",
        avatar="🧘‍♀️",
        animation="tada"
    )


# -------------------------------------
# GET: Check Profile Completeness
# -------------------------------------
@router.get("/status", response_model=UserProfileResponse)
async def get_profile_status(current_user: UserInDB = Depends(get_current_user)):
    """
    Return status message indicating how complete the profile is.
    """
    missing_fields = []
    if not current_user.age:
        missing_fields.append("age")
    if not current_user.gender:
        missing_fields.append("gender")
    if not current_user.dietary_preference:
        missing_fields.append("dietary preference")
    if not current_user.goal:
        missing_fields.append("goal")
    if not current_user.lifestyle:
        missing_fields.append("lifestyle")

    if not missing_fields:
        message = f"{PROFILE_ICONS['success']} Your profile is 100% complete!"
    else:
        message = (
            f"{PROFILE_ICONS['warning']} Please update: {', '.join(missing_fields)} "
            "to unlock better meal recommendations. 🍽️"
        )

    return UserProfileResponse(
        user_id=current_user.user_id,
        name=current_user.name,
        email=current_user.email,
        age=current_user.age,
        gender=current_user.gender,
        dietary_preference=current_user.dietary_preference,
        goal=current_user.goal,
        lifestyle=current_user.lifestyle,
        profile_created=current_user.profile_created,
        theme="progressTracker",
        message=message,
        avatar="🔎",
        animation="pulse"
    )
