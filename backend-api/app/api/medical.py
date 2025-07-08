# File: app/api/medical.py

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, validator
from uuid import UUID
import logging
from datetime import datetime

from app.db.database import get_db
from app.models.medical_model import MedicalRecord
from app.models.user_model import UserInDB
from app.services.auth_service import get_current_user

router = APIRouter(
    prefix="/medical",
    tags=["Medical Data"],
    responses={404: {"description": "Not found"}},
)

logger = logging.getLogger(__name__)

# =============================
# Pydantic Schemas
# =============================

class MedicalRequest(BaseModel):
    age: int = Field(..., ge=1, le=120)
    gender: str = Field(..., description="male | female | other")
    height_cm: float = Field(..., gt=30)
    weight_kg: float = Field(..., gt=10)
    allergies: list[str] = Field(default=[])
    conditions: list[str] = Field(default=[])
    medications: list[str] = Field(default=[])

    @validator('gender')
    def validate_gender(cls, v):
        if v.lower() not in ["male", "female", "other"]:
            raise ValueError("gender must be one of male | female | other")
        return v.lower()


class MedicalResponse(BaseModel):
    id: UUID
    user_id: UUID
    age: int
    gender: str
    height_cm: float
    weight_kg: float
    allergies: list[str]
    conditions: list[str]
    medications: list[str]
    created_at: str
    updated_at: str


# =============================
# Endpoints
# =============================

@router.post("/create", response_model=MedicalResponse, status_code=status.HTTP_201_CREATED)
def create_medical_record(
    request: MedicalRequest,
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        logger.info(f"Creating medical record for user {current_user.id}")

        # Check if record already exists
        existing = db.query(MedicalRecord).filter(MedicalRecord.user_id == current_user.id).first()
        if existing:
            raise HTTPException(status_code=400, detail="Medical record already exists. Please update it.")

        record = MedicalRecord(
            user_id=current_user.id,
            age=request.age,
            gender=request.gender,
            height_cm=request.height_cm,
            weight_kg=request.weight_kg,
            allergies=request.allergies,
            conditions=request.conditions,
            medications=request.medications,
        )

        db.add(record)
        db.commit()
        db.refresh(record)

        return MedicalResponse(
            id=record.id,
            user_id=record.user_id,
            age=record.age,
            gender=record.gender,
            height_cm=record.height_cm,
            weight_kg=record.weight_kg,
            allergies=record.allergies,
            conditions=record.conditions,
            medications=record.medications,
            created_at=record.created_at.isoformat(),
            updated_at=record.updated_at.isoformat()
        )

    except Exception as e:
        logger.error(f"Error creating medical record: {str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create medical record.")


@router.put("/update", response_model=MedicalResponse)
def update_medical_record(
    request: MedicalRequest,
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        logger.info(f"Updating medical record for user {current_user.id}")
        record = db.query(MedicalRecord).filter(MedicalRecord.user_id == current_user.id).first()

        if not record:
            raise HTTPException(status_code=404, detail="Medical record not found.")

        record.age = request.age
        record.gender = request.gender
        record.height_cm = request.height_cm
        record.weight_kg = request.weight_kg
        record.allergies = request.allergies
        record.conditions = request.conditions
        record.medications = request.medications
        record.updated_at = datetime.utcnow()

        db.commit()
        db.refresh(record)

        return MedicalResponse(
            id=record.id,
            user_id=record.user_id,
            age=record.age,
            gender=record.gender,
            height_cm=record.height_cm,
            weight_kg=record.weight_kg,
            allergies=record.allergies,
            conditions=record.conditions,
            medications=record.medications,
            created_at=record.created_at.isoformat(),
            updated_at=record.updated_at.isoformat()
        )

    except Exception as e:
        logger.error(f"Error updating medical record: {str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update medical record.")


@router.get("/get", response_model=MedicalResponse)
def get_medical_record(
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        logger.info(f"Fetching medical record for user {current_user.id}")
        record = db.query(MedicalRecord).filter(MedicalRecord.user_id == current_user.id).first()

        if not record:
            raise HTTPException(status_code=404, detail="No medical record found.")

        return MedicalResponse(
            id=record.id,
            user_id=record.user_id,
            age=record.age,
            gender=record.gender,
            height_cm=record.height_cm,
            weight_kg=record.weight_kg,
            allergies=record.allergies,
            conditions=record.conditions,
            medications=record.medications,
            created_at=record.created_at.isoformat(),
            updated_at=record.updated_at.isoformat()
        )

    except Exception as e:
        logger.error(f"Error fetching medical record: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve medical record.")


@router.delete("/delete", status_code=status.HTTP_204_NO_CONTENT)
def delete_medical_record(
    db: Session = Depends(get_db),
    current_user: UserInDB = Depends(get_current_user)
):
    try:
        logger.info(f"Deleting medical record for user {current_user.id}")
        record = db.query(MedicalRecord).filter(MedicalRecord.user_id == current_user.id).first()

        if not record:
            raise HTTPException(status_code=404, detail="No medical record found.")

        db.delete(record)
        db.commit()

        logger.info(f"Medical record deleted for user {current_user.id}")
        return

    except Exception as e:
        logger.error(f"Error deleting medical record: {str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete medical record.")
