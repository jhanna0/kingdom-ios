"""
Patrol action - Guard against saboteurs
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_and_set_slot_cooldown_atomic, format_datetime_iso, calculate_cooldown, get_cooldown, set_cooldown, check_and_deduct_food_cost, set_activity_status, award_reputation
from .constants import WORK_BASE_COOLDOWN, PATROL_DURATION_MINUTES, PATROL_REPUTATION_REWARD, PATROL_COOLDOWN


router = APIRouter()


@router.post("/patrol")
def start_patrol(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start a 10-minute patrol to guard against saboteurs"""
    from db.models.action_cooldown import ActionCooldown
    
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if user is checked in (do this first, before locking)
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to patrol"
        )
    
    # Check and deduct food cost (based on patrol duration, not cooldown)
    food_result = check_and_deduct_food_cost(db, current_user.id, PATROL_DURATION_MINUTES, "patrolling")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
        )
    
    now = datetime.utcnow()
    patrol_end = now + timedelta(minutes=PATROL_DURATION_MINUTES)
    
    # ATOMIC CHECK + SET for patrol
    # Patrol is unique: we check expires_at (active patrol), not last_performed
    if not DEV_MODE:
        # Lock the row with FOR UPDATE to prevent race conditions
        patrol_cooldown = db.query(ActionCooldown).filter(
            ActionCooldown.user_id == current_user.id,
            ActionCooldown.action_type == "patrol"
        ).with_for_update().first()
        
        # Check if already patrolling (expires_at > now)
        if patrol_cooldown and patrol_cooldown.expires_at and patrol_cooldown.expires_at > now:
            remaining = int((patrol_cooldown.expires_at - now).total_seconds())
            minutes = remaining // 60
            seconds = remaining % 60
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Already on patrol. {minutes}m {seconds}s remaining"
            )
        
        # Not patrolling - set the cooldown atomically (we hold the lock)
        if patrol_cooldown:
            patrol_cooldown.last_performed = now
            patrol_cooldown.expires_at = patrol_end
        else:
            patrol_cooldown = ActionCooldown(
                user_id=current_user.id,
                action_type="patrol",
                last_performed=now,
                expires_at=patrol_end
            )
            db.add(patrol_cooldown)
        
        db.flush()
    else:
        # DEV_MODE: no locking, just set cooldown
        set_cooldown(db, current_user.id, "patrol", patrol_end)
    
    # Award reputation with philosophy bonus
    rep_awarded, new_rep_total = award_reputation(
        db=db,
        user_id=current_user.id,
        kingdom_id=state.current_kingdom_id,
        base_amount=PATROL_REPUTATION_REWARD,
        philosophy_level=state.philosophy or 0
    )
    
    # NOTE: We intentionally don't log patrol to activity_log because:
    # 1. It happens every 10 minutes (would spam the feed)
    # 2. The player's status already shows "Patrolling" via cached activity
    # 3. Recent activity is used for online detection anyway
    
    # Update activity status
    set_activity_status(state, "Patrolling")
    
    db.commit()
    
    return {
        "success": True,
        "message": f"You're on patrol for {PATROL_DURATION_MINUTES} minutes",
        "expires_at": format_datetime_iso(patrol_end),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        "rewards": {
            "gold": None,
            "reputation": int(rep_awarded),  # Convert to int for frontend
            "experience": None,
            "iron": None
        }
    }

