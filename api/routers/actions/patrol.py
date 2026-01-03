"""
Patrol action - Guard against saboteurs
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, log_activity, set_cooldown
from .constants import WORK_BASE_COOLDOWN, PATROL_DURATION_MINUTES, PATROL_REPUTATION_REWARD


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
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=work_cooldown)
        
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
    from db.models.action_cooldown import ActionCooldown
    patrol_cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type == "patrol"
    ).first()
    
    if patrol_cooldown and patrol_cooldown.expires_at and patrol_cooldown.expires_at > datetime.utcnow():
        remaining = int((patrol_cooldown.expires_at - datetime.utcnow()).total_seconds())
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
    patrol_end = datetime.utcnow() + timedelta(minutes=PATROL_DURATION_MINUTES)
    set_cooldown(db, current_user.id, "patrol", patrol_end)
    
    # Award reputation to user_kingdoms table
    from db.models.kingdom import UserKingdom
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.kingdom_id == state.current_kingdom_id
    ).first()
    
    if user_kingdom:
        user_kingdom.local_reputation += PATROL_REPUTATION_REWARD
    else:
        # Create new user_kingdom record
        user_kingdom = UserKingdom(
            user_id=current_user.id,
            kingdom_id=state.current_kingdom_id,
            local_reputation=PATROL_REPUTATION_REWARD,
            times_conquered=0,
            total_reign_duration_hours=0.0,
            checkins_count=0,
            gold_earned=0,
            gold_spent=0
        )
        db.add(user_kingdom)
    
    # Log activity
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="patrol",
        action_category="kingdom",
        description="Patrolled",
        kingdom_id=state.current_kingdom_id,
        amount=PATROL_REPUTATION_REWARD,
        details={
            "reputation_earned": PATROL_REPUTATION_REWARD,
            "duration_minutes": PATROL_DURATION_MINUTES
        }
    )
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Patrol started! Guard duty for {PATROL_DURATION_MINUTES} minutes.",
        "expires_at": format_datetime_iso(patrol_end),
        "rewards": {
            "gold": None,
            "reputation": PATROL_REPUTATION_REWARD,
            "experience": None,
            "iron": None
        }
    }

