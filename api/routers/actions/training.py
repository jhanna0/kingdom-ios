"""
Training system - Purchase and work on stat training
Uses unified contract system (no more JSONB!)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta

from db import get_db, User, Kingdom, UnifiedContract, ContractContribution
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import WORK_BASE_COOLDOWN


router = APIRouter()


# Training types that map to player stats
TRAINING_TYPES = ["attack", "defense", "leadership", "building", "intelligence"]


def calculate_training_cost(stat_level: int, total_trainings: int = 0) -> int:
    """Calculate gold cost to purchase training based on current stat level and total trainings
    
    Formula: 100 * (level^1.5) * (1.15^total_trainings)
    """
    base_cost = 100.0 * pow(float(stat_level), 1.5)
    global_multiplier = pow(1.15, float(total_trainings))
    return int(base_cost * global_multiplier)


def calculate_training_actions_required(stat_level: int, education_level: int = 0) -> int:
    """Calculate how many actions required to complete training
    
    Formula: (3 + (level // 3)) * (1 - (education_level * 0.05))
    """
    base_actions = 3 + (stat_level // 3)
    education_reduction = 1.0 - (education_level * 0.05)
    reduced_actions = int(base_actions * education_reduction)
    return max(1, reduced_actions)


def get_stat_value(state, training_type: str) -> int:
    """Get current stat value for a training type"""
    stat_map = {
        "attack": state.attack_power,
        "defense": state.defense_power,
        "leadership": state.leadership,
        "building": state.building_skill,
        "intelligence": state.intelligence
    }
    return stat_map.get(training_type, 1)


def increment_stat(state, training_type: str) -> tuple[str, int]:
    """Increment the stat and return (stat_name, new_value)"""
    if training_type == "attack":
        state.attack_power += 1
        return "Attack Power", state.attack_power
    elif training_type == "defense":
        state.defense_power += 1
        return "Defense Power", state.defense_power
    elif training_type == "leadership":
        state.leadership += 1
        return "Leadership", state.leadership
    elif training_type == "building":
        state.building_skill += 1
        return "Building Skill", state.building_skill
    elif training_type == "intelligence":
        state.intelligence += 1
        return "Intelligence", state.intelligence
    return "Unknown", 0


@router.get("/train/costs")
def get_training_costs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current training costs for all stats"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    total_trainings = state.total_training_purchases or 0
    
    return {
        "total_training_purchases": total_trainings,
        "costs": {
            "attack": calculate_training_cost(state.attack_power, total_trainings),
            "defense": calculate_training_cost(state.defense_power, total_trainings),
            "leadership": calculate_training_cost(state.leadership, total_trainings),
            "building": calculate_training_cost(state.building_skill, total_trainings),
            "intelligence": calculate_training_cost(state.intelligence, total_trainings)
        },
        "current_stats": {
            "attack": state.attack_power,
            "defense": state.defense_power,
            "leadership": state.leadership,
            "building": state.building_skill,
            "intelligence": state.intelligence
        },
        "gold": state.gold
    }


@router.get("/train/contracts")
def get_training_contracts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's training contracts"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get all training contracts for this user
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type.in_(TRAINING_TYPES)
    ).order_by(UnifiedContract.created_at.desc()).all()
    
    result = []
    for contract in contracts:
        # Count contributions (= actions completed)
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        result.append({
            "id": str(contract.id),
            "type": contract.type,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": contract.status,
            "gold_paid": contract.gold_paid,
            "created_at": contract.created_at.isoformat() if contract.created_at else None,
            "completed_at": contract.completed_at.isoformat() if contract.completed_at else None,
            "progress_percent": min(100, int((actions_completed / contract.actions_required) * 100)) if contract.actions_required > 0 else 100
        })
    
    return {"contracts": result}


@router.post("/train/purchase")
def purchase_training(
    training_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a training contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate training type
    if training_type not in TRAINING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid training type. Must be one of: {', '.join(TRAINING_TYPES)}"
        )
    
    # Check if already have an active training contract (any type)
    active_contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type.in_(TRAINING_TYPES),
        UnifiedContract.status == 'in_progress'
    ).first()
    
    if active_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You must complete your current {active_contract.type} training before starting a new one"
        )
    
    # Get current stat level
    current_stat = get_stat_value(state, training_type)
    
    # Get kingdom education level for training bonus
    education_level = 0
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            education_level = kingdom.education_level
    
    # Calculate cost and actions required
    total_trainings = state.total_training_purchases or 0
    training_cost = calculate_training_cost(current_stat, total_trainings)
    actions_required = calculate_training_actions_required(current_stat, education_level)
    
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    # Create the contract in the database
    contract = UnifiedContract(
        user_id=current_user.id,
        type=training_type,
        actions_required=actions_required,
        gold_paid=training_cost,
        status='in_progress',
        kingdom_id=state.current_kingdom_id
    )
    db.add(contract)
    
    # Spend gold and increment training counter
    state.gold -= training_cost
    state.total_training_purchases = total_trainings + 1
    
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Purchased {training_type} training! Complete {actions_required} actions to improve stat.",
        "training_type": training_type,
        "cost": training_cost,
        "contract_id": str(contract.id),
        "actions_required": actions_required
    }


@router.post("/train/{contract_id}")
def work_on_training(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a training contract (2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=work_cooldown)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to train"
        )
    
    # Find the training contract
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.user_id == current_user.id
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Training contract not found"
        )
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already completed"
        )
    
    # Count current actions completed
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already has all required actions"
        )
    
    # Add a contribution (= 1 action)
    xp_earned = 10
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id,
        xp_earned=xp_earned
    )
    db.add(contribution)
    
    # Update cooldown (both new table and legacy column)
    cooldown_expires = datetime.utcnow() + timedelta(hours=2)
    set_cooldown(db, current_user.id, "training", cooldown_expires)
    state.last_training_action = datetime.utcnow()
    state.experience += xp_earned
    
    # Check if training is now complete
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    stat_name = None
    new_value = None
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Increment the stat
        stat_name, new_value = increment_stat(state, contract.type)
        
        # Bonus XP for completing training
        bonus_xp = 25
        xp_earned += bonus_xp
        state.experience += bonus_xp
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50  # Level-up bonus
    
    db.commit()
    
    progress_percent = min(100, int((new_actions_completed / contract.actions_required) * 100))
    
    if is_complete:
        message = f"Training complete! {stat_name} increased to {new_value}!"
    else:
        message = f"Training action completed! {new_actions_completed}/{contract.actions_required} actions done."
    
    return {
        "success": True,
        "message": message,
        "contract_id": str(contract.id),
        "training_type": contract.type,
        "actions_completed": new_actions_completed,
        "actions_required": contract.actions_required,
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }
