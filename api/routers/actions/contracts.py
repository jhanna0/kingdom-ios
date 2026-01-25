"""
Work on contract action (kingdom buildings and property upgrades)
Uses unified contract system with contract_contributions table
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
import random

from db import get_db, User, PlayerState, Kingdom, Property, UnifiedContract, ContractContribution
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import (
    calculate_cooldown, 
    check_and_set_slot_cooldown_atomic, 
    format_datetime_iso,
    set_cooldown,
    check_and_deduct_food_cost
)
from .constants import WORK_BASE_COOLDOWN
from .tax_utils import apply_kingdom_tax_with_bonus
from routers.tiers import BUILDING_TYPES


router = APIRouter()


@router.post("/work/{contract_id}")
def work_on_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a kingdom building contract.
    May require per-action resources (wood, iron, etc.) depending on building tier.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get contract FIRST (need building type and tier to check per-action costs)
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.category == 'kingdom_building'
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    # Check if already completed using completed_at timestamp
    if contract.completed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    if state.current_kingdom_id != contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the kingdom to work on contracts"
        )
    
    # Get per-action costs for this building tier (DYNAMIC from BUILDING_TYPES)
    from routers.tiers import get_building_per_action_costs
    from routers.resources import RESOURCES
    
    building_type = contract.type.lower()  # e.g., "wall"
    building_tier = contract.tier or 1  # The tier being built
    per_action_costs = get_building_per_action_costs(building_type, building_tier)
    
    # Enrich with display info and check affordability
    enriched_costs = []
    missing_resources = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        player_amount = getattr(state, resource_id, 0) or 0
        resource_info = RESOURCES.get(resource_id, {})
        
        enriched_costs.append({
            "resource": resource_id,
            "amount": amount,
            "display_name": resource_info.get("display_name", resource_id.capitalize()),
            "icon": resource_info.get("icon", "questionmark.circle")
        })
        
        if player_amount < amount:
            missing_resources.append({
                "resource": resource_id,
                "display_name": resource_info.get("display_name", resource_id.capitalize()),
                "needed": amount - player_amount,
                "have": player_amount
            })
    
    # BLOCK if not enough resources for this action
    if missing_resources:
        missing_str = ", ".join([f"{m['needed']} more {m['display_name']}" for m in missing_resources])
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough resources for this action. Need: {missing_str}"
        )
    
    # Calculate skill-adjusted cooldown ONCE - used for both check and display
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    # Check and deduct food cost BEFORE cooldown check (building contracts)
    food_result = check_and_deduct_food_cost(db, current_user.id, cooldown_minutes, "building work")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
        )
    
    # ATOMIC COOLDOWN CHECK + SET - prevents race conditions in serverless
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="work",
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
                detail=f"Building action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s."
            )
    else:
        # DEV_MODE: still set cooldown for functionality, just skip the check
        set_cooldown(db, current_user.id, "work", cooldown_expires)
    
    # Count current actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract already has all required actions"
        )
    
    # DEDUCT PER-ACTION RESOURCES
    resources_required = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        current = getattr(state, resource_id, 0) or 0
        setattr(state, resource_id, current - amount)
        resources_required.append({
            "resource": resource_id,
            "amount": amount,
            "new_total": current - amount
        })
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id
    )
    db.add(contribution)
    
    # Calculate reward - use the ruler-set action_reward
    base_gold = contract.action_reward or 0
    bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    
    net_income, tax_amount, tax_rate, gross_income = apply_kingdom_tax_with_bonus(
        db=db,
        kingdom_id=contract.kingdom_id,
        player_state=state,
        base_income=base_gold,
        bonus_multiplier=bonus_multiplier
    )
    
    state.gold += net_income
    contribution.gold_earned = net_income  # Store what they actually earned after taxes
    
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    if is_complete:
        # Mark as completed
        contract.completed_at = datetime.utcnow()
        
        # Upgrade the building
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            building_attr = f"{contract.type.lower()}_level"
            if hasattr(kingdom, building_attr):
                current_level = getattr(kingdom, building_attr, 0)
                setattr(kingdom, building_attr, current_level + 1)
    
    # Building skill: Chance to refund cooldown (values from tiers.py)
    from routers.tiers import get_building_refund_chance
    building_level = state.building_skill or 1
    refund_chance = get_building_refund_chance(building_level)
    cooldown_refunded = False
    if refund_chance > 0 and random.random() < refund_chance:
        cooldown_refunded = True
        # Clear the cooldown by setting last_performed to a time in the past
        from db import ActionCooldown
        cooldown_record = db.query(ActionCooldown).filter(
            ActionCooldown.user_id == current_user.id,
            ActionCooldown.action_type == "work"
        ).first()
        if cooldown_record:
            cooldown_record.last_performed = datetime.utcnow() - timedelta(hours=3)
    
    db.commit()
    
    progress_percent = int((new_actions_completed / contract.actions_required) * 100)
    
    # Get user's contribution count
    user_contribution = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id,
        ContractContribution.user_id == current_user.id
    ).scalar()
    
    # Build message with resource consumption info
    building_name = contract.type.capitalize()
    if is_complete:
        message = f"{building_name} construction complete!"
    else:
        if resources_required:
            required_str = ", ".join([f"-{c['amount']} {c['resource']}" for c in resources_required])
            message = f"You helped build the {building_name}! ({required_str})"
        else:
            message = f"You helped build the {building_name}!"
    
    if cooldown_refunded:
        message += " Your building expertise refunded the cooldown!"
    
    # Calculate next available time
    if cooldown_refunded:
        next_available = datetime.utcnow()
    else:
        next_available = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    return {
        "success": True,
        "message": message,
        "contract_id": str(contract_id),
        "actions_completed": new_actions_completed,
        "total_actions_required": contract.actions_required,
        "progress_percent": progress_percent,
        "your_contribution": user_contribution,
        "is_complete": is_complete,
        "cooldown_refunded": cooldown_refunded,
        "next_work_available_at": format_datetime_iso(next_available),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        "rewards": {
            "gold": int(net_income),
            "gold_before_tax": int(gross_income),
            "tax_amount": int(tax_amount),
            "tax_rate": tax_rate,
            "experience": None,
            "reputation": None,
            "iron": None
        },
        # NEW: Resources required this action
        "resources_required": resources_required,
        "per_action_costs": enriched_costs  # What future actions will cost
    }


@router.post("/work-property/{contract_id}")
def work_on_property_upgrade(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a property upgrade/construction contract.
    
    Pay-As-You-Go model:
    - Charges GOLD per action (base burned + tax to kingdom)
    - Consumes RESOURCES per action (wood, iron, etc.)
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get contract FIRST (need tier and cost_per_action)
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == "property"
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property upgrade contract not found"
        )
    
    # Check if already completed using completed_at timestamp
    if contract.completed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    # Get base gold cost per action from contract (locked in at purchase time)
    base_gold_cost = contract.cost_per_action or 0
    
    # Calculate tax on top
    tax_rate = 0
    kingdom = None
    if contract.kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            tax_rate = kingdom.tax_rate
    
    tax_amount = int(base_gold_cost * tax_rate / 100)
    total_gold_cost = base_gold_cost + tax_amount
    
    # Check if player can afford gold for this action
    if state.gold < total_gold_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {total_gold_cost}g ({base_gold_cost}g + {tax_amount}g tax), have {int(state.gold)}g"
        )
    
    # Get per-action RESOURCE costs for this tier (DYNAMIC from PROPERTY_TIERS)
    from routers.tiers import get_property_per_action_costs
    from routers.resources import RESOURCES
    
    from_tier = (contract.tier or 1) - 1
    per_action_costs = get_property_per_action_costs(contract.tier or 1)
    
    # Enrich with display info and check affordability
    enriched_costs = []
    missing_resources = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        player_amount = getattr(state, resource_id, 0) or 0
        resource_info = RESOURCES.get(resource_id, {})
        
        enriched_costs.append({
            "resource": resource_id,
            "amount": amount,
            "display_name": resource_info.get("display_name", resource_id.capitalize()),
            "icon": resource_info.get("icon", "questionmark.circle")
        })
        
        if player_amount < amount:
            missing_resources.append({
                "resource": resource_id,
                "display_name": resource_info.get("display_name", resource_id.capitalize()),
                "needed": amount - player_amount,
                "have": player_amount
            })
    
    # BLOCK if not enough resources for this action
    if missing_resources:
        missing_str = ", ".join([f"{m['needed']} more {m['display_name']}" for m in missing_resources])
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough resources for this action. Need: {missing_str}"
        )
    
    # Calculate skill-adjusted cooldown ONCE - used for both check and display
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    # Check and deduct food cost BEFORE cooldown check (property upgrades)
    food_result = check_and_deduct_food_cost(db, current_user.id, cooldown_minutes, "property work")
    if not food_result["success"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=food_result["error"]
        )
    
    # ATOMIC COOLDOWN CHECK + SET - prevents race conditions in serverless
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="work",
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
                detail=f"Building action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s."
            )
    else:
        # DEV_MODE: still set cooldown for functionality, just skip the check
        set_cooldown(db, current_user.id, "work", cooldown_expires)
    
    # Count current actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract already has all required actions"
        )
    
    # === PAY-AS-YOU-GO: Charge gold for this action ===
    # 1. Base cost is BURNED (removed from economy entirely)
    # 2. Tax goes to kingdom treasury
    state.gold -= total_gold_cost  # Player pays total
    
    # Tax goes to kingdom treasury (if kingdom exists)
    if kingdom and tax_amount > 0:
        kingdom.treasury_gold += tax_amount
    
    # Track total gold paid on contract
    contract.gold_paid = (contract.gold_paid or 0) + total_gold_cost
    
    # DEDUCT PER-ACTION RESOURCES
    resources_required = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        current = getattr(state, resource_id, 0) or 0
        setattr(state, resource_id, current - amount)
        resources_required.append({
            "resource": resource_id,
            "amount": amount,
            "new_total": current - amount
        })
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id,
        gold_earned=0  # Property work costs gold, doesn't earn it
    )
    db.add(contribution)
    
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    if is_complete:
        # Mark as completed
        contract.completed_at = datetime.utcnow()
        
        # Update the property tier (property is created at purchase time with tier=0)
        property = db.query(Property).filter(Property.id == contract.target_id).first()
        
        if property:
            property.tier = contract.tier
            if contract.tier > 1:
                property.last_upgraded = datetime.utcnow()
    
    db.commit()
    
    progress_percent = int((new_actions_completed / contract.actions_required) * 100)
    
    # Build message with cost info
    if is_complete:
        if contract.tier == 1:
            message = f"Property construction complete! You now own land in the kingdom!"
        else:
            message = f"Property upgraded to Tier {contract.tier}! Your land grows stronger!"
    else:
        action_word = "constructing" if contract.tier == 1 else "upgrading"
        resource_str = ", ".join([f"-{c['amount']} {c['resource']}" for c in resources_required])
        message = f"You worked on {action_word} your property! (-{total_gold_cost}g, {resource_str})"
    
    return {
        "success": True,
        "message": message,
        "contract_id": str(contract_id),
        "property_id": contract.target_id,
        "actions_completed": new_actions_completed,
        "actions_required": contract.actions_required,
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "new_tier": contract.tier if is_complete else None,
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        # Resources consumed this action
        "resources_required": resources_required,
        "per_action_costs": enriched_costs,  # What future actions will cost
        # Pay-As-You-Go gold cost breakdown
        "gold_cost": {
            "base_cost": base_gold_cost,  # Burned (destroyed)
            "tax_amount": tax_amount,  # To kingdom treasury
            "total_paid": total_gold_cost,  # What player paid this action
            "total_paid_contract": contract.gold_paid  # Cumulative on this contract
        }
    }
