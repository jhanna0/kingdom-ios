"""
Contract endpoints - Building contracts for kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Optional
import uuid
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


def calculate_actions_required(building_type: str, building_level: int, population: int) -> int:
    """Calculate total actions required based on building type, level, and population
    
    Small towns need fewer actions, big cities need many more!
    Example:
    - Level 3 Walls, 10 people: 400 * 1.33 = ~533 actions
    - Level 3 Walls, 1000 people: 400 * 34.33 = ~13,732 actions
    """
    # Base actions: 100 * 2^(level-1)
    # Level 1: 100, Level 2: 200, Level 3: 400, Level 4: 800, Level 5: 1600
    base_actions = 100 * math.pow(2.0, building_level - 1)
    
    # Population multiplier: +33% actions per 10 people
    # Same scaling as time - bigger cities need proportionally more work
    population_multiplier = 1.0 + (population / 30.0)
    
    return int(base_actions * population_multiplier)


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
        reward_pool=contract.reward_pool,
        workers=contract.workers or [],
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
    """Get contracts where current user is a worker"""
    contracts = db.query(Contract).filter(
        Contract.workers.contains([current_user.id]),
        Contract.status.in_(["open", "in_progress"])
    ).all()
    
    return [contract_to_response(c) for c in contracts]


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
    
    # Check if kingdom has enough gold in treasury
    if kingdom.treasury_gold < data.reward_pool:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient treasury funds. Have: {kingdom.treasury_gold}, Need: {data.reward_pool}"
        )
    
    # Deduct gold from kingdom treasury
    kingdom.treasury_gold -= data.reward_pool
    
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
        id=str(uuid.uuid4()),
        kingdom_id=data.kingdom_id,
        kingdom_name=data.kingdom_name,
        building_type=data.building_type,
        building_level=data.building_level,
        base_population=data.base_population,
        base_hours_required=base_hours,
        total_actions_required=total_actions,
        actions_completed=0,
        action_contributions={},
        reward_pool=data.reward_pool,
        workers=[],
        created_by=current_user.id,
        status="open"
    )
    
    db.add(contract)
    db.commit()
    db.refresh(contract)
    
    return contract_to_response(contract)


# ===== Contract Actions =====

@router.post("/{contract_id}/join")
def join_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Join a contract as a worker"""
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.status not in ["open", "in_progress"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is not accepting workers"
        )
    
    # DEV MODE: Allow rulers to join their own contracts
    if not DEV_MODE and contract.created_by == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rulers cannot accept their own contracts"
        )
    
    workers = contract.workers or []
    
    if current_user.id in workers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already joined this contract"
        )
    
    workers.append(current_user.id)
    contract.workers = workers
    
    # Start work timer if first worker
    if contract.work_started_at is None:
        contract.work_started_at = datetime.utcnow()
        contract.status = "in_progress"
    
    # Update user's active contract in player state
    state = current_user.player_state
    if not state:
        state = PlayerState(user_id=current_user.id, hometown_kingdom_id=current_user.hometown_kingdom_id)
        db.add(state)
    state.active_contract_id = contract_id
    
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Joined contract for {contract.building_type}",
        "contract": contract_to_response(contract)
    }


@router.post("/{contract_id}/leave")
def leave_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Leave a contract"""
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    workers = contract.workers or []
    
    if current_user.id not in workers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not a worker on this contract"
        )
    
    workers.remove(current_user.id)
    contract.workers = workers
    
    # If no workers left, reset timer
    if len(workers) == 0:
        contract.work_started_at = None
        contract.status = "open"
    
    # Clear user's active contract in player state
    state = current_user.player_state
    if state and state.active_contract_id == contract_id:
        state.active_contract_id = None
    
    db.commit()
    
    return {"success": True, "message": "Left contract"}


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
    
    # Check if enough time has passed (skip in dev mode)
    if not DEV_MODE and contract.work_started_at:
        worker_count = len(contract.workers or [])
        ideal_workers = 3.0
        worker_multiplier = ideal_workers / max(worker_count, 1)
        hours_needed = contract.base_hours_required * worker_multiplier
        
        elapsed = (datetime.utcnow() - contract.work_started_at).total_seconds() / 3600.0
        
        if elapsed < hours_needed:
            remaining = hours_needed - elapsed
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Contract not ready. {remaining:.1f} hours remaining."
            )
    
    # Complete the contract
    contract.status = "completed"
    contract.completed_at = datetime.utcnow()
    
    # Distribute rewards
    workers = contract.workers or []
    reward_per_worker = contract.reward_pool // max(len(workers), 1)
    
    # DEV MODE: Boost rewards
    rep_bonus = 100 if DEV_MODE else 10
    
    for worker_id in workers:
        worker_state = db.query(PlayerState).filter(PlayerState.user_id == worker_id).first()
        if worker_state:
            worker_state.gold += reward_per_worker
            worker_state.contracts_completed += 1
            worker_state.active_contract_id = None
            worker_state.reputation += rep_bonus  # Rep for completing contract
    
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
        "rewards_distributed": contract.reward_pool,
        "workers_paid": len(workers)
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
    
    # Clear active contract for all workers
    for worker_id in (contract.workers or []):
        worker = db.query(User).filter(User.id == worker_id).first()
        if worker and worker.active_contract_id == contract_id:
            worker.active_contract_id = None
    
    db.commit()
    
    return {"success": True, "message": "Contract cancelled"}

