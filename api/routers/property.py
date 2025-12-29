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
    purchased_at: str
    last_upgraded: str | None
    
    class Config:
        from_attributes = True


class PurchaseLandRequest(BaseModel):
    kingdom_id: str
    kingdom_name: str


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


def property_to_response(prop: Property) -> PropertyResponse:
    """Convert Property model to response"""
    return PropertyResponse(
        id=prop.id,
        kingdom_id=prop.kingdom_id,
        kingdom_name=prop.kingdom_name,
        owner_id=prop.owner_id,
        owner_name=prop.owner_name,
        tier=prop.tier,
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
        purchased_at=datetime.utcnow(),
        last_upgraded=None
    )
    
    db.add(new_property)
    db.commit()
    db.refresh(new_property)
    
    return property_to_response(new_property)


@router.post("/{property_id}/upgrade", response_model=PropertyResponse)
def upgrade_property(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upgrade property to next tier
    
    Tiers:
    T1: Land (50% travel cost, instant travel)
    T2: House (residence)
    T3: Workshop (crafting enabled, 15% faster crafting)
    T4: Beautiful Property (tax exemption)
    T5: Estate (50% survive conquest)
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
    
    # Calculate upgrade cost
    upgrade_cost = calculate_upgrade_cost(property.tier)
    
    # Check if player has enough gold
    if state.gold < upgrade_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {upgrade_cost}g, have {state.gold}g"
        )
    
    # Deduct gold and upgrade
    state.gold -= upgrade_cost
    property.tier += 1
    property.last_upgraded = datetime.utcnow()
    
    db.commit()
    db.refresh(property)
    
    return property_to_response(property)


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

