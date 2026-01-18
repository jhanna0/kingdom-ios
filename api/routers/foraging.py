"""
FORAGING API ROUTER
===================
Simple scratch-ticket minigame.

Flow:
1. POST /foraging/start - Get pre-calculated grid + result
2. Frontend reveals locally (no API calls needed!)
3. POST /foraging/collect - Claim reward if won
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
    }


@router.post("/start")
def start_foraging(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Start foraging - returns EVERYTHING pre-calculated.
    
    Frontend reveals locally, no more API calls until collect.
    """
    player_id = user.id
    
    # End any existing session
    if player_id in _sessions:
        del _sessions[player_id]
    
    # Create new session
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
    """Collect rewards from a winning session."""
    player_id = user.id
    
    if player_id not in _sessions:
        raise HTTPException(status_code=400, detail="No active session")
    
    session = _sessions[player_id]
    
    try:
        result = _manager.collect_rewards(session)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # Add to inventory if won
    if result["is_winner"] and result["reward_amount"] > 0:
        inv = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == player_id,
            PlayerInventory.item_id == result["reward_item"]
        ).first()
        
        if inv:
            inv.quantity += result["reward_amount"]
        else:
            inv = PlayerInventory(
                user_id=player_id,
                item_id=result["reward_item"],
                quantity=result["reward_amount"]
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
