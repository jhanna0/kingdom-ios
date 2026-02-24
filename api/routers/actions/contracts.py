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
    check_and_deduct_food_cost,
    log_activity
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
    from .utils import get_inventory_map
    
    building_type = contract.type.lower()  # e.g., "wall"
    building_tier = contract.tier or 1  # The tier being built
    per_action_costs = get_building_per_action_costs(building_type, building_tier)
    
    # Get player's inventory for resource checking
    inventory_map = get_inventory_map(db, current_user.id)
    
    # Enrich with display info and check affordability
    enriched_costs = []
    missing_resources = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        player_amount = inventory_map.get(resource_id, 0)
        resource_info = RESOURCES.get(resource_id, {})
        
        enriched_costs.append({
            "resource": resource_id,
            "amount": amount,
            "display_name": resource_info.get("display_name", resource_id.capitalize()),
            "icon": resource_info.get("icon", "questionmark.circle"),
            "color": resource_info.get("color", "inkMedium")
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
    
    # DEDUCT PER-ACTION RESOURCES (from inventory)
    from .utils import deduct_inventory_amount
    
    resources_required = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        new_total = deduct_inventory_amount(db, current_user.id, resource_id, amount)
        resources_required.append({
            "resource": resource_id,
            "amount": amount,
            "new_total": new_total
        })
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id
    )
    db.add(contribution)
    
    # Calculate reward - use the ruler-set action_reward
    # Note: Building skill provides cooldown reduction and refund chance, NOT gold bonus
    base_gold = contract.action_reward or 0
    
    net_income, tax_amount, tax_rate, gross_income = apply_kingdom_tax_with_bonus(
        db=db,
        kingdom_id=contract.kingdom_id,
        player_state=state,
        base_income=base_gold,
        bonus_multiplier=1.0  # No gold bonus from building skill
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
                new_level = current_level + 1
                setattr(kingdom, building_attr, new_level)
                
                # Log to activity feed - completed building construction
                log_activity(
                    db=db,
                    user_id=current_user.id,
                    action_type="building_complete",
                    action_category="building",
                    description=f"Helped complete {contract.type} L{new_level} in {kingdom.name}!",
                    kingdom_id=contract.kingdom_id,
                    amount=new_level,
                    details={"building": contract.type, "level": new_level, "kingdom": kingdom.name},
                    visibility="friends"
                )
    else:
        # Log building work to activity feed
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        kingdom_name = kingdom.name if kingdom else "Unknown"
        log_activity(
            db=db,
            user_id=current_user.id,
            action_type="building",
            action_category="building",
            description=f"Working on {contract.type} in {kingdom_name} ({new_actions_completed}/{contract.actions_required})",
            kingdom_id=contract.kingdom_id,
            amount=int(net_income) if net_income else None,
            details={"building": contract.type, "progress": f"{new_actions_completed}/{contract.actions_required}"},
            visibility="friends"
        )
    
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
    
    PAY-PER-ACTION SYSTEM:
    - NEW contracts (gold_per_action > 0): Pay gold_per_action + kingdom tax each action
    - OLD contracts (gold_paid > 0, gold_per_action = 0): Actions are FREE (already paid upfront)
    - Tax goes to kingdom treasury, base cost is burned
    - Also consumes per-action resources (wood, iron, etc.)
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get contract FIRST (need tier to check per-action costs)
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
    
    # === PAY-PER-ACTION GOLD COST ===
    # Check if this is a new-style contract (pay per action) or old-style (already paid)
    gold_per_action = contract.gold_per_action or 0
    action_gold_cost = 0
    tax_amount = 0
    tax_rate = 0
    
    if gold_per_action > 0:
        # NEW SYSTEM: Calculate action cost with tax
        kingdom = None
        if contract.kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        
        # Get tax rate (rulers now pay tax to fund their own treasury)
        # is_ruler = kingdom and kingdom.ruler_id == current_user.id
        # tax_rate = 0 if is_ruler else (kingdom.tax_rate if kingdom else 0)
        tax_rate = kingdom.tax_rate if kingdom else 0
        
        # Total cost = base + tax
        tax_amount = gold_per_action * tax_rate / 100
        action_gold_cost = gold_per_action + tax_amount
        
        # Check if player can afford gold
        if state.gold < action_gold_cost:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Not enough gold. Need {int(action_gold_cost)}g ({int(gold_per_action)}g + {int(tax_amount)}g tax), have {int(state.gold)}g"
            )
    # else: OLD SYSTEM - gold_paid > 0 means they paid upfront, action is FREE
    
    # Get per-action costs for this specific option
    from routers.tiers import get_property_option_per_action_costs
    from routers.resources import RESOURCES
    from .utils import get_inventory_map
    
    per_action_costs = get_property_option_per_action_costs(contract.tier, contract.option_id) if contract.tier else []
    
    # Get player's inventory for resource checking
    inventory_map = get_inventory_map(db, current_user.id)
    
    # Enrich with display info and check affordability
    enriched_costs = []
    missing_resources = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        player_amount = inventory_map.get(resource_id, 0)
        resource_info = RESOURCES.get(resource_id, {})
        
        enriched_costs.append({
            "resource": resource_id,
            "amount": amount,
            "display_name": resource_info.get("display_name", resource_id.capitalize()),
            "icon": resource_info.get("icon", "questionmark.circle"),
            "color": resource_info.get("color", "inkMedium")
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
    
    # === DEDUCT GOLD COST (if pay-per-action) ===
    if action_gold_cost > 0:
        state.gold -= action_gold_cost
        
        # Add tax to kingdom treasury (base cost is burned)
        if tax_amount > 0 and contract.kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
            if kingdom:
                kingdom.treasury_gold += tax_amount
    
    # DEDUCT PER-ACTION RESOURCES (from inventory)
    from .utils import deduct_inventory_amount
    
    resources_required = []
    for cost in per_action_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        new_total = deduct_inventory_amount(db, current_user.id, resource_id, amount)
        resources_required.append({
            "resource": resource_id,
            "amount": amount,
            "new_total": new_total
        })
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id
    )
    db.add(contribution)
    
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    if is_complete:
        # Mark as completed
        contract.completed_at = datetime.utcnow()
        
        # Update the property tier (legacy behavior - room contracts have option_id set)
        property_obj = db.query(Property).filter(Property.id == contract.target_id).first()
        
        if property_obj:
            if not contract.option_id:
                # Legacy tier upgrade
                property_obj.tier = contract.tier
            
            if contract.tier > 1:
                property_obj.last_upgraded = datetime.utcnow()
            
            # Log property completion to activity feed
            from routers.property import get_option_name, get_tier_name
            tier_name = get_option_name(contract.tier, contract.option_id) if contract.option_id else get_tier_name(contract.tier)
            log_activity(
                db=db,
                user_id=current_user.id,
                action_type="property_complete",
                action_category="property",
                description=f"Built {tier_name} in {contract.kingdom_name}!",
                kingdom_id=contract.kingdom_id,
                amount=contract.tier,
                details={"tier": contract.tier, "kingdom": contract.kingdom_name},
                visibility="friends"
            )
    else:
        # Log property work to activity feed
        from routers.property import get_option_name, get_tier_name
        tier_name = get_option_name(contract.tier, contract.option_id) if contract.option_id else get_tier_name(contract.tier)
        log_activity(
            db=db,
            user_id=current_user.id,
            action_type="property",
            action_category="property",
            description=f"Building {tier_name} ({new_actions_completed}/{contract.actions_required})",
            kingdom_id=contract.kingdom_id,
            amount=None,
            details={"tier": contract.tier, "progress": f"{new_actions_completed}/{contract.actions_required}"},
            visibility="friends"
        )
    
    db.commit()
    
    progress_percent = int((new_actions_completed / contract.actions_required) * 100)
    
    # Build message with resource consumption info
    if is_complete:
        if contract.tier == 1:
            message = f"Property construction complete! You now own land in the kingdom!"
        else:
            message = f"Property upgraded to Tier {contract.tier}! Your land grows stronger!"
    else:
        action_word = "constructing" if contract.tier == 1 else "upgrading"
        cost_parts = []
        if action_gold_cost > 0:
            cost_parts.append(f"-{int(action_gold_cost)}g")
        if resources_required:
            cost_parts.extend([f"-{c['amount']} {c['resource']}" for c in resources_required])
        
        if cost_parts:
            message = f"You worked on {action_word} your property! ({', '.join(cost_parts)})"
        else:
            message = f"You worked on {action_word} your property!"
    
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
        # Gold cost info for new pay-per-action system
        "gold_cost": {
            "base": round(gold_per_action, 1),
            "tax": round(tax_amount, 1),
            "tax_rate": tax_rate,
            "total": round(action_gold_cost, 1)
        } if gold_per_action > 0 else None,
        # Resources required this action (frontend can show)
        "resources_required": resources_required,
        "per_action_costs": enriched_costs  # What future actions will cost
    }
