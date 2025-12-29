"""
Scouting action - Gather intelligence on kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, format_datetime_iso


router = APIRouter()


@router.post("/scout/{kingdom_id}")
def scout_kingdom(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Scout an enemy kingdom to gather intelligence (once per day)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_scout_action, 1440)  # 24 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Scouting on cooldown. Wait {hours}h"
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
    
    # Update player state
    state.last_scout_action = datetime.utcnow()
    
    # Give gold reward for successful scouting
    state.gold += 10
    
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
        "next_scout_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=24)),
        "rewards": {
            "gold": 10,  # Small reward for scouting
            "reputation": None,
            "iron": None
        }
    }

