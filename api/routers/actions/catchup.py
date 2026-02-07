"""
Building Catchup - Track which buildings player needs to expand capacity for.

Players who join a kingdom after a building was constructed must contribute
to building contracts before they can use that building's benefits.

HOW IT WORKS:
1. Player clicks on building they can't use → frontend shows "Expand Capacity" view
2. Opening the view calls POST /catchup/{building}/start → creates catchup record
3. This makes the building appear in their Actions view under "Building" slot
4. Player works on NORMAL building contracts (same as everyone else)
5. Their contributions to that building type count toward catchup progress
6. Once they've contributed enough, they can use the building
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session

from db import get_db, User, Kingdom, BuildingCatchup
from routers.auth import get_current_user
from services.catchup_service import (
    get_catchup_status,
    calculate_catchup_actions,
    EXEMPT_BUILDINGS,
)

router = APIRouter()


@router.get("/catchup/{building_type}")
def get_building_catchup_status(
    building_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get catch-up status for a specific building in player's HOMETOWN."""
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Player state not found")
    
    if not state.hometown_kingdom_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Must have a hometown kingdom")
    
    from routers.tiers import BUILDING_TYPES
    building_type = building_type.lower()
    
    if building_type not in BUILDING_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unknown building type: {building_type}")
    
    if building_type in EXEMPT_BUILDINGS:
        return {"building_type": building_type, "needs_catchup": False, "can_use": True, "reason": "Building is always accessible"}
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hometown kingdom not found")
    
    level_attr = f"{building_type}_level"
    building_level = getattr(kingdom, level_attr, 0) if hasattr(kingdom, level_attr) else 0
    
    status_info = get_catchup_status(
        db, current_user.id, state.hometown_kingdom_id, 
        building_type, building_level, state.building_skill or 0
    )
    
    building_meta = BUILDING_TYPES.get(building_type, {})
    
    return {
        "building_type": building_type,
        "building_display_name": building_meta.get("display_name", building_type.capitalize()),
        "building_level": building_level,
        "needs_catchup": status_info["needs_catchup"],
        "can_use": status_info["can_use_building"],
        "actions_required": status_info["actions_required"],
        "actions_completed": status_info["actions_completed"],
        "actions_remaining": status_info["actions_remaining"],
        "reason": status_info["reason"],
    }


@router.post("/catchup/{building_type}/start")
def start_catchup(
    building_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Mark a building as "started" for catchup tracking in player's HOMETOWN.
    
    This is called when player opens the "Expand Capacity" view.
    Creates a catchup record so the building appears in their Actions view.
    
    Player then works on NORMAL building contracts to make progress.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Player state not found")
    
    if not state.hometown_kingdom_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Must have a hometown kingdom")
    
    from routers.tiers import BUILDING_TYPES
    building_type = building_type.lower()
    
    if building_type not in BUILDING_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unknown building type: {building_type}")
    
    if building_type in EXEMPT_BUILDINGS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This building doesn't require catchup")
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hometown kingdom not found")
    
    level_attr = f"{building_type}_level"
    building_level = getattr(kingdom, level_attr, 0) if hasattr(kingdom, level_attr) else 0
    
    if building_level <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Building not constructed")
    
    # Check if catchup is actually needed
    status_info = get_catchup_status(
        db, current_user.id, state.hometown_kingdom_id,
        building_type, building_level, state.building_skill or 0
    )
    
    if status_info["can_use_building"]:
        return {
            "success": True,
            "already_complete": True,
            "message": "You can already use this building"
        }
    
    # Check if there's already an incomplete catchup for this building
    existing = db.query(BuildingCatchup).filter(
        BuildingCatchup.user_id == current_user.id,
        BuildingCatchup.kingdom_id == state.hometown_kingdom_id,
        BuildingCatchup.building_type == building_type,
        BuildingCatchup.completed_at.is_(None)
    ).first()
    
    if existing:
        return {
            "success": True,
            "already_started": True,
            "actions_required": existing.actions_required,
            "actions_completed": existing.actions_completed,
            "actions_remaining": max(0, existing.actions_required - existing.actions_completed),
            "message": "Already tracking this building"
        }
    
    # Create catchup record for the REMAINDER only
    # actions_required = full requirement - existing contributions - previous catchup work
    remainder = status_info["actions_remaining"]
    
    catchup = BuildingCatchup(
        user_id=current_user.id,
        kingdom_id=state.hometown_kingdom_id,
        building_type=building_type,
        actions_required=max(1, remainder),
        actions_completed=0
    )
    db.add(catchup)
    db.commit()
    
    building_meta = BUILDING_TYPES.get(building_type, {})
    
    return {
        "success": True,
        "started": True,
        "building_type": building_type,
        "building_display_name": building_meta.get("display_name", building_type.capitalize()),
        "actions_required": catchup.actions_required,
        "actions_completed": 0,
        "actions_remaining": catchup.actions_required,
        "message": f"Work on {building_meta.get('display_name', building_type)} contracts to expand capacity"
    }


@router.post("/work/catchup/{catchup_id}")
def work_on_catchup(
    catchup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Work on a building catchup contract.
    
    Player must be in their hometown kingdom to work on catchup.
    Uses the same cooldown slot as regular building work.
    """
    from datetime import datetime, timedelta
    from .utils import (
        calculate_cooldown,
        check_and_set_slot_cooldown_atomic,
        format_datetime_iso,
        set_cooldown,
        check_and_deduct_food_cost
    )
    from .constants import WORK_BASE_COOLDOWN
    from config import DEV_MODE
    
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Player state not found")
    
    if not state.hometown_kingdom_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Must have a hometown kingdom")
    
    # Must be in hometown to work on catchup
    if state.current_kingdom_id != state.hometown_kingdom_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Must be in your hometown kingdom")
    
    # Get the catchup record
    catchup = db.query(BuildingCatchup).filter(
        BuildingCatchup.id == catchup_id,
        BuildingCatchup.user_id == current_user.id
    ).first()
    
    if not catchup:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Catchup contract not found")
    
    if catchup.completed_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Catchup already completed")
    
    # Calculate skill-adjusted cooldown
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    # Check and deduct food cost
    food_result = check_and_deduct_food_cost(db, current_user.id, cooldown_minutes, "catchup work")
    if not food_result["success"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=food_result["error"])
    
    # ATOMIC COOLDOWN CHECK + SET
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="work",
            cooldown_minutes=cooldown_minutes,
            expires_at=cooldown_expires
        )
        
        if not cooldown_result["ready"]:
            remaining = cooldown_result["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Building action is on cooldown. Wait {minutes}m {seconds}s."
            )
    else:
        set_cooldown(db, current_user.id, "work", cooldown_expires)
    
    # Increment actions completed
    catchup.actions_completed += 1
    
    # Check if complete
    is_complete = catchup.actions_completed >= catchup.actions_required
    if is_complete:
        catchup.completed_at = datetime.utcnow()
    
    db.commit()
    
    from routers.tiers import BUILDING_TYPES
    building_meta = BUILDING_TYPES.get(catchup.building_type, {})
    building_name = building_meta.get("display_name", catchup.building_type.capitalize())
    
    if is_complete:
        message = f"Capacity expanded! You can now use the {building_name}."
    else:
        message = f"You worked on expanding {building_name} capacity."
    
    progress_percent = int((catchup.actions_completed / catchup.actions_required) * 100)
    
    return {
        "success": True,
        "message": message,
        "catchup_id": catchup_id,
        "building_type": catchup.building_type,
        "building_display_name": building_name,
        "actions_completed": catchup.actions_completed,
        "actions_required": catchup.actions_required,
        "actions_remaining": max(0, catchup.actions_required - catchup.actions_completed),
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "next_work_available_at": format_datetime_iso(cooldown_expires),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"]
    }
