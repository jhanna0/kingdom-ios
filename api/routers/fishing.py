"""
FISHING API ROUTER
==================
Endpoints for the chill fishing minigame.

Flow:
1. POST /fishing/start - Start a fishing session
2. POST /fishing/cast - Cast line, get pre-calculated rolls
3. POST /fishing/reel - Reel in fish, get pre-calculated rolls
4. POST /fishing/end - End session, collect rewards

Sessions are stored in PostgreSQL, not in Lambda memory.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime

from db import get_db
from db.models import PlayerState, User
from db.models.inventory import PlayerInventory
from db.models.fishing_session import FishingSession as FishingSessionDB
from routers.actions.utils import log_activity
from routers.auth import get_current_user
from systems.fishing import FishingManager, FishingSession
from systems.fishing.config import (
    FISH,
    CAST_DROP_TABLE,
    CAST_DROP_TABLE_DISPLAY,
    REEL_BASE_CAUGHT,
    REEL_BASE_ESCAPED,
    REEL_DROP_TABLE_DISPLAY,
    LOOT_DROP_TABLE,
    LOOT_DROP_TABLE_DISPLAY,
    PHASE_CONFIG,
    FishingPhase,
    ROLL_HIT_CHANCE,
    ROLL_ANIMATION_DELAY_MS,
)


router = APIRouter(prefix="/fishing", tags=["fishing"])

# Manager instance (stateless - just does calculations)
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
        "kingdom_id": player.current_kingdom_id,
    }


def session_from_db(db_session: FishingSessionDB) -> FishingSession:
    """Reconstruct FishingSession from database record."""
    data = db_session.session_data
    session = FishingSession(
        session_id=db_session.fishing_id,
        player_id=db_session.created_by,
        total_meat=data.get("total_meat", 0),
        fish_caught=data.get("fish_caught", 0),
        pet_fish_dropped=data.get("pet_fish_dropped", False),
        current_fish=data.get("current_fish"),
        casts_attempted=data.get("stats", {}).get("casts_attempted", 0),
        successful_catches=data.get("stats", {}).get("successful_catches", 0),
        fish_escaped=data.get("stats", {}).get("fish_escaped", 0),
    )
    return session


def update_db_session(db_session: FishingSessionDB, session: FishingSession) -> None:
    """Update database record from FishingSession."""
    db_session.session_data = session.to_dict()
    db_session.updated_at = datetime.utcnow()


def add_rewards_to_inventory(db: Session, player_id: int, session: FishingSession) -> None:
    """
    Add fishing rewards to player's inventory.
    
    Note: Pet fish are added immediately when caught (in reel endpoint),
    so we only add meat here at session end.
    """
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
    
    # Pet fish already added in reel endpoint when caught - don't double add!


def broadcast_rare_loot(db: Session, player_id: int) -> None:
    """
    Broadcast pet fish drop to activity feed.
    This shows up in friends' activity feeds!
    """
    from routers.resources import RESOURCES
    fish = RESOURCES["pet_fish"]
    
    log_activity(
        db=db,
        user_id=player_id,
        action_type="rare_loot",
        action_category="fishing",
        description=f"Caught a {fish['display_name']}! 🐟",
        kingdom_id=None,
        amount=None,
        details={
            "item_id": "pet_fish",
            "item_name": fish["display_name"],
            "item_icon": fish["icon"],
        },
        visibility="friends"
    )


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
                "drop_table": {"escaped": REEL_BASE_ESCAPED, "caught": REEL_BASE_CAUGHT},
                "drop_table_display": REEL_DROP_TABLE_DISPLAY,
            },
            "loot": {
                **PHASE_CONFIG[FishingPhase.LOOTING],
                "drop_table": LOOT_DROP_TABLE,
                "drop_table_display": LOOT_DROP_TABLE_DISPLAY,
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
    stats = get_player_stats(db, player_id)
    
    # Check if player already has an active session in DB
    existing = db.query(FishingSessionDB).filter(
        FishingSessionDB.created_by == player_id,
        FishingSessionDB.status == 'active'
    ).first()
    
    if existing:
        # Check if expired
        if existing.is_expired:
            existing.status = 'expired'
            existing.updated_at = datetime.utcnow()
            db.commit()
        else:
            # Return existing session
            session = session_from_db(existing)
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
    
    # Store in database
    now = datetime.utcnow()
    db_session = FishingSessionDB(
        fishing_id=session.session_id,
        created_by=player_id,
        kingdom_id=stats.get("kingdom_id"),
        status='active',
        session_data=session.to_dict(),
        created_at=now,
        started_at=now,
        updated_at=now,
        expires_at=FishingSessionDB.default_expiry(),
    )
    db.add(db_session)
    db.commit()
    
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
    
    # Get active session from database
    db_session = db.query(FishingSessionDB).filter(
        FishingSessionDB.created_by == player_id,
        FishingSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active fishing session. Call /fishing/start first.")
    
    if db_session.is_expired:
        db_session.status = 'expired'
        db_session.updated_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=400, detail="Session expired. Start a new one.")
    
    # Reconstruct session from DB
    session = session_from_db(db_session)
    stats = get_player_stats(db, player_id)
    
    # Can't cast if fish is on the line (need to reel first)
    if session.current_fish:
        raise HTTPException(
            status_code=400, 
            detail=f"Fish on the line! Reel in your {FISH[session.current_fish]['name']} first."
        )
    
    # Execute cast with all rolls pre-calculated
    result = _manager.execute_cast(session, stats["building"])
    
    # Update database
    update_db_session(db_session, session)
    db.commit()
    
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
    
    If rare loot drops (pet fish), broadcasts to friends and adds to inventory immediately!
    """
    player_id = user.id
    
    # Get active session from database
    db_session = db.query(FishingSessionDB).filter(
        FishingSessionDB.created_by == player_id,
        FishingSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active fishing session. Call /fishing/start first.")
    
    if db_session.is_expired:
        db_session.status = 'expired'
        db_session.updated_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=400, detail="Session expired. Start a new one.")
    
    # Reconstruct session from DB
    session = session_from_db(db_session)
    stats = get_player_stats(db, player_id)
    
    # Must have fish on the line
    if not session.current_fish:
        raise HTTPException(status_code=400, detail="No fish on the line. Cast first!")
    
    # Execute reel with all rolls pre-calculated
    result = _manager.execute_reel(session, stats["defense"])
    
    # If caught and pet fish dropped, broadcast and add to inventory NOW
    if result.outcome == "caught" and result.outcome_display.get("rare_loot_dropped"):
        # Add pet fish to inventory immediately
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
        
        # Broadcast to friends
        broadcast_rare_loot(db, player_id)
    
    # Update database
    update_db_session(db_session, session)
    db.commit()
    
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
    
    Adds accumulated meat to player's inventory.
    """
    player_id = user.id
    
    # Get active session from database
    db_session = db.query(FishingSessionDB).filter(
        FishingSessionDB.created_by == player_id,
        FishingSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active fishing session.")
    
    # Reconstruct session from DB
    session = session_from_db(db_session)
    
    # Get final rewards summary
    rewards = _manager.end_session(session)
    
    # Add to inventory
    add_rewards_to_inventory(db, player_id, session)
    
    # Mark session as collected
    now = datetime.utcnow()
    db_session.status = 'collected'
    db_session.completed_at = now
    db_session.updated_at = now
    db.commit()
    
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
    
    # Get active session from database
    db_session = db.query(FishingSessionDB).filter(
        FishingSessionDB.created_by == player_id,
        FishingSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        return {
            "has_session": False,
            "session": None,
        }
    
    # Check if expired
    if db_session.is_expired:
        db_session.status = 'expired'
        db_session.updated_at = datetime.utcnow()
        db.commit()
        return {
            "has_session": False,
            "session": None,
        }
    
    session = session_from_db(db_session)
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
