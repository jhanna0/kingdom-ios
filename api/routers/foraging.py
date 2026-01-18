"""
FORAGING API ROUTER
===================
Two-round foraging with bonus round!

Flow:
1. POST /foraging/start - Get BOTH rounds pre-calculated upfront
   - Round 1: Berries (food) + potential seed trail
   - Round 2: Seeds (only if seed trail found in R1)
2. Frontend reveals locally + animates transition if bonus round
3. POST /foraging/collect - Claim ALL rewards (berries + seeds)
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Dict

from db import get_db
from db.models import User
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from systems.foraging.foraging_manager import ForagingManager, ForagingSession
from systems.foraging.config import GRID_SIZE, MAX_REVEALS, MATCHES_TO_WIN, BUSH_DISPLAY, GRID_CONFIG


router = APIRouter(prefix="/foraging", tags=["foraging"])

# In-memory sessions
_sessions: Dict[int, ForagingSession] = {}
_manager = ForagingManager()


class EmptyRequest(BaseModel):
    pass


@router.get("/config")
def get_config():
    """Get display config for frontend."""
    return {
        "grid_size": GRID_SIZE,
        "max_reveals": MAX_REVEALS,
        "matches_to_win": MATCHES_TO_WIN,
        "bush_types": BUSH_DISPLAY,
        "hidden_icon": GRID_CONFIG["bush_hidden_icon"],
        "hidden_color": GRID_CONFIG["bush_hidden_color"],
        "bonus_hidden_icon": GRID_CONFIG["bonus_hidden_icon"],
        "bonus_hidden_color": GRID_CONFIG["bonus_hidden_color"],
    }


@router.post("/start")
def start_foraging(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Start foraging - returns EVERYTHING pre-calculated for BOTH rounds.
    
    Response includes:
    - round1: Berries grid + result + seed_trail info
    - round2: Seeds grid + result (only if seed_trail found!)
    - has_bonus_round: Quick flag to check
    
    Frontend reveals locally, animates transition if bonus round.
    """
    player_id = user.id
    
    # End any existing session
    if player_id in _sessions:
        del _sessions[player_id]
    
    # Create new session (generates both rounds if seed trail found)
    session = _manager.create_session(player_id)
    _sessions[player_id] = session
    
    return {
        "success": True,
        "session": session.to_dict(),
    }


@router.post("/collect")
def collect_rewards(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Collect ALL rewards from the session.
    
    Can include:
    - Berries from Round 1 (if won)
    - Seeds from Round 2 bonus (if seed trail found AND won)
    """
    player_id = user.id
    
    if player_id not in _sessions:
        raise HTTPException(status_code=400, detail="No active session")
    
    session = _sessions[player_id]
    
    try:
        result = _manager.collect_rewards(session)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # Add ALL rewards to inventory
    for reward in result.get("rewards", []):
        item_id = reward["item"]
        amount = reward["amount"]
        
        if amount > 0:
            inv = db.query(PlayerInventory).filter(
                PlayerInventory.user_id == player_id,
                PlayerInventory.item_id == item_id
            ).first()
            
            if inv:
                inv.quantity += amount
            else:
                inv = PlayerInventory(
                    user_id=player_id,
                    item_id=item_id,
                    quantity=amount
                )
                db.add(inv)
    
    db.commit()
    
    # Clear session
    del _sessions[player_id]
    
    return result


@router.post("/end")
def end_foraging(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """End session without collecting."""
    player_id = user.id
    
    if player_id in _sessions:
        del _sessions[player_id]
    
    return {"success": True}
