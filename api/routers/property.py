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
from routers.actions.utils import format_datetime_iso

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


def get_upgrade_costs_full(current_tier: int, population: int = 0, actions_required: int = None) -> dict:
    """
    Get ALL upgrade costs for next tier - FULLY DYNAMIC from PROPERTY_TIERS!
    Returns dict with:
      - gold_cost: Gold paid UPFRONT to start the contract
      - per_action_costs: List of {resource, amount, display_name, icon} - required each action
      - total_costs: Total resources needed over all actions (for display)
    """
    from routers.tiers import PROPERTY_TIERS, get_property_max_tier
    from routers.resources import RESOURCES
    
    next_tier = current_tier + 1
    if current_tier >= get_property_max_tier():
        return {"gold_cost": 0, "per_action_costs": [], "total_costs": []}
    
    tier_data = PROPERTY_TIERS.get(next_tier, {})
    gold_cost = tier_data.get("gold_cost", 0)
    base_per_action = tier_data.get("per_action_costs", [])
    base_actions = tier_data.get("base_actions", 5)
    
    # Use provided actions_required or default to base
    total_actions = actions_required or base_actions
    
    def enrich_cost(cost):
        """Add display info from RESOURCES"""
        resource_id = cost["resource"]
        amount = cost["amount"]
        resource_info = RESOURCES.get(resource_id, {})
        return {
            "resource": resource_id,
            "amount": amount,
            "display_name": resource_info.get("display_name", resource_id.capitalize()),
            "icon": resource_info.get("icon", "questionmark.circle")
        }
    
    per_action_costs = [enrich_cost(c) for c in base_per_action]
    
    # Calculate total costs (for display: "280 wood total over 7 actions")
    total_costs = []
    for cost in per_action_costs:
        total_costs.append({
            **cost,
            "total_amount": cost["amount"] * total_actions,
            "per_action_amount": cost["amount"]
        })
    
    return {
        "gold_cost": gold_cost,
        "per_action_costs": per_action_costs,
        "total_costs": total_costs
    }


def get_upgrade_resource_costs(current_tier: int, population: int = 0) -> list:
    """
    Get TOTAL upgrade costs for display.
    Returns list with total amounts needed.
    """
    costs = get_upgrade_costs_full(current_tier, population)
    
    return [
        {
            "resource": cost["resource"],
            "amount": cost["total_amount"],
            "display_name": cost["display_name"],
            "icon": cost["icon"]
        }
        for cost in costs["total_costs"]
    ]


def calculate_upgrade_actions_required(current_tier: int, building_skill: int = 0) -> int:
    """Calculate how many actions required to complete property upgrade"""
    from routers.tiers import PROPERTY_TIERS, get_property_max_tier
    
    next_tier = current_tier + 1
    if current_tier >= get_property_max_tier():
        return 0
    
    tier_data = PROPERTY_TIERS.get(next_tier, {})
    base_actions = tier_data.get("base_actions", 5 + (current_tier * 2))
    
    building_reduction = 1.0 - min(building_skill * 0.05, 0.5)
    reduced_actions = int(base_actions * building_reduction)
    return max(1, reduced_actions)


def check_player_can_afford(state, resource_costs: list) -> dict:
    """Check if player can afford all resource costs"""
    results = {"can_afford": True, "missing": []}
    
    for cost in resource_costs:
        resource_id = cost["resource"]
        required = cost["amount"]
        
        # Get player's amount of this resource
        player_amount = getattr(state, resource_id, 0) or 0
        
        has_enough = player_amount >= required
        cost["player_has"] = player_amount
        cost["has_enough"] = has_enough
        
        if not has_enough:
            results["can_afford"] = False
            results["missing"].append({
                "resource": resource_id,
                "needed": required - player_amount
            })
    
    return results


def deduct_resource_costs(state, resource_costs: list):
    """Deduct resources from player state"""
    for cost in resource_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        current = getattr(state, resource_id, 0) or 0
        setattr(state, resource_id, current - amount)


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
        purchased_at=format_datetime_iso(prop.purchased_at),
        last_upgraded=format_datetime_iso(prop.last_upgraded) if prop.last_upgraded else None
    )


def get_property_contracts_for_user(db: Session, user_id: int) -> list:
    """Get property contracts from unified_contracts table - FULLY DYNAMIC"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type == 'property'
    ).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        # Get per-action costs for this tier (DYNAMIC from PROPERTY_TIERS)
        from_tier = (contract.tier or 1) - 1
        all_costs = get_upgrade_costs_full(from_tier, actions_required=contract.actions_required)
        
        result.append({
            "contract_id": str(contract.id),
            "property_id": contract.target_id,
            "kingdom_id": contract.kingdom_id,
            "kingdom_name": contract.kingdom_name,
            "from_tier": from_tier,
            "to_tier": contract.tier or 1,
            "target_tier_name": get_tier_name(contract.tier or 1),
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost": contract.gold_paid,
            "status": "completed" if contract.completed_at else "in_progress",
            "started_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "completed_at": format_datetime_iso(contract.completed_at) if contract.completed_at else None,
            # NEW: Per-action resource costs (required during work)
            "per_action_costs": all_costs["per_action_costs"],
            "endpoint": f"/actions/work-property/{contract.id}" if not contract.completed_at else None
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
            
            # Get land price from dynamic resource costs (tier 0 -> 1)
            land_costs = get_upgrade_resource_costs(0, population=kingdom.population)
            land_price = next((c["amount"] for c in land_costs if c["resource"] == "gold"), 500)
            
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
    
    # Get upgrade status for each property - FULLY DYNAMIC
    from routers.tiers import get_property_max_tier
    max_tier = get_property_max_tier()
    
    properties_upgrade_status = []
    for prop in properties:
        if prop.tier < max_tier:
            # Get dynamic resource costs
            resource_costs = get_upgrade_resource_costs(prop.tier)
            affordability = check_player_can_afford(state, resource_costs)
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
                "max_tier": max_tier,
                "can_upgrade": prop.tier < max_tier,
                "resource_costs": resource_costs,  # Dynamic list!
                "actions_required": actions_required,
                "can_afford": affordability["can_afford"],
                "missing_resources": affordability["missing"],
                "active_contract": active_contract
            })
    
    return {
        "player_gold": int(state.gold),
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
        tier_desc = "under construction" if existing_property.tier == 0 else f"Tier {existing_property.tier}"
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already own property in {request.kingdom_name} ({tier_desc})"
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
    
    # Calculate price using dynamic resource costs (tier 0 -> 1)
    land_costs = get_upgrade_resource_costs(0, population=kingdom.population)
    land_price = next((c["amount"] for c in land_costs if c["resource"] == "gold"), 500)
    
    if state.gold < land_price:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {land_price}g, have {int(state.gold)}g"
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
    
    # Create property immediately with tier=0 (under construction)
    new_property = Property(
        id=property_id,
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        owner_id=current_user.id,
        owner_name=current_user.display_name,
        tier=0,  # Under construction
        location=request.location.lower(),
        purchased_at=datetime.utcnow(),
        last_upgraded=None
    )
    db.add(new_property)
    
    # Create contract in unified_contracts
    contract = UnifiedContract(
        user_id=current_user.id,
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        category='personal_property',
        type='property',
        tier=1,  # Building to tier 1
        target_id=property_id,  # Just the property ID, no encoding needed
        actions_required=actions_required,
        gold_paid=land_price
    )
    db.add(contract)
    
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
    """Purchase property upgrade contract.
    Gold paid UPFRONT to start. Resources required per action during work.
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
    
    # FULLY DYNAMIC - check max tier from config
    from routers.tiers import get_property_max_tier
    max_tier = get_property_max_tier()
    
    if property.tier >= max_tier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Property is already at maximum tier ({max_tier})"
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
    
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill)
    next_tier = property.tier + 1
    
    # Get cost breakdown from tiers
    all_costs = get_upgrade_costs_full(property.tier, actions_required=actions_required)
    gold_cost = all_costs["gold_cost"]
    per_action_costs = all_costs["per_action_costs"]
    
    # Check if player can afford GOLD upfront
    if state.gold < gold_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {gold_cost}g, have {int(state.gold)}g"
        )
    
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
        gold_paid=gold_cost
    )
    db.add(contract)
    
    # Deduct GOLD upfront (per-action costs deducted during work)
    state.gold -= gold_cost
    
    db.commit()
    db.refresh(contract)
    
    tier_name = get_tier_name(next_tier)
    
    # Build warning message about per-action costs
    per_action_warning = ""
    if per_action_costs:
        per_action_str = ", ".join([f"{c['amount']} {c['display_name']}" for c in per_action_costs])
        per_action_warning = f" Each action requires: {per_action_str}."
    
    return {
        "success": True,
        "message": f"Started upgrade to {tier_name}! Complete {actions_required} actions to finish.{per_action_warning}",
        "contract_id": str(contract.id),
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": next_tier,
        "gold_cost": gold_cost,  # What was paid upfront
        "per_action_costs": per_action_costs,  # What each action will cost
        "total_costs": all_costs["total_costs"],  # Total resources over all actions
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
    """Get current upgrade contract status for a property - FULLY DYNAMIC"""
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
    
    from routers.tiers import get_property_max_tier
    max_tier = get_property_max_tier()
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill) if property.tier < max_tier else 0
    
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
        
        # Get per-action costs for this tier (for display on contract card)
        contract_costs = get_upgrade_costs_full(contract.tier - 1, actions_required=contract.actions_required)
        
        active_contract_data = {
            "contract_id": str(contract.id),
            "property_id": property_id,
            "to_tier": contract.tier or 1,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": "completed" if contract.completed_at else "in_progress",
            "per_action_costs": contract_costs["per_action_costs"]  # What each action costs
        }
    
    # FULLY DYNAMIC costs
    if property.tier < max_tier:
        all_costs = get_upgrade_costs_full(property.tier, actions_required=actions_required)
        gold_cost = all_costs["gold_cost"]
        per_action_costs = all_costs["per_action_costs"]
        total_costs = all_costs["total_costs"]
        
        # Check if player can afford gold upfront
        can_afford_gold = state.gold >= gold_cost
    else:
        gold_cost = 0
        per_action_costs = []
        total_costs = []
        can_afford_gold = False
    
    return {
        "property_id": property_id,
        "current_tier": property.tier,
        "max_tier": max_tier,
        "can_upgrade": property.tier < max_tier,
        # Gold paid upfront to start
        "gold_cost": gold_cost,
        # Resources required per action
        "per_action_costs": per_action_costs,
        # Total resources needed (for display)
        "total_costs": total_costs,
        "actions_required": actions_required,
        "can_afford": can_afford_gold,  # Can afford gold to START
        "player_gold": int(state.gold),
        "active_contract": active_contract_data,
        "player_building_skill": state.building_skill
    }
