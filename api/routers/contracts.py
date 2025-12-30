"""
Contract endpoints - Building contracts for kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Optional
import math

from db import get_db, User, PlayerState, Kingdom, Contract
from schemas import ContractCreate, ContractResponse
from routers.auth import get_current_user
from config import DEV_MODE


router = APIRouter(prefix="/contracts", tags=["contracts"])


def calculate_base_hours(building_type: str, building_level: int, population: int) -> float:
    """Calculate base hours required based on building type, level, and population"""
    # Base time with 3 ideal workers:
    # Level 1: 2 hours, Level 2: 4 hours, etc.
    base_hours = 2.0 * math.pow(2.0, building_level - 1)
    
    # Population multiplier: +33% time per 10 people
    population_multiplier = 1.0 + (population / 30.0)
    
    return base_hours * population_multiplier


def calculate_construction_cost(building_level: int, population: int) -> int:
    """Calculate upfront construction cost based on building level and population
    
    This is what the RULER pays from treasury to START the building project.
    Separate from reward_pool which is distributed to workers.
    
    Formula: 1000 * 2^(level-1) * (1 + population/50)
    
    Examples:
    - Level 1, 10 people: 1000 * 1 * 1.2 = 1,200g
    - Level 3, 100 people: 1000 * 4 * 3.0 = 12,000g
    - Level 5, 500 people: 1000 * 16 * 11.0 = 176,000g
    """
    base_cost = 1000 * math.pow(2.0, building_level - 1)
    population_multiplier = 1.0 + (population / 50.0)
    return int(base_cost * population_multiplier)


def calculate_actions_required(building_type: str, building_level: int, population: int) -> int:
    """Calculate total actions required based on building type, level, and population
    
    Small towns need fewer actions, big cities need many more!
    
    Formula: 100 * 2^(level-1) * (1 + population/30)
    
    Examples:
    - Level 1, 10 people: 100 * 1 * 1.33 = ~133 actions
    - Level 3, 100 people: 100 * 4 * 4.33 = ~1,733 actions
    - Level 5, 500 people: 100 * 16 * 17.67 = ~28,267 actions
    """
    # Base actions: 100 * 2^(level-1)
    # Level 1: 100, Level 2: 200, Level 3: 400, Level 4: 800, Level 5: 1600
    base_actions = 100 * math.pow(2.0, building_level - 1)
    
    # Population multiplier: +33% actions per 10 people
    # Same scaling as time - bigger cities need proportionally more work
    population_multiplier = 1.0 + (population / 30.0)
    
    return int(base_actions * population_multiplier)


def calculate_suggested_reward(actions_required: int, building_level: int) -> int:
    """Calculate suggested reward pool based on actions and level"""
    base_reward = 100 * building_level
    actions_bonus = int(actions_required * 0.1)
    return base_reward + actions_bonus


def contract_to_response(contract: Contract) -> ContractResponse:
    """Convert Contract model to response schema"""
    return ContractResponse(
        id=contract.id,
        kingdom_id=contract.kingdom_id,
        kingdom_name=contract.kingdom_name,
        building_type=contract.building_type,
        building_level=contract.building_level,
        base_population=contract.base_population,
        base_hours_required=contract.base_hours_required,
        work_started_at=contract.work_started_at,
        total_actions_required=contract.total_actions_required,
        actions_completed=contract.actions_completed or 0,
        action_contributions=contract.action_contributions or {},
        construction_cost=contract.construction_cost or 0,
        reward_pool=contract.reward_pool,
        created_by=contract.created_by,
        created_at=contract.created_at,
        completed_at=contract.completed_at,
        status=contract.status
    )


# ===== Contract CRUD =====

@router.get("", response_model=List[ContractResponse])
def list_contracts(
    kingdom_id: Optional[str] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """List contracts, optionally filtered by kingdom or status"""
    query = db.query(Contract)
    
    if kingdom_id:
        query = query.filter(Contract.kingdom_id == kingdom_id)
    
    if status:
        query = query.filter(Contract.status == status)
    
    contracts = query.order_by(Contract.created_at.desc()).offset(skip).limit(limit).all()
    return [contract_to_response(c) for c in contracts]


@router.get("/my", response_model=List[ContractResponse])
def get_my_contracts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get contracts where current user has contributed"""
    # Find contracts where user has made contributions
    all_contracts = db.query(Contract).filter(
        Contract.status.in_(["open", "in_progress"])
    ).all()
    
    # Filter to only contracts where user has contributed
    user_id_str = str(current_user.id)
    my_contracts = [c for c in all_contracts if user_id_str in (c.action_contributions or {})]
    
    return [contract_to_response(c) for c in my_contracts]


@router.get("/{contract_id}", response_model=ContractResponse)
def get_contract(contract_id: str, db: Session = Depends(get_db)):
    """Get contract by ID"""
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    return contract_to_response(contract)


@router.post("", response_model=ContractResponse, status_code=status.HTTP_201_CREATED)
def create_contract(
    data: ContractCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new contract (ruler only)
    
    Action requirements are calculated at creation time based on:
    - Building level (exponential: 100 * 2^(level-1))
    - Population scaling (+33% per 10 people)
    
    This means:
    - Small town (10 people): Level 3 walls = ~533 actions
    - Big city (1000 people): Level 3 walls = ~13,732 actions
    
    Population scaling ensures buildings in NYC are proportionally harder than small towns!
    """
    # Verify user is the ruler of this kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == data.kingdom_id).first()
    
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
    
    # Check if kingdom already has an active contract (open or in_progress)
    existing_contract = db.query(Contract).filter(
        Contract.kingdom_id == data.kingdom_id,
        Contract.status.in_(["open", "in_progress"])
    ).first()
    
    if existing_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kingdom already has an active contract for {existing_contract.building_type}"
        )
    
    # Calculate construction cost based on population and level
    construction_cost = calculate_construction_cost(data.building_level, data.base_population)
    total_cost = construction_cost + data.reward_pool
    
    # Check if kingdom has enough gold in treasury
    if kingdom.treasury_gold < total_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient treasury funds. Need {total_cost}g (construction: {construction_cost}g + rewards: {data.reward_pool}g). Have: {kingdom.treasury_gold}g"
        )
    
    # Deduct gold from kingdom treasury (both construction cost and reward pool)
    kingdom.treasury_gold -= total_cost
    
    # Calculate base hours required
    base_hours = calculate_base_hours(
        data.building_type,
        data.building_level,
        data.base_population
    )
    
    # Calculate action requirements based on population and level
    if data.total_actions_required:
        total_actions = data.total_actions_required
    else:
        total_actions = calculate_actions_required(
            data.building_type,
            data.building_level,
            data.base_population
        )
    
    contract = Contract(
        kingdom_id=data.kingdom_id,
        kingdom_name=data.kingdom_name,
        building_type=data.building_type,
        building_level=data.building_level,
        base_population=data.base_population,
        base_hours_required=base_hours,
        total_actions_required=total_actions,
        actions_completed=0,
        action_contributions={},
        construction_cost=construction_cost,
        reward_pool=data.reward_pool,
        created_by=current_user.id,
        status="open"
    )
    
    db.add(contract)
    db.commit()
    db.refresh(contract)
    
    return contract_to_response(contract)


# ===== Contract Actions =====

@router.post("/{contract_id}/complete")
def complete_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Complete a contract (auto-triggered when ready)"""
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.status != "in_progress":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is not in progress"
        )
    
    # Check if contract is actually complete (based on actions)
    if contract.actions_completed < contract.total_actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Contract not complete. {contract.actions_completed}/{contract.total_actions_required} actions done."
        )
    
    # Complete the contract (rewards already distributed per action)
    contract.status = "completed"
    contract.completed_at = datetime.utcnow()
    
    # Mark contract as completed for all contributors
    contributions = contract.action_contributions or {}
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
    
    return {
        "success": True,
        "message": f"Contract completed! {contract.building_type} upgraded.",
        "total_actions": contract.actions_completed,
        "contributors": len(contributions)
    }


@router.post("/{contract_id}/cancel")
def cancel_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a contract (ruler only)"""
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.created_by != current_user.id:
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

