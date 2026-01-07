"""
Wood Chopping action - Gather wood resources from lumbermill
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, log_activity, set_cooldown
from .constants import WORK_BASE_COOLDOWN

router = APIRouter()

# Wood chopping cooldown (same as farming - 60 minutes)
WOOD_CHOPPING_COOLDOWN = 60


def get_wood_per_action(lumbermill_level: int) -> int:
    """Get wood gathered based on lumbermill level"""
    wood_amounts = {
        0: 0,   # No lumbermill
        1: 10,  # Logging Camp
        2: 20,  # Sawmill
        3: 35,  # Lumber Yard
        4: 50,  # Industrial Mill
        5: 75   # Lumber Empire
    }
    return wood_amounts.get(lumbermill_level, 0)


@router.post("/chop-wood")
def chop_wood(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Chop wood at kingdom's lumbermill"""
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
            current_action_type="chop_wood",
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
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to chop wood"
        )
    
    # Get kingdom and check lumbermill level
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    lumbermill_level = kingdom.lumbermill_level if hasattr(kingdom, 'lumbermill_level') else 0
    
    if lumbermill_level == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This kingdom has no lumbermill. Ask the ruler to build one!"
        )
    
    # Calculate wood gathered
    wood_gathered = get_wood_per_action(lumbermill_level)
    
    # Apply building skill bonus (2% per level above 1)
    bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    wood_gathered = int(wood_gathered * bonus_multiplier)
    
    # Award wood to player
    state.wood += wood_gathered
    
    # Update cooldown
    cooldown_expires = datetime.utcnow() + timedelta(minutes=WOOD_CHOPPING_COOLDOWN)
    set_cooldown(db, current_user.id, "chop_wood", cooldown_expires)
    
    # Log activity
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="chop_wood",
        action_category="economy",
        description="Chopped wood",
        kingdom_id=state.current_kingdom_id,
        amount=wood_gathered,
        details={
            "wood_gathered": wood_gathered,
            "lumbermill_level": lumbermill_level,
            "building_skill_bonus": bonus_multiplier - 1.0
        }
    )
    
    db.commit()
    
    return {
        "success": True,
        "message": f"You chopped wood at the lumbermill",
        "next_chop_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=WOOD_CHOPPING_COOLDOWN)),
        "rewards": {
            "wood": wood_gathered,
            "lumbermill_level": lumbermill_level,
            "gold": None,
            "reputation": None,
            "experience": None
        }
    }

