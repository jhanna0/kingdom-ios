"""
Work on contract action (kingdom buildings and property upgrades)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import json

from db import get_db, User, PlayerState, Kingdom, Contract, Property
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import calculate_cooldown, check_cooldown, check_global_action_cooldown, format_datetime_iso
from .constants import WORK_BASE_COOLDOWN
from .tax_utils import apply_kingdom_tax_with_bonus


router = APIRouter()


@router.post("/work/{contract_id}")
def work_on_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a contract (base 2hr cooldown, reduced by building skill)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        global_cooldown = check_global_action_cooldown(state, work_cooldown=cooldown_minutes)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Get contract
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
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
    
    # Check if user is checked into the kingdom
    if state.current_kingdom_id != contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the kingdom to work on contracts"
        )
    
    # Increment action count
    contract.actions_completed += 1
    
    # Track contribution per user
    contributions = contract.action_contributions or {}
    user_id_str = str(current_user.id)
    contributions[user_id_str] = contributions.get(user_id_str, 0) + 1
    contract.action_contributions = contributions
    
    # Update player state
    state.last_work_action = datetime.utcnow()
    state.total_work_contributed += 1
    
    # Calculate reward per action (gold per action = reward_pool / total_actions_required)
    gold_per_action = contract.reward_pool / contract.total_actions_required
    base_gold = int(gold_per_action)
    
    # Apply building skill bonus (2% per level above 1)
    bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    
    # Apply tax AFTER bonuses
    net_income, tax_amount, tax_rate, gross_income = apply_kingdom_tax_with_bonus(
        db=db,
        kingdom_id=contract.kingdom_id,
        player_state=state,
        base_income=base_gold,
        bonus_multiplier=bonus_multiplier
    )
    
    # Award net gold (after tax) to player
    state.gold += net_income
    
    # Check if contract is complete
    is_complete = contract.actions_completed >= contract.total_actions_required
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Mark contract as completed for all contributors
        for worker_id_str in contributions.keys():
            worker_id = int(worker_id_str)
            worker_state = db.query(PlayerState).filter(PlayerState.user_id == worker_id).first()
            if worker_state:
                worker_state.contracts_completed += 1
        
        # Upgrade the building
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            building_attr = f"{contract.building_type.lower()}_level"
            if hasattr(kingdom, building_attr):
                current_level = getattr(kingdom, building_attr, 0)
                setattr(kingdom, building_attr, current_level + 1)
    
    db.commit()
    db.refresh(contract)
    
    progress_percent = int((contract.actions_completed / contract.total_actions_required) * 100)
    user_contribution = contributions.get(user_id_str, 0)
    
    return {
        "success": True,
        "message": "Work action completed! +1 action" + (" - Contract complete!" if is_complete else ""),
        "contract_id": contract_id,
        "actions_completed": contract.actions_completed,
        "total_actions_required": contract.total_actions_required,
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
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a property upgrade/construction contract (same cooldown as building contracts)
    
    Handles both:
    - New construction (from_tier=0): Creates property when complete
    - Upgrades (from_tier>0): Upgrades existing property tier
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown (same as building work)
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        global_cooldown = check_global_action_cooldown(state, work_cooldown=cooldown_minutes)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Get property upgrade contracts
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    
    # Find the contract
    contract_idx = None
    contract_data = None
    for idx, contract in enumerate(property_contracts):
        if contract["contract_id"] == contract_id:
            contract_idx = idx
            contract_data = contract
            break
    
    if contract_data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property upgrade contract not found"
        )
    
    if contract_data["status"] == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    # Increment action count
    contract_data["actions_completed"] += 1
    
    # Update player state
    state.last_work_action = datetime.utcnow()
    state.total_work_contributed += 1
    
    # Check if contract is complete
    is_complete = contract_data["actions_completed"] >= contract_data["actions_required"]
    
    if is_complete:
        contract_data["status"] = "completed"
        contract_data["completed_at"] = datetime.utcnow().isoformat()
        
        # Check if this is a new construction (from_tier=0) or an upgrade
        if contract_data.get("from_tier") == 0:
            # NEW CONSTRUCTION: Create the property
            from db.models import Property
            new_property = Property(
                id=contract_data["property_id"],
                kingdom_id=contract_data["kingdom_id"],
                kingdom_name=contract_data["kingdom_name"],
                owner_id=current_user.id,
                owner_name=current_user.display_name,
                tier=1,
                location=contract_data["location"],
                purchased_at=datetime.utcnow(),
                last_upgraded=None
            )
            db.add(new_property)
        else:
            # UPGRADE: Update existing property tier
            property = db.query(Property).filter(
                Property.id == contract_data["property_id"]
            ).first()
            
            if property:
                property.tier = contract_data["to_tier"]
                property.last_upgraded = datetime.utcnow()
        
        # Mark contract as completed
        state.contracts_completed += 1
    
    # Save updated contracts
    property_contracts[contract_idx] = contract_data
    state.property_upgrade_contracts = json.dumps(property_contracts)
    
    db.commit()
    
    progress_percent = int((contract_data["actions_completed"] / contract_data["actions_required"]) * 100)
    
    # Determine message based on contract type
    if is_complete:
        if contract_data.get("from_tier") == 0:
            completion_msg = " - Property construction complete!"
        else:
            completion_msg = " - Property upgrade complete!"
    else:
        completion_msg = ""
    
    return {
        "success": True,
        "message": "Work action completed! +1 action" + completion_msg,
        "contract_id": contract_id,
        "property_id": contract_data["property_id"],
        "actions_completed": contract_data["actions_completed"],
        "actions_required": contract_data["actions_required"],
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "new_tier": contract_data["to_tier"] if is_complete else None,
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes))
    }

