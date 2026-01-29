"""
Training system - Purchase and work on stat training
Uses unified contract system (no more JSONB!)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
import random

from db import get_db, User, Kingdom, UnifiedContract, ContractContribution
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_and_set_slot_cooldown_atomic, format_datetime_iso, calculate_cooldown, calculate_training_cooldown, set_cooldown, check_and_deduct_food_cost
from .constants import WORK_BASE_COOLDOWN, TRAINING_COOLDOWN


router = APIRouter()


# Import centralized skill definitions and training scaling functions
from routers.tiers import (
    SKILLS, SKILL_TYPES, 
    get_stat_value, increment_stat, get_total_skill_points, get_all_skill_values,
    calculate_training_gold_per_action, calculate_training_actions,
    get_education_training_reduction, get_science_cooldown_reduction
)

# Training types = all skill types (for backward compatibility)
TRAINING_TYPES = SKILL_TYPES


def get_training_actions_with_reductions(current_tier: int, total_skill_points: int, education_level: int = 0) -> int:
    """Calculate actions required with education reduction applied.
    
    Uses centralized formula from tiers.py, then applies reduction:
    - Education building (kingdom): reduces training ACTIONS required
    
    Note: Science skill reduces COOLDOWNS, not actions (handled separately).
    """
    # Get base actions from centralized formula
    base_actions = calculate_training_actions(current_tier, total_skill_points)
    
    # Education building reduces training actions (values from tiers.py)
    education_multiplier = get_education_training_reduction(education_level)
    
    # Apply reduction
    reduced_actions = int(base_actions * education_multiplier)
    return max(5, reduced_actions)


@router.get("/train/costs")
def get_training_costs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current training costs for all stats.
    
    NEW SYSTEM: Gold scales by tier, actions scale by tier + total points.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    total_skill_points = get_total_skill_points(state)
    current_stats = get_all_skill_values(state)
    
    # Get kingdom education level for training bonus
    education_level = 0
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            education_level = kingdom.education_level
    
    science_level = state.science or 1
    
    # Generate costs dynamically for each skill using centralized logic
    from routers.tiers import get_training_info_for_skill
    costs = {}
    for skill_type in SKILL_TYPES:
        info = get_training_info_for_skill(state, skill_type)
        
        # Apply education reduction to actions (kingdom building)
        actions_required = get_training_actions_with_reductions(
            info["current_tier"],
            total_skill_points, 
            education_level
        )
        
        costs[skill_type] = {
            "actions_required": actions_required,
            "gold_per_action": round(info["gold_per_action"], 1),
            "total_gold": round(info["gold_per_action"] * actions_required, 1)
        }
    
    # Get current kingdom tax rate for display
    current_tax_rate = 0
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            current_tax_rate = kingdom.tax_rate
    
    return {
        "total_skill_points": total_skill_points,
        "total_training_purchases": state.total_training_purchases or 0,
        "costs": costs,
        "current_stats": current_stats,
        "current_tax_rate": current_tax_rate,
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
    
    # Get current kingdom tax rate for display
    current_tax_rate = 0
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            current_tax_rate = kingdom.tax_rate
    
    result = []
    for contract in contracts:
        # Count contributions (= actions completed)
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        # Determine gold cost info
        gold_per_action = contract.gold_per_action or 0
        
        result.append({
            "id": str(contract.id),
            "type": contract.type,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": "completed" if contract.completed_at else "in_progress",
            "gold_paid": contract.gold_paid,  # OLD: upfront payment (backwards compat)
            "gold_per_action": round(gold_per_action, 1) if gold_per_action > 0 else None,  # NEW: per-action cost
            "current_tax_rate": current_tax_rate if gold_per_action > 0 else None,  # For display
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
    """Purchase a training contract.
    
    NEW PAY-PER-ACTION SYSTEM:
    - No upfront gold cost
    - Gold cost is calculated and stored as gold_per_action
    - Each training action costs gold_per_action + kingdom tax (paid at action time)
    - Tax goes to kingdom treasury, base cost is burned
    """
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
    
    # Use centralized function for training info
    from routers.tiers import get_training_info_for_skill
    info = get_training_info_for_skill(state, training_type)
    current_tier = info["current_tier"]
    target_tier = info["target_tier"]
    gold_per_action = info["gold_per_action"]
    
    # Get kingdom education level for training bonus
    education_level = 0
    kingdom = None
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            education_level = kingdom.education_level
    
    # Get total skill points (affects actions required)
    total_skill_points = get_total_skill_points(state)
    
    # Apply education reduction to actions (kingdom building)
    actions_required = get_training_actions_with_reductions(
        current_tier, total_skill_points, education_level
    )
    
    # Get current tax rate for display (actual tax applied at action time)
    current_tax_rate = kingdom.tax_rate if kingdom else 0
    
    # Create the contract in the database
    # gold_paid = 0 (no upfront), gold_per_action = calculated cost per action
    contract = UnifiedContract(
        user_id=current_user.id,
        category='personal_training',
        type=training_type,
        actions_required=actions_required,
        gold_paid=0,  # No upfront payment
        gold_per_action=gold_per_action,  # Pay per action
        kingdom_id=state.current_kingdom_id
    )
    db.add(contract)
    
    # Increment training counter (no gold spent yet)
    state.total_training_purchases = (state.total_training_purchases or 0) + 1
    
    db.commit()
    db.refresh(contract)
    
    # Calculate total for display
    total_gold = gold_per_action * actions_required
    
    return {
        "success": True,
        "message": f"Started {training_type} training! Complete {actions_required} actions to improve stat.",
        "training_type": training_type,
        "cost": int(total_gold),  # Backwards compat: total cost for display
        "gold_per_action": round(gold_per_action, 1),  # Cost per action before tax
        "total_gold": round(total_gold, 1),  # Total gold over all actions (for display)
        "current_tax_rate": current_tax_rate,  # Current rate (may change)
        "contract_id": str(contract.id),
        "actions_required": actions_required
    }


@router.post("/train/{contract_id}")
def work_on_training(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a training contract (2 hour cooldown).
    
    PAY-PER-ACTION SYSTEM:
    - NEW contracts (gold_per_action > 0): Pay gold_per_action + kingdom tax each action
    - OLD contracts (gold_paid > 0, gold_per_action = 0): Actions are FREE (already paid upfront)
    - Tax goes to kingdom treasury, base cost is burned
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Find the training contract FIRST (need to check gold cost before other checks)
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
    
    # === PAY-PER-ACTION GOLD COST ===
    # Check if this is a new-style contract (pay per action) or old-style (already paid)
    gold_per_action = contract.gold_per_action or 0
    action_gold_cost = 0
    tax_amount = 0
    tax_rate = 0
    
    if gold_per_action > 0:
        # NEW SYSTEM: Calculate action cost with tax
        kingdom = None
        if state.current_kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        
        # Get tax rate (rulers don't pay tax)
        is_ruler = kingdom and kingdom.ruler_id == current_user.id
        tax_rate = 0 if is_ruler else (kingdom.tax_rate if kingdom else 0)
        
        # Total cost = base + tax
        tax_amount = gold_per_action * tax_rate / 100
        action_gold_cost = gold_per_action + tax_amount
        
        # Check if player can afford
        if state.gold < action_gold_cost:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Not enough gold. Need {int(action_gold_cost)}g ({int(gold_per_action)}g + {int(tax_amount)}g tax), have {int(state.gold)}g"
            )
    # else: OLD SYSTEM - gold_paid > 0 means they paid upfront, action is FREE
    
    # Calculate cooldown with science skill reduction (personal skill reduces training cooldowns)
    science_level = state.science or 1
    cooldown_minutes = calculate_training_cooldown(TRAINING_COOLDOWN, science_level)
    
    # Check and deduct food cost BEFORE cooldown check
    food_result = check_and_deduct_food_cost(db, current_user.id, cooldown_minutes, "training")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
        )
    
    # ATOMIC COOLDOWN CHECK + SET - prevents race conditions in serverless
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="training",
            cooldown_minutes=cooldown_minutes,
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
    
    # Count current actions completed
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already has all required actions"
        )
    
    # === DEDUCT GOLD COST (if pay-per-action) ===
    if action_gold_cost > 0:
        state.gold -= action_gold_cost
        
        # Add tax to kingdom treasury (base cost is burned)
        if tax_amount > 0 and state.current_kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
            if kingdom:
                kingdom.treasury_gold += tax_amount
    
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
    
    # Science skill: Chance to refund training cooldown (values from tiers.py)
    from routers.tiers import get_science_refund_chance
    science_level = state.science or 1
    refund_chance = get_science_refund_chance(science_level)
    cooldown_refunded = False
    if refund_chance > 0 and random.random() < refund_chance:
        cooldown_refunded = True
        # Clear the cooldown by setting last_performed to a time in the past
        from db import ActionCooldown
        cooldown_record = db.query(ActionCooldown).filter(
            ActionCooldown.user_id == current_user.id,
            ActionCooldown.action_type == "training"
        ).first()
        if cooldown_record:
            cooldown_record.last_performed = datetime.utcnow() - timedelta(hours=3)
    
    db.commit()
    
    progress_percent = min(100, int((new_actions_completed / contract.actions_required) * 100))
    
    if is_complete:
        message = f"Training complete! {stat_name} increased to {new_value}"
    else:
        if action_gold_cost > 0:
            message = f"You trained! (-{int(action_gold_cost)}g)"
        else:
            message = f"You trained!"
    
    if cooldown_refunded:
        message += " Your scientific knowledge instantly refunded your training!"
    
    # Calculate next available time (using science-reduced cooldown)
    if cooldown_refunded:
        next_available = datetime.utcnow()
    else:
        next_available = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    return {
        "success": True,
        "message": message,
        "contract_id": str(contract.id),
        "training_type": contract.type,
        "actions_completed": new_actions_completed,
        "actions_required": contract.actions_required,
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "cooldown_refunded": cooldown_refunded,
        "next_train_available_at": format_datetime_iso(next_available),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        # Gold cost info for new pay-per-action system
        "gold_cost": {
            "base": round(gold_per_action, 1),
            "tax": round(tax_amount, 1),
            "tax_rate": tax_rate,
            "total": round(action_gold_cost, 1)
        } if gold_per_action > 0 else None,
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }
