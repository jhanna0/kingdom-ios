"""
Property API - Land ownership and upgrades
Uses unified contract system (no more JSONB!)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import uuid
from datetime import datetime

from db import get_db, Property, User, Kingdom, UnifiedContract, ContractContribution, UserKingdom
from routers.auth import get_current_user

router = APIRouter(prefix="/properties", tags=["properties"])


# ===== Schemas =====


# ===== Schemas =====

from pydantic import BaseModel

class PropertyResponse(BaseModel):
    id: str
    kingdom_id: str
    kingdom_name: str
    owner_id: int
    owner_name: str
    tier: int
    location: str | None
    purchased_at: str
    last_upgraded: str | None
    
    class Config:
        from_attributes = True


class PurchaseLandRequest(BaseModel):
    kingdom_id: str
    kingdom_name: str
    location: str  # "north", "south", "east", "west"


class PurchaseConstructionResponse(BaseModel):
    success: bool
    message: str
    contract_id: int
    property_id: str
    kingdom_id: str
    kingdom_name: str
    location: str
    actions_required: int
    cost_paid: int


# ===== Helper Functions =====

def get_tier_name(tier: int) -> str:
    """Get the display name for a property tier."""
    # Import from unified tier system
    from routers.tiers import PROPERTY_TIERS
    return PROPERTY_TIERS.get(tier, {}).get("name", f"Tier {tier}")


def calculate_land_price(population: int) -> int:
    """Calculate land purchase price based on kingdom population"""
    base_price = 500
    population_multiplier = 1.0 + (population / 50.0)
    return int(base_price * population_multiplier)


def calculate_upgrade_cost(current_tier: int) -> int:
    """Calculate upgrade cost for next tier"""
    if current_tier >= 5:
        return 0
    base_price = 500
    next_tier = current_tier + 1
    return base_price * (2 ** (next_tier - 2))


def calculate_wood_required(current_tier: int) -> int:
    """Calculate wood required for next tier (T1 land clearing doesn't need wood)"""
    next_tier = current_tier + 1
    if next_tier <= 1:
        return 0  # T1 land clearing doesn't need wood
    # T2-T5 need increasing amounts of wood
    wood_requirements = {
        2: 20,   # House needs 20 wood
        3: 50,   # Workshop needs 50 wood
        4: 100,  # Beautiful Property needs 100 wood
        5: 200   # Defensive Walls needs 200 wood
    }
    return wood_requirements.get(next_tier, 0)


def calculate_upgrade_actions_required(current_tier: int, building_skill: int = 0) -> int:
    """Calculate how many actions required to complete property upgrade"""
    base_actions = 5 + (current_tier * 2)
    building_reduction = 1.0 - min(building_skill * 0.05, 0.5)
    reduced_actions = int(base_actions * building_reduction)
    return max(1, reduced_actions)


def property_to_response(prop: Property) -> PropertyResponse:
    """Convert Property model to response"""
    return PropertyResponse(
        id=prop.id,
        kingdom_id=prop.kingdom_id,
        kingdom_name=prop.kingdom_name,
        owner_id=prop.owner_id,
        owner_name=prop.owner_name,
        tier=prop.tier,
        location=prop.location,
        purchased_at=prop.purchased_at.isoformat(),
        last_upgraded=prop.last_upgraded.isoformat() if prop.last_upgraded else None
    )


def get_property_contracts_for_user(db: Session, user_id: int) -> list:
    """Get property contracts from unified_contracts table"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type == 'property'
    ).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        result.append({
            "contract_id": str(contract.id),
            "property_id": contract.target_id,
            "kingdom_id": contract.kingdom_id,
            "kingdom_name": contract.kingdom_name,
            "from_tier": (contract.tier or 1) - 1,  # tier is target, from_tier = tier - 1
            "to_tier": contract.tier or 1,
            "target_tier_name": get_tier_name(contract.tier or 1),
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost": contract.gold_paid,
            "status": "completed" if contract.completed_at else "in_progress",
            "started_at": contract.created_at.isoformat() if contract.created_at else None,
            "completed_at": contract.completed_at.isoformat() if contract.completed_at else None
        })
    
    return result


# ===== Endpoints =====

@router.get("/status")
def get_property_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get ALL property-related data in one call"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get player's properties
    properties = db.query(Property).filter(
        Property.owner_id == current_user.id
    ).all()
    properties_list = [property_to_response(p) for p in properties]
    
    # Get property contracts from unified_contracts
    property_contracts = get_property_contracts_for_user(db, current_user.id)
    
    # Get current kingdom info
    current_kingdom = None
    land_price = None
    already_owns_property_in_current_kingdom = False
    
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            current_kingdom = {
                "id": kingdom.id,
                "name": kingdom.name,
                "population": kingdom.population
            }
            
            land_price = calculate_land_price(kingdom.population)
            
            # Check if player already owns property in THIS kingdom
            already_owns_property_in_current_kingdom = any(
                p.kingdom_id == kingdom.id for p in properties
            )
            
            # Also check for pending construction contracts
            if not already_owns_property_in_current_kingdom:
                for contract in property_contracts:
                    if (contract["status"] == "in_progress" and 
                        contract["from_tier"] == 0 and
                        contract["kingdom_id"] == kingdom.id):
                        already_owns_property_in_current_kingdom = True
                        break
    
    # Get reputation from user_kingdoms table for current kingdom
    current_kingdom_reputation = 0
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == current_user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        current_kingdom_reputation = user_kingdom.local_reputation if user_kingdom else 0
    
    # Purchase validation flags
    meets_reputation_requirement = current_kingdom_reputation >= 50
    can_afford = land_price is not None and state.gold >= land_price
    can_purchase = (
        current_kingdom is not None 
        and not already_owns_property_in_current_kingdom
        and meets_reputation_requirement 
        and can_afford
    )
    
    # Get upgrade status for each property
    properties_upgrade_status = []
    for prop in properties:
        if prop.tier < 5:
            upgrade_cost = calculate_upgrade_cost(prop.tier)
            wood_required = calculate_wood_required(prop.tier)
            actions_required = calculate_upgrade_actions_required(prop.tier, state.building_skill)
            
            # Find active contract for this property
            active_contract = None
            for contract in property_contracts:
                if contract["property_id"] == prop.id and contract["status"] == "in_progress":
                    active_contract = contract
                    break
            
            properties_upgrade_status.append({
                "property_id": prop.id,
                "current_tier": prop.tier,
                "can_upgrade": prop.tier < 5,
                "upgrade_cost": upgrade_cost,
                "wood_required": wood_required,
                "actions_required": actions_required,
                "can_afford": state.gold >= upgrade_cost and state.wood >= wood_required,
                "has_enough_gold": state.gold >= upgrade_cost,
                "has_enough_wood": state.wood >= wood_required,
                "active_contract": active_contract
            })
    
    return {
        "player_gold": state.gold,
        "player_wood": state.wood,
        "player_reputation": current_kingdom_reputation,
        "player_level": state.level,
        "player_building_skill": state.building_skill,
        "properties": properties_list,
        "property_upgrade_contracts": property_contracts,
        "properties_upgrade_status": properties_upgrade_status,
        "current_kingdom": current_kingdom,
        "land_price": land_price,
        "can_afford": can_afford,
        "already_owns_property_in_current_kingdom": already_owns_property_in_current_kingdom,
        "meets_reputation_requirement": meets_reputation_requirement,
        "can_purchase": can_purchase
    }


@router.post("/purchase")
def purchase_land(
    request: PurchaseLandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase land and start construction contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check reputation requirement - get from user_kingdoms for this kingdom
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.kingdom_id == request.kingdom_id
    ).first()
    current_reputation = user_kingdom.local_reputation if user_kingdom else 0
    
    if current_reputation < 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need 50+ reputation in {request.kingdom_name}. Current: {current_reputation}"
        )
    
    # Check if player already owns property in this kingdom
    existing_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.kingdom_id == request.kingdom_id
    ).first()
    
    if existing_property:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already own property in {request.kingdom_name} (Tier {existing_property.tier})"
        )
    
    # Check for pending construction contract in this kingdom
    pending_construction = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.tier == 1,  # tier 1 = new construction
        UnifiedContract.kingdom_id == request.kingdom_id,
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).first()
    
    if pending_construction:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already have a construction in progress in {request.kingdom_name}"
        )
    
    # Check if ANY property contract is in progress
    active_contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).first()
    
    if active_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already have a property upgrade/construction in progress. Complete it first."
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Calculate price
    land_price = calculate_land_price(kingdom.population)
    
    if state.gold < land_price:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {land_price}g, have {state.gold}g"
        )
    
    # Validate location
    valid_locations = ["north", "south", "east", "west"]
    if request.location.lower() not in valid_locations:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid location. Choose: north, south, east, or west"
        )
    
    actions_required = calculate_upgrade_actions_required(0, state.building_skill)
    property_id = str(uuid.uuid4())
    
    # Create contract in unified_contracts
    contract = UnifiedContract(
        user_id=current_user.id,
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        category='personal_property',
        type='property',
        tier=1,  # Building to tier 1
        target_id=property_id,  # Store future property ID
        actions_required=actions_required,
        gold_paid=land_price,
        status='in_progress'
    )
    db.add(contract)
    
    # Store location in a simple way - we'll need it when creating the property
    # We can use target_id to encode property_id|location
    contract.target_id = f"{property_id}|{request.location.lower()}"
    
    state.gold -= land_price
    
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Started construction in {request.kingdom_name}! Complete {actions_required} actions to build your property.",
        "contract_id": str(contract.id),
        "property_id": property_id,
        "kingdom_id": request.kingdom_id,
        "kingdom_name": request.kingdom_name,
        "location": request.location.lower(),
        "actions_required": actions_required,
        "cost_paid": land_price
    }


@router.post("/{property_id}/upgrade/purchase")
def start_property_upgrade(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase property upgrade contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get property
    property = db.query(Property).filter(
        Property.id == property_id,
        Property.owner_id == current_user.id
    ).first()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found or not owned by you"
        )
    
    if property.tier >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Property is already at maximum tier (5)"
        )
    
    # Check if ANY property upgrade in progress
    active_contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).first()
    
    if active_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already have a property upgrade in progress. Complete it first."
        )
    
    upgrade_cost = calculate_upgrade_cost(property.tier)
    wood_required = calculate_wood_required(property.tier)
    
    if state.gold < upgrade_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {upgrade_cost}g, have {state.gold}g"
        )
    
    # Check wood requirements (ensure wood is not None)
    player_wood = state.wood if state.wood is not None else 0
    if player_wood < wood_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough wood. Need {wood_required} wood, have {state.wood} wood. Chop wood at a lumbermill!"
        )
    
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill)
    next_tier = property.tier + 1
    
    # Create contract
    contract = UnifiedContract(
        user_id=current_user.id,
        kingdom_id=property.kingdom_id,
        kingdom_name=property.kingdom_name,
        category='personal_property',
        type='property',
        tier=next_tier,
        target_id=property_id,
        actions_required=actions_required,
        gold_paid=upgrade_cost,
        wood_paid=wood_required,
        status='in_progress'
    )
    db.add(contract)
    
    state.gold -= upgrade_cost
    state.wood -= wood_required
    
    db.commit()
    db.refresh(contract)
    
    tier_name = get_tier_name(next_tier)
    
    return {
        "success": True,
        "message": f"Started upgrade to {tier_name}! Complete {actions_required} actions to finish.",
        "contract_id": str(contract.id),
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": next_tier,
        "cost": upgrade_cost,
        "wood_cost": wood_required,
        "actions_required": actions_required
    }


@router.get("/{property_id}", response_model=PropertyResponse)
def get_property(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get single property details"""
    property = db.query(Property).filter(
        Property.id == property_id,
        Property.owner_id == current_user.id
    ).first()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found or not owned by you"
        )
    
    return property_to_response(property)


@router.get("/{property_id}/upgrade/status")
def get_property_upgrade_status(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current upgrade contract status for a property"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    property = db.query(Property).filter(
        Property.id == property_id,
        Property.owner_id == current_user.id
    ).first()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found or not owned by you"
        )
    
    # Find active upgrade contract
    active_contract_data = None
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.target_id.contains(property_id),
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).first()
    
    if contract:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        active_contract_data = {
            "contract_id": str(contract.id),
            "property_id": property_id,
            "to_tier": contract.tier,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": "completed" if contract.completed_at else "in_progress"
        }
    
    upgrade_cost = calculate_upgrade_cost(property.tier) if property.tier < 5 else 0
    wood_required = calculate_wood_required(property.tier) if property.tier < 5 else 0
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill) if property.tier < 5 else 0
    
    player_wood = state.wood if state.wood is not None else 0
    
    return {
        "property_id": property_id,
        "current_tier": property.tier,
        "max_tier": 5,
        "can_upgrade": property.tier < 5,
        "upgrade_cost": upgrade_cost,
        "wood_required": wood_required,
        "actions_required": actions_required,
        "can_afford": state.gold >= upgrade_cost and player_wood >= wood_required,
        "has_enough_gold": state.gold >= upgrade_cost,
        "has_enough_wood": player_wood >= wood_required,
        "active_contract": active_contract_data,
        "player_gold": state.gold,
        "player_wood": player_wood,
        "player_building_skill": state.building_skill
    }
