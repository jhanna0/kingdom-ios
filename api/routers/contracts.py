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
from config import DEV_MODE


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
        "id": str(contract.id),
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
        "created_by": contract.user_id,  # The ruler who created it
        "created_at": contract.created_at,
        "completed_at": contract.completed_at,
        "status": contract.status
    }


# Building types that are kingdom buildings
BUILDING_TYPES = ["wall", "vault", "mine", "market", "farm", "education"]


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
        UnifiedContract.type.in_(BUILDING_TYPES)
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
        UnifiedContract.type.in_(BUILDING_TYPES),
        UnifiedContract.status.in_(["open", "in_progress"])
    ).all()
    
    return [contract_to_response(c, db) for c in contracts]


@router.get("/{contract_id}")
def get_contract(contract_id: int, db: Session = Depends(get_db)):
    """Get contract by ID"""
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.type.in_(BUILDING_TYPES)
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    return contract_to_response(contract, db)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_contract(
    kingdom_id: str,
    kingdom_name: str,
    building_type: str,
    building_level: int,
    base_population: int,
    reward_pool: int = 0,
    total_actions_required: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new building contract (ruler only)"""
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
    
    # Check if kingdom already has an active contract
    existing_contract = db.query(UnifiedContract).filter(
        UnifiedContract.kingdom_id == kingdom_id,
        UnifiedContract.type.in_(BUILDING_TYPES),
        UnifiedContract.status.in_(["open", "in_progress"])
    ).first()
    
    if existing_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kingdom already has an active contract for {existing_contract.type}"
        )
    
    # Calculate costs
    construction_cost = calculate_construction_cost(building_level, base_population)
    
    if kingdom.treasury_gold < construction_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient treasury funds. Need {construction_cost}g. Have: {kingdom.treasury_gold}g"
        )
    
    kingdom.treasury_gold -= construction_cost
    
    # Calculate actions required
    if total_actions_required:
        actions_required = total_actions_required
    else:
        actions_required = calculate_actions_required(building_type, building_level, base_population)
    
    contract = UnifiedContract(
        user_id=current_user.id,  # The ruler who created it
        kingdom_id=kingdom_id,
        kingdom_name=kingdom_name,
        type=building_type.lower(),
        tier=building_level,
        actions_required=actions_required,
        gold_paid=construction_cost,
        reward_pool=reward_pool,
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
        UnifiedContract.type.in_(BUILDING_TYPES)
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
        UnifiedContract.type.in_(BUILDING_TYPES)
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
