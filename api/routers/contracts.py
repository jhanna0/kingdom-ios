"""
Contract endpoints - Building contracts for kingdoms
Uses unified contract system with contract_contributions table
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
from typing import List, Optional
import math

from db import get_db, User, PlayerState, Kingdom, UnifiedContract, ContractContribution
from db.models.kingdom_event import KingdomEvent
from routers.auth import get_current_user
from routers.tiers import BUILDING_TYPES
from config import DEV_MODE
from schemas.contract import ContractCreate
from websocket.broadcast import notify_kingdom, KingdomEvents


router = APIRouter(prefix="/contracts", tags=["contracts"])

# Import centralized kingdom calculations
from services.kingdom_service import (
    get_active_citizens_count,
    calculate_actions_required,
    calculate_construction_cost,
)


def contract_to_response(contract: UnifiedContract, db: Session = None, inventory_map: dict = None) -> dict:
    """Convert UnifiedContract to response dict.
    
    Args:
        contract: The contract to convert
        db: Database session for querying contributions
        inventory_map: Optional dict of {item_id: quantity} for checking affordability
    """
    # Count contributions
    actions_completed = 0
    action_contributions = {}
    
    if db:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        # Get per-user contribution counts
        contrib_counts = db.query(
            ContractContribution.user_id,
            func.count(ContractContribution.id)
        ).filter(
            ContractContribution.contract_id == contract.id
        ).group_by(ContractContribution.user_id).all()
        
        action_contributions = {str(user_id): count for user_id, count in contrib_counts}
    
    # Get building benefit information from tiers.py
    building_benefit = None
    building_icon = None
    building_display_name = None
    per_action_costs = []
    can_afford_all = True
    
    if contract.type in BUILDING_TYPES:
        building_data = BUILDING_TYPES[contract.type]
        building_display_name = building_data.get("display_name")
        building_icon = building_data.get("icon")
        tier_data = building_data.get("tiers", {}).get(contract.tier, {})
        building_benefit = tier_data.get("benefit")
        
        # Get per-action costs for this tier (DYNAMIC)
        raw_per_action_costs = tier_data.get("per_action_costs", [])
        if raw_per_action_costs:
            from routers.resources import RESOURCES
            for cost in raw_per_action_costs:
                resource_id = cost["resource"]
                resource_info = RESOURCES.get(resource_id, {})
                # Check affordability if inventory provided
                player_has = inventory_map.get(resource_id, 0) if inventory_map else 0
                has_enough = player_has >= cost["amount"] if inventory_map else True
                if not has_enough:
                    can_afford_all = False
                per_action_costs.append({
                    "resource": resource_id,
                    "amount": cost["amount"],
                    "display_name": resource_info.get("display_name", resource_id.capitalize()),
                    "icon": resource_info.get("icon", "questionmark.circle"),
                    "color": resource_info.get("color", "inkMedium"),
                    "can_afford": has_enough
                })
    
    # Derive status from completion state (for backwards compatibility with clients)
    status = "completed" if contract.completed_at else "open"
    
    return {
        "id": str(contract.id),  # String for consistency with other contract endpoints
        "kingdom_id": contract.kingdom_id,
        "kingdom_name": contract.kingdom_name or "",
        "building_type": contract.type or "",
        "building_level": contract.tier or 0,
        "building_benefit": building_benefit,  # e.g. "Gather 10 wood per action"
        "building_icon": building_icon,  # e.g. "tree.fill"
        "building_display_name": building_display_name,  # e.g. "Lumbermill"
        "base_population": 0,  # Not stored in unified contracts
        "base_hours_required": 0,  # Not stored in unified contracts
        "work_started_at": contract.created_at,
        "total_actions_required": contract.actions_required,
        "actions_completed": actions_completed,
        "action_contributions": action_contributions,
        "construction_cost": contract.gold_paid or 0,
        "reward_pool": contract.reward_pool or 0,
        "action_reward": contract.action_reward or 0,
        "created_by": contract.user_id or 0,  # The ruler who created it
        "created_at": contract.created_at,
        "completed_at": contract.completed_at,
        "status": status,  # Computed from completed_at, not stored in DB
        "per_action_costs": per_action_costs,
        "can_afford": can_afford_all  # Can player afford all per-action resource costs?
    }


@router.get("")
def list_contracts(
    kingdom_id: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """List ACTIVE building contracts (not completed) - always returns only contracts you can work on"""
    query = db.query(UnifiedContract).filter(
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.completed_at.is_(None)  # ONLY active contracts
    )
    
    if kingdom_id:
        query = query.filter(UnifiedContract.kingdom_id == kingdom_id)
    
    contracts = query.order_by(UnifiedContract.created_at.desc()).offset(skip).limit(limit).all()
    return [contract_to_response(c, db) for c in contracts]


@router.get("/my")
def get_my_contracts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get contracts where current user has contributed"""
    # Find contracts where user has contributions
    contributed_contract_ids = db.query(ContractContribution.contract_id).filter(
        ContractContribution.user_id == current_user.id
    ).distinct().subquery()
    
    # Only show active (not completed) contracts
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.id.in_(contributed_contract_ids),
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.completed_at.is_(None)
    ).all()
    
    return [contract_to_response(c, db) for c in contracts]


@router.get("/{contract_id}")
def get_contract(contract_id: int, db: Session = Depends(get_db)):
    """Get contract by ID"""
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.category == 'kingdom_building'
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    return contract_to_response(contract, db)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_contract(
    request: ContractCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new building contract (ruler only)"""
    # Extract fields from request
    kingdom_id = request.kingdom_id
    kingdom_name = request.kingdom_name
    building_type = request.building_type
    building_level = request.building_level
    base_population = request.base_population
    action_reward = request.action_reward  # Gold per action (ruler-set)
    total_actions_required = request.total_actions_required
    
    # Verify user is the ruler
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    if kingdom.ruler_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the ruler can create contracts"
        )
    
    # SECURITY: Validate building type is valid
    # Keys are lowercase matching DB column prefixes (e.g., "wall", "education", "lumbermill")
    if building_type not in BUILDING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid building type: {building_type}. Valid types: {', '.join(BUILDING_TYPES.keys())}"
        )
    
    # Get the display name for UI (e.g., "Education Hall" for key "education")
    building_display_name = BUILDING_TYPES[building_type]["display_name"]
    
    # SECURITY: Validate building level is in valid range (1-5)
    if building_level < 1 or building_level > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid building level: {building_level}. Must be between 1 and 5"
        )
    
    # SECURITY: Check that kingdom's current building level is exactly building_level - 1
    # Can't skip tiers (e.g., can't upgrade from 0 to 2, must go 0→1→2)
    # Keys already match DB column prefixes: "wall" → "wall_level", "education" → "education_level"
    current_level = getattr(kingdom, f"{building_type}_level", None)
    if current_level is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Building type {building_type} not found on kingdom"
        )
    
    if current_level != building_level - 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{building_type.capitalize()} is currently level {current_level}. Cannot upgrade to level {building_level}. Must upgrade to level {current_level + 1} first."
        )
    
    # Check if kingdom already has an active (not completed) contract
    existing_contract = db.query(UnifiedContract).filter(
        UnifiedContract.kingdom_id == kingdom_id,
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.completed_at.is_(None)
    ).first()
    
    if existing_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kingdom already has an active contract for {existing_contract.type}"
        )
    
    # Calculate actions required using LIVE citizen count (players with this kingdom as hometown)
    # Farm building reduces actions required
    active_citizens_count = get_active_citizens_count(db, kingdom_id)
    farm_level = kingdom.farm_level if hasattr(kingdom, 'farm_level') else 0
    
    if total_actions_required:
        actions_required = total_actions_required
    else:
        actions_required = calculate_actions_required(building_type, building_level, active_citizens_count, farm_level)
    
    # Calculate upfront cost: actions_required × action_reward
    upfront_cost = actions_required * action_reward
    
    if kingdom.treasury_gold < upfront_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient treasury funds. Need {upfront_cost}g ({actions_required} actions × {action_reward}g/action). Have: {int(kingdom.treasury_gold)}g"
        )
    
    # Deduct upfront cost from treasury
    kingdom.treasury_gold -= upfront_cost
    
    contract = UnifiedContract(
        user_id=current_user.id,  # The ruler who created it
        kingdom_id=kingdom_id,
        kingdom_name=kingdom_name,
        category='kingdom_building',
        type=building_type,  # Store the key (e.g., "wall", "education") - matches DB column prefix
        tier=building_level,
        actions_required=actions_required,
        gold_paid=upfront_cost,  # What ruler paid upfront
        reward_pool=upfront_cost,  # Same as gold_paid - this is what workers draw from
        action_reward=action_reward  # Gold per action
    )
    
    db.add(contract)
    db.commit()
    db.refresh(contract)
    
    # Add to kingdom activity feed
    event = KingdomEvent(
        kingdom_id=kingdom_id,
        title=f"New Contract: {building_display_name}",
        description=f"{current_user.display_name} posted a contract to upgrade {building_display_name} to level {building_level}. Reward: {action_reward}g per action."
    )
    db.add(event)
    db.commit()
    
    # Send real-time notification to kingdom members
    notify_kingdom(
        kingdom_id=str(kingdom_id),
        event_type=KingdomEvents.CONTRACT_POSTED,
        data={
            "contract_id": str(contract.id),
            "building_type": building_type,
            "building_display_name": building_display_name,
            "building_level": building_level,
            "action_reward": action_reward,
            "actions_required": actions_required,
            "posted_by": current_user.display_name
        }
    )
    
    return contract_to_response(contract, db)


@router.post("/{contract_id}/complete")
def complete_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Complete a contract (auto-triggered when ready)"""
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
    
    # Count actions completed from ContractContribution table
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed < contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Contract not complete. {actions_completed}/{contract.actions_required} actions done."
        )
    
    # Mark as completed
    contract.completed_at = datetime.utcnow()
    
    # Upgrade the building
    # contract.type is now stored as lowercase key (e.g., "wall", "education")
    kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
    if kingdom:
        building_attr = f"{contract.type}_level"
        if hasattr(kingdom, building_attr):
            current_level = getattr(kingdom, building_attr, 0)
            setattr(kingdom, building_attr, current_level + 1)
    
    db.commit()
    
    # Get contributor count
    contributor_count = db.query(func.count(func.distinct(ContractContribution.user_id))).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    # Get display name for message
    display_name = BUILDING_TYPES.get(contract.type, {}).get("display_name", contract.type)
    
    return {
        "success": True,
        "message": f"Contract completed! {display_name} upgraded.",
        "total_actions": actions_completed,
        "contributors": contributor_count
    }


@router.post("/{contract_id}/cancel")
def cancel_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a contract (ruler only) - DELETES the contract"""
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.category == 'kingdom_building'
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the creator can cancel this contract"
        )
    
    # Check if already completed
    if contract.completed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel completed contract"
        )
    
    # Delete the contract and all contributions
    db.query(ContractContribution).filter(
        ContractContribution.contract_id == contract.id
    ).delete()
    db.delete(contract)
    db.commit()
    
    return {"success": True, "message": "Contract cancelled"}
