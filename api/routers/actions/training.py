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
from .utils import check_and_set_slot_cooldown_atomic, format_datetime_iso, calculate_cooldown, set_cooldown, calculate_training_reduction, check_and_deduct_food_cost
from .constants import WORK_BASE_COOLDOWN, TRAINING_COOLDOWN


router = APIRouter()


# Import centralized skill definitions
from routers.tiers import SKILLS, SKILL_TYPES, get_stat_value, increment_stat, get_total_skill_points, get_all_skill_values

# Training types = all skill types (for backward compatibility)
TRAINING_TYPES = SKILL_TYPES


def calculate_training_cost(total_skill_points: int) -> int:
    """DEPRECATED - Use calculate_training_gold_per_action() from tiers.py instead.
    
    This function calculates the OLD upfront cost. Kept for reference/migration.
    """
    base_cost = 100.0
    cost_multiplier = pow(1.4, float(total_skill_points + 1))
    return int(base_cost * cost_multiplier)


# Import the centralized function from tiers.py
from routers.tiers import calculate_training_gold_per_action


def calculate_training_actions_required(stat_level: int, education_level: int = 0, science_level: int = 0) -> int:
    """Calculate how many actions required to complete training
    
    Formula: base_actions = 10 + (stat_level * 18) + (stat_level^2 * 3)
    
    This gives exponential growth:
    - Tier 1 (level 0 -> 1): 10 actions
    - Tier 2 (level 1 -> 2): 31 actions  
    - Tier 3 (level 2 -> 3): 58 actions
    - Tier 4 (level 3 -> 4): 91 actions
    - Tier 5 (level 4 -> 5): 130 actions
    - ...scales up to tier 10
    
    Reductions (values from tiers.py):
    - Education building (kingdom): from BUILDING_TYPES["education"]["tiers"]
    - Science skill (personal): from SKILLS["science"]["mechanics"]["training_reduction"]
    """
    from routers.tiers import get_education_training_reduction
    
    # Exponential scaling formula
    base_actions = 10 + (stat_level * 18) + (stat_level ** 2 * 3)
    
    # Education building reduces training time (values from tiers.py)
    education_multiplier = get_education_training_reduction(education_level)
    
    # Science skill reduces training actions required (values from tiers.py)
    science_multiplier = calculate_training_reduction(science_level)
    
    # Apply both reductions (multiplicative)
    reduced_actions = int(base_actions * education_multiplier * science_multiplier)
    return max(5, reduced_actions)


@router.get("/train/costs")
def get_training_costs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current training costs for all stats.
    
    Pay-As-You-Go model:
    - No upfront cost to start training
    - cost_per_action: Gold paid each training click (BASE COST, burned)
    - tax_per_action: Additional gold going to kingdom treasury
    - total_per_action: What player actually pays per click
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # ALL skills cost the SAME based on total skill points
    total_skill_points = get_total_skill_points(state)
    
    # NEW: Pay-As-You-Go - cost per action instead of upfront
    base_cost_per_action = calculate_training_gold_per_action(total_skill_points)
    
    # Get kingdom tax rate for display
    tax_rate = 0
    kingdom_name = None
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            tax_rate = kingdom.tax_rate
            kingdom_name = kingdom.name
    
    # Calculate tax on top of base cost
    tax_per_action = int(base_cost_per_action * tax_rate / 100)
    total_per_action = base_cost_per_action + tax_per_action
    
    # Generate costs dynamically for all skills (same cost for all)
    costs = {skill_type: total_per_action for skill_type in SKILL_TYPES}
    
    # Get current stats dynamically for all skills
    current_stats = get_all_skill_values(state)
    
    return {
        "total_skill_points": total_skill_points,
        "total_training_purchases": state.total_training_purchases or 0,
        "costs": costs,  # Total cost per action (for backward compat, now means per-action)
        "current_stats": current_stats,
        "gold": int(state.gold),
        # NEW: Pay-As-You-Go breakdown
        "pay_as_you_go": {
            "base_cost_per_action": base_cost_per_action,  # This amount is BURNED
            "tax_rate": tax_rate,
            "tax_per_action": tax_per_action,  # This goes to kingdom
            "total_per_action": total_per_action,  # What player pays
            "kingdom_name": kingdom_name,
            "explanation": f"Each training action costs {base_cost_per_action}g (burned) + {tax_per_action}g tax = {total_per_action}g"
        }
    }


@router.get("/train/contracts")
def get_training_contracts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's training contracts with Pay-As-You-Go info"""
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
        
        # Get tax rate for this contract's kingdom
        tax_rate = 0
        kingdom_name = None
        if contract.kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
            if kingdom:
                tax_rate = kingdom.tax_rate
                kingdom_name = kingdom.name
        
        # Calculate per-action costs
        base_cost = contract.cost_per_action or 0
        tax_per_action = int(base_cost * tax_rate / 100)
        total_per_action = base_cost + tax_per_action
        
        # Calculate remaining cost
        actions_remaining = max(0, contract.actions_required - actions_completed)
        estimated_remaining_cost = total_per_action * actions_remaining
        
        result.append({
            "id": str(contract.id),
            "type": contract.type,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": "completed" if contract.completed_at else "in_progress",
            "gold_paid": contract.gold_paid,  # Total paid so far
            "created_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "completed_at": format_datetime_iso(contract.completed_at) if contract.completed_at else None,
            "progress_percent": min(100, int((actions_completed / contract.actions_required) * 100)) if contract.actions_required > 0 else 100,
            # Pay-As-You-Go info
            "pay_as_you_go": {
                "cost_per_action": base_cost,  # Base cost (burned)
                "tax_rate": tax_rate,
                "tax_per_action": tax_per_action,  # Tax (to kingdom)
                "total_per_action": total_per_action,  # What player pays each action
                "actions_remaining": actions_remaining,
                "estimated_remaining_cost": estimated_remaining_cost,
                "kingdom_name": kingdom_name
            }
        })
    
    return {"contracts": result}


@router.post("/train/purchase")
def purchase_training(
    training_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start a training contract (Pay-As-You-Go model).
    
    NO upfront gold cost! Gold is paid per action instead.
    - cost_per_action is locked in at purchase time
    - Each training action costs: base_cost (burned) + tax (to kingdom)
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
    
    # Get current stat level
    current_stat = get_stat_value(state, training_type)
    
    # Get kingdom education level for training bonus
    education_level = 0
    tax_rate = 0
    kingdom_name = None
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            education_level = kingdom.education_level
            tax_rate = kingdom.tax_rate
            kingdom_name = kingdom.name
    
    # Calculate cost per action based on TOTAL SKILL POINTS (locked in at purchase time)
    total_skill_points = get_total_skill_points(state)
    cost_per_action = calculate_training_gold_per_action(total_skill_points)
    
    # Calculate tax that will be added on top
    tax_per_action = int(cost_per_action * tax_rate / 100)
    total_per_action = cost_per_action + tax_per_action
    
    # Get player's science level for training reduction
    science_level = state.science or 1
    actions_required = calculate_training_actions_required(current_stat, education_level, science_level)
    
    # Calculate total estimated cost for display (not charged upfront!)
    estimated_total_cost = total_per_action * actions_required
    
    # Create the contract in the database
    # NOTE: gold_paid starts at 0 and accumulates as actions are performed
    contract = UnifiedContract(
        user_id=current_user.id,
        category='personal_training',
        type=training_type,
        actions_required=actions_required,
        gold_paid=0,  # Pay-As-You-Go: starts at 0
        cost_per_action=cost_per_action,  # Lock in the base cost
        kingdom_id=state.current_kingdom_id
    )
    db.add(contract)
    
    # Increment training counter (no gold spent yet!)
    state.total_training_purchases = (state.total_training_purchases or 0) + 1
    
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Started {training_type} training! Each action costs {total_per_action}g ({cost_per_action}g + {tax_per_action}g tax).",
        "training_type": training_type,
        "contract_id": str(contract.id),
        "actions_required": actions_required,
        # Pay-As-You-Go info
        "pay_as_you_go": {
            "cost_per_action": cost_per_action,  # Base cost (burned)
            "tax_rate": tax_rate,
            "tax_per_action": tax_per_action,  # Goes to kingdom
            "total_per_action": total_per_action,  # What player pays each action
            "estimated_total": estimated_total_cost,  # Total if completed (for display only)
            "kingdom_name": kingdom_name
        }
    }


@router.post("/train/{contract_id}")
def work_on_training(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a training contract (2 hour cooldown).
    
    Pay-As-You-Go model:
    - Charges gold PER ACTION (not upfront)
    - Base cost is BURNED (destroyed from economy)
    - Tax is added ON TOP and goes to kingdom treasury
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Find the training contract FIRST (need cost_per_action)
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
    
    # Get base cost per action from contract (locked in at purchase time)
    base_cost = contract.cost_per_action or 0
    
    # Calculate tax on top
    tax_rate = 0
    kingdom = None
    if contract.kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            tax_rate = kingdom.tax_rate
    
    tax_amount = int(base_cost * tax_rate / 100)
    total_cost = base_cost + tax_amount
    
    # Check if player can afford this action
    if state.gold < total_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {total_cost}g ({base_cost}g + {tax_amount}g tax), have {int(state.gold)}g"
        )
    
    # Check and deduct food cost BEFORE cooldown check
    food_result = check_and_deduct_food_cost(db, current_user.id, TRAINING_COOLDOWN, "training")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
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
    
    # Count current actions completed
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already has all required actions"
        )
    
    # === PAY-AS-YOU-GO: Charge gold for this action ===
    # 1. Base cost is BURNED (removed from economy entirely)
    # 2. Tax goes to kingdom treasury
    state.gold -= total_cost  # Player pays total
    
    # Tax goes to kingdom treasury (if kingdom exists)
    if kingdom and tax_amount > 0:
        kingdom.treasury_gold += tax_amount
    
    # Track total gold paid on contract
    contract.gold_paid = (contract.gold_paid or 0) + total_cost
    
    # Add a contribution (= 1 action)
    xp_earned = 10
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id,
        xp_earned=xp_earned,
        gold_earned=0  # Training doesn't earn gold, it costs gold
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
        message = f"You trained! (-{total_cost}g)"
    
    if cooldown_refunded:
        message += " Your scientific knowledge instantly refunded your training!"
    
    # Calculate next available time
    if cooldown_refunded:
        next_available = datetime.utcnow()
    else:
        next_available = datetime.utcnow() + timedelta(minutes=TRAINING_COOLDOWN)
    
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
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        },
        # Pay-As-You-Go cost breakdown
        "gold_cost": {
            "base_cost": base_cost,  # Burned (destroyed)
            "tax_amount": tax_amount,  # To kingdom treasury
            "total_paid": total_cost,  # What player paid
            "total_paid_contract": contract.gold_paid  # Cumulative on this contract
        }
    }
