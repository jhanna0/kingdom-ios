"""
HUNTING API ROUTER
==================
Endpoints for the group hunting activity.

Endpoints:
- POST /hunts/create - Create a new hunt in hometown kingdom
- POST /hunts/{hunt_id}/join - Join an existing hunt
- POST /hunts/{hunt_id}/ready - Mark yourself as ready
- POST /hunts/{hunt_id}/start - Start the hunt (creator only)
- POST /hunts/{hunt_id}/phase/{phase} - Execute a phase (auto-progresses)
- GET /hunts/{hunt_id} - Get hunt status
- GET /hunts/kingdom/{kingdom_id} - Get active hunt in a kingdom
- GET /hunts/preview - Get probability preview for current player
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime

from db import get_db
from db.models import User, PlayerState, PlayerInventory, Kingdom
from routers.auth import get_current_user
from routers.actions.tax_utils import apply_kingdom_tax
from systems.hunting import HuntManager, HuntConfig, HuntPhase
from systems.hunting.config import HUNTING_PERMIT_COST, HUNTING_PERMIT_DURATION_MINUTES, MEAT_MARKET_VALUE
from systems.hunting.hunt_manager import get_hunt_probability_preview, HuntStatus
from websocket.broadcast import notify_hunt_participants, PartyEvents

router = APIRouter(prefix="/hunts", tags=["hunts"])

# Global hunt manager (in production, this would be Redis-backed)
_hunt_manager = HuntManager()


def get_hunt_manager() -> HuntManager:
    """Get the global hunt manager instance."""
    return _hunt_manager


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class CreateHuntRequest(BaseModel):
    kingdom_id: str


class HuntResponse(BaseModel):
    success: bool
    message: str
    hunt: Optional[dict] = None


class PhaseResultResponse(BaseModel):
    success: bool
    message: str
    phase_result: Optional[dict] = None
    hunt: Optional[dict] = None


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_player_stats(db: Session, user_id: int) -> Dict[str, int]:
    """Get player's stats for hunting."""
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    if not state:
        return {}
    
    return {
        "intelligence": state.intelligence or 0,
        "attack_power": state.attack_power or 0,
        "defense": state.defense_power or 0,
        "faith": state.faith or 0,
        "leadership": state.leadership or 0,
    }


def add_to_inventory(db: Session, user_id: int, item_id: str, quantity: int) -> None:
    """Add items to player inventory (upsert)."""
    if quantity <= 0:
        return
    
    existing = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).first()
    
    if existing:
        existing.quantity += quantity
    else:
        db.add(PlayerInventory(user_id=user_id, item_id=item_id, quantity=quantity))


def apply_hunt_rewards(db: Session, hunt: dict) -> None:
    """Apply hunt rewards to participants.
    
    Hunts award MEAT + GOLD (meat * 0.5) and sinew (rare) for bow crafting.
    Gold is taxed by the kingdom where the hunt takes place.
    Uses proper inventory table, not columns per item type!
    
    Note: Leaderboard stats are derived directly from hunt_sessions table.
    """
    kingdom_id = hunt.get("kingdom_id")
    
    for player_id_str, participant in hunt.get("participants", {}).items():
        player_id = int(player_id_str)
        meat_earned = participant.get("meat_earned", 0)
        items_earned = participant.get("items_earned", [])
        
        # Add meat to inventory
        if meat_earned > 0:
            add_to_inventory(db, player_id, "meat", meat_earned)
        
        # Add gold based on meat earned (with tax)
        if meat_earned > 0:
            player_state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
            if player_state:
                gold_value = float(meat_earned) * MEAT_MARKET_VALUE
                net_gold, tax_amount, tax_rate = apply_kingdom_tax(
                    db, kingdom_id, player_state, gold_value
                )
                gold_earned = int(net_gold) if net_gold >= 1 else 1
                player_state.gold += gold_earned
                # Store gold earned in participant data for response
                participant["gold_earned"] = gold_earned
                participant["gold_tax"] = int(tax_amount)
        
        # Add rare drops (sinew, etc)
        for item_id in items_earned:
            add_to_inventory(db, player_id, item_id, 1)
    
    db.commit()


def calculate_hunting_stats(db: Session, player_id: int) -> dict:
    """
    Get total loot from hunts completed in the LAST HOUR.
    Just query the database and sum everything up.
    """
    from db.models import HuntSession as HuntSessionModel
    from routers.resources import RESOURCES
    from datetime import datetime, timedelta
    
    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    
    # Get all completed hunts from last hour where player participated
    hunts = db.query(HuntSessionModel).filter(
        HuntSessionModel.status == 'completed',
        HuntSessionModel.completed_at >= one_hour_ago
    ).all()
    
    total_meat = 0
    total_gold = 0
    items_count = {}
    hunt_count = 0
    
    player_id_str = str(player_id)
    
    for hunt in hunts:
        data = hunt.session_data
        if not data:
            continue
        
        # Check if player was in this hunt
        participants = data.get("participants", {})
        if player_id_str not in participants:
            continue
        
        hunt_count += 1
        
        # Get this player's loot from this hunt
        participant = participants[player_id_str]
        meat = participant.get("meat_earned", 0)
        total_meat += meat
        
        # Gold = meat * market value
        gold = int(meat * MEAT_MARKET_VALUE) if meat * MEAT_MARKET_VALUE >= 1 else 1
        total_gold += gold
        
        # Items are stored at top level as items_dropped, NOT in rewards
        items = data.get("items_dropped", [])
        for item_id in items:
            if item_id:
                items_count[item_id] = items_count.get(item_id, 0) + 1
    
    # Build item details from RESOURCES config
    item_details = []
    for item_id, count in items_count.items():
        item_config = RESOURCES.get(item_id, {})
        item_details.append({
            "id": item_id,
            "display_name": item_config.get("display_name", item_id.replace("_", " ").title()),
            "icon": item_config.get("icon", "cube.fill"),
            "color": item_config.get("color", "gray"),
            "count": count,
        })
    
    return {
        "meat": total_meat,
        "gold": total_gold,
        "item_details": item_details,
        "hunt_count": hunt_count,
    }


# ============================================================
# ENDPOINTS - Static routes MUST come before dynamic routes!
# ============================================================

# --- Static GET routes (must be before /{hunt_id}) ---

@router.get("/preview")
def get_hunt_preview(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get hunt probability preview based on player's stats.
    Shows chances for each phase and potential animals.
    """
    stats = get_player_stats(db, user.id)
    preview = get_hunt_probability_preview(stats)
    
    return {
        "player_stats": stats,
        **preview,
    }


@router.get("/leaderboard/{kingdom_id}")
def get_hunt_leaderboard(
    kingdom_id: str,
    limit: int = 10,
    db: Session = Depends(get_db),
):
    """
    Get hunt leaderboard for a kingdom.
    
    Queries hunt_sessions directly - no separate stats table needed.
    Returns top hunters sorted by hunts completed, with per-creature kill counts.
    """
    from systems.hunting.config import ANIMALS
    from db.models import HuntSession as HuntSessionModel
    from sqlalchemy import text
    
    # Query completed hunts from hunt_sessions, aggregate by participant
    # session_data contains: animal_id (string), participants (dict)
    query = text("""
        WITH hunt_participants AS (
            SELECT 
                (p.value->>'player_id')::bigint as player_id,
                session_data->>'animal_id' as animal_id
            FROM hunt_sessions,
            jsonb_each(session_data->'participants') as p
            WHERE kingdom_id = :kingdom_id
            AND status = 'completed'
            AND session_data->>'animal_id' IS NOT NULL
            AND session_data->>'animal_id' != ''
        ),
        creature_counts AS (
            SELECT 
                player_id,
                animal_id,
                COUNT(*) as animal_count
            FROM hunt_participants
            GROUP BY player_id, animal_id
        ),
        player_totals AS (
            SELECT 
                player_id,
                SUM(animal_count) as hunts_completed,
                jsonb_object_agg(animal_id, animal_count) as creature_kills
            FROM creature_counts
            GROUP BY player_id
        )
        SELECT * FROM player_totals
        ORDER BY hunts_completed DESC
        LIMIT :limit
    """)
    
    results = db.execute(query, {"kingdom_id": kingdom_id, "limit": limit}).fetchall()
    
    # Build creature info for frontend
    creatures = {
        creature_id: {"name": data["name"], "icon": data["icon"]}
        for creature_id, data in ANIMALS.items()
    }
    
    leaderboard = []
    for rank, row in enumerate(results, start=1):
        user = db.query(User).filter(User.id == row.player_id).first()
        leaderboard.append({
            "rank": rank,
            "user_id": row.player_id,
            "display_name": user.display_name if user else f"Player {row.player_id}",
            "avatar_url": user.avatar_url if user else None,
            "hunts_completed": row.hunts_completed,
            "creature_kills": row.creature_kills or {},
        })
    
    return {
        "kingdom_id": kingdom_id,
        "creatures": creatures,
        "leaderboard": leaderboard,
    }


@router.get("/config")
def get_hunt_config():
    """
    Get hunt configuration for the UI.
    Includes timing, party limits, animals, phases, and drop tables.
    
    NOTE: Hunts drop MEAT + GOLD (equal amounts, gold is taxed) + sinew (rare) for bow crafting.
    """
    from systems.hunting.config import (
        PHASE_CONFIG, ANIMALS, TRACK_TIER_THRESHOLDS, DROP_TABLES, MEAT_MARKET_VALUE,
        TRACK_DROP_TABLE_DISPLAY, ATTACK_DROP_TABLE_DISPLAY, BLESSING_DROP_TABLE_DISPLAY,
        LOOT_TIERS
    )
    from routers.resources import HUNTING_BOW, RESOURCES
    
    def _build_animal_config(animal_id: str, data: dict) -> dict:
        """Build animal config with rare drop info from LOOT_TIERS and RESOURCES."""
        # Get rare items from LOOT_TIERS config
        rare_items = LOOT_TIERS.get("rare", {}).get("items", [])
        can_drop_rare = data["tier"] >= 2 and len(rare_items) > 0
        
        # Build rare_drop object from RESOURCES (single source of truth!)
        rare_drop = None
        if can_drop_rare and rare_items:
            item_id = rare_items[0]  # First rare item
            item_config = RESOURCES.get(item_id, {})
            rare_drop = {
                "item_id": item_id,
                "item_name": item_config.get("display_name", item_id.title()),
                "item_icon": item_config.get("icon", "cube.fill"),
            }
        
        return {
            "id": animal_id,
            "name": data["name"],
            "icon": data["icon"],
            "tier": data["tier"],
            "meat": data["meat"],
            "hp": data["hp"],
            "rare_drop": rare_drop,  # None if can't drop rare, or {item_id, item_name, item_icon}
            "description": data["description"],
            "track_requirement": TRACK_TIER_THRESHOLDS.get(data["tier"], 0),
        }
    
    return {
        "timing": {
            "lobby_timeout_seconds": HuntConfig.LOBBY_TIMEOUT,
            "phase_duration_seconds": HuntConfig.PHASE_DURATION,
            "results_duration_seconds": HuntConfig.RESULTS_DURATION,
            "cooldown_minutes": HuntConfig.COOLDOWN,
        },
        "party": {
            "min_size": HuntConfig.MIN_PARTY,
            "max_size": HuntConfig.MAX_PARTY,
        },
        "phases": {
            phase.value: {
                "name": config["name"],
                "display_name": config["display_name"],
                "stat": config["stat"],
                "icon": config["icon"],
                "description": config["description"],
                # Include rare item info for blessing phase
                "rare_item_name": config.get("rare_item_name"),
                "rare_item_icon": config.get("rare_item_icon"),
            }
            for phase, config in PHASE_CONFIG.items()
        },
        "animals": [
            _build_animal_config(animal_id, data)
            for animal_id, data in ANIMALS.items()
        ],
        "tier_thresholds": TRACK_TIER_THRESHOLDS,
        "hunting_bow": HUNTING_BOW,
        "meat_market_value": MEAT_MARKET_VALUE,
        # Drop table display configs - sent to frontend for UI
        "drop_tables": {
            "track": TRACK_DROP_TABLE_DISPLAY,
            "strike": ATTACK_DROP_TABLE_DISPLAY,
            "blessing": BLESSING_DROP_TABLE_DISPLAY,
        },
        "notes": {
            "rewards": "Hunts drop MEAT + GOLD (equal, taxed) + fur (uncommon) + sinew (rare)",
            "fur": "Drops from deer and larger game - used to craft defense armor",
            "sinew": "Rarer drop from boar and larger game - used to craft hunting bow",
            "bow": "Craft hunting bow with 10 wood + 3 sinew for +2 attack in hunts",
        },
        "hunting_permit": {
            "cost": HUNTING_PERMIT_COST,
            "duration_minutes": HUNTING_PERMIT_DURATION_MINUTES,
            "description": "Required to hunt in kingdoms other than your hometown",
        },
    }


@router.get("/kingdom/{kingdom_id}")
def get_kingdom_hunt(
    kingdom_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Get active hunt for the current user in a kingdom, if any.
    
    Only returns hunts where the user is a participant - other users' hunts
    don't block you from hunting.
    """
    # Get the user's active hunt (not just any hunt in the kingdom)
    session = manager.get_active_hunt_for_player(db, user.id)
    
    # Only return if the hunt is in this kingdom
    if session and session.kingdom_id == kingdom_id:
        return {"active_hunt": session.to_dict()}
    
    return {"active_hunt": None}


@router.get("/permit-status/{kingdom_id}")
def get_permit_status(
    kingdom_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get hunting permit status for a kingdom.
    
    Returns whether the user needs a permit and if they have one.
    """
    player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not player_state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    is_hometown = player_state.hometown_kingdom_id == kingdom_id
    is_visiting = player_state.current_kingdom_id == kingdom_id and not is_hometown
    
    has_valid_permit = (
        player_state.hunting_permit_kingdom_id == kingdom_id and
        player_state.hunting_permit_expires_at and
        player_state.hunting_permit_expires_at > datetime.utcnow()
    )
    
    permit_expires_at = None
    minutes_remaining = 0
    if has_valid_permit:
        permit_expires_at = player_state.hunting_permit_expires_at.isoformat()
        remaining = player_state.hunting_permit_expires_at - datetime.utcnow()
        minutes_remaining = max(0, int(remaining.total_seconds() / 60))
    
    return {
        "kingdom_id": kingdom_id,
        "is_hometown": is_hometown,
        "is_visiting": is_visiting,
        "needs_permit": is_visiting,
        "has_valid_permit": has_valid_permit,
        "can_hunt": is_hometown or has_valid_permit,
        "permit_expires_at": permit_expires_at,
        "minutes_remaining": minutes_remaining,
        "permit_cost": HUNTING_PERMIT_COST,
        "permit_duration_minutes": HUNTING_PERMIT_DURATION_MINUTES,
    }


@router.post("/buy-permit")
def buy_hunting_permit(
    request: CreateHuntRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Buy a hunting permit for a kingdom you're visiting.
    
    - Costs 10 gold (goes to kingdom treasury)
    - Valid for 10 minutes
    - Required to start hunts in non-hometown kingdoms
    """
    from datetime import timedelta
    
    player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not player_state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Must be visiting the kingdom (not your hometown)
    if player_state.current_kingdom_id != request.kingdom_id:
        return {
            "success": False,
            "message": "You must be in the kingdom to buy a permit",
        }
    
    if player_state.hometown_kingdom_id == request.kingdom_id:
        return {
            "success": False,
            "message": "You don't need a permit in your hometown!",
        }
    
    # Check if already has a valid permit for this kingdom
    if (player_state.hunting_permit_kingdom_id == request.kingdom_id and 
        player_state.hunting_permit_expires_at and 
        player_state.hunting_permit_expires_at > datetime.utcnow()):
        remaining = player_state.hunting_permit_expires_at - datetime.utcnow()
        minutes_left = int(remaining.total_seconds() / 60)
        return {
            "success": False,
            "message": f"You already have a valid permit ({minutes_left}m remaining)",
            "permit_expires_at": player_state.hunting_permit_expires_at.isoformat(),
        }
    
    # Check gold
    if player_state.gold < HUNTING_PERMIT_COST:
        return {
            "success": False,
            "message": f"Not enough gold (need {HUNTING_PERMIT_COST}g)",
        }
    
    # Get kingdom to add gold to treasury
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    # Deduct gold and add to kingdom treasury
    player_state.gold -= HUNTING_PERMIT_COST
    kingdom.treasury_gold += HUNTING_PERMIT_COST
    
    # Set permit
    player_state.hunting_permit_kingdom_id = request.kingdom_id
    player_state.hunting_permit_expires_at = datetime.utcnow() + timedelta(minutes=HUNTING_PERMIT_DURATION_MINUTES)
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Hunting permit purchased! Valid for {HUNTING_PERMIT_DURATION_MINUTES} minutes.",
        "permit_expires_at": player_state.hunting_permit_expires_at.isoformat(),
        "gold_spent": HUNTING_PERMIT_COST,
        "new_gold": int(player_state.gold),
    }


# --- Dynamic routes (after static routes) ---

@router.post("/create", response_model=HuntResponse)
def create_hunt(
    request: CreateHuntRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Create a new group hunt in a kingdom.
    Players can only have one active hunt at a time.
    Players can create hunts in their hometown OR in kingdoms where they have a valid hunting permit.
    """
    player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not player_state:
        return HuntResponse(
            success=False,
            message="Player state not found",
            hunt=None,
        )
    
    # Must be in the kingdom you're trying to hunt in
    if player_state.current_kingdom_id != request.kingdom_id:
        return HuntResponse(
            success=False,
            message="You must be in the kingdom to start a hunt",
            hunt=None,
        )
    
    # Check if this is hometown OR has valid permit
    is_hometown = player_state.hometown_kingdom_id == request.kingdom_id
    has_valid_permit = (
        player_state.hunting_permit_kingdom_id == request.kingdom_id and
        player_state.hunting_permit_expires_at and
        player_state.hunting_permit_expires_at > datetime.utcnow()
    )
    
    if not is_hometown and not has_valid_permit:
        return HuntResponse(
            success=False,
            message="You need a hunting permit to hunt in this kingdom! (10g for 10 minutes)",
            hunt=None,
        )
    
    # Check if player already has an active hunt
    existing = manager.get_active_hunt_for_player(db, user.id)
    if existing:
        return HuntResponse(
            success=False,
            message="You already have an active hunt",
            hunt=existing.to_dict(),
        )
    
    # Get player stats
    stats = get_player_stats(db, user.id)
    
    # Create the hunt
    session = manager.create_hunt(
        db=db,
        kingdom_id=request.kingdom_id,
        creator_id=user.id,
        creator_name=user.display_name or f"Player {user.id}",
        creator_stats=stats,
    )
    
    hunt_dict = session.to_dict()
    
    # Broadcast to kingdom that a hunt is available
    notify_hunt_participants(
        hunt_session=hunt_dict,
        event_type=PartyEvents.HUNT_LOBBY_CREATED,
        data={"message": f"{user.display_name} started a hunt!"}
    )
    
    return HuntResponse(
        success=True,
        message="Hunt created! Waiting for party members...",
        hunt=hunt_dict,
    )


@router.post("/{hunt_id}/join", response_model=HuntResponse)
def join_hunt(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """Join an existing hunt lobby. User must be in the same kingdom as the hunt."""
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    # Check that user is in the same kingdom as the hunt
    player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    user_kingdom = player_state.current_kingdom_id if player_state else None
    
    if not user_kingdom or user_kingdom != session.kingdom_id:
        return HuntResponse(
            success=False,
            message="You can only join hunts in your current kingdom",
            hunt=None,
        )
    
    if session.status != HuntStatus.LOBBY:
        return HuntResponse(
            success=False,
            message="Hunt has already started",
            hunt=session.to_dict(),
        )
    
    if user.id in session.participants:
        return HuntResponse(
            success=False,
            message="You're already in this hunt",
            hunt=session.to_dict(),
        )
    
    stats = get_player_stats(db, user.id)
    
    if not session.add_participant(
        player_id=user.id,
        player_name=user.display_name or f"Player {user.id}",
        stats=stats,
    ):
        return HuntResponse(
            success=False,
            message="Hunt is full",
            hunt=session.to_dict(),
        )
    
    # Save to database
    manager.save_hunt(db, session)
    
    hunt_dict = session.to_dict()
    
    # Notify other participants
    notify_hunt_participants(
        hunt_session=hunt_dict,
        event_type=PartyEvents.HUNT_PLAYER_JOINED,
        data={
            "player_id": user.id,
            "player_name": user.display_name or f"Player {user.id}",
        }
    )
    
    return HuntResponse(
        success=True,
        message=f"Joined the hunt! ({len(session.participants)}/{HuntConfig.MAX_PARTY})",
        hunt=hunt_dict,
    )


@router.post("/{hunt_id}/leave", response_model=HuntResponse)
def leave_hunt(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """Leave or abandon a hunt."""
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if user.id not in session.participants:
        return HuntResponse(
            success=False,
            message="You're not in this hunt",
            hunt=session.to_dict(),
        )
    
    # Remove participant
    session.remove_participant(user.id)
    
    # If no participants left or creator left, cancel the hunt
    if len(session.participants) == 0 or session.created_by == user.id:
        session.status = HuntStatus.CANCELLED
    
    # Save to database
    manager.save_hunt(db, session)
    
    return HuntResponse(
        success=True,
        message="Left the hunt",
        hunt=session.to_dict(),
    )


@router.post("/{hunt_id}/ready", response_model=HuntResponse)
def toggle_ready(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """Toggle ready status in hunt lobby."""
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if user.id not in session.participants:
        return HuntResponse(
            success=False,
            message="You're not in this hunt",
        )
    
    current = session.participants[user.id].is_ready
    session.set_ready(user.id, not current)
    
    # Save to database
    manager.save_hunt(db, session)
    
    hunt_dict = session.to_dict()
    
    # Notify others of ready status change
    notify_hunt_participants(
        hunt_session=hunt_dict,
        event_type=PartyEvents.HUNT_PLAYER_READY,
        data={
            "player_id": user.id,
            "ready": not current,
        }
    )
    
    return HuntResponse(
        success=True,
        message="Ready!" if not current else "Not ready",
        hunt=hunt_dict,
    )


@router.post("/{hunt_id}/start", response_model=HuntResponse)
def start_hunt(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """Start the hunt (creator only, all must be ready)."""
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if session.created_by != user.id:
        return HuntResponse(
            success=False,
            message="Only the hunt leader can start",
            hunt=session.to_dict(),
        )
    
    if not session.all_ready():
        return HuntResponse(
            success=False,
            message="Not all party members are ready",
            hunt=session.to_dict(),
        )
    
    if not manager.start_hunt(db, session):
        return HuntResponse(
            success=False,
            message="Cannot start hunt",
            hunt=session.to_dict(),
        )
    
    hunt_dict = session.to_dict()
    
    # Notify all participants that hunt started
    notify_hunt_participants(
        hunt_session=hunt_dict,
        event_type=PartyEvents.HUNT_STARTED,
        data={"message": "The hunt begins!"}
    )
    
    return HuntResponse(
        success=True,
        message="The hunt begins!",
        hunt=hunt_dict,
    )


# ============================================================
# MULTI-ROLL ENDPOINTS
# ============================================================

class RollResponse(BaseModel):
    """Response for individual roll within a phase"""
    success: bool
    message: str
    roll_result: Optional[dict] = None
    phase_state: Optional[dict] = None
    phase_update: Optional[dict] = None
    hunt: Optional[dict] = None


@router.post("/{hunt_id}/roll", response_model=RollResponse)
def execute_roll(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Execute a single roll within the current phase.
    
    TRACK phase: Each roll shifts creature probabilities
    STRIKE phase: Each roll deals damage or risks escape
    BLESSING phase: Each roll adds to loot bonus
    """
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if session.status != HuntStatus.IN_PROGRESS:
        return RollResponse(
            success=False,
            message="Hunt is not active",
            hunt=session.to_dict(),
        )
    
    if user.id not in session.participants:
        return RollResponse(
            success=False,
            message="You're not in this hunt",
        )
    
    if not session.current_phase_state:
        return RollResponse(
            success=False,
            message="No active phase",
            hunt=session.to_dict(),
        )
    
    # Execute the roll
    result = manager.execute_roll(db, session, user.id)
    
    if not result.get("success"):
        return RollResponse(
            success=False,
            message=result.get("message", "Cannot roll"),
            hunt=session.to_dict(),
        )
    
    # Broadcast roll to other participants
    notify_hunt_participants(
        hunt_session=session.to_dict(),
        event_type="hunt_roll",
        data={
            "player_id": user.id,
            "roll_result": result.get("roll_result"),
            "phase_update": result.get("phase_update"),
        }
    )
    
    return RollResponse(
        success=True,
        message=result["roll_result"]["message"],
        roll_result=result.get("roll_result"),
        phase_state=result.get("phase_state"),
        phase_update=result.get("phase_update"),
        hunt=result.get("hunt"),
    )


@router.post("/{hunt_id}/resolve", response_model=PhaseResultResponse)
def resolve_phase(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Resolve/finalize the current phase.
    
    TRACK phase: Performs the "Master Roll" that slides along the probability bar
    STRIKE phase: Finalizes the combat (kill or escape)
    BLESSING phase: Calculates final loot with accumulated bonus
    """
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if session.status != HuntStatus.IN_PROGRESS:
        return PhaseResultResponse(
            success=False,
            message="Hunt is not active",
            hunt=session.to_dict(),
        )
    
    if user.id not in session.participants:
        return PhaseResultResponse(
            success=False,
            message="You're not in this hunt",
        )
    
    # Resolve the phase
    result = manager.resolve_phase(db, session)
    
    if not result.get("success"):
        return PhaseResultResponse(
            success=False,
            message=result.get("message", "Cannot resolve phase"),
            hunt=session.to_dict(),
        )
    
    # Broadcast phase completion
    notify_hunt_participants(
        hunt_session=session.to_dict(),
        event_type=PartyEvents.HUNT_PHASE_COMPLETE,
        data={
            "phase": result.get("phase"),
            "result": result.get("phase_result"),
        }
    )
    
    return PhaseResultResponse(
        success=True,
        message=result.get("message", "Phase resolved"),
        phase_result=result.get("phase_result"),
        hunt=result.get("hunt"),
    )


@router.post("/{hunt_id}/next-phase", response_model=HuntResponse)
def advance_phase(
    hunt_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Advance to the next phase after resolving current one.
    If no more phases, finalizes the hunt.
    """
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if session.status != HuntStatus.IN_PROGRESS:
        return HuntResponse(
            success=False,
            message="Hunt is not active",
            hunt=session.to_dict(),
        )
    
    if user.id not in session.participants:
        return HuntResponse(
            success=False,
            message="You're not in this hunt",
        )
    
    # Check current phase is resolved
    if session.current_phase_state and not session.current_phase_state.is_resolved:
        return HuntResponse(
            success=False,
            message="Must resolve current phase first",
            hunt=session.to_dict(),
        )
    
    # Advance to next phase
    next_phase = manager.advance_to_next_phase(db, session)
    
    if next_phase:
        notify_hunt_participants(
            hunt_session=session.to_dict(),
            event_type="hunt_phase_start",
            data={"phase": next_phase.value}
        )
        
        return HuntResponse(
            success=True,
            message=f"Starting {next_phase.value} phase",
            hunt=session.to_dict(),
        )
    else:
        # Hunt is complete
        final_result = manager.finalize_hunt(db, session)
        apply_hunt_rewards(db, final_result)
        
        # Add hunting efficiency stats (loot per hour based on recent hunts)
        final_result["hunting_stats"] = calculate_hunting_stats(db, user.id)
        
        notify_hunt_participants(
            hunt_session=final_result,
            event_type=PartyEvents.HUNT_ENDED,
            data={"message": "Hunt complete!"}
        )
        
        return HuntResponse(
            success=True,
            message="Hunt complete!",
            hunt=final_result,
        )


# ============================================================
# LEGACY PHASE ENDPOINT (for backwards compatibility)
# ============================================================

@router.post("/{hunt_id}/phase/{phase_name}", response_model=PhaseResultResponse)
def execute_phase(
    hunt_id: str,
    phase_name: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """
    Execute a hunt phase (LEGACY - uses old single-roll system).
    For new clients, use /roll and /resolve endpoints instead.
    
    Phases must be executed in order: track -> strike -> blessing
    """
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    if session.status != HuntStatus.IN_PROGRESS:
        return PhaseResultResponse(
            success=False,
            message="Hunt is not active",
            hunt=session.to_dict(),
        )
    
    if user.id not in session.participants:
        return PhaseResultResponse(
            success=False,
            message="You're not in this hunt",
        )
    
    # Parse phase
    try:
        phase = HuntPhase(phase_name)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid phase: {phase_name}")
    
    # Validate phase order (Approach removed - was boring)
    phase_order = [HuntPhase.TRACK, HuntPhase.STRIKE, HuntPhase.BLESSING]
    
    if phase not in phase_order:
        return PhaseResultResponse(
            success=False,
            message=f"Invalid phase: {phase_name}",
        )
    
    # Check if this phase was already executed
    executed_phases = [pr.phase for pr in session.phase_results]
    if phase in executed_phases:
        return PhaseResultResponse(
            success=False,
            message=f"Phase {phase.value} already completed",
            hunt=session.to_dict(),
        )
    
    # Check phase order
    phase_index = phase_order.index(phase)
    for i in range(phase_index):
        if phase_order[i] not in executed_phases:
            return PhaseResultResponse(
                success=False,
                message=f"Must complete {phase_order[i].value} phase first",
            )
    
    # Execute the phase
    result = manager.execute_phase(db, session, phase)
    
    # Check for early termination conditions
    hunt_ended = False
    final_result = None
    
    if phase == HuntPhase.TRACK and session.track_score <= 0:
        # No trail found - hunt ends
        final_result = manager.finalize_hunt(db, session)
        hunt_ended = True
    elif phase == HuntPhase.STRIKE and session.animal_escaped:
        # Animal escaped - hunt ends
        final_result = manager.finalize_hunt(db, session)
        hunt_ended = True
    elif phase == HuntPhase.BLESSING:
        # Hunt complete!
        final_result = manager.finalize_hunt(db, session)
        hunt_ended = True
        
        # Apply rewards to database
        apply_hunt_rewards(db, final_result)
    
    # Add hunting efficiency stats when hunt ends
    if hunt_ended and final_result:
        final_result["hunting_stats"] = calculate_hunting_stats(db, user.id)
    
    # Broadcast phase completion
    hunt_dict = final_result if hunt_ended else session.to_dict()
    notify_hunt_participants(
        hunt_session=hunt_dict,
        event_type=PartyEvents.HUNT_PHASE_COMPLETE if not hunt_ended else PartyEvents.HUNT_ENDED,
        data={
            "phase": phase.value,
            "result": result.to_dict(),
        }
    )
    
    return PhaseResultResponse(
        success=True,
        message=result.outcome_message,
        phase_result=result.to_dict(),
        hunt=hunt_dict,
    )


@router.get("/{hunt_id}")
def get_hunt_status(
    hunt_id: str,
    db: Session = Depends(get_db),
    manager: HuntManager = Depends(get_hunt_manager),
):
    """Get current hunt status."""
    session = manager.get_hunt(db, hunt_id)
    if not session:
        raise HTTPException(status_code=404, detail="Hunt not found")
    
    return session.to_dict()


