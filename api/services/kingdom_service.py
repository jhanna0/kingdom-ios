"""
Kingdom service - centralized kingdom-related business logic
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
import math
from datetime import datetime, timedelta
from typing import Dict, List

from db import PlayerState, User
from routers.tiers import (
    BUILDING_BASE_CONSTRUCTION_COST,
    BUILDING_LEVEL_COST_EXPONENT,
    BUILDING_POPULATION_COST_DIVISOR,
)

# Building action scaling constants
BUILDING_ACTIONS_PER_CITIZEN = 13  # Actions per active citizen
BUILDING_ACTIONS_MINIMUM = 100  # Minimum actions for any building
BUILDING_LEVEL_MULTIPLIERS = {1: 1.0, 2: 1.5, 3: 2.0, 4: 2.5, 5: 3.0}  # Per-level scaling
ACTIVE_CITIZEN_DAYS = 7  # Days since last login to count as "active"


def get_active_citizens_count(db: Session, kingdom_id: str) -> int:
    """Get count of ACTIVE citizens (logged in within last 7 days) whose hometown is this kingdom."""
    cutoff = datetime.utcnow() - timedelta(days=ACTIVE_CITIZEN_DAYS)
    return db.query(PlayerState).join(
        User, PlayerState.user_id == User.id
    ).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True,
        User.last_login >= cutoff
    ).count()


def get_active_citizens_batch(db: Session, kingdom_ids: List[str]) -> Dict[str, int]:
    """Get ACTIVE citizen counts (logged in within last 7 days) for multiple kingdoms in one query"""
    if not kingdom_ids:
        return {}
    cutoff = datetime.utcnow() - timedelta(days=ACTIVE_CITIZEN_DAYS)
    counts = db.query(
        PlayerState.hometown_kingdom_id,
        func.count(PlayerState.user_id)
    ).join(
        User, PlayerState.user_id == User.id
    ).filter(
        PlayerState.hometown_kingdom_id.in_(kingdom_ids),
        PlayerState.is_alive == True,
        User.last_login >= cutoff
    ).group_by(PlayerState.hometown_kingdom_id).all()
    return {kingdom_id: count for kingdom_id, count in counts}


def calculate_construction_cost(building_level: int, population: int) -> int:
    """Calculate upfront construction cost"""
    base_cost = BUILDING_BASE_CONSTRUCTION_COST * math.pow(BUILDING_LEVEL_COST_EXPONENT, building_level - 1)
    population_multiplier = 1.0 + (population / BUILDING_POPULATION_COST_DIVISOR)
    return int(base_cost * population_multiplier)


def calculate_actions_required(building_type: str, building_level: int, active_citizens: int, farm_level: int = 0) -> int:
    """Calculate total actions required for building contracts.
    
    Formula: max(100, active_citizens × 13) × level_multiplier × farm_reduction
    
    This ensures ~13 actions per active citizen regardless of kingdom size,
    with a minimum of 100 actions for small/new kingdoms.
    
    Farm building reduces actions required (kingdom building benefit).
    """
    from routers.tiers import get_farm_action_reduction
    
    # Base actions: 13 per active citizen, minimum 100
    base_actions = max(BUILDING_ACTIONS_MINIMUM, active_citizens * BUILDING_ACTIONS_PER_CITIZEN)
    
    # Level multiplier: 1.0, 1.5, 2.0, 2.5, 3.0 for levels 1-5
    level_multiplier = BUILDING_LEVEL_MULTIPLIERS.get(building_level, 1.0)
    raw_actions = base_actions * level_multiplier
    
    # Apply farm reduction (kingdom building reduces actions)
    farm_multiplier = get_farm_action_reduction(farm_level)
    return max(BUILDING_ACTIONS_MINIMUM, int(raw_actions * farm_multiplier))
