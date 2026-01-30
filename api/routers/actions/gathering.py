"""
Resource Gathering action - Click to gather wood/iron/stone
1 second backend cooldown to prevent scripted abuse
Daily limit: 200 * hometown building level per resource
"""
import random
from fastapi import APIRouter, HTTPException, Depends, status, Query
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta, time

from db import get_db, User, ActionCooldown, Kingdom, DailyGathering
from routers.auth import get_current_user
from systems.gathering import GatherManager, GatherConfig
from .utils import log_activity

router = APIRouter()

# Singleton manager
_gather_manager = GatherManager()

# 1 second cooldown to prevent scripted abuse (frontend uses 0.5s)
GATHER_COOLDOWN_SECONDS = 1

# Daily limit per building level
DAILY_LIMIT_PER_LEVEL = 200


def get_daily_limit(db: Session, user: User, resource_type: str) -> int:
    """Get daily gathering limit based on hometown building level."""
    state = user.player_state
    if not state or not state.hometown_kingdom_id:
        return 0  # No hometown = no gathering allowed
    
    hometown = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if not hometown:
        return 0
    
    # Get building level based on resource type
    if resource_type == "wood":
        level = getattr(hometown, 'lumbermill_level', 0) or 0
    elif resource_type == "stone":
        # Stone unlocks at mine level 1
        level = getattr(hometown, 'mine_level', 0) or 0
    elif resource_type == "iron":
        # Iron unlocks at mine level 2
        mine_level = getattr(hometown, 'mine_level', 0) or 0
        level = max(0, mine_level - 1)  # Level 2 mine = level 1 for iron limit
    else:
        level = 0
    
    return level * DAILY_LIMIT_PER_LEVEL


def get_gathered_today(db: Session, user_id: int, resource_type: str) -> int:
    """Get amount gathered today for this resource."""
    today = date.today()
    record = db.query(DailyGathering).filter(
        DailyGathering.user_id == user_id,
        DailyGathering.resource_type == resource_type,
        DailyGathering.gather_date == today
    ).first()
    return record.amount_gathered if record else 0


def add_gathered_amount(db: Session, user_id: int, resource_type: str, amount: int):
    """Add to today's gathered amount."""
    today = date.today()
    record = db.query(DailyGathering).filter(
        DailyGathering.user_id == user_id,
        DailyGathering.resource_type == resource_type,
        DailyGathering.gather_date == today
    ).with_for_update().first()
    
    if record:
        record.amount_gathered += amount
    else:
        record = DailyGathering(
            user_id=user_id,
            resource_type=resource_type,
            gather_date=today,
            amount_gathered=amount
        )
        db.add(record)


@router.post("/gather")
def gather_resource(
    resource_type: str = Query(..., description="Resource type: 'wood' or 'iron'"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Gather a resource (wood or iron).
    
    1 second backend cooldown prevents scripted abuse while allowing rapid clicking.
    Frontend handles 0.5s cooldown for UX.
    
    Returns tier (black/brown/green/gold) and amount gathered (0-3).
    Resources are automatically added to player inventory.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
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
                "new_total": getattr(state, GatherConfig.get_resource(resource_type)["player_field"], 0)
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
    
    # Validate resource type
    resource_config = GatherConfig.get_resource(resource_type)
    if not resource_config:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid resource type: {resource_type}"
        )
    
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
    
    # CHECK DAILY LIMIT - wood uses lumbermill_level, iron uses mine_level
    daily_limit = get_daily_limit(db, current_user, resource_type)
    gathered_today = get_gathered_today(db, current_user.id, resource_type)
    
    if daily_limit <= 0:
        # No building = can't gather
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
            "new_total": getattr(state, resource_config["player_field"], 0),
            "exhausted": True,
            "exhausted_message": msg
        }
    
    if gathered_today >= daily_limit:
        # Calculate time until reset (midnight)
        now = datetime.now()
        tomorrow_midnight = datetime.combine(date.today() + timedelta(days=1), time.min)
        remaining = tomorrow_midnight - now
        hours, remainder = divmod(int(remaining.total_seconds()), 3600)
        minutes, _ = divmod(remainder, 60)
        time_str = f"{hours}h {minutes}m"

        # Daily limit reached - get building level for message
        building_level = daily_limit // DAILY_LIMIT_PER_LEVEL
        resource_verb = "chopped" if resource_type == "wood" else "quarried" if resource_type == "stone" else "mined"
        return {
            "resource_type": resource_type,
            "tier": "black", 
            "amount": 0,
            "new_total": getattr(state, resource_config["player_field"], 0),
            "exhausted": True,
            "exhausted_message": f"You've {resource_verb} all available {resource_type} for today. Resets in {time_str}."
        }
    
    # Get current amount of this resource
    player_field = resource_config["player_field"]
    current_amount = getattr(state, player_field, 0)
    
    # Execute gather roll
    result = _gather_manager.gather(resource_type, current_amount)
    
    # Add gathered resources to player's inventory AND track daily gathering
    if result.amount > 0:
        setattr(state, player_field, result.new_total)
        add_gathered_amount(db, current_user.id, resource_type, result.amount)
    
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
