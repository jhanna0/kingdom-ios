"""
COVERT INCIDENT API ROUTER
==========================
Endpoints for the intelligence/sabotage incident system.

Endpoints:
- POST /incidents/trigger - Attempt to trigger an incident in enemy kingdom
- POST /incidents/{incident_id}/join - Join an existing incident
- POST /incidents/{incident_id}/roll - Execute a roll
- POST /incidents/{incident_id}/resolve - Resolve the incident (master roll)
- GET /incidents/{incident_id} - Get incident status
- GET /incidents/active/{kingdom_id} - Get active incidents for a kingdom
- GET /incidents/config - Get tunable config values
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta

from db import get_db
from db.models import User, PlayerState, Kingdom
from db.models.action_cooldown import ActionCooldown
from routers.auth import get_current_user
from routers.actions.utils import set_cooldown, check_and_deduct_food_cost
from systems.incidents import IncidentManager, IncidentConfig
from websocket.broadcast import notify_kingdom

router = APIRouter(prefix="/incidents", tags=["incidents"])

# Global incident manager (in production, this would be Redis-backed)
_incident_manager = IncidentManager()


def get_incident_manager() -> IncidentManager:
    """Get the global incident manager instance."""
    return _incident_manager


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class JoinRequest(BaseModel):
    side: str  # "attacker" or "defender"


class IncidentResponse(BaseModel):
    success: bool
    message: str
    incident: Optional[dict] = None
    # Additional fields for trigger response
    triggered: Optional[bool] = None
    success_chance: Optional[float] = None
    roll: Optional[float] = None
    intelligence_tier: Optional[int] = None
    active_patrols: Optional[int] = None


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_player_stats(state: PlayerState) -> dict:
    """Extract relevant stats for incident rolls"""
    return {
        "intelligence": state.intelligence or 1,
        "attack_power": state.attack_power or 1,
        "defense_power": state.defense_power or 1,
    }


def count_active_patrols(db: Session, kingdom_id: str) -> int:
    """Count players currently on patrol in a kingdom"""
    now = datetime.utcnow()
    
    # Get all players in this kingdom
    players_in_kingdom = db.query(PlayerState.user_id).filter(
        PlayerState.current_kingdom_id == kingdom_id
    ).all()
    user_ids = [p.user_id for p in players_in_kingdom]
    
    if not user_ids:
        return 0
    
    # Count active patrol cooldowns
    count = db.query(ActionCooldown).filter(
        ActionCooldown.user_id.in_(user_ids),
        ActionCooldown.action_type == "patrol",
        ActionCooldown.expires_at > now
    ).count()
    
    return count


# ============================================================
# ENDPOINTS
# ============================================================

@router.get("/config")
def get_incident_config():
    """
    Get incident configuration values.
    Useful for frontend to display chances and rules.
    
    TWO-PHASE SYSTEM:
    1. Initial Success Roll: int_tier vs patrol_count determines if you succeed
    2. If success: Tug-of-war incident begins, outcomes determined by probability bar
    
    Outcomes scale with tier:
    - T1: intel only
    - T3: + disruption
    - T5: + contract_sabotage, vault_heist
    """
    from systems.incidents.config import (
        INCIDENT_DROP_TABLE_T1, 
        INCIDENT_DROP_TABLE_T3, 
        INCIDENT_DROP_TABLE_T5,
        INITIAL_SUCCESS_BY_TIER,
        PATROL_PENALTY_PER_PATROL,
        MIN_SUCCESS_CHANCE,
        MAX_SUCCESS_CHANCE,
    )
    
    return {
        # NEW: Initial success configuration
        "initial_success": {
            "base_by_tier": INITIAL_SUCCESS_BY_TIER,
            "patrol_penalty": PATROL_PENALTY_PER_PATROL,
            "min_chance": MIN_SUCCESS_CHANCE,
            "max_chance": MAX_SUCCESS_CHANCE,
            "description": "success = base_for_tier - (patrols * penalty), clamped to [min, max]",
        },
        # Example success chances for different scenarios
        "example_success_chances": {
            "T1_0_patrols": round(IncidentConfig.calculate_initial_success_chance(1, 0), 3),
            "T1_3_patrols": round(IncidentConfig.calculate_initial_success_chance(1, 3), 3),
            "T1_5_patrols": round(IncidentConfig.calculate_initial_success_chance(1, 5), 3),
            "T3_0_patrols": round(IncidentConfig.calculate_initial_success_chance(3, 0), 3),
            "T3_3_patrols": round(IncidentConfig.calculate_initial_success_chance(3, 3), 3),
            "T3_5_patrols": round(IncidentConfig.calculate_initial_success_chance(3, 5), 3),
            "T5_0_patrols": round(IncidentConfig.calculate_initial_success_chance(5, 0), 3),
            "T5_3_patrols": round(IncidentConfig.calculate_initial_success_chance(5, 3), 3),
            "T5_5_patrols": round(IncidentConfig.calculate_initial_success_chance(5, 5), 3),
            "T5_10_patrols": round(IncidentConfig.calculate_initial_success_chance(5, 10), 3),
        },
        # Incident phase config (after initial success)
        "duration_seconds": IncidentConfig.DURATION_SECONDS,
        "max_rolls_per_player": IncidentConfig.MAX_ROLLS_PLAYER,
        "max_rolls_per_side": IncidentConfig.MAX_ROLLS_SIDE,
        "shift_per_success": IncidentConfig.SHIFT_PER_SUCCESS,
        "critical_multiplier": IncidentConfig.CRITICAL_MULTIPLIER,
        "cost_gold": IncidentConfig.COST,
        # Tier-based drop tables - higher tier = more outcomes!
        "drop_tables_by_tier": {
            "T1": INCIDENT_DROP_TABLE_T1,
            "T3": INCIDENT_DROP_TABLE_T3,
            "T5": INCIDENT_DROP_TABLE_T5,
        },
        "tier_unlocks": {
            "T1": ["intel"],
            "T3": ["intel", "disruption"],
            "T5": ["intel", "disruption", "contract_sabotage", "vault_heist"],
        },
    }


@router.post("/trigger", response_model=IncidentResponse)
def trigger_incident(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: IncidentManager = Depends(get_incident_manager),
):
    """
    Attempt to trigger a covert incident in your current kingdom.
    
    TWO-PHASE SYSTEM:
    1. Initial Success Roll: Based on your intelligence tier vs enemy patrol count
       - Higher int tier = better chance
       - More patrols = worse chance  
       - If FAILS: operation fails, you lose gold + cooldown but get nothing
    2. If success: Incident triggers, tug-of-war probability bar begins
    
    Requirements:
    - Must be checked into a kingdom (uses current_kingdom_id)
    - Cannot target your own hometown
    - Costs gold (paid upfront win or lose)
    - Intelligence T1+ required
    """
    state = user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Must be checked into a kingdom
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=400,
            detail="Must be checked into a kingdom"
        )
    
    # Use current kingdom as the target
    defender_kingdom_id = state.current_kingdom_id
    
    # Requires Intelligence T1+
    if state.intelligence < 1:
        raise HTTPException(
            status_code=400,
            detail=f"Requires Intelligence T1+ (you have T{state.intelligence})"
        )
    
    # Cannot target hometown
    if state.hometown_kingdom_id == defender_kingdom_id:
        raise HTTPException(
            status_code=400,
            detail="Cannot target your own kingdom"
        )
    
    # Must have a hometown
    if not state.hometown_kingdom_id:
        raise HTTPException(
            status_code=400,
            detail="Must have a hometown kingdom"
        )
    
    # Check gold
    if state.gold < IncidentConfig.COST:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient gold. Need {IncidentConfig.COST}g"
        )
    
    # Check and deduct food cost (30 minute cooldown = 15 food)
    food_result = check_and_deduct_food_cost(db, user.id, 30, "infiltration")
    if not food_result["success"]:
        raise HTTPException(
            status_code=400,
            detail=food_result["error"]
        )
    
    # Deduct gold (paid upfront, win or lose!)
    state.gold -= IncidentConfig.COST
    
    # Set cooldown for scout action (30 minutes) - applies win or lose
    cooldown_expires = datetime.utcnow() + timedelta(minutes=30)
    set_cooldown(db, user.id, "scout", cooldown_expires)
    
    # Count patrols in defender kingdom
    active_patrols = count_active_patrols(db, defender_kingdom_id)
    
    # Attempt operation with TWO-PHASE logic:
    # Phase 1: Initial success roll (int tier vs patrols)
    # Phase 2: If success, incident triggers for tug-of-war
    result = manager.attempt_trigger(
        attacker_kingdom_id=state.hometown_kingdom_id,
        defender_kingdom_id=defender_kingdom_id,
        attacker_id=user.id,
        attacker_name=user.display_name or f"Player {user.id}",
        attacker_stats=get_player_stats(state),
        active_patrols=active_patrols,
    )
    
    db.commit()
    
    # If triggered (initial success AND incident created), notify both kingdoms
    if result.get("triggered"):
        # Notify defender kingdom
        notify_kingdom(
            kingdom_id=defender_kingdom_id,
            event_type="incident_triggered",
            data={
                "incident_id": result["incident_id"],
                "attacker_kingdom_id": state.hometown_kingdom_id,
                "message": "Covert operation detected! Defenders needed!",
            }
        )
        
        # Notify attacker kingdom
        notify_kingdom(
            kingdom_id=state.hometown_kingdom_id,
            event_type="incident_triggered",
            data={
                "incident_id": result["incident_id"],
                "defender_kingdom_id": defender_kingdom_id,
                "message": "Operation in progress! Support your agents!",
            }
        )
    
    # Add food info to the response by extending the incident dict
    response_incident = result.get("incident")
    if response_incident:
        response_incident["food_cost"] = food_result["food_cost"]
        response_incident["food_remaining"] = food_result["food_remaining"]
    
    return IncidentResponse(
        success=result.get("success", False),
        message=result["message"],
        incident=response_incident,
        triggered=result.get("triggered"),
        success_chance=result.get("success_chance"),
        roll=result.get("roll"),
        intelligence_tier=result.get("intelligence_tier"),
        active_patrols=result.get("active_patrols"),
    )


@router.post("/{incident_id}/join", response_model=IncidentResponse)
def join_incident(
    incident_id: str,
    request: JoinRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: IncidentManager = Depends(get_incident_manager),
):
    """
    Join an active incident as attacker or defender.
    
    - Attackers must be from the attacking kingdom
    - Defenders must be checked into the defending kingdom
    """
    state = user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    incident = manager.get_incident(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    
    # Validate side and location
    if request.side == "attacker":
        if state.hometown_kingdom_id != incident.attacker_kingdom_id:
            raise HTTPException(
                status_code=400,
                detail="Must be from the attacking kingdom"
            )
        kingdom_id = state.hometown_kingdom_id
    elif request.side == "defender":
        if state.current_kingdom_id != incident.defender_kingdom_id:
            raise HTTPException(
                status_code=400,
                detail="Must be checked into the defending kingdom"
            )
        kingdom_id = state.current_kingdom_id
    else:
        raise HTTPException(status_code=400, detail="Side must be 'attacker' or 'defender'")
    
    result = manager.join_incident(
        incident_id=incident_id,
        player_id=user.id,
        player_name=user.display_name or f"Player {user.id}",
        side=request.side,
        stats=get_player_stats(state),
        kingdom_id=kingdom_id,
    )
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    # Notify participants
    notify_kingdom(
        kingdom_id=incident.defender_kingdom_id,
        event_type="incident_player_joined",
        data={
            "incident_id": incident_id,
            "player_name": user.display_name,
            "side": request.side,
        }
    )
    
    return IncidentResponse(
        success=True,
        message=result["message"],
        incident=result.get("incident"),
    )


@router.post("/{incident_id}/roll", response_model=IncidentResponse)
def execute_roll(
    incident_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: IncidentManager = Depends(get_incident_manager),
):
    """
    Execute a roll in the incident.
    
    - Must be a participant
    - Shifts the probability bar based on success
    """
    result = manager.execute_roll(incident_id, user.id)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    incident = manager.get_incident(incident_id)
    
    # Broadcast roll to both kingdoms
    if incident:
        for kingdom_id in [incident.attacker_kingdom_id, incident.defender_kingdom_id]:
            notify_kingdom(
                kingdom_id=kingdom_id,
                event_type="incident_roll",
                data={
                    "incident_id": incident_id,
                    "roll": result["roll"],
                    "probabilities": incident.get_probabilities(),
                }
            )
    
    return IncidentResponse(
        success=True,
        message=result["message"],
        incident=result.get("incident"),
    )


@router.post("/{incident_id}/resolve", response_model=IncidentResponse)
def resolve_incident(
    incident_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: IncidentManager = Depends(get_incident_manager),
):
    """
    Resolve the incident with a master roll.
    
    - Must have at least 1 roll
    - Picks outcome based on current probability bar
    """
    result = manager.resolve_incident(incident_id)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    incident = manager.get_incident(incident_id)
    
    # Apply outcome effects (TODO: implement these)
    outcome = result["outcome"]
    if outcome == "intel":
        # TODO: Create KingdomIntelligence snapshot
        pass
    elif outcome == "disruption":
        # TODO: Apply temporary debuff to defender kingdom
        pass
    elif outcome == "contract_sabotage":
        # TODO: Delay defender's active contract
        pass
    elif outcome == "prevent":
        # TODO: Award defenders reputation/gold
        pass
    
    # Broadcast resolution to both kingdoms
    if incident:
        for kingdom_id in [incident.attacker_kingdom_id, incident.defender_kingdom_id]:
            notify_kingdom(
                kingdom_id=kingdom_id,
                event_type="incident_resolved",
                data={
                    "incident_id": incident_id,
                    "outcome": outcome,
                    "winner": result["winner"],
                    "message": result["message"],
                    "master_roll": result["master_roll"],
                }
            )
    
    return IncidentResponse(
        success=True,
        message=result["message"],
        incident=result.get("incident"),
    )


@router.get("/{incident_id}")
def get_incident_status(
    incident_id: str,
    manager: IncidentManager = Depends(get_incident_manager),
):
    """Get current status of an incident."""
    incident = manager.get_incident(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    
    return incident.to_dict()


@router.get("/active/attacking/{kingdom_id}")
def get_incidents_by_attacker(
    kingdom_id: str,
    manager: IncidentManager = Depends(get_incident_manager),
):
    """Get active incidents where this kingdom is the attacker."""
    incidents = [
        inc.to_dict() for inc in manager._incidents.values()
        if inc.attacker_kingdom_id == kingdom_id and inc.status.value == "active"
    ]
    return {"incidents": incidents, "count": len(incidents)}


@router.get("/active/defending/{kingdom_id}")
def get_incidents_by_defender(
    kingdom_id: str,
    manager: IncidentManager = Depends(get_incident_manager),
):
    """Get active incidents where this kingdom is the defender."""
    incidents = manager.get_incidents_for_defender(kingdom_id)
    return {
        "incidents": [inc.to_dict() for inc in incidents],
        "count": len(incidents),
    }
