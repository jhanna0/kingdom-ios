"""
Action status endpoint - Get cooldown status for all actions
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
import json

from db import get_db, User, PlayerState, Contract
from routers.auth import get_current_user
from routers.property import get_tier_name  # Import tier name helper
from .utils import check_cooldown, calculate_cooldown, check_global_action_cooldown
from .training import calculate_training_cost
from .crafting import get_craft_cost, get_iron_required, get_steel_required, get_actions_required, get_stat_bonus
from .constants import (
    WORK_BASE_COOLDOWN,
    PATROL_COOLDOWN,
    SABOTAGE_COOLDOWN,
    SCOUT_COOLDOWN,
    TRAINING_COOLDOWN
)


router = APIRouter()


@router.get("/status")
def get_action_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get cooldown status for all actions AND available contracts in current kingdom"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Calculate cooldowns based on skills
    work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    patrol_cooldown = PATROL_COOLDOWN
    sabotage_cooldown = SABOTAGE_COOLDOWN
    scout_cooldown = SCOUT_COOLDOWN
    training_cooldown = TRAINING_COOLDOWN
    
    # Count active patrollers in current kingdom
    active_patrollers = 0
    if state.current_kingdom_id:
        active_patrollers = db.query(PlayerState).filter(
            PlayerState.current_kingdom_id == state.current_kingdom_id,
            PlayerState.patrol_expires_at > datetime.utcnow()
        ).count()
    
    # Get contracts for current kingdom
    contracts = []
    if state.current_kingdom_id:
        from routers.contracts import contract_to_response
        contracts_query = db.query(Contract).filter(
            Contract.kingdom_id == state.current_kingdom_id,
            Contract.status.in_(["open", "in_progress"])
        ).all()
        contracts = [contract_to_response(c) for c in contracts_query]
    
    # Check global action cooldown (ONE ACTION AT A TIME!)
    global_cooldown = check_global_action_cooldown(
        state, 
        work_cooldown, 
        patrol_cooldown, 
        sabotage_cooldown, 
        scout_cooldown, 
        training_cooldown
    )
    
    # Get crafting costs for all tiers
    crafting_costs = {}
    for tier in range(1, 6):
        crafting_costs[f"tier_{tier}"] = {
            "gold": get_craft_cost(tier),
            "iron": get_iron_required(tier),
            "steel": get_steel_required(tier),
            "actions_required": get_actions_required(tier),
            "stat_bonus": get_stat_bonus(tier)
        }
    
    # Load property upgrade contracts and add computed tier names
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    for contract in property_contracts:
        # Compute target_tier_name from to_tier (not stored in DB!)
        contract["target_tier_name"] = get_tier_name(contract["to_tier"])
    
    return {
        "global_cooldown": global_cooldown,  # NEW: Global action lock
        "work": {
            **check_cooldown(state.last_work_action, work_cooldown),
            "cooldown_minutes": work_cooldown
        },
        "patrol": {
            **check_cooldown(state.last_patrol_action, patrol_cooldown),
            "cooldown_minutes": patrol_cooldown,
            "is_patrolling": state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow(),
            "active_patrollers": active_patrollers
        },
        "sabotage": {
            **check_cooldown(state.last_sabotage_action, sabotage_cooldown),
            "cooldown_minutes": sabotage_cooldown
        },
        "scout": {
            **check_cooldown(state.last_scout_action, scout_cooldown),
            "cooldown_minutes": scout_cooldown
        },
        "training": {
            **check_cooldown(state.last_training_action, training_cooldown),
            "cooldown_minutes": training_cooldown
        },
        "crafting": {
            **check_cooldown(state.last_crafting_action, work_cooldown),  # Same cooldown as building work
            "cooldown_minutes": work_cooldown
        },
        "training_contracts": state.training_contracts or [],
        "training_costs": {
            "attack": calculate_training_cost(state.attack_power),
            "defense": calculate_training_cost(state.defense_power),
            "leadership": calculate_training_cost(state.leadership),
            "building": calculate_training_cost(state.building_skill)
        },
        "crafting_queue": state.crafting_queue or [],
        "crafting_costs": crafting_costs,
        "property_upgrade_contracts": property_contracts,
        "contracts": contracts
    }

