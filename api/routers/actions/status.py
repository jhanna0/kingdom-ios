"""
Action status endpoint - Get cooldown status for all actions
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime

from db import get_db, User, PlayerState, Contract
from routers.auth import get_current_user
from .utils import check_cooldown, calculate_cooldown
from .training import calculate_training_cost


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
    work_cooldown = calculate_cooldown(120, state.building_skill)  # Base 2 hours
    patrol_cooldown = 10  # Always 10 minutes
    sabotage_cooldown = 1440  # 24 hours (once per day)
    mine_cooldown = 1440  # 24 hours (once per day)
    scout_cooldown = 1440  # 24 hours (once per day)
    training_cooldown = 120  # 2 hours for training actions
    
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
    
    return {
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
        "mine": {
            **check_cooldown(state.last_mining_action, mine_cooldown),
            "cooldown_minutes": mine_cooldown
        },
        "scout": {
            **check_cooldown(state.last_scout_action, scout_cooldown),
            "cooldown_minutes": scout_cooldown
        },
        "training": {
            **check_cooldown(state.last_training_action, training_cooldown),
            "cooldown_minutes": training_cooldown
        },
        "training_contracts": state.training_contracts or [],
        "training_costs": {
            "attack": calculate_training_cost(state.attack_power),
            "defense": calculate_training_cost(state.defense_power),
            "leadership": calculate_training_cost(state.leadership),
            "building": calculate_training_cost(state.building_skill)
        },
        "contracts": contracts
    }

