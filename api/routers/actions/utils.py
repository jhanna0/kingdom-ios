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
    """Format datetime as ISO8601 with Z suffix for iOS compatibility.
    
    - Strips microseconds (Swift's default ISO8601 parser can't handle them)
    - Always appends 'Z' for UTC datetimes
    - Handles both naive datetimes (assumes UTC) and timezone-aware datetimes
    """
    if dt is None:
        return None
    # Strip microseconds - Swift's .iso8601 decoder can't parse them
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    # Handle timezone-aware datetimes with +00:00
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    # Handle naive datetimes - assume UTC and add Z
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        return iso_str + 'Z'
    return iso_str


def calculate_cooldown(base_minutes: float, skill_level: int) -> float:
    """Calculate action cooldown based on skill level.
    
    Each level of building skill reduces cooldown by 5% (compounding).
    Level 1: 5% reduction, Level 2: ~10%, Level 3: ~14%, etc.
    """
    reduction = math.pow(0.95, skill_level)
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


def check_and_set_cooldown_atomic(
    db: Session, 
    user_id: int, 
    action_type: str, 
    cooldown_minutes: float,
    expires_at: datetime = None
) -> Dict:
    """
    ATOMIC cooldown check and set - prevents race conditions in serverless.
    
    Uses SELECT FOR UPDATE to lock the row, then checks + updates in one transaction.
    This prevents the TOCTOU race where multiple Lambda instances could all pass
    the cooldown check before any of them set the new cooldown.
    
    Returns:
        {"ready": True} if action can proceed (cooldown has been set)
        {"ready": False, "seconds_remaining": N, "blocking_action": str} if on cooldown
    """
    from sqlalchemy import text
    
    now = datetime.utcnow()
    required_seconds = cooldown_minutes * 60
    
    # Lock the row with FOR UPDATE (or create if doesn't exist)
    cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == action_type
    ).with_for_update().first()
    
    if cooldown and cooldown.last_performed:
        elapsed = (now - cooldown.last_performed).total_seconds()
        
        if elapsed < required_seconds:
            # Still on cooldown - return without modifying
            remaining = int(required_seconds - elapsed)
            return {
                "ready": False, 
                "seconds_remaining": remaining,
                "blocking_action": action_type
            }
        
        # Cooldown expired - update it atomically (we hold the lock)
        cooldown.last_performed = now
        cooldown.expires_at = expires_at
    else:
        # No cooldown record exists - create one
        if cooldown:
            # Row exists but no last_performed
            cooldown.last_performed = now
            cooldown.expires_at = expires_at
        else:
            cooldown = ActionCooldown(
                user_id=user_id,
                action_type=action_type,
                last_performed=now,
                expires_at=expires_at
            )
            db.add(cooldown)
    
    # Flush to ensure the lock is held until commit
    db.flush()
    
    return {"ready": True, "seconds_remaining": 0, "blocking_action": None}


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


def check_and_set_slot_cooldown_atomic(
    db: Session, 
    user_id: int,
    action_type: str,
    cooldown_minutes: float,
    expires_at: datetime = None,
    work_cooldown: float = WORK_BASE_COOLDOWN,
    patrol_cooldown: float = PATROL_COOLDOWN,
    farm_cooldown: float = FARM_COOLDOWN,
    sabotage_cooldown: float = SABOTAGE_COOLDOWN,
    training_cooldown: float = TRAINING_COOLDOWN
) -> Dict:
    """
    ATOMIC slot-based cooldown check and set - prevents race conditions in serverless.
    
    Uses SELECT FOR UPDATE to lock all rows in the same slot, checks if any are on cooldown,
    and if not, sets the cooldown for the current action atomically.
    
    This prevents TOCTOU races where multiple Lambda instances could all pass the cooldown 
    check before any of them set the new cooldown.
    
    Returns:
        {"ready": True} if action can proceed (cooldown has been set)
        {"ready": False, "seconds_remaining": N, "blocking_action": str} if on cooldown
    """
    from .action_config import get_action_slot, ACTION_SLOTS
    
    now = datetime.utcnow()
    
    action_cooldowns = {
        "work": work_cooldown,
        "patrol": patrol_cooldown,
        "farm": farm_cooldown,
        "sabotage": sabotage_cooldown,
        "training": training_cooldown,
        "crafting": work_cooldown,
        "intelligence": 24 * 60,
        "chop_wood": farm_cooldown,
        "property_upgrade": work_cooldown,
        "vault_heist": 168 * 60,
    }
    
    # Get the slot for this action
    current_slot = get_action_slot(action_type)
    
    # Find all action types in the same slot
    actions_in_slot = [a for a, s in ACTION_SLOTS.items() if s == current_slot]
    
    # Lock ALL rows for this user in this slot with FOR UPDATE
    # This prevents any other request from reading these rows until we commit
    cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type.in_(actions_in_slot)
    ).with_for_update().all()
    
    # Check if any action in the slot is still on cooldown
    max_remaining = 0
    blocking_action = None
    
    for cooldown in cooldowns:
        if cooldown.action_type in action_cooldowns and cooldown.last_performed:
            cooldown_mins = action_cooldowns[cooldown.action_type]
            elapsed = (now - cooldown.last_performed).total_seconds()
            required = cooldown_mins * 60
            remaining = required - elapsed
            
            if remaining > max_remaining:
                max_remaining = remaining
                blocking_action = cooldown.action_type
    
    if max_remaining > 0:
        # Still on cooldown - return without modifying (lock will release on commit/rollback)
        return {
            "ready": False,
            "seconds_remaining": int(max_remaining),
            "blocking_action": blocking_action,
            "blocking_slot": current_slot
        }
    
    # Not on cooldown - set the cooldown for this action atomically
    existing = next((c for c in cooldowns if c.action_type == action_type), None)
    
    if existing:
        existing.last_performed = now
        existing.expires_at = expires_at
    else:
        new_cooldown = ActionCooldown(
            user_id=user_id,
            action_type=action_type,
            last_performed=now,
            expires_at=expires_at
        )
        db.add(new_cooldown)
    
    # Flush to ensure the update is visible within this transaction
    db.flush()
    
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
