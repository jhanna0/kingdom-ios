"""
Kingdom service - centralized kingdom-related business logic
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
import math
from typing import Dict, List

from db import PlayerState
from routers.tiers import (
    BUILDING_BASE_CONSTRUCTION_COST,
    BUILDING_LEVEL_COST_EXPONENT,
    BUILDING_POPULATION_COST_DIVISOR,
    BUILDING_BASE_ACTIONS_REQUIRED,
    BUILDING_LEVEL_ACTIONS_EXPONENT,
    BUILDING_POPULATION_ACTIONS_DIVISOR,
)


def get_active_citizens_count(db: Session, kingdom_id: str) -> int:
    """Get live count of active citizens (players whose hometown is this kingdom)"""
    return db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).count()


def get_active_citizens_batch(db: Session, kingdom_ids: List[str]) -> Dict[str, int]:
    """Get active citizen counts for multiple kingdoms in one query"""
    if not kingdom_ids:
        return {}
    counts = db.query(
        PlayerState.hometown_kingdom_id,
        func.count(PlayerState.user_id)
    ).filter(
        PlayerState.hometown_kingdom_id.in_(kingdom_ids),
        PlayerState.is_alive == True
    ).group_by(PlayerState.hometown_kingdom_id).all()
    return {kingdom_id: count for kingdom_id, count in counts}


def calculate_construction_cost(building_level: int, population: int) -> int:
    """Calculate upfront construction cost"""
    base_cost = BUILDING_BASE_CONSTRUCTION_COST * math.pow(BUILDING_LEVEL_COST_EXPONENT, building_level - 1)
    population_multiplier = 1.0 + (population / BUILDING_POPULATION_COST_DIVISOR)
    return int(base_cost * population_multiplier)


def calculate_actions_required(building_type: str, building_level: int, population: int, farm_level: int = 0) -> int:
    """Calculate total actions required for building contracts.
    
    Farm building reduces actions required (kingdom building benefit).
    Values come from tiers.py BUILDING_TYPES["farm"]["tiers"][level]["reduction"]
    """
    from routers.tiers import get_farm_action_reduction
    
    base_actions = BUILDING_BASE_ACTIONS_REQUIRED * math.pow(BUILDING_LEVEL_ACTIONS_EXPONENT, building_level - 1)
    population_multiplier = 1.0 + (population / BUILDING_POPULATION_ACTIONS_DIVISOR)
    raw_actions = base_actions * population_multiplier
    
    # Apply farm reduction (kingdom building reduces actions)
    farm_multiplier = get_farm_action_reduction(farm_level)
    return max(5, int(raw_actions * farm_multiplier))
