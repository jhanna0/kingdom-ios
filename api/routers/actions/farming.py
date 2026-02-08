"""
Farm action - Generate gold for your kingdom
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_and_set_slot_cooldown_atomic, format_datetime_iso, calculate_cooldown, check_and_deduct_food_cost
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
    
    # ATOMIC COOLDOWN CHECK + SET - prevents race conditions in serverless
    if not DEV_MODE:
        cooldown_expires = datetime.utcnow() + timedelta(minutes=FARM_COOLDOWN)
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="farm",
            cooldown_minutes=FARM_COOLDOWN,
            expires_at=cooldown_expires
        )
        
        if not cooldown_result["ready"]:
            remaining = cooldown_result["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = cooldown_result["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Economy action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s."
            )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to farm"
        )
    
    # Check and deduct food cost
    food_result = check_and_deduct_food_cost(db, current_user.id, FARM_COOLDOWN, "farming")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
        )
    
    # Calculate base gold reward
    # Note: Building skill provides cooldown reduction and refund chance, NOT gold bonus
    base_gold = FARM_GOLD_REWARD
    
    # Apply tax (no gold bonus from building skill)
    net_income, tax_amount, tax_rate, gross_income = apply_kingdom_tax_with_bonus(
        db=db,
        kingdom_id=state.current_kingdom_id,
        player_state=state,
        base_income=base_gold,
        bonus_multiplier=1.0  # No gold bonus from building skill
    )
    
    # Award gold to player
    state.gold += net_income
    
    # NOTE: We intentionally don't log farm to activity_log because:
    # 1. It happens every 10 minutes (would spam the feed)
    # 2. The player's status already shows "Farming" via _get_player_activity()
    # 3. Recent activity is used for online detection anyway
    
    db.commit()
    
    return {
        "success": True,
        "message": "You worked the farm",
        "next_farm_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=FARM_COOLDOWN)),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        "rewards": {
            "gold": int(net_income),
            "gold_before_tax": int(gross_income),
            "tax_amount": int(tax_amount),
            "tax_rate": tax_rate,
            "reputation": None,
            "experience": None,
            "iron": None
        }
    }

