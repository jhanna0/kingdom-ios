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
    """Calculate BUILDING action cooldown based on building skill level.
    
    Building skill reduces building cooldowns (personal skill).
    Values are centralized in tiers.py SKILLS["building"]["mechanics"]["cooldown_reduction"]
    """
    from routers.tiers import get_building_cooldown_reduction
    multiplier = get_building_cooldown_reduction(skill_level)
    return base_minutes * multiplier


def calculate_training_cooldown(base_minutes: float, science_level: int) -> float:
    """Calculate TRAINING action cooldown based on science skill level.
    
    Science skill reduces training cooldowns (personal skill).
    Values are centralized in tiers.py SKILLS["science"]["mechanics"]["cooldown_reduction"]
    """
    from routers.tiers import get_science_cooldown_reduction
    multiplier = get_science_cooldown_reduction(science_level)
    return base_minutes * multiplier


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
    current_action_type: str,
    cooldown_minutes: float
) -> Dict:
    """
    Check if any action in the SAME SLOT is on cooldown.
    
    Parallel action system - actions in different slots can run simultaneously!
    - building slot: work, property_upgrade
    - economy slot: farm
    - security slot: patrol
    - intelligence slot: scout
    - personal slot: training, crafting
    
    IMPORTANT: The caller must pass the skill-adjusted cooldown_minutes
    (use calculate_cooldown() before calling). This same value is used for
    all actions in the slot since they share the cooldown.
    """
    from .action_config import get_action_slot
    
    now = datetime.utcnow()
    
    # Get the slot for the action being attempted
    current_slot = get_action_slot(current_action_type)
    
    # Get all cooldowns for this user
    cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id
    ).all()
    
    max_remaining = 0
    blocking_action = None
    required_seconds = cooldown_minutes * 60
    
    for cooldown in cooldowns:
        if cooldown.last_performed:
            # PARALLEL ACTION SYSTEM: Only check actions in the SAME slot
            action_slot = get_action_slot(cooldown.action_type)
            
            # Skip actions in different slots (they can run in parallel!)
            if action_slot != current_slot:
                continue
            
            # Use the passed cooldown_minutes (already skill-adjusted by caller)
            elapsed = (now - cooldown.last_performed).total_seconds()
            remaining = required_seconds - elapsed
            
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
    expires_at: datetime = None
) -> Dict:
    """
    ATOMIC slot-based cooldown check and set - prevents race conditions in serverless.
    
    Uses SELECT FOR UPDATE to lock all rows in the same slot, checks if any are on cooldown,
    and if not, sets the cooldown for the current action atomically.
    
    This prevents TOCTOU races where multiple Lambda instances could all pass the cooldown 
    check before any of them set the new cooldown.
    
    IMPORTANT: The caller must pass the skill-adjusted cooldown_minutes 
    (use calculate_cooldown() before calling this function).
    This same value is used for BOTH checking and setting - no desync!
    
    Returns:
        {"ready": True} if action can proceed (cooldown has been set)
        {"ready": False, "seconds_remaining": N, "blocking_action": str} if on cooldown
    """
    from .action_config import get_action_slot, ACTION_SLOTS
    
    now = datetime.utcnow()
    
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
    # USE THE SAME cooldown_minutes FOR ALL ACTIONS IN THE SLOT
    # (They share the same slot, so they share the same cooldown duration)
    max_remaining = 0
    blocking_action = None
    required_seconds = cooldown_minutes * 60
    
    for cooldown in cooldowns:
        if cooldown.last_performed:
            elapsed = (now - cooldown.last_performed).total_seconds()
            remaining = required_seconds - elapsed
            
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


def get_food_items() -> list:
    """Get list of item_ids that count as food from RESOURCES config."""
    from routers.resources import RESOURCES
    return [item_id for item_id, config in RESOURCES.items() if config.get("is_food", False)]


def get_player_food_total(db: Session, user_id: int) -> int:
    """Get total food available for a player from inventory."""
    from db.models.inventory import PlayerInventory
    
    food_item_ids = get_food_items()
    if not food_item_ids:
        return 0
    
    food_items = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id.in_(food_item_ids)
    ).all()
    
    return sum(item.quantity for item in food_items)


def check_and_deduct_food_cost(
    db: Session,
    user_id: int,
    cooldown_minutes: float,
    action_name: str = "action"
) -> Dict:
    """
    Check if player has enough food for an action and deduct it from inventory.
    
    Food cost = cooldown_minutes * FOOD_COST_PER_COOLDOWN_MINUTE (default 0.5)
    Food items are defined in RESOURCES with is_food=True (currently: meat)
    
    Args:
        db: Database session
        user_id: The user's ID
        cooldown_minutes: The action's cooldown in minutes (skill-adjusted)
        action_name: Human-readable action name for error messages
        
    Returns:
        {"success": True, "food_cost": N, "food_remaining": N} if player has enough food
        {"success": False, "error": str, "food_cost": N, "food_have": N} if not enough food
    """
    from routers.tiers import calculate_food_cost
    from db.models.inventory import PlayerInventory
    
    food_cost = calculate_food_cost(cooldown_minutes)
    food_item_ids = get_food_items()
    
    if not food_item_ids:
        # No food items defined - skip food check (shouldn't happen in production)
        return {
            "success": True,
            "food_cost": 0,
            "food_remaining": 0
        }
    
    # Get all food items for this player, ordered by quantity (deduct from largest first)
    food_items = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id.in_(food_item_ids)
    ).order_by(PlayerInventory.quantity.desc()).all()
    
    total_food = sum(item.quantity for item in food_items)
    
    if total_food < food_cost:
        return {
            "success": False,
            "error": f"Not enough food for {action_name}. Need {food_cost}, have {total_food}.",
            "food_cost": food_cost,
            "food_have": total_food
        }
    
    # Deduct food from inventory (largest stacks first)
    remaining_cost = food_cost
    for item in food_items:
        if remaining_cost <= 0:
            break
        
        deduct_amount = min(item.quantity, remaining_cost)
        item.quantity -= deduct_amount
        remaining_cost -= deduct_amount
        
        # Remove empty stacks
        if item.quantity <= 0:
            db.delete(item)
    
    new_total = total_food - food_cost
    
    return {
        "success": True,
        "food_cost": food_cost,
        "food_remaining": new_total
    }


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
                "id": str(item.id),
                "type": item.type,
                "tier": item.tier,
                "attack_bonus": item.attack_bonus,
                "defense_bonus": item.defense_bonus,
            }
        elif item.type == "armor":
            result["equipped_armor"] = {
                "id": str(item.id),
                "type": item.type,
                "tier": item.tier,
                "attack_bonus": item.attack_bonus,
                "defense_bonus": item.defense_bonus,
            }
        elif item.type == "shield":
            result["equipped_shield"] = {
                "id": str(item.id),
                "type": item.type,
                "tier": item.tier,
                "attack_bonus": item.attack_bonus,
                "defense_bonus": item.defense_bonus,
            }
    
    return result


def get_inventory(db: Session, user_id: int) -> list:
    """Get all inventory resources for a user from player_inventory table.
    
    NOTE: This returns RESOURCES (fur, meat, blueprint, etc), NOT equipment.
    Equipment is handled separately via get_equipped_items() and player_items table.
    """
    from db.models.inventory import PlayerInventory
    
    items = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id
    ).all()
    
    inventory = []
    for item in items:
        inventory.append({
            "item_id": item.item_id,
            "quantity": item.quantity
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


def set_activity_status(state, status: Optional[str] = None):
    """Set player's activity status. Pass None to clear."""
    state.current_activity_status = status
