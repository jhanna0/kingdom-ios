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
from .utils import check_and_set_slot_cooldown_atomic, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import WORK_BASE_COOLDOWN, TRAINING_COOLDOWN


router = APIRouter()


# Import centralized skill definitions
from routers.tiers import SKILLS, SKILL_TYPES, get_stat_value, increment_stat, get_total_skill_points, get_all_skill_values

# Training types = all skill types (for backward compatibility)
TRAINING_TYPES = SKILL_TYPES


def calculate_training_cost(total_skill_points: int) -> int:
    """Calculate gold cost to purchase training based ONLY on TOTAL SKILL POINTS across ALL skills
    
    ALL skills cost the same for their next tier based on the SUM of all skill levels.
    This prevents min-maxing - every skill point makes ALL skills more expensive.
    
    Formula: 100 * (1.5^(total_skill_points + 1))
    
    We use (total + 1) because we're calculating the cost for the NEXT skill point.
    
    Examples:
    - 0 total skill points: 100 * 1.5^1 = 150g for ANY skill's first tier
    - 3 total skill points: 100 * 1.5^4 = 506g for ANY skill's next tier
    - 10 total skill points: 100 * 1.5^11 = 8659g for ANY skill's next tier
    """
    base_cost = 100.0
    # Use total + 1 because we're buying the NEXT skill point
    cost_multiplier = pow(1.5, float(total_skill_points + 1))
    return int(base_cost * cost_multiplier)


def calculate_training_actions_required(stat_level: int, education_level: int = 0) -> int:
    """Calculate how many actions required to complete training
    
    Formula: base_actions = 10 + (stat_level * 18) + (stat_level^2 * 3)
    
    This gives exponential growth:
    - Tier 1 (level 0 -> 1): 10 actions
    - Tier 2 (level 1 -> 2): 31 actions  
    - Tier 3 (level 2 -> 3): 58 actions
    - Tier 4 (level 3 -> 4): 91 actions
    - Tier 5 (level 4 -> 5): 130 actions
    - ...scales up to tier 10
    
    Education building can reduce this by up to 25% at max level.
    """
    # Exponential scaling formula
    base_actions = 10 + (stat_level * 18) + (stat_level ** 2 * 3)
    
    # Education building reduces training time (max 25% reduction at level 5)
    education_reduction = 1.0 - min(education_level * 0.05, 0.25)
    reduced_actions = int(base_actions * education_reduction)
    return max(5, reduced_actions)


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
    
    # ALL skills cost the SAME based on total skill points
    total_skill_points = get_total_skill_points(state)
    unified_cost = calculate_training_cost(total_skill_points)
    
    # Generate costs dynamically for all skills
    costs = {skill_type: unified_cost for skill_type in SKILL_TYPES}
    
    # Get current stats dynamically for all skills
    current_stats = get_all_skill_values(state)
    
    return {
        "total_skill_points": total_skill_points,
        "total_training_purchases": state.total_training_purchases or 0,
        "costs": costs,
        "current_stats": current_stats,
        "gold": int(state.gold)
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
            "status": "completed" if contract.completed_at else "in_progress",
            "gold_paid": contract.gold_paid,
            "created_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "completed_at": format_datetime_iso(contract.completed_at) if contract.completed_at else None,
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
        UnifiedContract.completed_at.is_(None)  # Active contracts only
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
    
    # Calculate cost based on TOTAL SKILL POINTS across ALL skills
    total_skill_points = get_total_skill_points(state)
    training_cost = calculate_training_cost(total_skill_points)
    actions_required = calculate_training_actions_required(current_stat, education_level)
    
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {int(state.gold)}g"
        )
    
    # Create the contract in the database
    contract = UnifiedContract(
        user_id=current_user.id,
        category='personal_training',
        type=training_type,
        actions_required=actions_required,
        gold_paid=training_cost,
        kingdom_id=state.current_kingdom_id
    )
    db.add(contract)
    
    # Spend gold and increment training counter
    state.gold -= training_cost
    state.total_training_purchases = (state.total_training_purchases or 0) + 1
    
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
    
    # ATOMIC COOLDOWN CHECK + SET - prevents race conditions in serverless
    cooldown_expires = datetime.utcnow() + timedelta(minutes=TRAINING_COOLDOWN)
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="training",
            cooldown_minutes=TRAINING_COOLDOWN,
            expires_at=cooldown_expires
        )
        
        if not cooldown_result["ready"]:
            remaining = cooldown_result["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = cooldown_result["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Personal action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s."
            )
    else:
        # DEV_MODE: still set cooldown for functionality, just skip the check
        set_cooldown(db, current_user.id, "training", cooldown_expires)
    
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
    
    if contract.completed_at is not None:
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
    
    state.experience += xp_earned
    
    # Check if training is now complete
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    stat_name = None
    new_value = None
    
    if is_complete:
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
        message = f"Training complete! {stat_name} increased to {new_value}"
    else:
        message = f"You begin training!"
    
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
