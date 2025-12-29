"""
Patrol action - Guard against saboteurs
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, check_global_action_cooldown, format_datetime_iso, calculate_cooldown


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
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(120, state.building_skill)
        global_cooldown = check_global_action_cooldown(
            state, 
            work_cooldown=work_cooldown,
            patrol_cooldown=10,
            sabotage_cooldown=1440,
            mine_cooldown=1440,
            scout_cooldown=1440,
            training_cooldown=120
        )
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Check if already patrolling
    if state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow():
        remaining = int((state.patrol_expires_at - datetime.utcnow()).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Already on patrol. {remaining}s remaining"
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

