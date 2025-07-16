# === FILE: app/api/feedback.py ===

from fastapi import APIRouter, HTTPException, Depends, Request, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from datetime import datetime
import logging
import uuid

from app.db.database import get_db
from app.models.feedback_model import Feedback
from app.models.user_model import UserInDB
from app.services.auth_service import get_current_user
from app.utils.SharedPrefsUtil import get_shared_preferences
from typing import List, Optional

router = APIRouter(
    prefix="/feedback",
    tags=["Feedback"]
)

# === Logging Setup === #
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# === Pydantic Schemas === #
class FeedbackCreate(BaseModel):
    message: str = Field(..., max_length=1000)
    rating: Optional[int] = Field(default=None, ge=1, le=5)
    source: Optional[str] = Field(default="user", max_length=100)

class FeedbackResponse(BaseModel):
    id: str
    user_id: str
    message: str
    rating: Optional[int]
    source: Optional[str]
    sentiment: Optional[str]
    created_at: datetime


# === POST: Submit Feedback === #
@router.post("/", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
def submit_feedback(
    feedback_data: FeedbackCreate,
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        feedback = Feedback(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            message=feedback_data.message.strip(),
            rating=feedback_data.rating,
            source=feedback_data.source or "user",
            sentiment=_analyze_sentiment(feedback_data.message),
            created_at=datetime.utcnow()
        )
        db.add(feedback)
        db.commit()
        db.refresh(feedback)
        logger.info(f"Feedback submitted by user {current_user.id}")
        return feedback
    except Exception as e:
        logger.error(f"Error submitting feedback: {e}")
        raise HTTPException(status_code=500, detail="Could not submit feedback")


# === GET: List Feedback (User-Specific) === #
@router.get("/", response_model=List[FeedbackResponse])
def get_user_feedback(
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        feedback_entries = db.query(Feedback).filter(Feedback.user_id == current_user.id).order_by(Feedback.created_at.desc()).all()
        return feedback_entries
    except Exception as e:
        logger.error(f"Error retrieving feedback: {e}")
        raise HTTPException(status_code=500, detail="Could not retrieve feedback")


# === GET: Admin View of All Feedback === #
@router.get("/all", response_model=List[FeedbackResponse])
def get_all_feedback(
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")

    try:
        all_feedback = db.query(Feedback).order_by(Feedback.created_at.desc()).all()
        return all_feedback
    except Exception as e:
        logger.error(f"Error fetching all feedback: {e}")
        raise HTTPException(status_code=500, detail="Unable to fetch feedback")


# === GET: Feedback Analytics Summary === #
@router.get("/summary")
def get_feedback_summary(
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access only")

    try:
        feedback_entries = db.query(Feedback).all()
        total = len(feedback_entries)
        sentiment_summary = {"positive": 0, "neutral": 0, "negative": 0}
        rating_distribution = {str(i): 0 for i in range(1, 6)}

        for f in feedback_entries:
            if f.sentiment in sentiment_summary:
                sentiment_summary[f.sentiment] += 1
            if f.rating:
                rating_distribution[str(f.rating)] += 1

        return {
            "total_feedback": total,
            "sentiment_breakdown": sentiment_summary,
            "rating_distribution": rating_distribution
        }
    except Exception as e:
        logger.error(f"Error generating feedback summary: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate summary")


# === Utility: Basic Sentiment Analysis (Mock) === #
def _analyze_sentiment(text: str) -> str:
    lower = text.lower()
    if any(word in lower for word in ["love", "great", "awesome", "thanks", "good"]):
        return "positive"
    elif any(word in lower for word in ["bad", "hate", "terrible", "worst", "slow"]):
        return "negative"
    else:
        return "neutral"


# === Optional: Admin Response to Feedback (Future) === #
@router.post("/{feedback_id}/respond")
def respond_to_feedback(
    feedback_id: str,
    response: str,
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access only")

    try:
        feedback = db.query(Feedback).filter(Feedback.id == feedback_id).first()
        if not feedback:
            raise HTTPException(status_code=404, detail="Feedback not found")

        # In production, save admin response to separate table or send notification
        logger.info(f"Admin responded to feedback {feedback_id}: {response}")
        return {"message": "Response logged successfully"}
    except Exception as e:
        logger.error(f"Error responding to feedback: {e}")
        raise HTTPException(status_code=500, detail="Error processing admin response")
