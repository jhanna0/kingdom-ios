"""
Mining action - Gather resources once per day
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, format_datetime_iso


router = APIRouter()


@router.post("/mine")
def mine_resources(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mine resources (once per day)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_mining_action, 1440)  # 24 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Mining on cooldown. Wait {hours}h"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to mine"
        )
    
    # Get kingdom to check mine level
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Calculate rewards based on mine level
    mine_level = kingdom.mine_level or 0
    base_gold = 20 * mine_level if mine_level > 0 else 10  # Level 0: 10 gold, Level 1: 20, Level 2: 40, etc.
    base_rep = 5  # Fixed reputation reward
    
    # Update player resources
    state.gold += base_gold
    state.reputation += base_rep
    state.last_mining_action = datetime.utcnow()
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Mining complete!",
        "next_mine_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=24)),
        "rewards": {
            "gold": base_gold,
            "reputation": base_rep,
            "iron": None
        }
    }

