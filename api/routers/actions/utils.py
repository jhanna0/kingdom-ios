"""
Utility functions for actions system
"""
from datetime import datetime
from typing import Dict, Optional
from sqlalchemy.orm import Session
import math
from .constants import (
    PATROL_COOLDOWN,
    FARM_COOLDOWN,
    SABOTAGE_COOLDOWN,
    SCOUT_COOLDOWN,
    TRAINING_COOLDOWN
)
from db.models.activity_log import PlayerActivityLog
from db import Kingdom


def format_datetime_iso(dt: datetime) -> str:
    """Format datetime as ISO8601 with Z suffix for UTC"""
    if dt is None:
        return None
    return dt.strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def calculate_cooldown(base_minutes: float, skill_level: int) -> float:
    """Calculate action cooldown based on skill level
    
    Args:
        base_minutes: Base cooldown in minutes (e.g., 120 for 2 hours)
        skill_level: Player's relevant skill level
    
    Returns:
        Adjusted cooldown in minutes
    """
    # Each skill level reduces cooldown by 5%
    # Formula: base * (0.95 ^ skill_level)
    # Level 1: 100%, Level 5: 77%, Level 10: 60%, Level 20: 36%
    reduction = math.pow(0.95, skill_level - 1)
    return base_minutes * reduction


def check_cooldown(last_action: datetime, cooldown_minutes: float) -> Dict:
    """Check if action is off cooldown
    
    Returns:
        Dict with 'ready' bool and 'seconds_remaining' int
    """
    if not last_action:
        return {"ready": True, "seconds_remaining": 0}
    
    elapsed = (datetime.utcnow() - last_action).total_seconds()
    required = cooldown_minutes * 60
    
    if elapsed >= required:
        return {"ready": True, "seconds_remaining": 0}
    
    remaining = int(required - elapsed)
    return {"ready": False, "seconds_remaining": remaining}


def check_global_action_cooldown(state, work_cooldown: float, patrol_cooldown: float = PATROL_COOLDOWN,
                                  farm_cooldown: float = FARM_COOLDOWN,
                                  sabotage_cooldown: float = SABOTAGE_COOLDOWN,
                                  scout_cooldown: float = SCOUT_COOLDOWN, training_cooldown: float = TRAINING_COOLDOWN) -> Dict:
    """Check if ANY action is on cooldown (global action lock)
    
    Returns:
        Dict with 'ready' bool, 'seconds_remaining' int, and 'blocking_action' str
    """
    now = datetime.utcnow()
    actions = [
        ("work", state.last_work_action, work_cooldown),
        ("patrol", state.last_patrol_action, patrol_cooldown),
        ("farm", state.last_farm_action, farm_cooldown),
        ("sabotage", state.last_sabotage_action, sabotage_cooldown),
        ("scout", state.last_scout_action, scout_cooldown),
        ("training", state.last_training_action, training_cooldown),
    ]
    
    max_remaining = 0
    blocking_action = None
    
    for action_name, last_action, cooldown_minutes in actions:
        if last_action:
            elapsed = (now - last_action).total_seconds()
            required = cooldown_minutes * 60
            remaining = required - elapsed
            
            if remaining > max_remaining:
                max_remaining = remaining
                blocking_action = action_name
    
    if max_remaining > 0:
        return {
            "ready": False,
            "seconds_remaining": int(max_remaining),
            "blocking_action": blocking_action
        }
    
    return {"ready": True, "seconds_remaining": 0, "blocking_action": None}


def log_activity(
    db: Session,
    user_id: int,
    action_type: str,
    action_category: str,
    description: str,
    kingdom_id: Optional[str] = None,
    amount: Optional[int] = None,
    details: Optional[dict] = None,
    visibility: str = "friends"
) -> PlayerActivityLog:
    """
    Log an action to the activity feed
    
    Args:
        db: Database session
        user_id: User ID performing the action
        action_type: Type of action (farm, patrol, scout, etc.)
        action_category: Category (economy, kingdom, combat, social)
        description: Human-readable description
        kingdom_id: Optional kingdom ID where action occurred
        amount: Optional quantitative value (gold earned, rep gained, etc.)
        details: Optional dict with additional context
        visibility: Who can see this activity (friends, public, private)
    
    Returns:
        The created PlayerActivityLog entry
    """
    # Get kingdom name if kingdom_id provided
    kingdom_name = None
    if kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
        kingdom_name = kingdom.name if kingdom else kingdom_id
    
    activity = PlayerActivityLog(
        user_id=user_id,
        action_type=action_type,
        action_category=action_category,
        description=description,
        kingdom_id=kingdom_id,
        kingdom_name=kingdom_name,
        amount=amount,
        details=details or {},
        visibility=visibility
    )
    db.add(activity)
    return activity

