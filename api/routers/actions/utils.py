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
    TRAINING_COOLDOWN,
    WORK_BASE_COOLDOWN
)
from db.models.activity_log import PlayerActivityLog
from db import Kingdom, ActionCooldown, PlayerItem


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
    current_action_type: str = None,
    work_cooldown: float = WORK_BASE_COOLDOWN,
    patrol_cooldown: float = PATROL_COOLDOWN,
    farm_cooldown: float = FARM_COOLDOWN,
    sabotage_cooldown: float = SABOTAGE_COOLDOWN,
    training_cooldown: float = TRAINING_COOLDOWN
) -> Dict:
    """
    Check if any action in the SAME SLOT is on cooldown.
    
    NEW: Parallel action system - actions in different slots can run simultaneously!
    - building slot: work, property_upgrade
    - economy slot: farm, chop_wood
    - security slot: patrol
    - intelligence slot: scout, sabotage, vault_heist
    - personal slot: training, crafting
    
    Args:
        current_action_type: The action being attempted (to check its slot)
    """
    # Import here to avoid circular dependency
    from .action_config import get_action_slot
    
    now = datetime.utcnow()
    
    action_cooldowns = {
        "work": work_cooldown,
        "patrol": patrol_cooldown,
        "farm": farm_cooldown,
        "sabotage": sabotage_cooldown,
        "training": training_cooldown,
        "crafting": work_cooldown,
        "intelligence": 24 * 60,  # 24 hours for intelligence gathering
        "chop_wood": farm_cooldown,
        "property_upgrade": work_cooldown,
        "vault_heist": 168 * 60,  # 7 days for vault heist
    }
    
    # Get the slot for the action being attempted
    current_slot = get_action_slot(current_action_type) if current_action_type else None
    
    # Get all cooldowns for this user
    cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id
    ).all()
    
    max_remaining = 0
    blocking_action = None
    
    for cooldown in cooldowns:
        if cooldown.action_type in action_cooldowns and cooldown.last_performed:
            # PARALLEL ACTION SYSTEM: Only check actions in the SAME slot
            action_slot = get_action_slot(cooldown.action_type)
            
            # Skip actions in different slots (they can run in parallel!)
            if current_slot and action_slot != current_slot:
                continue
            
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
            "blocking_action": blocking_action,
            "blocking_slot": get_action_slot(blocking_action) if blocking_action else None
        }
    
    return {"ready": True, "seconds_remaining": 0, "blocking_action": None, "blocking_slot": None}


def check_global_action_cooldown(state, work_cooldown: float, patrol_cooldown: float = PATROL_COOLDOWN,
                                  farm_cooldown: float = FARM_COOLDOWN,
                                  sabotage_cooldown: float = SABOTAGE_COOLDOWN,
                                  training_cooldown: float = TRAINING_COOLDOWN) -> Dict:
    """Check if ANY action is on cooldown (legacy - uses player_state columns)"""
    now = datetime.utcnow()
    actions = [
        ("work", state.last_work_action, work_cooldown),
        ("patrol", state.last_patrol_action, patrol_cooldown),
        ("farm", state.last_farm_action, farm_cooldown),
        ("sabotage", state.last_sabotage_action, sabotage_cooldown),
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


def get_equipped_items(db: Session, user_id: int) -> Dict:
    """Get all equipped items for a user from player_items table"""
    equipped = db.query(PlayerItem).filter(
        PlayerItem.user_id == user_id,
        PlayerItem.is_equipped == True
    ).all()
    
    result = {
        "equipped_weapon": None,
        "equipped_armor": None,
        "equipped_shield": None,
    }
    
    for item in equipped:
        if item.type == "weapon":
            result["equipped_weapon"] = {
                "tier": item.tier,
                "attackBonus": item.attack_bonus
            }
        elif item.type == "armor":
            result["equipped_armor"] = {
                "tier": item.tier,
                "defenseBonus": item.defense_bonus
            }
        elif item.type == "shield":
            result["equipped_shield"] = {
                "tier": item.tier,
                "defenseBonus": item.defense_bonus
            }
    
    return result


def get_inventory(db: Session, user_id: int) -> list:
    """Get all inventory items (non-equipped) for a user from player_items table"""
    items = db.query(PlayerItem).filter(
        PlayerItem.user_id == user_id,
        PlayerItem.is_equipped == False
    ).all()
    
    inventory = []
    for item in items:
        inventory.append({
            "type": item.type,
            "tier": item.tier,
            "attackBonus": item.attack_bonus,
            "defenseBonus": item.defense_bonus
        })
    
    return inventory


def is_patrolling(db: Session, user_id: int) -> bool:
    """Check if a user is currently on patrol"""
    cooldown = get_cooldown(db, user_id, "patrol")
    if not cooldown or not cooldown.expires_at:
        return False
    return cooldown.expires_at > datetime.utcnow()


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
