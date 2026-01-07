"""
Farm action - Generate gold for your kingdom
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, log_activity, set_cooldown
from .constants import WORK_BASE_COOLDOWN, FARM_COOLDOWN, FARM_GOLD_REWARD
from .tax_utils import apply_kingdom_tax_with_bonus


router = APIRouter()


@router.post("/farm")
def perform_farming(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Farm to generate gold - always available like patrol"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # ACTION SLOT CHECK: Check if any action in the ECONOMY slot is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(
            db, current_user.id, 
            current_action_type="farm",
            work_cooldown=work_cooldown
        )
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Economy action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s."
            )
    
    # Set cooldown IMMEDIATELY to prevent double-click exploits
    cooldown_expires = datetime.utcnow() + timedelta(minutes=FARM_COOLDOWN)
    set_cooldown(db, current_user.id, "farm", cooldown_expires)
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to farm"
        )
    
    # Calculate base gold reward
    base_gold = FARM_GOLD_REWARD
    
    # Apply building skill bonus (2% per level above 1)
    bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    
    # Apply tax AFTER bonuses
    net_income, tax_amount, tax_rate, gross_income = apply_kingdom_tax_with_bonus(
        db=db,
        kingdom_id=state.current_kingdom_id,
        player_state=state,
        base_income=base_gold,
        bonus_multiplier=bonus_multiplier
    )
    
    # Award gold to player
    state.gold += net_income
    
    # Log activity
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="farm",
        action_category="economy",
        description="Farmed",
        kingdom_id=state.current_kingdom_id,
        amount=net_income,
        details={
            "gold_earned": net_income,
            "gold_before_tax": gross_income,
            "tax_amount": tax_amount,
            "tax_rate": tax_rate,
            "building_skill_bonus": bonus_multiplier - 1.0
        }
    )
    
    db.commit()
    
    return {
        "success": True,
        "message": "You worked the farm",
        "next_farm_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=FARM_COOLDOWN)),
        "rewards": {
            "gold": net_income,
            "gold_before_tax": gross_income,
            "tax_amount": tax_amount,
            "tax_rate": tax_rate,
            "reputation": None,
            "experience": None,
            "iron": None
        }
    }

