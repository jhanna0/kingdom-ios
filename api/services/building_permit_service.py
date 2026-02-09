"""
Building Permit Service
=======================
Handles building access checks and permit management for visiting players.

RULES:
1. Hometown: Always have access (subject to catchup if joined late)
2. Same empire / Allied: Free access, no permit needed
3. Visitor (not allied): Must buy permit (10g for 10 minutes)

RESTRICTIONS (cannot buy/use permit if):
- Hometown doesn't have that building type (can't bypass progression)
- Active catchup contract for that building (must complete expansion first)

BUILDINGS REQUIRING PERMITS:
- lumbermill, mine, market, townhall (the "clickable" buildings)
- wall, vault, farm, education are passive benefits, no permit needed
"""
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple
from sqlalchemy.orm import Session

from db import Kingdom, BuildingCatchup, BuildingPermit, User, PlayerState
from routers.alliances import are_empires_allied
from services.catchup_service import EXEMPT_BUILDINGS


# Configuration
PERMIT_COST_GOLD = 10
PERMIT_DURATION_MINUTES = 10

# Buildings that require permits for visitors
# These are the "clickable" buildings with active functionality
PERMIT_REQUIRED_BUILDINGS = {"lumbermill", "mine", "market", "townhall"}


def get_kingdom_empire_id(kingdom: Kingdom) -> str:
    """Get the empire ID for a kingdom (uses kingdom.id if no empire_id set)"""
    return kingdom.empire_id or kingdom.id


def get_hometown_building_level(db: Session, state: PlayerState, building_type: str) -> int:
    """Get the level of a building in the player's hometown"""
    if not state or not state.hometown_kingdom_id:
        return 0
    
    hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if not hometown:
        return 0
    
    level_attr = f"{building_type}_level"
    return getattr(hometown, level_attr, 0) or 0


def has_active_catchup(db: Session, user_id: int, kingdom_id: str, building_type: str) -> bool:
    """Check if user has an incomplete catchup contract for this building in their hometown"""
    catchup = db.query(BuildingCatchup).filter(
        BuildingCatchup.user_id == user_id,
        BuildingCatchup.kingdom_id == kingdom_id,
        BuildingCatchup.building_type == building_type.lower(),
        BuildingCatchup.completed_at.is_(None)
    ).first()
    
    if not catchup:
        return False
    
    # Check if actually incomplete
    return catchup.actions_completed < catchup.actions_required


def get_valid_permit(db: Session, user_id: int, kingdom_id: str, building_type: str) -> Optional[BuildingPermit]:
    """Get a valid (non-expired) permit if one exists"""
    permit = db.query(BuildingPermit).filter(
        BuildingPermit.user_id == user_id,
        BuildingPermit.kingdom_id == kingdom_id,
        BuildingPermit.building_type == building_type.lower(),
        BuildingPermit.expires_at > datetime.utcnow()
    ).first()
    return permit


def check_building_access(
    db: Session,
    user: User,
    state: PlayerState,
    current_kingdom: Kingdom,
    building_type: str
) -> Dict:
    """
    Master helper function to check if a player can access a building.
    
    Returns a dict with all the information needed for UI and access control:
    {
        "can_access": bool,           # Final verdict - can they use this building?
        "reason": str,                # Human-readable explanation
        "is_hometown": bool,          # Is this their hometown?
        "is_allied": bool,            # Are they allied/same empire?
        "needs_permit": bool,         # Do they need to buy a permit?
        "has_valid_permit": bool,     # Do they have an active permit?
        "permit_expires_at": datetime or None,
        "permit_minutes_remaining": int,
        
        # Blockers (why they CAN'T get a permit)
        "hometown_has_building": bool,    # Does their hometown have this building?
        "hometown_building_level": int,   # Level of building in hometown
        "has_active_catchup": bool,       # Do they have incomplete expansion?
        "catchup_actions_remaining": int, # How many actions left on catchup
        
        # For permit purchase
        "can_buy_permit": bool,       # Are they eligible to buy a permit?
        "permit_cost": int,           # Cost in gold
        "permit_duration_minutes": int,
    }
    """
    building_type = building_type.lower()
    result = {
        "can_access": False,
        "reason": "",
        "is_hometown": False,
        "is_allied": False,
        "needs_permit": False,
        "has_valid_permit": False,
        "permit_expires_at": None,
        "permit_minutes_remaining": 0,
        "hometown_has_building": False,
        "hometown_building_level": 0,
        "has_active_catchup": False,
        "catchup_actions_remaining": 0,
        "can_buy_permit": False,
        "permit_cost": PERMIT_COST_GOLD,
        "permit_duration_minutes": PERMIT_DURATION_MINUTES,
    }
    
    # Check if this building type requires permits at all
    if building_type not in PERMIT_REQUIRED_BUILDINGS:
        result["can_access"] = True
        result["reason"] = "This building doesn't require a permit"
        return result
    
    # Get hometown info
    hometown_level = get_hometown_building_level(db, state, building_type)
    result["hometown_building_level"] = hometown_level
    result["hometown_has_building"] = hometown_level > 0
    
    # Check if this is their hometown
    is_hometown = state and state.hometown_kingdom_id == current_kingdom.id
    result["is_hometown"] = is_hometown
    
    if is_hometown:
        # Hometown access - subject to catchup if building exists
        if hometown_level <= 0:
            result["can_access"] = False
            result["reason"] = f"Your hometown hasn't built a {building_type} yet"
            return result
        
        # Check catchup for hometown
        if building_type not in EXEMPT_BUILDINGS:
            if has_active_catchup(db, user.id, current_kingdom.id, building_type):
                catchup = db.query(BuildingCatchup).filter(
                    BuildingCatchup.user_id == user.id,
                    BuildingCatchup.kingdom_id == current_kingdom.id,
                    BuildingCatchup.building_type == building_type.lower()
                ).first()
                result["has_active_catchup"] = True
                result["catchup_actions_remaining"] = catchup.actions_remaining if catchup else 0
                result["can_access"] = False
                result["reason"] = "Complete expansion work first"
                return result
        
        result["can_access"] = True
        result["reason"] = "This is your hometown"
        return result
    
    # Not hometown - check alliance status
    if state and state.hometown_kingdom_id:
        hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
        if hometown:
            hometown_empire_id = get_kingdom_empire_id(hometown)
            current_empire_id = get_kingdom_empire_id(current_kingdom)
            is_allied = are_empires_allied(db, hometown_empire_id, current_empire_id)
            result["is_allied"] = is_allied
    
    # BLOCKER CHECK 1: Hometown must have this building
    if not result["hometown_has_building"]:
        result["can_access"] = False
        result["needs_permit"] = False
        result["can_buy_permit"] = False
        result["reason"] = f"Your hometown needs a {building_type} first"
        return result
    
    # BLOCKER CHECK 2: Cannot have active catchup in hometown
    if state and state.hometown_kingdom_id:
        if has_active_catchup(db, user.id, state.hometown_kingdom_id, building_type):
            catchup = db.query(BuildingCatchup).filter(
                BuildingCatchup.user_id == user.id,
                BuildingCatchup.kingdom_id == state.hometown_kingdom_id,
                BuildingCatchup.building_type == building_type.lower()
            ).first()
            result["has_active_catchup"] = True
            result["catchup_actions_remaining"] = catchup.actions_remaining if catchup else 0
            result["can_access"] = False
            result["needs_permit"] = False
            result["can_buy_permit"] = False
            result["reason"] = "Complete expansion in your hometown first"
            return result
    
    # Allied/same empire = free access
    if result["is_allied"]:
        result["can_access"] = True
        result["needs_permit"] = False
        result["reason"] = "Free access (allied/same empire)"
        return result
    
    # Not allied - need permit
    result["needs_permit"] = True
    
    # Check for existing valid permit
    permit = get_valid_permit(db, user.id, current_kingdom.id, building_type)
    if permit:
        result["has_valid_permit"] = True
        result["permit_expires_at"] = permit.expires_at
        result["permit_minutes_remaining"] = permit.minutes_remaining
        result["can_access"] = True
        result["reason"] = f"Permit valid for {permit.minutes_remaining}m"
        return result
    
    # No permit - can they buy one?
    result["can_buy_permit"] = True
    result["can_access"] = False
    result["reason"] = f"Permit required ({PERMIT_COST_GOLD}g for {PERMIT_DURATION_MINUTES}m)"
    
    return result


def buy_permit(
    db: Session,
    user: User,
    state: PlayerState,
    kingdom: Kingdom,
    building_type: str
) -> Tuple[bool, str, Optional[BuildingPermit]]:
    """
    Purchase a building permit.
    
    Returns: (success, message, permit_or_none)
    """
    building_type = building_type.lower()
    
    # Run access check first
    access = check_building_access(db, user, state, kingdom, building_type)
    
    # Already have access?
    if access["can_access"]:
        if access["is_hometown"]:
            return False, "This is your hometown - no permit needed", None
        if access["is_allied"]:
            return False, "You're allied - no permit needed", None
        if access["has_valid_permit"]:
            return False, f"You already have a valid permit ({access['permit_minutes_remaining']}m remaining)", None
    
    # Check blockers
    if not access["hometown_has_building"]:
        return False, f"Your hometown needs a {building_type} first", None
    
    if access["has_active_catchup"]:
        return False, "Complete expansion in your hometown first", None
    
    if not access["can_buy_permit"]:
        return False, access["reason"], None
    
    # Check gold
    if state.gold < PERMIT_COST_GOLD:
        return False, f"Not enough gold (need {PERMIT_COST_GOLD}g, have {int(state.gold)}g)", None
    
    # Deduct gold from player
    state.gold -= PERMIT_COST_GOLD
    
    # Add gold to kingdom treasury
    kingdom.treasury_gold = (kingdom.treasury_gold or 0) + PERMIT_COST_GOLD
    
    # Create or update permit
    expires_at = datetime.utcnow() + timedelta(minutes=PERMIT_DURATION_MINUTES)
    
    # Check for existing expired permit to update
    existing = db.query(BuildingPermit).filter(
        BuildingPermit.user_id == user.id,
        BuildingPermit.kingdom_id == kingdom.id,
        BuildingPermit.building_type == building_type
    ).first()
    
    if existing:
        existing.expires_at = expires_at
        existing.purchased_at = datetime.utcnow()
        existing.gold_paid = PERMIT_COST_GOLD
        permit = existing
    else:
        permit = BuildingPermit(
            user_id=user.id,
            kingdom_id=kingdom.id,
            building_type=building_type,
            expires_at=expires_at,
            gold_paid=PERMIT_COST_GOLD
        )
        db.add(permit)
    
    db.flush()
    
    return True, f"Permit purchased! Valid for {PERMIT_DURATION_MINUTES} minutes", permit


def get_all_building_access(
    db: Session,
    user: User,
    state: PlayerState,
    kingdom: Kingdom
) -> Dict[str, Dict]:
    """
    Get access status for ALL permit-required buildings in a kingdom.
    Used by city_service to populate building metadata.
    
    Returns: {building_type: access_dict, ...}
    """
    result = {}
    for building_type in PERMIT_REQUIRED_BUILDINGS:
        result[building_type] = check_building_access(db, user, state, kingdom, building_type)
    return result
