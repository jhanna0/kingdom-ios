"""
FISHING API ROUTER
==================
Endpoints for the chill fishing minigame.

Flow:
1. POST /fishing/start - Start a fishing session
2. POST /fishing/cast - Cast line, get pre-calculated rolls
3. POST /fishing/reel - Reel in fish, get pre-calculated rolls
4. POST /fishing/end - End session, collect rewards
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, Dict
import time

from db import get_db
from db.models import PlayerState, User
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from systems.fishing import FishingManager, FishingSession
from systems.fishing.config import (
    FISH,
    CAST_DROP_TABLE,
    CAST_DROP_TABLE_DISPLAY,
    REEL_DROP_TABLE,
    REEL_DROP_TABLE_DISPLAY,
    PHASE_CONFIG,
    FishingPhase,
    ROLL_HIT_CHANCE,
    ROLL_ANIMATION_DELAY_MS,
)


router = APIRouter(prefix="/fishing", tags=["fishing"])

# In-memory session storage (simple for now)
# In production, could use Redis or DB if sessions need to persist across Lambda invocations
_active_sessions: Dict[int, FishingSession] = {}

# Manager instance
_manager = FishingManager()


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class StartFishingRequest(BaseModel):
    """Request to start a fishing session."""
    pass  # No params needed, uses player's stats


class CastRequest(BaseModel):
    """Request to cast the line."""
    pass  # No params needed


class ReelRequest(BaseModel):
    """Request to reel in a fish."""
    pass  # No params needed


class EndSessionRequest(BaseModel):
    """Request to end session and collect rewards."""
    pass  # No params needed


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_player_stats(db: Session, player_id: int) -> dict:
    """Get player's fishing-relevant stats."""
    player = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    return {
        "building": player.building_skill or 0,
        "defense": player.defense_power or 0,
    }


def add_rewards_to_inventory(db: Session, player_id: int, session: FishingSession) -> None:
    """Add fishing rewards to player's inventory."""
    # Add meat
    if session.total_meat > 0:
        meat_entry = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == player_id,
            PlayerInventory.item_id == "meat"
        ).first()
        
        if meat_entry:
            meat_entry.quantity += session.total_meat
        else:
            meat_entry = PlayerInventory(
                user_id=player_id,
                item_id="meat",
                quantity=session.total_meat
            )
            db.add(meat_entry)
    
    # Add pet fish if dropped
    if session.pet_fish_dropped:
        pet_entry = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == player_id,
            PlayerInventory.item_id == "pet_fish"
        ).first()
        
        if pet_entry:
            pet_entry.quantity += 1
        else:
            pet_entry = PlayerInventory(
                user_id=player_id,
                item_id="pet_fish",
                quantity=1
            )
            db.add(pet_entry)
    
    db.commit()


# ============================================================
# ENDPOINTS
# ============================================================

@router.get("/config")
def get_fishing_config():
    """
    Get fishing configuration for frontend.
    
    Returns all display data so frontend can be a dumb template.
    """
    return {
        "fish": FISH,
        "phases": {
            "cast": {
                **PHASE_CONFIG[FishingPhase.CASTING],
                "drop_table": CAST_DROP_TABLE,
                "drop_table_display": CAST_DROP_TABLE_DISPLAY,
            },
            "reel": {
                **PHASE_CONFIG[FishingPhase.REELING],
                "drop_table": REEL_DROP_TABLE,
                "drop_table_display": REEL_DROP_TABLE_DISPLAY,
            },
        },
        "roll_hit_chance": int(ROLL_HIT_CHANCE * 100),
        "animation_delay_ms": ROLL_ANIMATION_DELAY_MS,
    }


@router.post("/start")
def start_fishing(
    request: StartFishingRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Start a new fishing session.
    
    Returns initial session state and player's relevant stats.
    """
    player_id = user.id
    
    # Check if player already has an active session
    if player_id in _active_sessions:
        # Return existing session
        session = _active_sessions[player_id]
        stats = get_player_stats(db, player_id)
        return {
            "success": True,
            "message": "Resumed existing fishing session",
            "session": session.to_dict(),
            "player_stats": stats,
            "config": {
                "cast_rolls": 1 + stats["building"],
                "reel_rolls": 1 + stats["defense"],
                "hit_chance": int(ROLL_HIT_CHANCE * 100),
            },
        }
    
    # Create new session
    session = _manager.create_session(player_id)
    _active_sessions[player_id] = session
    
    stats = get_player_stats(db, player_id)
    
    return {
        "success": True,
        "message": "Started fishing session",
        "session": session.to_dict(),
        "player_stats": stats,
        "config": {
            "cast_rolls": 1 + stats["building"],
            "reel_rolls": 1 + stats["defense"],
            "hit_chance": int(ROLL_HIT_CHANCE * 100),
        },
    }


@router.post("/cast")
def cast_line(
    request: CastRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Cast the fishing line.
    
    Returns ALL roll results pre-calculated.
    Frontend animates through them for a chill experience.
    """
    player_id = user.id
    
    if player_id not in _active_sessions:
        raise HTTPException(status_code=400, detail="No active fishing session. Call /fishing/start first.")
    
    session = _active_sessions[player_id]
    stats = get_player_stats(db, player_id)
    
    # Can't cast if fish is on the line (need to reel first)
    if session.current_fish:
        raise HTTPException(
            status_code=400, 
            detail=f"Fish on the line! Reel in your {FISH[session.current_fish]['name']} first."
        )
    
    # Execute cast with all rolls pre-calculated
    result = _manager.execute_cast(session, stats["building"])
    
    return {
        "success": True,
        "result": result.to_dict(),
        "session": session.to_dict(),
    }


@router.post("/reel")
def reel_in(
    request: ReelRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Reel in a fish on the line.
    
    Returns ALL roll results pre-calculated.
    Frontend animates through them for a chill experience.
    """
    player_id = user.id
    
    if player_id not in _active_sessions:
        raise HTTPException(status_code=400, detail="No active fishing session. Call /fishing/start first.")
    
    session = _active_sessions[player_id]
    stats = get_player_stats(db, player_id)
    
    # Must have fish on the line
    if not session.current_fish:
        raise HTTPException(status_code=400, detail="No fish on the line. Cast first!")
    
    # Execute reel with all rolls pre-calculated
    result = _manager.execute_reel(session, stats["defense"])
    
    return {
        "success": True,
        "result": result.to_dict(),
        "session": session.to_dict(),
    }


@router.post("/end")
def end_fishing(
    request: EndSessionRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    End the fishing session and collect all rewards.
    
    Adds accumulated meat and pet fish to player's inventory.
    """
    player_id = user.id
    
    if player_id not in _active_sessions:
        raise HTTPException(status_code=400, detail="No active fishing session.")
    
    session = _active_sessions[player_id]
    
    # Get final rewards summary
    rewards = _manager.end_session(session)
    
    # Add to inventory
    add_rewards_to_inventory(db, player_id, session)
    
    # Clean up session
    del _active_sessions[player_id]
    
    return {
        "success": True,
        "message": "Fishing session complete!",
        "rewards": rewards,
    }


@router.get("/status")
def get_fishing_status(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Get current fishing session status.
    
    Returns session state if active, or null if no session.
    """
    player_id = user.id
    
    if player_id not in _active_sessions:
        return {
            "has_session": False,
            "session": None,
        }
    
    session = _active_sessions[player_id]
    stats = get_player_stats(db, player_id)
    
    return {
        "has_session": True,
        "session": session.to_dict(),
        "player_stats": stats,
        "config": {
            "cast_rolls": 1 + stats["building"],
            "reel_rolls": 1 + stats["defense"],
            "hit_chance": int(ROLL_HIT_CHANCE * 100),
        },
    }
