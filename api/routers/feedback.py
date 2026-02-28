"""
Feedback Router - Simple in-app feedback
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from db import get_db
from routers.auth import get_current_user

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackRequest(BaseModel):
    message: str
    prompt_id: Optional[str] = None


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
    
    if request.prompt_id:
        db.execute(text("""
            INSERT INTO prompt_dismissals (user_id, prompt_id, dismissal_count, completed, last_shown_at, dismissed_at)
            VALUES (:user_id, :prompt_id, 0, TRUE, NOW(), NOW())
            ON CONFLICT (user_id, prompt_id) DO UPDATE SET
                completed = TRUE
        """), {"user_id": user.id, "prompt_id": request.prompt_id})
    
    db.commit()
    
    return {"success": True}
