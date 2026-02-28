"""
Kingdom service - centralized kingdom-related business logic
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
import math
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

from db import PlayerState, User, Kingdom
from db.models.kingdom_history import KingdomHistory
from db.models.kingdom_event import KingdomEvent
from routers.tiers import (
    BUILDING_BASE_CONSTRUCTION_COST,
    BUILDING_LEVEL_COST_EXPONENT,
    BUILDING_POPULATION_COST_DIVISOR,
)

# Building action scaling constants
BUILDING_ACTIONS_PER_CITIZEN = 15  # Actions per active citizen
BUILDING_ACTIONS_MINIMUM = 75  # Minimum actions for any building
BUILDING_LEVEL_MULTIPLIERS = {1: 1.0, 2: 1.3, 3: 1.6, 4: 1.9, 5: 2.2}  # Per-level scaling
ACTIVE_CITIZEN_DAYS = 7  # Days since last login to count as "active"

# Ruler abandonment threshold
RULER_ABANDONMENT_DAYS = 60  # Days without login before ruler abandons their reign


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


def get_active_project_kingdoms(db: Session, kingdom_ids: List[str]) -> set:
    """Get set of kingdom IDs that have an active building contract"""
    if not kingdom_ids:
        return set()
    from db.models import UnifiedContract
    active_contracts = db.query(UnifiedContract.kingdom_id).filter(
        UnifiedContract.kingdom_id.in_(kingdom_ids),
        UnifiedContract.category == 'kingdom_building',
        UnifiedContract.completed_at.is_(None)
    ).all()
    return {c.kingdom_id for c in active_contracts}


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
    # Note: farm reduction can bring actions below the minimum - that's the benefit of having a farm
    farm_multiplier = get_farm_action_reduction(farm_level)
    return int(raw_actions * farm_multiplier)


def check_ruler_abandonment(db: Session, kingdom: Kingdom) -> Optional[Tuple[int, str]]:
    """
    Check if a kingdom's ruler has abandoned their reign (no login in 60+ days).
    
    If abandoned:
    - Sets kingdom.ruler_id to None
    - Closes the KingdomHistory entry with event_type 'abandoned'
    - Creates a KingdomEvent notification for citizens
    - Commits the changes
    
    Returns:
        Tuple of (old_ruler_id, old_ruler_name) if abandonment occurred, None otherwise
    """
    if not kingdom.ruler_id:
        return None
    
    # Get the ruler
    ruler = db.query(User).filter(User.id == kingdom.ruler_id).first()
    if not ruler:
        return None
    
    # Check if ruler has been inactive for 60+ days
    if not ruler.last_login:
        # No login recorded - treat as abandoned if kingdom is old enough
        if kingdom.ruler_started_at:
            days_since_start = (datetime.utcnow() - kingdom.ruler_started_at).days
            if days_since_start < RULER_ABANDONMENT_DAYS:
                return None
        else:
            return None
    else:
        days_since_login = (datetime.utcnow() - ruler.last_login).days
        if days_since_login < RULER_ABANDONMENT_DAYS:
            return None
    
    # Ruler has abandoned their reign
    now = datetime.utcnow()
    old_ruler_id = kingdom.ruler_id
    old_ruler_name = ruler.display_name
    
    # Close the current KingdomHistory entry
    # Query matches: kingdom_id + ruler_id + ended_at is NULL (current reign)
    current_history = db.query(KingdomHistory).filter(
        KingdomHistory.kingdom_id == kingdom.id,
        KingdomHistory.ruler_id == old_ruler_id,
        KingdomHistory.ended_at.is_(None)
    ).first()
    if current_history:
        current_history.ended_at = now
    
    # Clear the ruler from the kingdom
    kingdom.ruler_id = None
    kingdom.ruler_started_at = None
    kingdom.last_activity = now
    
    # Create a kingdom event with special title for abandonment notifications
    # The notification system will detect "Ruler Abandoned" prefix for special styling
    event = KingdomEvent(
        kingdom_id=kingdom.id,
        title="Ruler Abandoned Throne",
        description=f"{old_ruler_name} has abandoned their reign after 60 days of absence. The throne is now vacant and can be claimed by a citizen."
    )
    db.add(event)
    
    db.commit()
    
    return (old_ruler_id, old_ruler_name)


def check_ruler_abandonment_batch(db: Session, kingdoms: List[Kingdom]) -> Dict[str, Tuple[int, str]]:
    """
    Check multiple kingdoms for ruler abandonment in a batch-optimized way.
    
    Returns:
        Dict mapping kingdom_id -> (old_ruler_id, old_ruler_name) for kingdoms where abandonment occurred
    """
    if not kingdoms:
        return {}
    
    # Filter to kingdoms with rulers
    kingdoms_with_rulers = [k for k in kingdoms if k.ruler_id]
    if not kingdoms_with_rulers:
        return {}
    
    # Batch fetch all rulers
    ruler_ids = [k.ruler_id for k in kingdoms_with_rulers]
    rulers = db.query(User).filter(User.id.in_(ruler_ids)).all()
    rulers_by_id = {u.id: u for u in rulers}
    
    # Check each kingdom
    now = datetime.utcnow()
    cutoff = now - timedelta(days=RULER_ABANDONMENT_DAYS)
    abandonments = {}
    
    for kingdom in kingdoms_with_rulers:
        ruler = rulers_by_id.get(kingdom.ruler_id)
        if not ruler:
            continue
        
        # Check if ruler is inactive
        is_abandoned = False
        if not ruler.last_login:
            # No login recorded - check if kingdom is old enough
            if kingdom.ruler_started_at and kingdom.ruler_started_at < cutoff:
                is_abandoned = True
        elif ruler.last_login < cutoff:
            is_abandoned = True
        
        if not is_abandoned:
            continue
        
        # Process abandonment
        old_ruler_id = kingdom.ruler_id
        old_ruler_name = ruler.display_name
        
        # Close the current KingdomHistory entry
        current_history = db.query(KingdomHistory).filter(
            KingdomHistory.kingdom_id == kingdom.id,
            KingdomHistory.ruler_id == old_ruler_id,
            KingdomHistory.ended_at.is_(None)
            ).first()
        if current_history:
            current_history.ended_at = now
        
        # Clear the ruler from the kingdom
        kingdom.ruler_id = None
        kingdom.ruler_started_at = None
        kingdom.last_activity = now
        
        # Create a kingdom event
        event = KingdomEvent(
            kingdom_id=kingdom.id,
            title="Ruler Abandoned Throne",
            description=f"{old_ruler_name} has abandoned their reign after 60 days of absence. The throne is now vacant and can be claimed by a citizen."
        )
        db.add(event)
        
        abandonments[kingdom.id] = (old_ruler_id, old_ruler_name)
    
    if abandonments:
        db.commit()
    
    return abandonments
