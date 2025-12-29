"""
Property API - Land ownership and upgrades
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid
from datetime import datetime

from db import get_db, Property, User, Kingdom
from routers.auth import get_current_user

router = APIRouter(prefix="/properties", tags=["properties"])


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


class UpgradePropertyRequest(BaseModel):
    property_id: str


# ===== Helper Functions =====

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
    # T1->T2: 500, T2->T3: 1000, T3->T4: 2000, T4->T5: 4000
    return base_price * (2 ** (next_tier - 2))


def calculate_upgrade_actions_required(current_tier: int, building_skill: int = 0) -> int:
    """Calculate how many actions required to complete property upgrade
    
    Formula: (5 + (tier * 2)) * (1 - (building_skill * 0.05))
    Base actions scale with tier - higher tiers take more work
    Building skill reduces actions required by 5% per level (up to 50% at level 10)
    
    Tier 1->2: 7 actions base
    Tier 2->3: 9 actions base
    Tier 3->4: 11 actions base
    Tier 4->5: 13 actions base
    
    With building skill 10: 50% reduction
    """
    base_actions = 5 + (current_tier * 2)
    building_reduction = 1.0 - min(building_skill * 0.05, 0.5)  # Cap at 50% reduction
    reduced_actions = int(base_actions * building_reduction)
    # Minimum of 1 action required
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


# ===== Endpoints =====

@router.get("", response_model=List[PropertyResponse])
def get_player_properties(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all properties owned by current player"""
    properties = db.query(Property).filter(
        Property.owner_id == current_user.id
    ).all()
    
    return [property_to_response(p) for p in properties]


@router.post("/purchase", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def purchase_land(
    request: PurchaseLandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Purchase land (T1) in a kingdom
    
    Requirements:
    - 50+ reputation
    - Enough gold (price scales with kingdom population)
    - Cannot own property in this kingdom already (ONE per kingdom)
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check reputation requirement
    if state.reputation < 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need 50+ reputation. Current: {state.reputation}"
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
    
    # Get kingdom to calculate price
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Calculate land price based on population
    land_price = calculate_land_price(kingdom.population)
    
    # Check if player has enough gold
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
    
    # Deduct gold
    state.gold -= land_price
    
    # Create property at T1
    new_property = Property(
        id=str(uuid.uuid4()),
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        owner_id=current_user.id,
        owner_name=current_user.display_name,
        tier=1,
        location=request.location.lower(),
        purchased_at=datetime.utcnow(),
        last_upgraded=None
    )
    
    db.add(new_property)
    db.commit()
    db.refresh(new_property)
    
    return property_to_response(new_property)


@router.post("/{property_id}/upgrade/purchase")
def start_property_upgrade(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Purchase property upgrade (creates a contract that requires actions to complete)
    
    Works like training system:
    1. Pay gold to START upgrade
    2. Get a contract requiring X actions
    3. Do actions to work on it
    4. When complete, tier increases
    
    Tiers:
    T1: Land (instant travel)
    T2: House (residence)
    T3: Workshop (crafting)
    T4: Beautiful Property (no taxes)
    T5: Estate (conquest protection)
    """
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
    
    # Check if already max tier
    if property.tier >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Property is already at maximum tier (5)"
        )
    
    # Check if upgrade already in progress
    import json
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    for contract in property_contracts:
        if contract["property_id"] == property_id and contract["status"] == "in_progress":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Upgrade already in progress for this property"
            )
    
    # Calculate upgrade cost
    upgrade_cost = calculate_upgrade_cost(property.tier)
    
    # Check if player has enough gold
    if state.gold < upgrade_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {upgrade_cost}g, have {state.gold}g"
        )
    
    # Calculate actions required (building skill helps)
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill)
    
    # Create upgrade contract
    contract_id = str(uuid.uuid4())
    tier_names = {1: "House", 2: "Workshop", 3: "Beautiful Property", 4: "Estate"}
    next_tier = property.tier + 1
    
    new_contract = {
        "contract_id": contract_id,
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": next_tier,
        "target_tier_name": tier_names.get(next_tier, f"Tier {next_tier}"),
        "actions_required": actions_required,
        "actions_completed": 0,
        "cost": upgrade_cost,
        "status": "in_progress",
        "started_at": datetime.utcnow().isoformat()
    }
    
    # Add contract and spend gold
    property_contracts.append(new_contract)
    state.property_upgrade_contracts = json.dumps(property_contracts)
    state.gold -= upgrade_cost
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Started upgrade to {new_contract['target_tier_name']}! Complete {actions_required} actions to finish.",
        "contract_id": contract_id,
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": next_tier,
        "cost": upgrade_cost,
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
    
    # Check property exists and is owned by user
    property = db.query(Property).filter(
        Property.id == property_id,
        Property.owner_id == current_user.id
    ).first()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found or not owned by you"
        )
    
    # Find active upgrade contract for this property
    import json
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    
    active_contract = None
    for contract in property_contracts:
        if contract["property_id"] == property_id and contract["status"] == "in_progress":
            active_contract = contract
            break
    
    # Calculate upgrade costs and requirements
    upgrade_cost = calculate_upgrade_cost(property.tier) if property.tier < 5 else 0
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill) if property.tier < 5 else 0
    
    return {
        "property_id": property_id,
        "current_tier": property.tier,
        "max_tier": 5,
        "can_upgrade": property.tier < 5,
        "upgrade_cost": upgrade_cost,
        "actions_required": actions_required,
        "active_contract": active_contract,
        "player_gold": state.gold,
        "player_building_skill": state.building_skill
    }

