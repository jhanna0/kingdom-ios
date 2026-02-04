"""
Property API - Land ownership and upgrades
Uses unified contract system (no more JSONB!)

Fortification System:
- Unlocked at T2 (House)
- Sacrifice weapons/armor to increase fortification %
- Decays 1% per day (lazy decay - calculated on read)
- T5 estates have 50% base that doesn't decay
- Protects property tier during kingdom conquest
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
import uuid
import random
from datetime import datetime, timezone, timedelta

from db import get_db, Property, User, Kingdom, UnifiedContract, ContractContribution, UserKingdom, PlayerItem
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso

router = APIRouter(prefix="/properties", tags=["properties"])


# ===== Fortification Config =====

# RNG fortification gain ranges by equipment tier
FORTIFICATION_GAIN_RANGES = {
    1: (3, 8),    # T1: +3..+8%
    2: (6, 12),   # T2: +6..+12%
    3: (10, 18),  # T3: +10..+18%
    4: (15, 25),  # T4: +15..+25%
    5: (20, 35),  # T5: +20..+35%
}

# Decay rate: 1% per day
FORTIFICATION_DECAY_PER_DAY = 1

# T5 base fortification (doesn't decay)
T5_BASE_FORTIFICATION = 50


# ===== Fortification Helpers =====

def apply_fortification_decay(prop: Property, now: datetime = None) -> int:
    """
    Apply lazy decay to property fortification.
    Returns the amount decayed.
    
    Lazy decay: Only calculate and apply decay when property is accessed.
    """
    if now is None:
        now = datetime.now(timezone.utc)
    
    # Ensure now is timezone-aware
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    
    # If fortification is 0 or at base, nothing to decay
    base = T5_BASE_FORTIFICATION if prop.tier >= 5 else 0
    if prop.fortification_percent <= base:
        prop.fortification_last_decay_at = now
        return 0
    
    # If no last decay timestamp, initialize it now (no decay applied)
    if prop.fortification_last_decay_at is None:
        prop.fortification_last_decay_at = now
        return 0
    
    # Ensure last_decay_at is timezone-aware
    last_decay = prop.fortification_last_decay_at
    if last_decay.tzinfo is None:
        last_decay = last_decay.replace(tzinfo=timezone.utc)
    
    # Calculate days elapsed
    time_elapsed = now - last_decay
    days_elapsed = int(time_elapsed.total_seconds() / 86400)  # 86400 seconds per day
    
    if days_elapsed <= 0:
        return 0
    
    # Calculate decay (1% per day)
    decay_amount = days_elapsed * FORTIFICATION_DECAY_PER_DAY
    old_percent = prop.fortification_percent
    
    # Decay to base minimum (T5 = 50%, others = 0%)
    prop.fortification_percent = max(base, prop.fortification_percent - decay_amount)
    
    # Update timestamp (advance by whole days)
    prop.fortification_last_decay_at = last_decay + timedelta(days=days_elapsed)
    
    return old_percent - prop.fortification_percent


def roll_fortification_gain(tier: int) -> int:
    """Roll random fortification gain based on item tier."""
    min_gain, max_gain = FORTIFICATION_GAIN_RANGES.get(tier, (3, 8))
    return random.randint(min_gain, max_gain)


def get_fortification_gain_range(tier: int) -> tuple:
    """Get the min/max gain range for an item tier."""
    return FORTIFICATION_GAIN_RANGES.get(tier, (3, 8))


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
    # Fortification fields
    fortification_unlocked: bool = False
    fortification_percent: int = 0
    fortification_base_percent: int = 0
    
    class Config:
        from_attributes = True


class FortifyRequest(BaseModel):
    player_item_id: int


class FortifyResponse(BaseModel):
    success: bool
    message: str
    fortification_before: int
    fortification_gain: int
    fortification_after: int
    item_consumed: str  # Display name of consumed item


class FortifyOptionItem(BaseModel):
    id: int
    item_id: str | None
    display_name: str
    icon: str
    type: str
    tier: int
    gain_min: int
    gain_max: int
    is_equipped: bool
    count: int = 1


class FortifyOptionsResponse(BaseModel):
    property_id: str
    fortification_unlocked: bool
    current_fortification: int
    base_fortification: int
    eligible_items: list[FortifyOptionItem]
    weapon_count: int
    armor_count: int
    # Explanation content (so we can update it without app release)
    explanation: dict  # title, description, mechanics, decay_info, t5_bonus


class PurchaseLandRequest(BaseModel):
    kingdom_id: str
    kingdom_name: str
    location: str  # "north", "south", "east", "west"


class UpgradePropertyRequest(BaseModel):
    option_id: str | None = None  # Which option to build (e.g., 'workshop', 'kitchen'). If None, uses first option at next tier.


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
    """Get the display name for a property tier.
    
    Returns the first option's name if available (e.g., 'Workshop' instead of 'Workshop & Kitchen').
    Falls back to legacy tier name if no options defined.
    """
    from routers.tiers import PROPERTY_TIERS
    tier_data = PROPERTY_TIERS.get(tier, {})
    options = tier_data.get("options", [])
    if options:
        return options[0].get("name", f"Tier {tier}")
    return tier_data.get("name", f"Tier {tier}")


def get_option_name(tier: int, option_id: str) -> str | None:
    """Get display name for an option_id at a specific tier."""
    from routers.tiers import PROPERTY_TIERS
    tier_data = PROPERTY_TIERS.get(tier, {})
    for opt in tier_data.get("options", []):
        if opt.get("id") == option_id:
            return opt.get("name")
    return None


def get_upgrade_costs_full(current_tier: int, population: int = 0, actions_required: int = None, option_id: str = None) -> dict:
    """
    Get ALL upgrade costs for next tier - FULLY DYNAMIC from tiers.py!
    Returns dict with:
      - gold_cost: Total gold (gold_per_action × actions) for display
      - gold_per_action: Gold cost per action (before tax)
      - per_action_costs: List of {resource, amount, display_name, icon} - required each action
      - total_costs: Total resources needed over all actions (for display)
    """
    from routers.tiers import (
        get_property_max_tier, get_property_option_per_action_costs,
        calculate_property_gold_per_action, calculate_property_actions
    )
    from routers.resources import RESOURCES
    
    next_tier = current_tier + 1
    if current_tier >= get_property_max_tier():
        return {"gold_cost": 0, "gold_per_action": 0, "per_action_costs": [], "total_costs": []}
    gold_per_action = calculate_property_gold_per_action(next_tier)
    base_per_action = get_property_option_per_action_costs(next_tier, option_id)
    base_actions = calculate_property_actions(next_tier)
    
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
            "icon": resource_info.get("icon", "questionmark.circle"),
            "color": resource_info.get("color", "inkMedium")
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
    
    # Calculate total gold from gold_per_action × actions
    gold_cost = int(gold_per_action * total_actions)
    
    return {
        "gold_cost": gold_cost,  # Total gold (for display)
        "gold_per_action": gold_per_action,  # Per-action cost (before tax)
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
    from routers.tiers import get_property_max_tier, get_building_action_reduction, calculate_property_actions
    
    next_tier = current_tier + 1
    if current_tier >= get_property_max_tier():
        return 0
    
    # Get base actions from centralized config
    base_actions = calculate_property_actions(next_tier)
    
    # Use centralized building skill reduction
    building_reduction = get_building_action_reduction(building_skill)
    reduced_actions = int(base_actions * building_reduction)
    return max(1, reduced_actions)


def check_player_can_afford(db: Session, user_id: int, resource_costs: list) -> dict:
    """Check if player can afford all resource costs (from inventory)"""
    from routers.actions.utils import get_inventory_map
    
    results = {"can_afford": True, "missing": []}
    inventory_map = get_inventory_map(db, user_id)
    
    for cost in resource_costs:
        resource_id = cost["resource"]
        required = cost["amount"]
        
        # Get player's amount from inventory
        player_amount = inventory_map.get(resource_id, 0)
        
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


def deduct_resource_costs(db: Session, user_id: int, resource_costs: list):
    """Deduct resources from player inventory"""
    from routers.actions.utils import deduct_inventory_amount
    
    for cost in resource_costs:
        resource_id = cost["resource"]
        amount = cost["amount"]
        deduct_inventory_amount(db, user_id, resource_id, amount)


def get_available_rooms(tier: int, built_rooms: list[str]) -> list:
    """Get list of rooms available to use at this property.
    
    Reads from PROPERTY_TIERS config - no hardcoding!
    A room is available if:
      - It has free_at_tier <= current tier (backwards compat)
      - OR it's in built_rooms (explicitly built via contract)
    
    Args:
        tier: Property tier level
        built_rooms: List of room IDs that have been built via completed contracts.
    """
    from routers.tiers import PROPERTY_TIERS
    
    rooms = []
    
    # Tier 2+ gets fortification and garden free (no contract needed)
    if tier >= 2:
        rooms.append({
            "id": "fortification",
            "name": "Fortification",
            "icon": "shield.checkered",
            "color": "royalBlue",
            "description": "Sacrifice equipment to protect your property",
            "route": "/fortify"
        })
        rooms.append({
            "id": "garden",
            "name": "Garden",
            "icon": "leaf.fill",
            "color": "buttonSuccess",
            "description": "Plant seeds and grow your garden",
            "route": "/garden"
        })
    
    # Check all options from config for rooms to show
    # Only show options that have a "route" defined (actual rooms, not tier upgrades)
    seen_ids = set()
    for tier_num, tier_data in PROPERTY_TIERS.items():
        for opt in tier_data.get("options", []):
            opt_id = opt.get("id")
            
            # Skip if no route defined - it's a tier upgrade, not an accessible room
            if not opt.get("route"):
                continue
                
            if opt_id in seen_ids:
                continue
            
            # Room is available if: free_at_tier <= current tier OR explicitly built
            free_at = opt.get("free_at_tier")
            is_free = free_at is not None and tier >= free_at
            is_built = opt_id in built_rooms
            
            if is_free or is_built:
                rooms.append({
                    "id": opt_id,
                    "name": opt.get("name", opt_id),
                    "icon": opt.get("icon", "questionmark"),
                    "color": opt.get("color", "inkMedium"),
                    "description": opt.get("description", ""),
                    "route": opt.get("route")
                })
                seen_ids.add(opt_id)
    
    return rooms


def property_to_response(prop: Property, apply_decay: bool = True) -> PropertyResponse:
    """Convert Property model to response.
    
    Args:
        prop: Property model
        apply_decay: If True, applies lazy decay before returning (default True).
                    Note: Caller must commit after if decay was applied.
    """
    # Apply lazy decay if requested
    if apply_decay and prop.fortification_percent > 0:
        apply_fortification_decay(prop)
    
    # Calculate fortification values
    fortification_unlocked = prop.tier >= 2
    base_fortification = T5_BASE_FORTIFICATION if prop.tier >= 5 else 0
    
    return PropertyResponse(
        id=prop.id,
        kingdom_id=prop.kingdom_id,
        kingdom_name=prop.kingdom_name,
        owner_id=prop.owner_id,
        owner_name=prop.owner_name,
        tier=prop.tier,
        location=prop.location,
        purchased_at=format_datetime_iso(prop.purchased_at),
        last_upgraded=format_datetime_iso(prop.last_upgraded) if prop.last_upgraded else None,
        fortification_unlocked=fortification_unlocked,
        fortification_percent=prop.fortification_percent,
        fortification_base_percent=base_fortification
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
        
        # Get per-action costs for this specific option
        from_tier = (contract.tier or 1) - 1
        all_costs = get_upgrade_costs_full(from_tier, actions_required=contract.actions_required, option_id=contract.option_id)
        
        # Get gold per action info
        gold_per_action = contract.gold_per_action or 0
        
        # Get current kingdom tax rate for display
        current_tax_rate = 0
        if contract.kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
            if kingdom:
                current_tax_rate = kingdom.tax_rate
        
        # Look up option name
        option_name = get_option_name(contract.tier, contract.option_id) if contract.tier and contract.option_id else None
        
        result.append({
            "contract_id": str(contract.id),
            "property_id": contract.target_id,
            "kingdom_id": contract.kingdom_id,
            "kingdom_name": contract.kingdom_name,
            "from_tier": from_tier,
            "to_tier": contract.tier or 1,
            "target_tier_name": get_tier_name(contract.tier or 1),
            "option_id": contract.option_id,  # Which specific room is being built
            "option_name": option_name,  # Display name for the room
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost": contract.gold_paid or 0,  # OLD: upfront payment (backwards compat)
            "gold_per_action": round(gold_per_action, 1) if gold_per_action > 0 else None,  # NEW: per-action cost
            "current_tax_rate": current_tax_rate if gold_per_action > 0 else None,  # For display
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
    
    # Get all completed room contracts for this user
    completed_room_contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.completed_at.isnot(None),
        UnifiedContract.option_id.isnot(None)
    ).all()
    
    # Build a dict of property_id -> list of built room IDs
    built_rooms_by_property = {}
    for contract in completed_room_contracts:
        prop_id = contract.target_id
        if prop_id not in built_rooms_by_property:
            built_rooms_by_property[prop_id] = []
        built_rooms_by_property[prop_id].append(contract.option_id)
    
    # Get all buildable options from tiers config
    from routers.tiers import PROPERTY_TIERS
    all_buildable_options = []
    for tier_num, tier_data in PROPERTY_TIERS.items():
        for opt in tier_data.get("options", []):
            all_buildable_options.append({
                "id": opt.get("id"),
                "name": opt.get("name"),
                "tier": tier_num,
                "icon": opt.get("icon"),
                "description": opt.get("description"),
            })
    
    # Convert properties to response format and add available rooms
    # Note: property_to_response applies lazy decay to fortification
    properties_list = []
    for p in properties:
        prop_dict = property_to_response(p).model_dump()
        built_rooms = built_rooms_by_property.get(str(p.id), [])
        prop_dict["available_rooms"] = get_available_rooms(p.tier, built_rooms)
        prop_dict["built_rooms"] = built_rooms  # List of room IDs that are built
        
        # Available options to build at next tier (only if not already built)
        next_tier = p.tier + 1
        next_tier_options = [opt for opt in all_buildable_options if opt["tier"] == next_tier]
        next_tier_option_ids = [opt["id"] for opt in next_tier_options]
        
        # Check if ALL options at next tier are built
        all_next_tier_built = all(opt_id in built_rooms for opt_id in next_tier_option_ids) if next_tier_option_ids else True
        
        if all_next_tier_built and next_tier_option_ids:
            # All options at next tier built - show tier after that
            prop_dict["available_options"] = [
                opt for opt in all_buildable_options 
                if opt["tier"] == next_tier + 1 and opt["id"] not in built_rooms
            ]
        else:
            # Show remaining options at next tier
            prop_dict["available_options"] = [
                opt for opt in next_tier_options 
                if opt["id"] not in built_rooms
            ]
        
        # Add fortification info object for easier UI consumption
        if p.tier >= 2:  # Fortification unlocked at T2
            prop_dict["fortification"] = {
                "percent": p.fortification_percent,
                "base_percent": T5_BASE_FORTIFICATION if p.tier >= 5 else 0,
                "decays_per_day": FORTIFICATION_DECAY_PER_DAY
            }
        properties_list.append(prop_dict)
    
    # Commit any lazy decay changes
    db.commit()
    
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
            
            # Get land costs from centralized config (tier 0 -> 1)
            from routers.tiers import calculate_property_gold_per_action, calculate_property_actions
            gold_per_action_for_land = calculate_property_gold_per_action(1)
            actions_for_land = calculate_upgrade_actions_required(0, state.building_skill)
            land_price = int(gold_per_action_for_land * actions_for_land)
            
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
    # NOTE: With pay-per-action system, no upfront gold required to start
    meets_reputation_requirement = current_kingdom_reputation >= 500
    can_purchase = (
        current_kingdom is not None 
        and not already_owns_property_in_current_kingdom
        and meets_reputation_requirement
        # NOTE: No upfront payment required - gold paid per action
    )
    
    # Per-action cost info already calculated above when current_kingdom was set
    # If no kingdom, set defaults
    if not current_kingdom:
        from routers.tiers import calculate_property_gold_per_action
        gold_per_action_for_land = calculate_property_gold_per_action(1)
        actions_for_land = 1
    
    # Get upgrade status for each property - FULLY DYNAMIC
    from routers.tiers import get_property_max_tier
    max_tier = get_property_max_tier()
    
    properties_upgrade_status = []
    for prop in properties:
        if prop.tier < max_tier:
            # Get dynamic resource costs (total for display)
            resource_costs = get_upgrade_resource_costs(prop.tier)
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
                "resource_costs": resource_costs,  # Dynamic list (for display)
                "actions_required": actions_required,
                "can_afford": True,  # No upfront payment - cost checked at action time
                "missing_resources": [],
                "active_contract": active_contract
            })
    
    # Get wood from inventory
    wood_inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == current_user.id,
        PlayerInventory.item_id == "wood"
    ).first()
    player_wood = wood_inv.quantity if wood_inv else 0
    
    return {
        "player_gold": int(state.gold),
        "player_wood": player_wood,
        "player_reputation": current_kingdom_reputation,
        "player_level": state.level,
        "player_building_skill": state.building_skill,
        "properties": properties_list,
        "property_upgrade_contracts": property_contracts,
        "properties_upgrade_status": properties_upgrade_status,
        "current_kingdom": current_kingdom,
        "land_price": land_price,  # Total cost (for display)
        "gold_per_action_for_land": round(gold_per_action_for_land, 1),  # NEW: per-action cost
        "actions_for_land": actions_for_land,  # NEW: number of actions needed
        "already_owns_property_in_current_kingdom": already_owns_property_in_current_kingdom,
        "meets_reputation_requirement": meets_reputation_requirement,
        "can_afford": True,  # Backwards compat: always True since no upfront payment required
        "can_purchase": can_purchase
    }


@router.post("/purchase")
def purchase_land(
    request: PurchaseLandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase land and start construction contract.
    
    NEW PAY-PER-ACTION SYSTEM:
    - No upfront gold cost
    - Gold cost is calculated and stored as gold_per_action
    - Each construction action costs gold_per_action + kingdom tax (paid at action time)
    - Tax goes to kingdom treasury, base cost is burned
    """
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
    
    if current_reputation < 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need 500+ reputation in {request.kingdom_name}. Current: {current_reputation}"
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
    
    # Validate location
    valid_locations = ["north", "south", "east", "west"]
    if request.location.lower() not in valid_locations:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid location. Choose: north, south, east, or west"
        )
    
    # Get costs from centralized config (tier 0 -> 1)
    from routers.tiers import calculate_property_gold_per_action, calculate_property_actions
    gold_per_action = calculate_property_gold_per_action(1)  # Building to tier 1
    base_actions = calculate_property_actions(1)
    actions_required = calculate_upgrade_actions_required(0, state.building_skill)
    property_id = str(uuid.uuid4())
    
    # Total gold for display
    land_price = int(gold_per_action * actions_required)
    
    # Get current tax rate for display (actual tax applied at action time)
    current_tax_rate = kingdom.tax_rate if kingdom else 0
    
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
    # NEW: gold_paid = 0 (no upfront), gold_per_action = calculated cost per action
    contract = UnifiedContract(
        user_id=current_user.id,
        kingdom_id=request.kingdom_id,
        kingdom_name=request.kingdom_name,
        category='personal_property',
        type='property',
        tier=1,  # Building to tier 1
        target_id=property_id,  # Just the property ID, no encoding needed
        actions_required=actions_required,
        gold_paid=0,  # NEW: No upfront payment
        gold_per_action=gold_per_action  # NEW: Pay per action
    )
    db.add(contract)
    
    # No gold deducted upfront
    
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
        "cost_paid": 0,  # OLD: backwards compat (no upfront payment in new system)
        "total_cost": land_price,  # Total if paid upfront (for display)
        "gold_per_action": int(gold_per_action),  # NEW: Cost per action before tax
        "current_tax_rate": current_tax_rate  # NEW: Current rate (may change)
    }


@router.post("/{property_id}/upgrade/purchase")
def start_property_upgrade(
    property_id: str,
    request: UpgradePropertyRequest = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase property upgrade contract for a specific room/option.
    
    NEW PAY-PER-ACTION SYSTEM:
    - No upfront gold cost
    - Gold cost is calculated and stored as gold_per_action
    - Each upgrade action costs gold_per_action + kingdom tax (paid at action time)
    - Tax goes to kingdom treasury, base cost is burned
    - Resources still required per action (wood, etc.)
    """
    from routers.tiers import PROPERTY_TIERS, get_property_max_tier
    
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
    
    # Get option_id from request, or default to first option at next tier (backwards compat)
    option_id = request.option_id if request and request.option_id else None
    next_tier = property.tier + 1
    
    if not option_id:
        # Default to first option at next tier
        tier_data = PROPERTY_TIERS.get(next_tier, {})
        options = tier_data.get("options", [])
        if options:
            option_id = options[0].get("id")
    
    # Find which tier this option belongs to
    option_tier = None
    option_data = None
    for t in range(1, 6):
        tier_data = PROPERTY_TIERS.get(t, {})
        for opt in tier_data.get("options", []):
            if opt.get("id") == option_id:
                option_tier = t
                option_data = opt
                break
        if option_tier:
            break
    
    if not option_tier or not option_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown option: {option_id}"
        )
    
    # Check if this option is already built (query completed contracts)
    already_built = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.target_id == property_id,
        UnifiedContract.option_id == option_id,
        UnifiedContract.completed_at.isnot(None)
    ).first()
    
    if already_built:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You've already built {option_id}"
        )
    
    # Check if player can build this option (tier requirement)
    if option_tier > property.tier + 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{option_data['name']} requires tier {option_tier}. Your property is tier {property.tier}."
        )
    
    # Check if ANY property upgrade in progress for this option
    active_contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type == 'property',
        UnifiedContract.target_id == property_id,
        UnifiedContract.option_id == option_id,
        UnifiedContract.completed_at.is_(None)
    ).first()
    
    if active_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already have a contract to build {option_data['name']}. Complete it first."
        )
    
    actions_required = calculate_upgrade_actions_required(property.tier, state.building_skill)
    
    # Get cost breakdown for this specific option
    all_costs = get_upgrade_costs_full(option_tier - 1, actions_required=actions_required, option_id=option_id)
    gold_cost = all_costs["gold_cost"]  # Total gold for display
    gold_per_action = all_costs["gold_per_action"]  # Per-action cost (before tax)
    per_action_costs = all_costs["per_action_costs"]
    
    # Get kingdom for tax rate display
    kingdom = db.query(Kingdom).filter(Kingdom.id == property.kingdom_id).first()
    current_tax_rate = kingdom.tax_rate if kingdom else 0
    
    # Create contract with option_id
    contract = UnifiedContract(
        user_id=current_user.id,
        kingdom_id=property.kingdom_id,
        kingdom_name=property.kingdom_name,
        category='personal_property',
        type='property',
        tier=option_tier,
        target_id=property_id,
        option_id=option_id,
        actions_required=actions_required,
        gold_paid=0,
        gold_per_action=gold_per_action
    )
    db.add(contract)
    
    db.commit()
    db.refresh(contract)
    
    option_name = option_data.get("name", option_id)
    
    # Build warning message about per-action costs
    per_action_warning = ""
    if per_action_costs:
        per_action_str = ", ".join([f"{c['amount']} {c['display_name']}" for c in per_action_costs])
        per_action_warning = f" Each action requires: {per_action_str}."
    
    return {
        "success": True,
        "message": f"Started building {option_name}! Complete {actions_required} actions to finish.{per_action_warning}",
        "contract_id": str(contract.id),
        "property_id": property_id,
        "from_tier": property.tier,
        "to_tier": option_tier,
        "option_id": option_id,
        "option_name": option_name,
        "gold_cost": gold_cost,
        "gold_per_action": int(gold_per_action),
        "current_tax_rate": current_tax_rate,
        "per_action_costs": per_action_costs,
        "total_costs": all_costs["total_costs"],
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
        
        # Get per-action costs for this specific option
        contract_costs = get_upgrade_costs_full(contract.tier - 1, actions_required=contract.actions_required, option_id=contract.option_id)
        
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
    else:
        gold_cost = 0
        per_action_costs = []
        total_costs = []
    
    return {
        "property_id": property_id,
        "current_tier": property.tier,
        "max_tier": max_tier,
        "can_upgrade": property.tier < max_tier,
        "gold_cost": gold_cost,
        "per_action_costs": per_action_costs,
        "total_costs": total_costs,
        "actions_required": actions_required,
        "can_afford": True,  # No upfront payment - cost checked at action time
        "player_gold": int(state.gold),
        "active_contract": active_contract_data,
        "player_building_skill": state.building_skill
    }


# ===== Fortification Endpoints =====

def get_item_display_info(item: PlayerItem) -> dict:
    """Get display info for a player item."""
    from routers.tiers import EQUIPMENT_TIERS
    from routers.workshop import CRAFTABLE_ITEMS
    
    # Try to get display info from CRAFTABLE_ITEMS config
    item_info = CRAFTABLE_ITEMS.get(item.item_id, {}) if item.item_id else {}
    tier_info = EQUIPMENT_TIERS.get(item.tier, {})
    
    display_name = item_info.get("display_name", f"T{item.tier} {item.type.capitalize()}")
    icon = item_info.get("icon", "questionmark.circle")
    
    # Add tier name prefix if not already in display name
    tier_name = tier_info.get("name", f"T{item.tier}")
    if tier_name.lower() not in display_name.lower():
        display_name = f"{display_name}"
    
    return {
        "display_name": display_name,
        "icon": icon,
        "tier_name": tier_name
    }


def get_fortification_explanation(tier: int) -> dict:
    """Get fortification explanation content.
    Centralized here so we can update it without app releases.
    """
    return {
        "title": "Fortification",
        # UI strings + icons (so the frontend doesn't hardcode copy)
        "ui": {
            # Card titles / labels
            "convert_card_title": "Convert Equipment",
            "convert_card_icon": "arrow.triangle.2.circlepath",
            "convert_card_accent_color": "buttondanger",
            # States
            "loading_eligible_items": "Loading eligible items…",
            "locked_message": "Fortification is locked. Upgrade this property to a House (Tier 2) to unlock it.",
            "empty_title": "No eligible equipment to convert right now.",
            "empty_message": "You can only convert unequipped weapons or armor, and you can’t convert your last of each type.",
            "choose_item_message": "Choose an item to convert into fortification.",
            # Inventory labels
            "weapons_label": "Weapons",
            "armor_label": "Armor",
            # Actions (use non-violent language)
            "primary_action_label": "Convert",
            "confirmation_title": "Convert Equipment",
            "confirmation_confirm_label": "Convert",
            "confirmation_cancel_label": "Cancel",
            "confirmation_message_template": "Convert {item_name} into fortification?\n\nThis will consume the item and add {gain_range} fortification.",
            "result_title": "Fortification Increased!",
            "result_ok_label": "OK",
            "result_message_template": "{item_name} was converted.\n\n+{gain_percent}% fortification\n{before_percent}% → {after_percent}%",
            # Generic errors
            "generic_error_title": "Error",
            "generic_error_ok_label": "OK",
        },
        # TLDR - 3 bullet summary
        "tldr": {
            "title": "How It Works",
            "icon": "info.circle.fill",
            "points": [
                "During wartimes, unprotected properties have a chance of being destroyed.",
                "Your fortification % is the chance your property is NOT destroyed.",
                "Convert weapons and armor below to increase your %."
            ]
        },
        # Gain ranges by tier - displayed prominently
        "gain_ranges": {
            "title": "Fortification Gain by Tier",
            "icon": "arrow.up.circle.fill",
            "color": "buttonsuccess",
            "tiers": [
                {"tier": 1, "min": 3, "max": 8},
                {"tier": 2, "min": 6, "max": 12},
                {"tier": 3, "min": 10, "max": 18},
                {"tier": 4, "min": 15, "max": 25},
                {"tier": 5, "min": 20, "max": 35}
            ]
        },
        # Key info
        "decay": f"Drops {FORTIFICATION_DECAY_PER_DAY}% daily",
        "decay_icon": "clock.arrow.circlepath",
        "decay_color": "buttonwarning",
        "cap": 100,
        "rules": "Can't convert equipped items or your last weapon/armor.",
        "rules_icon": "shield.slash",
        "rules_color": "inkmedium",
        "tip": "Lower tier gear/repeat drops stay value for their fortification value.",
        "tip_icon": "lightbulb.fill",
        "tip_color": "gold",
        # T5 only
        "t5_bonus": {
            "base": T5_BASE_FORTIFICATION,
            "text": f"{T5_BASE_FORTIFICATION}% base that never drops",
            "icon": "crown.fill",
            "color": "gold",
        } if tier >= 5 else None
    }


@router.get("/{property_id}/fortify/options", response_model=FortifyOptionsResponse)
def get_fortify_options(
    property_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get list of items eligible for sacrifice to fortify property."""
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
    
    # Apply lazy decay
    apply_fortification_decay(property)
    db.commit()
    
    fortification_unlocked = property.tier >= 2
    base_fortification = T5_BASE_FORTIFICATION if property.tier >= 5 else 0
    
    # Get player's weapons and armor
    all_weapons = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.type == 'weapon'
    ).all()
    
    all_armor = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.type == 'armor'
    ).all()
    
    weapon_count = len(all_weapons)
    armor_count = len(all_armor)
    
    # Build eligible items list (stacked by item_id, type, and tier)
    eligible_items_map = {}
    
    for item in all_weapons + all_armor:
        # Skip if equipped (v1 simplification)
        if item.is_equipped:
            continue
        
        # Check "can't sacrifice last" rule
        if item.type == 'weapon' and weapon_count <= 1:
            continue
        if item.type == 'armor' and armor_count <= 1:
            continue
        
        # Grouping key
        key = (item.item_id, item.type, item.tier)
        
        if key in eligible_items_map:
            eligible_items_map[key]["count"] += 1
        else:
            # Get display info and gain range
            display_info = get_item_display_info(item)
            min_gain, max_gain = get_fortification_gain_range(item.tier)
            
            eligible_items_map[key] = {
                "id": item.id,
                "item_id": item.item_id,
                "display_name": display_info["display_name"],
                "icon": display_info["icon"],
                "type": item.type,
                "tier": item.tier,
                "gain_min": min_gain,
                "gain_max": max_gain,
                "is_equipped": item.is_equipped,
                "count": 1
            }
            
    eligible_items = [FortifyOptionItem(**val) for val in eligible_items_map.values()]
    
    # Sort by tier (higher first), then by type
    eligible_items.sort(key=lambda x: (-x.tier, x.type))
    
    return FortifyOptionsResponse(
        property_id=property_id,
        fortification_unlocked=fortification_unlocked,
        current_fortification=property.fortification_percent,
        base_fortification=base_fortification,
        eligible_items=eligible_items,
        weapon_count=weapon_count,
        armor_count=armor_count,
        explanation=get_fortification_explanation(property.tier)
    )


@router.post("/{property_id}/fortify", response_model=FortifyResponse)
def fortify_property(
    property_id: str,
    request: FortifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Convert a weapon or armor into property fortification."""
    from sqlalchemy import text
    
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
    
    # Check fortification is unlocked (T2+)
    if property.tier < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Fortification requires a House (Tier 2+). Upgrade your property first."
        )
    
    # Get the item to convert
    item = db.query(PlayerItem).filter(
        PlayerItem.id == request.player_item_id,
        PlayerItem.user_id == current_user.id
    ).first()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found or not owned by you"
        )
    
    # Validate item type
    if item.type not in ('weapon', 'armor'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only weapons and armor can be converted for fortification"
        )
    
    # Check if equipped (v1: can't convert equipped items)
    if item.is_equipped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot convert equipped items. Unequip first."
        )
    
    # Check "can't convert last" rule
    same_type_count = db.query(func.count(PlayerItem.id)).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.type == item.type
    ).scalar()
    
    if same_type_count <= 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot convert your last {item.type}. Craft another first."
        )
    
    # Apply lazy decay before calculating new value
    apply_fortification_decay(property)
    
    fortification_before = property.fortification_percent
    
    # Roll fortification gain
    gain = roll_fortification_gain(item.tier)
    
    # Apply gain (cap at 100%)
    property.fortification_percent = min(100, property.fortification_percent + gain)
    reached_max = property.fortification_percent >= 100
    
    # Update decay timestamp to now (fresh start after conversion)
    property.fortification_last_decay_at = datetime.now(timezone.utc)
    
    # Get item display info before deleting
    display_info = get_item_display_info(item)
    item_name = display_info["display_name"]
    
    # Consume the item
    db.delete(item)
    
    # =====================================================
    # UPDATE FORTIFICATION STATS FOR ACHIEVEMENTS
    # =====================================================
    db.execute(text("""
        INSERT INTO player_fortification_stats (user_id, items_sacrificed, fortification_gained, max_fortification_reached)
        VALUES (:user_id, 1, :gain, :reached_max)
        ON CONFLICT (user_id) DO UPDATE SET
            items_sacrificed = player_fortification_stats.items_sacrificed + 1,
            fortification_gained = player_fortification_stats.fortification_gained + :gain,
            max_fortification_reached = player_fortification_stats.max_fortification_reached OR :reached_max,
            updated_at = NOW()
    """), {"user_id": current_user.id, "gain": gain, "reached_max": reached_max})
    
    db.commit()
    
    return FortifyResponse(
        success=True,
        message=f"Converted {item_name} into fortification!",
        fortification_before=fortification_before,
        fortification_gain=gain,
        fortification_after=property.fortification_percent,
        item_consumed=item_name
    )
