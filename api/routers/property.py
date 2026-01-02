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


class PurchaseConstructionResponse(BaseModel):
    """Response when starting property construction (similar to PropertyUpgradeResponse)"""
    success: bool
    message: str
    contract_id: str
    property_id: str
    kingdom_id: str
    kingdom_name: str
    location: str
    actions_required: int
    cost_paid: int


# ===== Helper Functions =====

def get_tier_name(tier: int) -> str:
    """
    Get the display name for a property tier.
    Single source of truth for tier names!
    """
    tier_names = {
        1: "Land",
        2: "House", 
        3: "Workshop",
        4: "Beautiful Property",
        5: "Estate"
    }
    return tier_names.get(tier, f"Tier {tier}")


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

@router.get("/status")
def get_property_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get ALL property-related data in one call (like /actions/status)
    
    Returns:
    - Player's properties list
    - Player resources (gold, reputation, level)
    - Current kingdom context
    - Land price for current kingdom
    - Purchase validation flags
    - Upgrade status for all properties
    - Property upgrade contracts
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    import json
    
    # Get player's properties
    properties = db.query(Property).filter(
        Property.owner_id == current_user.id
    ).all()
    properties_list = [property_to_response(p) for p in properties]
    
    # Load property upgrade/construction contracts
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    
    # Get current kingdom info (if checked in)
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
            
            # Calculate land price for current kingdom
            land_price = calculate_land_price(kingdom.population)
            
            # Check if player already owns property in THIS kingdom (including pending construction)
            already_owns_property_in_current_kingdom = any(
                p.kingdom_id == kingdom.id for p in properties
            )
            
            # Also check for pending construction contracts in this kingdom
            if not already_owns_property_in_current_kingdom:
                for contract in property_contracts:
                    if (contract.get("status") == "in_progress" and 
                        contract.get("from_tier") == 0 and
                        contract.get("kingdom_id") == kingdom.id):
                        already_owns_property_in_current_kingdom = True
                        break
    
    # Purchase validation flags
    meets_reputation_requirement = state.reputation >= 50
    can_afford = land_price is not None and state.gold >= land_price
    can_purchase = (
        current_kingdom is not None 
        and not already_owns_property_in_current_kingdom
        and meets_reputation_requirement 
        and can_afford
    )
    
    # Add computed fields to contracts
    for contract in property_contracts:
        # Compute target_tier_name from to_tier (not stored in DB)
        contract["target_tier_name"] = get_tier_name(contract["to_tier"])
    
    # Get upgrade status for each property
    properties_upgrade_status = []
    for prop in properties:
        if prop.tier < 5:
            upgrade_cost = calculate_upgrade_cost(prop.tier)
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
                "actions_required": actions_required,
                "can_afford": state.gold >= upgrade_cost,
                "active_contract": active_contract
            })
    
    return {
        # Player resources
        "player_gold": state.gold,
        "player_reputation": state.reputation,
        "player_level": state.level,
        "player_building_skill": state.building_skill,
        
        # Properties
        "properties": properties_list,
        "property_upgrade_contracts": property_contracts,
        "properties_upgrade_status": properties_upgrade_status,
        
        # Current kingdom purchase context
        "current_kingdom": current_kingdom,
        "land_price": land_price,
        "can_afford": can_afford,
        "already_owns_property_in_current_kingdom": already_owns_property_in_current_kingdom,
        "meets_reputation_requirement": meets_reputation_requirement,
        "can_purchase": can_purchase
    }


@router.post("/purchase", response_model=PurchaseConstructionResponse)
def purchase_land(
    request: PurchaseLandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Purchase land and start construction contract (like training system)
    
    Requirements:
    - 50+ reputation
    - Enough gold (price scales with kingdom population)
    - Cannot own property in this kingdom already (ONE per kingdom)
    
    Works like training:
    1. Pay gold upfront
    2. Get a construction contract requiring actions
    3. Complete actions to build the property
    4. Property is created when contract finishes
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
    
    # Check if player already owns property in this kingdom (including pending construction)
    existing_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.kingdom_id == request.kingdom_id
    ).first()
    
    if existing_property:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already own property in {request.kingdom_name} (Tier {existing_property.tier})"
        )
    
    # Check if player has pending construction contract in this kingdom
    import json
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    for contract in property_contracts:
        if (contract.get("status") == "in_progress" and 
            contract.get("from_tier") == 0 and
            contract.get("kingdom_id") == request.kingdom_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You already have a construction in progress in {request.kingdom_name}"
            )
    
    # Check if ANY property upgrade/construction is in progress (only one at a time)
    for contract in property_contracts:
        if contract.get("status") == "in_progress":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You already have a property upgrade/construction in progress. Complete it before starting a new one."
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
    
    # Calculate actions required for construction (tier 0->1)
    actions_required = calculate_upgrade_actions_required(0, state.building_skill)
    
    # Generate property ID (will be used when construction completes)
    property_id = str(uuid.uuid4())
    contract_id = str(uuid.uuid4())
    
    # Create construction contract (from_tier=0 indicates new construction)
    new_contract = {
        "contract_id": contract_id,
        "property_id": property_id,
        "kingdom_id": request.kingdom_id,
        "kingdom_name": request.kingdom_name,
        "location": request.location.lower(),
        "from_tier": 0,  # 0 = new construction
        "to_tier": 1,
        "actions_required": actions_required,
        "actions_completed": 0,
        "cost": land_price,
        "status": "in_progress",
        "started_at": datetime.utcnow().isoformat()
    }
    
    # Deduct gold and add construction contract
    state.gold -= land_price
    property_contracts.append(new_contract)
    state.property_upgrade_contracts = json.dumps(property_contracts)
    
    db.commit()
    
    return PurchaseConstructionResponse(
        success=True,
        message=f"Started construction in {request.kingdom_name}! Complete {actions_required} actions to build your property.",
        contract_id=contract_id,
        property_id=property_id,
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        location=request.location.lower(),
        actions_required=actions_required,
        cost_paid=land_price
    )


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
    
    # Check if ANY upgrade already in progress (only one at a time, like training)
    import json
    property_contracts = json.loads(state.property_upgrade_contracts or "[]")
    for contract in property_contracts:
        if contract["status"] == "in_progress":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You already have a property upgrade in progress. Complete it before starting a new one."
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
    next_tier = property.tier + 1
    
    new_contract = {
        "contract_id": contract_id,
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": next_tier,
        # NOTE: target_tier_name is NOT stored - it's computed on read from to_tier
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
    
    # Compute tier name on the fly (not stored in DB)
    tier_name = get_tier_name(next_tier)
    
    return {
        "success": True,
        "message": f"Started upgrade to {tier_name}! Complete {actions_required} actions to finish.",
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

