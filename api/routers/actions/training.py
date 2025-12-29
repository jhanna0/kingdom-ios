"""
Training system - Purchase and work on stat training
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import uuid

from db import get_db, User
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, format_datetime_iso


router = APIRouter()


def calculate_training_cost(stat_level: int) -> int:
    """Calculate gold cost to purchase training based on current stat level
    
    Formula: 100 * (level^1.5)
    Level 1→2: 100g
    Level 5→6: 559g
    Level 10→11: 1581g
    """
    return int(100.0 * pow(float(stat_level), 1.5))


def calculate_training_actions_required(stat_level: int) -> int:
    """Calculate how many actions required to complete training
    
    Formula: 3 + (level // 3)
    Level 1: 3 actions
    Level 5: 4 actions
    Level 10: 6 actions
    Scales with stat level - higher stats take more work
    """
    return 3 + (stat_level // 3)


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
    valid_types = ["attack", "defense", "leadership", "building"]
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
        "building": state.building_skill
    }
    current_stat = stat_map[training_type]
    
    # Calculate cost and actions required
    training_cost = calculate_training_cost(current_stat)
    actions_required = calculate_training_actions_required(current_stat)
    
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    # Check if already have a contract for this type
    training_contracts = state.training_contracts or []
    for contract in training_contracts:
        if contract.get("type") == training_type and contract.get("status") != "completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Already have an active {training_type} training contract"
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
    
    # Add contract and spend gold
    training_contracts.append(new_contract)
    state.training_contracts = training_contracts
    state.gold -= training_cost
    
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
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_training_action, 120)  # 2 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        minutes = (cooldown_status["seconds_remaining"] % 3600) // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Training on cooldown. Wait {hours}h {minutes}m"
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

