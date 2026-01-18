"""
Building Catchup Service
========================
Handles the catch-up system for players who join after buildings were constructed.

Players must complete catch-up work before using a building's benefits.
Formula: actions_required = CATCHUP_ACTIONS_PER_LEVEL * building_level * building_skill_reduction

Building skill reduces catch-up actions (same formula as property upgrades):
- 5% reduction per building skill level
- Maximum 50% reduction at skill level 10

EXEMPT BUILDINGS:
- townhall: Always accessible (community gathering place)
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from typing import Dict, List, Optional, Tuple
from datetime import datetime

from db import User, Kingdom, BuildingCatchup, ContractContribution, UnifiedContract


# ============================================================
# CONFIGURATION
# ============================================================

# Actions required per building level for catch-up
CATCHUP_ACTIONS_PER_LEVEL = 15

# Buildings that DON'T require catch-up (always accessible)
# All other buildings in BUILDING_TYPES require catch-up
EXEMPT_BUILDINGS = {"townhall"}


# ============================================================
# CATCHUP CHECK FUNCTIONS
# ============================================================

def calculate_catchup_actions(building_level: int, building_skill: int = 0) -> int:
    """
    Calculate how many catch-up actions are required for a building level.
    
    Building skill reduces the requirement (uses centralized reduction from tiers.py).
    
    Formula: base_actions * building_skill_reduction
    Where: base_actions = CATCHUP_ACTIONS_PER_LEVEL * building_level
    """
    from routers.tiers import get_building_action_reduction
    
    base_actions = CATCHUP_ACTIONS_PER_LEVEL * building_level
    
    # Use centralized building skill reduction
    building_reduction = get_building_action_reduction(building_skill)
    reduced_actions = int(base_actions * building_reduction)
    
    return max(1, reduced_actions)


def requires_catchup(building_type: str) -> bool:
    """Check if a building type requires catch-up (uses centralized BUILDING_TYPES)."""
    from routers.tiers import BUILDING_TYPES
    
    building_type = building_type.lower()
    
    # Exempt buildings don't need catchup
    if building_type in EXEMPT_BUILDINGS:
        return False
    
    # Only buildings defined in BUILDING_TYPES can require catchup
    return building_type in BUILDING_TYPES


def get_building_contributions(db: Session, user_id: int, kingdom_id: str, building_type: str) -> int:
    """
    Get total contributions (work actions) user has done on this building type in this kingdom.
    
    This counts ALL work actions across ALL contracts for this building type.
    """
    from sqlalchemy import func as sql_func
    
    total = db.query(sql_func.count(ContractContribution.id)).join(
        UnifiedContract,
        ContractContribution.contract_id == UnifiedContract.id
    ).filter(
        ContractContribution.user_id == user_id,
        UnifiedContract.kingdom_id == kingdom_id,
        UnifiedContract.category == 'kingdom_building',
        func.lower(UnifiedContract.type) == building_type.lower()
    ).scalar() or 0
    
    return total


def has_contributed_to_building(db: Session, user_id: int, kingdom_id: str, building_type: str) -> bool:
    """Check if user has contributed at all to this building."""
    return get_building_contributions(db, user_id, kingdom_id, building_type) > 0


def get_catchup_status(
    db: Session, 
    user_id: int, 
    kingdom_id: str, 
    building_type: str,
    building_level: int,
    building_skill: int = 0
) -> Dict:
    """
    Check if a player needs catch-up for a specific building.
    
    Progress is based on ACTUAL contributions to building contracts.
    Player works on normal building contracts to make progress.
    
    Returns dict with needs_catchup, can_use_building, actions_required/completed/remaining
    """
    building_type = building_type.lower()
    
    # Exempt buildings are always accessible
    if building_type in EXEMPT_BUILDINGS:
        return {
            "needs_catchup": False,
            "can_use_building": True,
            "actions_required": 0,
            "actions_completed": 0,
            "actions_remaining": 0,
            "reason": "Building is always accessible"
        }
    
    # Building not built yet - no catchup needed, but can't use either
    if building_level <= 0:
        return {
            "needs_catchup": False,
            "can_use_building": False,
            "actions_required": 0,
            "actions_completed": 0,
            "actions_remaining": 0,
            "reason": "Building not yet constructed"
        }
    
    # Get actual contributions from building contract work
    contributions = get_building_contributions(db, user_id, kingdom_id, building_type)
    
    # Calculate required actions (15 * level, reduced by building skill)
    actions_required = calculate_catchup_actions(building_level, building_skill)
    
    # If they've contributed enough, they can use the building
    if contributions >= actions_required:
        return {
            "needs_catchup": False,
            "can_use_building": True,
            "actions_required": actions_required,
            "actions_completed": contributions,
            "actions_remaining": 0,
            "reason": "Contributed enough to building"
        }
    
    # Needs more contributions - work on building contracts!
    return {
        "needs_catchup": True,
        "can_use_building": False,
        "actions_required": actions_required,
        "actions_completed": contributions,
        "actions_remaining": actions_required - contributions,
        "reason": f"Work on building contracts ({contributions}/{actions_required} contributions)"
    }


def get_or_create_catchup(
    db: Session,
    user_id: int,
    kingdom_id: str,
    building_type: str,
    building_level: int,
    building_skill: int = 0
) -> BuildingCatchup:
    """
    Get or create a catch-up record for a player-building combination.
    
    Args:
        building_skill: Player's building skill level (reduces actions required)
    """
    catchup = db.query(BuildingCatchup).filter(
        BuildingCatchup.user_id == user_id,
        BuildingCatchup.kingdom_id == kingdom_id,
        BuildingCatchup.building_type == building_type.lower()
    ).first()
    
    if not catchup:
        catchup = BuildingCatchup(
            user_id=user_id,
            kingdom_id=kingdom_id,
            building_type=building_type.lower(),
            actions_required=calculate_catchup_actions(building_level, building_skill),
            actions_completed=0
        )
        db.add(catchup)
        db.flush()
    
    return catchup


def perform_catchup_action(
    db: Session,
    user_id: int,
    kingdom_id: str,
    building_type: str,
    building_level: int,
    building_skill: int = 0
) -> Dict:
    """
    Perform one catch-up action for a building.
    
    Args:
        building_skill: Player's building skill level (reduces actions required)
    
    Returns:
        {
            "success": bool,
            "actions_completed": int,
            "actions_required": int,
            "actions_remaining": int,
            "is_complete": bool,
            "message": str
        }
    """
    catchup = get_or_create_catchup(db, user_id, kingdom_id, building_type, building_level, building_skill)
    
    # Already complete?
    if catchup.is_complete:
        return {
            "success": True,
            "actions_completed": catchup.actions_completed,
            "actions_required": catchup.actions_required,
            "actions_remaining": 0,
            "is_complete": True,
            "message": "Catch-up already complete! You can now use this building."
        }
    
    # Perform the action
    catchup.actions_completed += 1
    
    # Check if now complete
    if catchup.actions_completed >= catchup.actions_required:
        catchup.completed_at = datetime.utcnow()
        is_complete = True
        message = "Catch-up complete! You can now use this building."
    else:
        is_complete = False
        remaining = catchup.actions_required - catchup.actions_completed
        message = f"{remaining} more actions to complete catch-up"
    
    db.flush()
    
    return {
        "success": True,
        "actions_completed": catchup.actions_completed,
        "actions_required": catchup.actions_required,
        "actions_remaining": max(0, catchup.actions_required - catchup.actions_completed),
        "is_complete": is_complete,
        "message": message
    }


def get_all_catchup_statuses(
    db: Session,
    user_id: int,
    kingdom_id: str,
    kingdom: Kingdom,
    building_skill: int = 0
) -> Dict[str, Dict]:
    """
    Get catch-up status for ALL buildings in a kingdom.
    
    Args:
        building_skill: Player's building skill level (reduces actions required)
    
    Returns dict of building_type -> catchup status
    Used for the city info endpoint to show which buildings need catch-up.
    """
    from routers.tiers import BUILDING_TYPES
    
    statuses = {}
    
    for building_type in BUILDING_TYPES.keys():
        # Get building level from kingdom
        level_attr = f"{building_type}_level"
        building_level = getattr(kingdom, level_attr, 0) if hasattr(kingdom, level_attr) else 0
        
        status = get_catchup_status(db, user_id, kingdom_id, building_type, building_level, building_skill)
        
        # Only include buildings that exist (level > 0) or need catchup info
        if building_level > 0 or status["needs_catchup"]:
            statuses[building_type] = {
                "building_type": building_type,
                "building_level": building_level,
                "needs_catchup": status["needs_catchup"],
                "can_use": status["can_use_building"],
                "actions_required": status["actions_required"],
                "actions_completed": status["actions_completed"],
                "actions_remaining": status["actions_remaining"],
            }
    
    return statuses


def check_building_access(
    db: Session,
    user_id: int,
    kingdom_id: str,
    building_type: str,
    building_level: int,
    building_skill: int = 0
) -> Tuple[bool, str, Optional[Dict]]:
    """
    Utility function to check if a player can use a building.
    
    Args:
        building_skill: Player's building skill level (reduces actions required)
    
    Returns:
        (can_access: bool, reason: str, catchup_info: dict or None)
        
    catchup_info is populated if player needs to complete catch-up first.
    """
    status = get_catchup_status(db, user_id, kingdom_id, building_type, building_level, building_skill)
    
    if status["can_use_building"]:
        return (True, status["reason"], None)
    
    # Can't use - provide catchup info
    catchup_info = {
        "building_type": building_type,
        "building_level": building_level,
        "actions_required": status["actions_required"],
        "actions_completed": status["actions_completed"],
        "actions_remaining": status["actions_remaining"],
    }
    
    return (False, status["reason"], catchup_info)
