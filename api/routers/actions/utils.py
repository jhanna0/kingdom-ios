"""
Utility functions for actions system
Uses action_cooldowns table instead of player_state columns
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
    TRAINING_COOLDOWN,
    WORK_BASE_COOLDOWN
)
from db.models.activity_log import PlayerActivityLog
from db import Kingdom, ActionCooldown


def format_datetime_iso(dt: datetime) -> str:
    """Format datetime as ISO8601 with Z suffix for UTC"""
    if dt is None:
        return None
    return dt.strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def calculate_cooldown(base_minutes: float, skill_level: int) -> float:
    """Calculate action cooldown based on skill level"""
    reduction = math.pow(0.95, skill_level - 1)
    return base_minutes * reduction


def get_cooldown(db: Session, user_id: int, action_type: str) -> Optional[ActionCooldown]:
    """Get cooldown record for a specific action"""
    return db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == action_type
    ).first()


def set_cooldown(db: Session, user_id: int, action_type: str, expires_at: datetime = None):
    """Set or update cooldown for an action"""
    cooldown = get_cooldown(db, user_id, action_type)
    
    if cooldown:
        cooldown.last_performed = datetime.utcnow()
        cooldown.expires_at = expires_at
    else:
        cooldown = ActionCooldown(
            user_id=user_id,
            action_type=action_type,
            last_performed=datetime.utcnow(),
            expires_at=expires_at
        )
        db.add(cooldown)


def check_cooldown_from_table(db: Session, user_id: int, action_type: str, cooldown_minutes: float) -> Dict:
    """Check if action is off cooldown using action_cooldowns table"""
    cooldown = get_cooldown(db, user_id, action_type)
    
    if not cooldown or not cooldown.last_performed:
        return {"ready": True, "seconds_remaining": 0}
    
    elapsed = (datetime.utcnow() - cooldown.last_performed).total_seconds()
    required = cooldown_minutes * 60
    
    if elapsed >= required:
        return {"ready": True, "seconds_remaining": 0}
    
    remaining = int(required - elapsed)
    return {"ready": False, "seconds_remaining": remaining}


def check_cooldown(last_action: datetime, cooldown_minutes: float) -> Dict:
    """Check if action is off cooldown (legacy - uses timestamp directly)"""
    if not last_action:
        return {"ready": True, "seconds_remaining": 0}
    
    elapsed = (datetime.utcnow() - last_action).total_seconds()
    required = cooldown_minutes * 60
    
    if elapsed >= required:
        return {"ready": True, "seconds_remaining": 0}
    
    remaining = int(required - elapsed)
    return {"ready": False, "seconds_remaining": remaining}


def check_global_action_cooldown_from_table(
    db: Session, 
    user_id: int,
    work_cooldown: float = WORK_BASE_COOLDOWN,
    patrol_cooldown: float = PATROL_COOLDOWN,
    farm_cooldown: float = FARM_COOLDOWN,
    sabotage_cooldown: float = SABOTAGE_COOLDOWN,
    scout_cooldown: float = SCOUT_COOLDOWN,
    training_cooldown: float = TRAINING_COOLDOWN
) -> Dict:
    """Check if ANY action is on cooldown using action_cooldowns table"""
    now = datetime.utcnow()
    
    action_cooldowns = {
        "work": work_cooldown,
        "patrol": patrol_cooldown,
        "farm": farm_cooldown,
        "sabotage": sabotage_cooldown,
        "scout": scout_cooldown,
        "training": training_cooldown,
        "crafting": work_cooldown,
        "intelligence": SCOUT_COOLDOWN,
    }
    
    # Get all cooldowns for this user
    cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id
    ).all()
    
    max_remaining = 0
    blocking_action = None
    
    for cooldown in cooldowns:
        if cooldown.action_type in action_cooldowns and cooldown.last_performed:
            cooldown_minutes = action_cooldowns[cooldown.action_type]
            elapsed = (now - cooldown.last_performed).total_seconds()
            required = cooldown_minutes * 60
            remaining = required - elapsed
            
            if remaining > max_remaining:
                max_remaining = remaining
                blocking_action = cooldown.action_type
    
    if max_remaining > 0:
        return {
            "ready": False,
            "seconds_remaining": int(max_remaining),
            "blocking_action": blocking_action
        }
    
    return {"ready": True, "seconds_remaining": 0, "blocking_action": None}


def check_global_action_cooldown(state, work_cooldown: float, patrol_cooldown: float = PATROL_COOLDOWN,
                                  farm_cooldown: float = FARM_COOLDOWN,
                                  sabotage_cooldown: float = SABOTAGE_COOLDOWN,
                                  scout_cooldown: float = SCOUT_COOLDOWN, training_cooldown: float = TRAINING_COOLDOWN) -> Dict:
    """Check if ANY action is on cooldown (legacy - uses player_state columns)"""
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
    """Log an action to the activity feed"""
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
