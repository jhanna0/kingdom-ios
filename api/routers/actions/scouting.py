"""
Scouting action - Gather intelligence on kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import WORK_BASE_COOLDOWN, SCOUT_COOLDOWN, SCOUT_GOLD_REWARD
from .tax_utils import apply_kingdom_tax


router = APIRouter()


@router.post("/scout/{kingdom_id}")
def scout_kingdom(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Scout an enemy kingdom to gather intelligence (2 hour cooldown)"""
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
    
    # Check if user is checked into the target kingdom
    if state.current_kingdom_id != kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the target kingdom to scout"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Update cooldown (both new table and legacy column)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=SCOUT_COOLDOWN)
    set_cooldown(db, current_user.id, "scout", cooldown_expires)
    state.last_scout_action = datetime.utcnow()
    
    # Give gold reward for successful scouting (with tax)
    net_income, tax_amount, tax_rate = apply_kingdom_tax(
        db=db,
        kingdom_id=kingdom_id,
        player_state=state,
        gross_income=SCOUT_GOLD_REWARD
    )
    state.gold += net_income
    
    db.commit()
    
    # Return intelligence
    return {
        "success": True,
        "message": f"Scouted {kingdom.name}!",
        "intelligence": {
            "kingdom_name": kingdom.name,
            "ruler_name": kingdom.ruler_name,
            "wall_level": kingdom.wall_level,
            "vault_level": kingdom.vault_level,
            "mine_level": kingdom.mine_level,
            "market_level": kingdom.market_level,
            "treasury_gold": kingdom.treasury_gold,
            "checked_in_players": kingdom.checked_in_players,
            "population": kingdom.population
        },
        "next_scout_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=SCOUT_COOLDOWN)),
        "rewards": {
            "gold": net_income,
            "gold_before_tax": SCOUT_GOLD_REWARD,
            "tax_amount": tax_amount,
            "tax_rate": tax_rate,
            "reputation": None,
            "iron": None
        }
    }

