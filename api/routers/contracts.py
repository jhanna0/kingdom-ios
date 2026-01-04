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
from routers.auth import get_current_user
from routers.tiers import BUILDING_TYPES as BUILDING_TYPES_DICT
from config import DEV_MODE
from schemas.contract import ContractCreate


router = APIRouter(prefix="/contracts", tags=["contracts"])


# ===== SCALING CONSTANTS =====
BASE_CONSTRUCTION_COST = 1000
LEVEL_COST_EXPONENT = 1.7
POPULATION_COST_DIVISOR = 50
BASE_ACTIONS_REQUIRED = 100
LEVEL_ACTIONS_EXPONENT = 1.7
POPULATION_ACTIONS_DIVISOR = 30


def calculate_base_hours(building_type: str, building_level: int, population: int) -> float:
    """Calculate base hours required based on building type, level, and population"""
    base_hours = 2.0 * math.pow(2.0, building_level - 1)
    population_multiplier = 1.0 + (population / 30.0)
    return base_hours * population_multiplier


def calculate_construction_cost(building_level: int, population: int) -> int:
    """Calculate upfront construction cost"""
    base_cost = BASE_CONSTRUCTION_COST * math.pow(LEVEL_COST_EXPONENT, building_level - 1)
    population_multiplier = 1.0 + (population / POPULATION_COST_DIVISOR)
    return int(base_cost * population_multiplier)


def calculate_actions_required(building_type: str, building_level: int, population: int) -> int:
    """Calculate total actions required"""
    base_actions = BASE_ACTIONS_REQUIRED * math.pow(LEVEL_ACTIONS_EXPONENT, building_level - 1)
    population_multiplier = 1.0 + (population / POPULATION_ACTIONS_DIVISOR)
    return int(base_actions * population_multiplier)


def contract_to_response(contract: UnifiedContract, db: Session = None) -> dict:
    """Convert UnifiedContract to response dict"""
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
    
    return {
        "id": str(contract.id),  # String for consistency with other contract endpoints
        "kingdom_id": contract.kingdom_id,
        "kingdom_name": contract.kingdom_name,
        "building_type": contract.type,
        "building_level": contract.tier,
        "base_population": 0,  # Not stored in unified contracts
        "base_hours_required": 0,  # Not stored in unified contracts
        "work_started_at": contract.created_at,
        "total_actions_required": contract.actions_required,
        "actions_completed": actions_completed,
        "action_contributions": action_contributions,
        "construction_cost": contract.gold_paid or 0,
        "reward_pool": contract.reward_pool or 0,
        "action_reward": contract.action_reward or 0,
        "created_by": contract.user_id,  # The ruler who created it
        "created_at": contract.created_at,
        "completed_at": contract.completed_at,
        "status": contract.status
    }


# Building types that are kingdom buildings (just the keys for validation)
BUILDING_TYPES = list(BUILDING_TYPES_DICT.keys())


@router.get("")
def list_contracts(
    kingdom_id: Optional[str] = None,
    status_filter: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """List building contracts, optionally filtered by kingdom or status"""
    query = db.query(UnifiedContract).filter(
        UnifiedContract.category == 'kingdom_building'
    )
    
    if kingdom_id:
        query = query.filter(UnifiedContract.kingdom_id == kingdom_id)
    
    if status_filter:
        query = query.filter(UnifiedContract.status == status_filter)
    
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
    
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.id.in_(contributed_contract_ids),
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.status.in_(["open", "in_progress"])
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
    building_type_lower = building_type.lower()
    if building_type_lower not in BUILDING_TYPES_DICT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid building type: {building_type}. Valid types: {', '.join(BUILDING_TYPES_DICT.keys())}"
        )
    
    # Get the proper display name from BUILDING_TYPES (e.g., "Lumbermill" not "lumbermill")
    building_display_name = BUILDING_TYPES_DICT[building_type_lower]["display_name"]
    
    # SECURITY: Validate building level is in valid range (1-5)
    if building_level < 1 or building_level > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid building level: {building_level}. Must be between 1 and 5"
        )
    
    # SECURITY: Check that kingdom's current building level is exactly building_level - 1
    # Can't skip tiers (e.g., can't upgrade from 0 to 2, must go 0→1→2)
    current_level = getattr(kingdom, f"{building_type_lower}_level", None)
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
    
    # Check if kingdom already has an active contract
    existing_contract = db.query(UnifiedContract).filter(
        UnifiedContract.kingdom_id == kingdom_id,
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.status.in_(["open", "in_progress"])
    ).first()
    
    if existing_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kingdom already has an active contract for {existing_contract.type}"
        )
    
    # Calculate actions required
    if total_actions_required:
        actions_required = total_actions_required
    else:
        actions_required = calculate_actions_required(building_type_lower, building_level, base_population)
    
    # Calculate upfront cost: actions_required × action_reward
    upfront_cost = actions_required * action_reward
    
    if kingdom.treasury_gold < upfront_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient treasury funds. Need {upfront_cost}g ({actions_required} actions × {action_reward}g/action). Have: {kingdom.treasury_gold}g"
        )
    
    # Deduct upfront cost from treasury
    kingdom.treasury_gold -= upfront_cost
    
    contract = UnifiedContract(
        user_id=current_user.id,  # The ruler who created it
        kingdom_id=kingdom_id,
        kingdom_name=kingdom_name,
        category='kingdom_building',
        type=building_display_name,  # Store the proper display name (e.g., "Lumbermill")
        tier=building_level,
        actions_required=actions_required,
        gold_paid=upfront_cost,  # What ruler paid upfront
        reward_pool=upfront_cost,  # Same as gold_paid - this is what workers draw from
        action_reward=action_reward,  # Gold per action
        status="open"
    )
    
    db.add(contract)
    db.commit()
    db.refresh(contract)
    
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
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    # Count actions completed
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed < contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Contract not complete. {actions_completed}/{contract.actions_required} actions done."
        )
    
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
    
    # Get contributor count
    contributor_count = db.query(func.count(func.distinct(ContractContribution.user_id))).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    return {
        "success": True,
        "message": f"Contract completed! {contract.type} upgraded.",
        "total_actions": actions_completed,
        "contributors": contributor_count
    }


@router.post("/{contract_id}/cancel")
def cancel_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a contract (ruler only)"""
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
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel completed contract"
        )
    
    contract.status = "cancelled"
    db.commit()
    
    return {"success": True, "message": "Contract cancelled"}
