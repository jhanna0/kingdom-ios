"""
Resource Gathering action - Click to gather wood/iron/stone
1 second backend cooldown to prevent scripted abuse
Daily limit: 200 * hometown building level per resource (GLOBAL per user)

With building permits, players can gather in multiple kingdoms:
- Hometown: free access (subject to catchup)
- Allied/same empire: free access
- Other kingdoms: requires permit (10g for 10 minutes)

The daily limit is GLOBAL - gathering at any kingdom counts toward the same limit.
Permits only control ACCESS to buildings, not additional gathering capacity.
"""
import random
from fastapi import APIRouter, HTTPException, Depends, status, Query
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta, time
from typing import Optional

from db import get_db, User, ActionCooldown, Kingdom, DailyGathering
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from systems.gathering import GatherManager, GatherConfig
from services.building_permit_service import check_building_access
from .utils import log_activity

router = APIRouter()

# Singleton manager
_gather_manager = GatherManager()


def get_inventory_amount(db: Session, user_id: int, item_id: str) -> int:
    """Get amount of an item in player's inventory."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).first()
    return inv.quantity if inv else 0


def add_inventory_amount(db: Session, user_id: int, item_id: str, amount: int):
    """Add amount to player's inventory (creates row if needed)."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).with_for_update().first()
    
    if inv:
        inv.quantity += amount
    else:
        inv = PlayerInventory(
            user_id=user_id,
            item_id=item_id,
            quantity=amount
        )
        db.add(inv)

# 1 second cooldown to prevent scripted abuse (frontend uses 0.5s)
GATHER_COOLDOWN_SECONDS = 1

# Daily limit per building level
DAILY_LIMIT_PER_LEVEL = 200


def get_building_for_resource(resource_type: str) -> str:
    """Map resource type to building type."""
    if resource_type == "wood":
        return "lumbermill"
    elif resource_type in ("stone", "iron"):
        return "mine"
    return "mine"  # Default


def get_daily_limit(db: Session, user: User, resource_type: str) -> int:
    """
    Get daily gathering limit based on HOMETOWN building level.
    This is a GLOBAL limit - gathering at any kingdom counts toward the same daily cap.
    
    For mining (stone/iron): they share ONE combined limit = mine_level * 200
    """
    state = user.player_state
    if not state or not state.hometown_kingdom_id:
        return 0  # No hometown = no gathering allowed
    
    hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if not hometown:
        return 0
    
    # Get building level based on resource type
    if resource_type == "wood":
        level = getattr(hometown, 'lumbermill_level', 0) or 0
    elif resource_type in ("stone", "iron"):
        # Stone and iron share the same limit based on mine level
        level = getattr(hometown, 'mine_level', 0) or 0
    else:
        level = 0
    
    return level * DAILY_LIMIT_PER_LEVEL


def get_gathered_today(db: Session, user_id: int, resource_type: str) -> int:
    """
    Get total amount gathered today for this resource (across all kingdoms).
    The daily limit is GLOBAL per user, regardless of which kingdoms they gather at.
    
    For mining (stone/iron): returns combined total since they share one limit.
    """
    from sqlalchemy import func
    today = date.today()
    
    # Stone and iron share the same limit, so sum both
    if resource_type in ("stone", "iron"):
        total = db.query(func.sum(DailyGathering.amount_gathered)).filter(
            DailyGathering.user_id == user_id,
            DailyGathering.resource_type.in_(["stone", "iron"]),
            DailyGathering.gather_date == today
        ).scalar()
    else:
        total = db.query(func.sum(DailyGathering.amount_gathered)).filter(
            DailyGathering.user_id == user_id,
            DailyGathering.resource_type == resource_type,
            DailyGathering.gather_date == today
        ).scalar()
    return total or 0


def add_gathered_amount(db: Session, user_id: int, resource_type: str, amount: int, kingdom_id: str):
    """Add to today's gathered amount. Kingdom tracked for analytics but limit is global."""
    today = date.today()
    # Look up by PK (user_id, resource_type, gather_date) - NOT by kingdom_id
    record = db.query(DailyGathering).filter(
        DailyGathering.user_id == user_id,
        DailyGathering.resource_type == resource_type,
        DailyGathering.gather_date == today
    ).with_for_update().first()
    
    if record:
        record.amount_gathered += amount
        # Update kingdom_id to most recent (for analytics)
        record.kingdom_id = kingdom_id
    else:
        record = DailyGathering(
            user_id=user_id,
            resource_type=resource_type,
            gather_date=today,
            kingdom_id=kingdom_id,
            amount_gathered=amount
        )
        db.add(record)


@router.post("/gather")
def gather_resource(
    resource_type: str = Query(..., description="Resource type: 'wood', 'stone', or 'iron'"),
    kingdom_id: Optional[str] = Query(None, description="Kingdom to gather in (defaults to current location)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Gather a resource (wood, stone, or iron).
    
    Can gather in:
    - Hometown (free, subject to catchup)
    - Allied/same empire kingdoms (free)
    - Other kingdoms (requires permit - 10g for 10 minutes)
    
    Daily limit is GLOBAL based on HOMETOWN building level.
    Permits only control access, not additional gathering capacity.
    
    Returns tier (black/brown/green/gold) and amount gathered (0-3).
    Resources are automatically added to player inventory.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Determine which kingdom to gather in
    target_kingdom_id = kingdom_id or state.current_kingdom_id
    if not target_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must specify a kingdom or be in a kingdom"
        )
    
    # Get the target kingdom
    target_kingdom = db.query(Kingdom).filter(Kingdom.id == target_kingdom_id).first()
    if not target_kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Must be in the kingdom to gather
    if state.current_kingdom_id != target_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be in the kingdom to gather resources"
        )
    
    # Validate resource type
    resource_config = GatherConfig.get_resource(resource_type)
    if not resource_config:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid resource type: {resource_type}"
        )
    
    # Determine which building is needed for this resource
    building_type = get_building_for_resource(resource_type)
    
    # CHECK BUILDING ACCESS (permits, alliance, catchup, etc.)
    access = check_building_access(db, current_user, state, target_kingdom, building_type)
    
    if not access["can_access"]:
        return {
            "resource_type": resource_type,
            "tier": "black",
            "amount": 0,
            "new_total": get_inventory_amount(db, current_user.id, resource_type),
            "exhausted": True,
            "exhausted_message": access["reason"],
            "access_denied": True,
            "needs_permit": access.get("needs_permit", False),
            "can_buy_permit": access.get("can_buy_permit", False),
        }
    
    # ATOMIC COOLDOWN CHECK + SET - prevents scripted abuse
    now = datetime.utcnow()
    action_type = f"gather_{resource_type}"
    
    # Lock the row with FOR UPDATE
    cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type == action_type
    ).with_for_update().first()
    
    if cooldown and cooldown.last_performed:
        elapsed = (now - cooldown.last_performed).total_seconds()
        if elapsed < GATHER_COOLDOWN_SECONDS:
            # Silently return empty result - don't show error for rapid clicking
            return {
                "resource_type": resource_type,
                "tier": "black",
                "amount": 0,
                "new_total": get_inventory_amount(db, current_user.id, resource_type)
            }
        cooldown.last_performed = now
    else:
        if cooldown:
            cooldown.last_performed = now
        else:
            cooldown = ActionCooldown(
                user_id=current_user.id,
                action_type=action_type,
                last_performed=now
            )
            db.add(cooldown)
    
    db.flush()
    
    # Mine level 2+ gives scaling chance of iron instead of stone
    # Level 2: 50%, Level 3: 60%, Level 4: 70%, Level 5: 80%
    if resource_type == "stone":
        hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
        mine_level = getattr(hometown, 'mine_level', 0) or 0 if hometown else 0
        if mine_level >= 2:
            iron_chance = 0.40 + (mine_level * 0.10)  # L2=50%, L3=60%, L4=70%, L5=80%
            if random.random() < iron_chance:
                resource_type = "iron"
                resource_config = GatherConfig.get_resource(resource_type)
    
    # CHECK DAILY LIMIT - based on HOMETOWN building level, GLOBAL across all kingdoms
    daily_limit = get_daily_limit(db, current_user, resource_type)
    gathered_today = get_gathered_today(db, current_user.id, resource_type)
    
    if daily_limit <= 0:
        # No building in hometown = can't gather anywhere
        if resource_type == "wood":
            msg = "Your hometown needs a lumbermill to gather wood."
        elif resource_type == "stone":
            msg = "Your hometown needs a mine to quarry stone."
        elif resource_type == "iron":
            msg = "Your hometown needs a level 2 mine to extract iron."
        else:
            msg = f"Your hometown cannot gather {resource_type}."
        
        return {
            "resource_type": resource_type,
            "tier": "black",
            "amount": 0,
            "new_total": get_inventory_amount(db, current_user.id, resource_type),
            "exhausted": True,
            "exhausted_message": msg
        }
    
    if gathered_today >= daily_limit:
        # Calculate time until reset (midnight)
        now_local = datetime.now()
        tomorrow_midnight = datetime.combine(date.today() + timedelta(days=1), time.min)
        remaining = tomorrow_midnight - now_local
        reset_seconds = int(remaining.total_seconds())
        hours, remainder = divmod(reset_seconds, 3600)
        minutes, _ = divmod(remainder, 60)
        time_str = f"{hours}h {minutes}m"

        # Daily limit reached (global across all kingdoms)
        # Stone/iron share a combined mine limit
        if resource_type == "wood":
            exhausted_msg = f"You've chopped all available wood for today. Resets in {time_str}."
        else:
            # Stone and iron share the mine limit
            exhausted_msg = f"The mine is exhausted for today. Resets in {time_str}."
        
        return {
            "resource_type": resource_type,
            "tier": "black", 
            "amount": 0,
            "new_total": get_inventory_amount(db, current_user.id, resource_type),
            "exhausted": True,
            "exhausted_message": exhausted_msg,
            "reset_seconds": reset_seconds
        }
    
    # Get current amount of this resource from inventory
    current_amount = get_inventory_amount(db, current_user.id, resource_type)
    
    # Get building level for probability scaling (lumbermill for wood, mine for stone/iron)
    hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if resource_type == "wood":
        building_level = getattr(hometown, 'lumbermill_level', 1) or 1 if hometown else 1
    else:
        building_level = getattr(hometown, 'mine_level', 1) or 1 if hometown else 1
    
    # Execute gather roll (building level affects tier probabilities)
    result = _gather_manager.gather(resource_type, current_amount, building_level)
    
    # Add gathered resources to player's inventory AND track daily gathering
    if result.amount > 0:
        add_inventory_amount(db, current_user.id, resource_type, result.amount)
        add_gathered_amount(db, current_user.id, resource_type, result.amount, target_kingdom_id)
    
    db.commit()
    
    return result.to_dict()


@router.get("/gather/config")
def get_gather_config(
    current_user: User = Depends(get_current_user),
):
    """
    Get gathering configuration for frontend display.
    Includes resource types and tier probabilities.
    """
    return {
        "resources": GatherConfig.get_all_resources(),
        "tiers": GatherConfig.get_tier_display_info(),
    }
