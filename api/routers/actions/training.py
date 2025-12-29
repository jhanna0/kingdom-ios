"""
Training system - Purchase and work on stat training
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import uuid

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, check_global_action_cooldown, format_datetime_iso, calculate_cooldown


router = APIRouter()


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


def calculate_training_cost(stat_level: int, total_trainings: int = 0) -> int:
    """Calculate gold cost to purchase training based on current stat level and total trainings
    
    Formula: 100 * (level^1.5) * (1.15^total_trainings)
    
    Base cost scales with stat level:
    - Level 1→2: 100g (base)
    - Level 5→6: 559g (base)
    - Level 10→11: 1581g (base)
    
    Global multiplier (1.15^total_trainings) makes everything more expensive:
    - 0 trainings: 1.0x
    - 5 trainings: 2.01x
    - 10 trainings: 4.05x
    - 15 trainings: 8.14x
    - 20 trainings: 16.37x
    
    This forces strategic choices - can't easily max everything!
    """
    base_cost = 100.0 * pow(float(stat_level), 1.5)
    global_multiplier = pow(1.15, float(total_trainings))
    return int(base_cost * global_multiplier)


def calculate_training_actions_required(stat_level: int, education_level: int = 0) -> int:
    """Calculate how many actions required to complete training
    
    Formula: (3 + (level // 3)) * (1 - (education_level * 0.05))
    Base actions scale with stat level - higher stats take more work
    Education building reduces actions required by 5% per level (up to 25% at T5)
    
    Level 1: 3 actions base
    Level 5: 4 actions base
    Level 10: 6 actions base
    
    With education T5: 25% reduction
    """
    base_actions = 3 + (stat_level // 3)
    education_reduction = 1.0 - (education_level * 0.05)
    reduced_actions = int(base_actions * education_reduction)
    # Minimum of 1 action required
    return max(1, reduced_actions)


@router.post("/train/purchase")
def purchase_training(
    training_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a training contract (works like building contracts)
    
    Args:
        training_type: "attack", "defense", "leadership", or "building"
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate training type
    valid_types = ["attack", "defense", "leadership", "building", "intelligence"]
    if training_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid training type. Must be one of: {', '.join(valid_types)}"
        )
    
    # Get current stat level
    stat_map = {
        "attack": state.attack_power,
        "defense": state.defense_power,
        "leadership": state.leadership,
        "building": state.building_skill,
        "intelligence": state.intelligence
    }
    current_stat = stat_map[training_type]
    
    # Get kingdom education level for training bonus
    education_level = 0
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            education_level = kingdom.education_level
    
    # Get total training purchases for global cost scaling
    total_trainings = state.total_training_purchases or 0
    
    # Calculate cost and actions required (with education bonus and global scaling)
    training_cost = calculate_training_cost(current_stat, total_trainings)
    actions_required = calculate_training_actions_required(current_stat, education_level)
    
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    # Check if already have ANY active training contract
    training_contracts = state.training_contracts or []
    for contract in training_contracts:
        if contract.get("status") != "completed":
            active_type = contract.get("type")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You must complete your current {active_type} training before starting a new one"
            )
    
    # Create training contract
    contract_id = str(uuid.uuid4())
    new_contract = {
        "id": contract_id,
        "type": training_type,
        "actions_required": actions_required,
        "actions_completed": 0,
        "cost_paid": training_cost,
        "created_at": datetime.utcnow().isoformat(),
        "status": "in_progress"
    }
    
    # Add contract, spend gold, and increment training counter
    training_contracts.append(new_contract)
    state.training_contracts = training_contracts
    state.gold -= training_cost
    state.total_training_purchases = total_trainings + 1  # Increment for next purchase
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased {training_type} training! Complete {actions_required} actions to improve stat.",
        "training_type": training_type,
        "cost": training_cost,
        "contract_id": contract_id,
        "actions_required": actions_required
    }


@router.post("/train/{contract_id}")
def work_on_training(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a training contract (2 hour cooldown, like building contracts)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(120, state.building_skill)
        global_cooldown = check_global_action_cooldown(
            state, 
            work_cooldown=work_cooldown,
            patrol_cooldown=10,
            sabotage_cooldown=1440,
            scout_cooldown=1440,
            training_cooldown=120
        )
        
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
    training_contracts = state.training_contracts or []
    contract = None
    contract_index = None
    for i, c in enumerate(training_contracts):
        if c.get("id") == contract_id:
            contract = c
            contract_index = i
            break
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Training contract not found"
        )
    
    if contract.get("status") == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already completed"
        )
    
    # Increment actions completed
    contract["actions_completed"] = contract.get("actions_completed", 0) + 1
    state.last_training_action = datetime.utcnow()
    
    # Check if training is complete
    is_complete = contract["actions_completed"] >= contract["actions_required"]
    
    # Award XP for each action
    xp_earned = 10  # 10 XP per training action
    state.experience += xp_earned
    
    if is_complete:
        contract["status"] = "completed"
        contract["completed_at"] = datetime.utcnow().isoformat()
        
        # Increase the stat!
        training_type = contract["type"]
        if training_type == "attack":
            state.attack_power += 1
            stat_name = "Attack Power"
            new_value = state.attack_power
        elif training_type == "defense":
            state.defense_power += 1
            stat_name = "Defense Power"
            new_value = state.defense_power
        elif training_type == "leadership":
            state.leadership += 1
            stat_name = "Leadership"
            new_value = state.leadership
        elif training_type == "building":
            state.building_skill += 1
            stat_name = "Building Skill"
            new_value = state.building_skill
        elif training_type == "intelligence":
            state.intelligence += 1
            stat_name = "Intelligence"
            new_value = state.intelligence
        
        # Bonus XP for completing training
        xp_earned += 25  # Total 35 XP when complete
        state.experience += 25
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50
    
    # Update the contract in the list
    training_contracts[contract_index] = contract
    state.training_contracts = training_contracts
    
    db.commit()
    
    progress_percent = int((contract["actions_completed"] / contract["actions_required"]) * 100)
    
    if is_complete:
        message = f"Training complete! {stat_name} increased to {new_value}!"
    else:
        message = f"Training action completed! {contract['actions_completed']}/{contract['actions_required']} actions done."
    
    return {
        "success": True,
        "message": message,
        "contract_id": contract_id,
        "training_type": contract["type"],
        "actions_completed": contract["actions_completed"],
        "actions_required": contract["actions_required"],
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }

