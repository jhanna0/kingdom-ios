"""
Work on contract action (kingdom buildings and property upgrades)
Uses unified contract system with contract_contributions table
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta

from db import get_db, User, PlayerState, Kingdom, Property, UnifiedContract, ContractContribution
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import (
    calculate_cooldown, 
    check_global_action_cooldown_from_table, 
    format_datetime_iso,
    set_cooldown
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
    """Contribute one action to a kingdom building contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    if not DEV_MODE:
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=cooldown_minutes)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Get contract from unified_contracts (kingdom buildings only)
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.category == 'kingdom_building'
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    if state.current_kingdom_id != contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the kingdom to work on contracts"
        )
    
    # Count current actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract already has all required actions"
        )
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id
    )
    db.add(contribution)
    
    # Set cooldown in action_cooldowns table
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    set_cooldown(db, current_user.id, "work", cooldown_expires)
    
    # Calculate reward - use the ruler-set action_reward
    # NOTE: This only applies to kingdom building contracts (filtered above by BUILDING_TYPES)
    # Property/training/crafting contracts have action_reward = 0 and earn no gold
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
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Upgrade the building
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            building_attr = f"{contract.type.lower()}_level"
            if hasattr(kingdom, building_attr):
                current_level = getattr(kingdom, building_attr, 0)
                setattr(kingdom, building_attr, current_level + 1)
    
    db.commit()
    
    progress_percent = int((new_actions_completed / contract.actions_required) * 100)
    
    # Get user's contribution count
    user_contribution = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id,
        ContractContribution.user_id == current_user.id
    ).scalar()
    
    # Build a better message
    building_name = contract.type.capitalize()
    if is_complete:
        message = f"{building_name} construction complete!"
    else:
        message = f"You helped build the {building_name}. Progress: {progress_percent}%"
    
    return {
        "success": True,
        "message": message,
        "contract_id": str(contract_id),
        "actions_completed": new_actions_completed,
        "total_actions_required": contract.actions_required,
        "progress_percent": progress_percent,
        "your_contribution": user_contribution,
        "is_complete": is_complete,
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "rewards": {
            "gold": net_income,
            "gold_before_tax": gross_income,
            "tax_amount": tax_amount,
            "tax_rate": tax_rate,
            "experience": None,
            "reputation": None,
            "iron": None
        }
    }


@router.post("/work-property/{contract_id}")
def work_on_property_upgrade(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a property upgrade/construction contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    if not DEV_MODE:
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=cooldown_minutes)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Get contract from unified_contracts (property contracts)
    # Property contracts use type='property', tier=1 for construction, tier>1 for upgrades
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
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    # Count current actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract already has all required actions"
        )
    
    # Add contribution
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id
    )
    db.add(contribution)
    
    # Set cooldown
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    set_cooldown(db, current_user.id, "work", cooldown_expires)
    
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # tier=1 means new construction, tier>1 means upgrade
        if contract.tier == 1 and "|" in (contract.target_id or ""):
            # NEW CONSTRUCTION: Create the property
            # target_id is encoded as "property_id|location"
            parts = contract.target_id.split("|")
            property_id = parts[0]
            location = parts[1] if len(parts) > 1 else "center"
            
            new_property = Property(
                id=property_id,
                kingdom_id=contract.kingdom_id,
                kingdom_name=contract.kingdom_name,
                owner_id=current_user.id,
                owner_name=current_user.display_name,
                tier=1,
                location=location,
                purchased_at=datetime.utcnow(),
                last_upgraded=None
            )
            db.add(new_property)
        else:
            # UPGRADE: Update existing property tier
            property = db.query(Property).filter(
                Property.id == contract.target_id
            ).first()
            
            if property:
                property.tier = contract.tier
                property.last_upgraded = datetime.utcnow()
    
    db.commit()
    
    progress_percent = int((new_actions_completed / contract.actions_required) * 100)
    
    # Build a better message
    if is_complete:
        if contract.tier == 1 and "|" in (contract.target_id or ""):
            message = f"Property construction complete! You now own land in the kingdom!"
        else:
            message = f"Property upgraded to Tier {contract.tier}! Your land grows stronger!"
    else:
        action_word = "constructing" if (contract.tier == 1 and "|" in (contract.target_id or "")) else "upgrading"
        message = f"You worked on {action_word} your property. Progress: {progress_percent}%"
    
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
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes))
    }
