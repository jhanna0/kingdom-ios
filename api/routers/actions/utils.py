"""
Utility functions for actions system
"""
from datetime import datetime
from typing import Dict
import math


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

