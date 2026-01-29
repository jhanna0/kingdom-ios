"""
Feedback Router - Simple in-app feedback
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from datetime import datetime

from db import get_db
from routers.auth import get_current_user

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackRequest(BaseModel):
    message: str


@router.post("")
def submit_feedback(
    request: FeedbackRequest,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not request.message or len(request.message.strip()) < 5:
        raise HTTPException(status_code=400, detail="Message too short")
    
    db.execute(text("""
        INSERT INTO feedback (user_id, display_name, message, created_at)
        VALUES (:user_id, :display_name, :message, :created_at)
    """), {
        "user_id": user.id,
        "display_name": user.display_name,
        "message": request.message.strip(),
        "created_at": datetime.utcnow()
    })
    db.commit()
    
    return {"success": True}
