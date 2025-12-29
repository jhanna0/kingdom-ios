"""
Patrol action - Guard against saboteurs
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, format_datetime_iso


router = APIRouter()


@router.post("/patrol")
def start_patrol(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start a 10-minute patrol to guard against saboteurs"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if already patrolling
    if state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow():
        remaining = int((state.patrol_expires_at - datetime.utcnow()).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Already on patrol. {remaining}s remaining"
        )
    
    # Check cooldown (can patrol again after previous one expires)
    cooldown_status = check_cooldown(state.last_patrol_action, 10)
    if not DEV_MODE and not cooldown_status["ready"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Patrol on cooldown. Wait {cooldown_status['seconds_remaining']}s"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to patrol"
        )
    
    # Start patrol
    state.last_patrol_action = datetime.utcnow()
    state.patrol_expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    # Award reputation for patrol (civic duty)
    rep_earned = 10
    state.reputation += rep_earned
    
    db.commit()
    
    return {
        "success": True,
        "message": "Patrol started! Guard duty for 10 minutes.",
        "expires_at": format_datetime_iso(state.patrol_expires_at),
        "rewards": {
            "gold": None,
            "reputation": rep_earned,
            "experience": None,
            "iron": None
        }
    }

