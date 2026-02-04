"""
KITCHEN SYSTEM - Bake wheat into sourdough bread!
=================================================
Load wheat into oven → Wait 3 hours → Collect 12 loaves per wheat!

The baking process:
1. Player loads wheat into an empty oven slot
2. The dough rises and bakes for 3 hours
3. Player collects delicious sourdough bread!

ALL LOGIC IS SERVER-SIDE! Frontend is a dumb renderer.
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, Property
from db.models.kitchen import OvenSlot, OvenStatus
from db.models.kitchen_history import KitchenHistory
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.resources import RESOURCES
from routers.actions.utils import format_datetime_iso, log_activity

router = APIRouter(prefix="/kitchen", tags=["kitchen"])


# ===== KITCHEN CONFIG - Single source of truth =====
# Change these values here and the whole system adapts!

KITCHEN_CONFIG = {
    "max_slots": 4,  # 4 oven slots (can hold 4 dozen at a time)
    "baking_hours": 3,  # Hours for bread to bake
    "loaves_per_wheat": 12,  # 1 wheat = 12 loaves (a dozen)
    "wheat_item_id": "wheat",  # Item consumed when loading oven
    "output_item_id": "sourdough",  # Item produced when collecting
    
    # Fun flavor text for the baking process
    "flavor": {
        "loading": [
            "You knead the wheat into a soft dough...",
            "The dough rises beautifully in the warm kitchen...",
            "You shape the loaves and place them in the oven...",
        ],
        "baking": [
            "The aroma of baking bread fills the air...",
            "You can hear the bread crackling as the crust forms...",
            "Golden perfection is almost ready...",
        ],
        "ready": [
            "Fresh bread! The crust is perfectly golden!",
            "The loaves look absolutely delicious!",
            "That sourdough smell is irresistible!",
        ],
    },
    
    # UI Config sent to frontend
    "ui": {
        "empty_slot": {
            "icon": "circle.dashed",
            "color": "inkLight",
            "label": "Empty",
            "description": "Load wheat to start baking",
        },
        "baking_slot": {
            "icon": "flame.fill",
            "color": "buttonWarning",
            "label": "Baking",
        },
        "ready_slot": {
            "icon": "cloud.fill",
            "color": "goldLight",
            "label": "Ready!",
        },
        "oven": {
            "icon": "flame.fill",
            "color": "buttonWarning",
        },
        "bread": {
            "icon": "cloud.fill",  # Puffy bread shape
            "color": "goldLight",
        },
    },
}


def get_player_wheat_count(db: Session, user_id: int) -> int:
    """Get how much wheat the player has."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == KITCHEN_CONFIG["wheat_item_id"]
    ).first()
    return inv.quantity if inv else 0


def consume_wheat(db: Session, user_id: int, amount: int = 1) -> bool:
    """Consume wheat. Returns True if successful."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == KITCHEN_CONFIG["wheat_item_id"]
    ).first()
    
    if not inv or inv.quantity < amount:
        return False
    
    inv.quantity -= amount
    if inv.quantity <= 0:
        db.delete(inv)
    
    return True


def add_to_inventory(db: Session, user_id: int, item_id: str, amount: int):
    """Add items to player inventory."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).first()
    
    if inv:
        inv.quantity += amount
    else:
        inv = PlayerInventory(
            user_id=user_id,
            item_id=item_id,
            quantity=amount
        )
        db.add(inv)


def check_and_update_oven_status(slot: OvenSlot) -> OvenSlot:
    """
    Check if a baking slot has finished.
    Updates the slot status if bread is ready.
    """
    if slot.status != OvenStatus.BAKING:
        return slot
    
    # Check if baking is complete
    if slot.ready_at and datetime.utcnow() >= slot.ready_at:
        slot.status = OvenStatus.READY
    
    return slot


def get_or_create_oven_slots(db: Session, user_id: int) -> list[OvenSlot]:
    """Get existing oven slots or create them if they don't exist."""
    slots = db.query(OvenSlot).filter(
        OvenSlot.user_id == user_id
    ).order_by(OvenSlot.slot_index).all()
    
    # Create slots if they don't exist
    if len(slots) < KITCHEN_CONFIG["max_slots"]:
        for i in range(len(slots), KITCHEN_CONFIG["max_slots"]):
            new_slot = OvenSlot(
                user_id=user_id,
                slot_index=i,
                status=OvenStatus.EMPTY
            )
            db.add(new_slot)
            slots.append(new_slot)
        db.commit()
    
    # Check and update status for each slot
    for slot in slots:
        check_and_update_oven_status(slot)
    
    db.commit()
    return slots


def slot_to_response(slot: OvenSlot) -> dict:
    """Convert an oven slot to a frontend-friendly response."""
    config = KITCHEN_CONFIG
    
    base = {
        "slot_index": slot.slot_index,
        "status": slot.status.value,
    }
    
    if slot.status == OvenStatus.EMPTY:
        return {
            **base,
            "icon": config["ui"]["empty_slot"]["icon"],
            "color": config["ui"]["empty_slot"]["color"],
            "label": config["ui"]["empty_slot"]["label"],
            "description": config["ui"]["empty_slot"]["description"],
            "can_load": True,
            "can_collect": False,
        }
    
    elif slot.status == OvenStatus.BAKING:
        # Calculate time remaining
        seconds_remaining = 0
        progress_percent = 0
        
        if slot.ready_at and slot.started_at:
            total_seconds = (slot.ready_at - slot.started_at).total_seconds()
            elapsed_seconds = (datetime.utcnow() - slot.started_at).total_seconds()
            seconds_remaining = max(0, int((slot.ready_at - datetime.utcnow()).total_seconds()))
            progress_percent = min(100, int((elapsed_seconds / total_seconds) * 100))
        
        return {
            **base,
            "icon": config["ui"]["baking_slot"]["icon"],
            "color": config["ui"]["baking_slot"]["color"],
            "label": f"Baking... ({progress_percent}%)",
            "wheat_used": slot.wheat_used,
            "loaves_pending": slot.loaves_pending,
            "started_at": format_datetime_iso(slot.started_at) if slot.started_at else None,
            "ready_at": format_datetime_iso(slot.ready_at) if slot.ready_at else None,
            "seconds_remaining": seconds_remaining,
            "progress_percent": progress_percent,
            "can_load": False,
            "can_collect": False,
        }
    
    elif slot.status == OvenStatus.READY:
        return {
            **base,
            "icon": config["ui"]["ready_slot"]["icon"],
            "color": config["ui"]["ready_slot"]["color"],
            "label": f"Ready! ({slot.loaves_pending} loaves)",
            "wheat_used": slot.wheat_used,
            "loaves_pending": slot.loaves_pending,
            "can_load": False,
            "can_collect": True,
        }
    
    return base


@router.get("/status")
def get_kitchen_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get kitchen status - oven slots, wheat owned, what can be done.
    Frontend renders everything from this response.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check property requirement (tier 3+ = villa with kitchen)
    kitchen_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    has_kitchen = kitchen_property is not None
    
    if not has_kitchen:
        return {
            "has_kitchen": False,
            "kitchen_requirement": "Upgrade to a Villa (Tier 3) to unlock your kitchen.",
            "slots": [],
            "wheat_count": 0,
            "config": KITCHEN_CONFIG["ui"],
        }
    
    # Get or create oven slots
    slots = get_or_create_oven_slots(db, current_user.id)
    
    # Get wheat count
    wheat_count = get_player_wheat_count(db, current_user.id)
    
    # Build slot responses
    slot_responses = [slot_to_response(slot) for slot in slots]
    
    # Count stats for display
    empty_count = sum(1 for s in slots if s.status == OvenStatus.EMPTY)
    baking_count = sum(1 for s in slots if s.status == OvenStatus.BAKING)
    ready_count = sum(1 for s in slots if s.status == OvenStatus.READY)
    total_loaves_ready = sum(s.loaves_pending for s in slots if s.status == OvenStatus.READY)
    
    return {
        "has_kitchen": True,
        "kitchen_property": {
            "id": str(kitchen_property.id),
            "kingdom_name": kitchen_property.kingdom_name,
            "tier": kitchen_property.tier,
        },
        "slots": slot_responses,
        "wheat_count": wheat_count,
        "can_load": wheat_count > 0 and empty_count > 0,
        "stats": {
            "empty_slots": empty_count,
            "baking": baking_count,
            "ready": ready_count,
            "total_loaves_ready": total_loaves_ready,
            "total_slots": KITCHEN_CONFIG["max_slots"],
        },
        "config": {
            **KITCHEN_CONFIG["ui"],
            "baking_hours": KITCHEN_CONFIG["baking_hours"],
            "loaves_per_wheat": KITCHEN_CONFIG["loaves_per_wheat"],
        },
        "flavor": KITCHEN_CONFIG["flavor"],
    }


@router.post("/load/{slot_index}")
def load_oven(
    slot_index: int,
    wheat_amount: int = 1,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Load wheat into an oven slot to start baking.
    Consumes wheat and starts the 3-hour baking timer.
    
    The fun process:
    - Wheat is kneaded into dough
    - Dough is shaped into loaves
    - Loaves go into the oven
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Validate wheat amount (1-4 per batch for now)
    if wheat_amount < 1:
        wheat_amount = 1
    if wheat_amount > 4:
        wheat_amount = 4  # Max 4 wheat per slot (48 loaves)
    
    # Check property requirement (tier 3+ = villa with kitchen)
    kitchen_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    if not kitchen_property:
        raise HTTPException(status_code=400, detail="You need a Villa (Tier 3+) to have a kitchen.")
    
    # Validate slot index
    if slot_index < 0 or slot_index >= KITCHEN_CONFIG["max_slots"]:
        raise HTTPException(status_code=400, detail="Invalid slot index.")
    
    # Get the slot
    slots = get_or_create_oven_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot is empty
    if slot.status != OvenStatus.EMPTY:
        if slot.status == OvenStatus.BAKING:
            raise HTTPException(status_code=400, detail="This oven is already baking!")
        raise HTTPException(status_code=400, detail="This oven has bread ready to collect.")
    
    # Check player has enough wheat
    wheat_count = get_player_wheat_count(db, current_user.id)
    if wheat_count < wheat_amount:
        raise HTTPException(status_code=400, detail=f"Not enough wheat! You have {wheat_count}, need {wheat_amount}.")
    
    # Consume wheat
    if not consume_wheat(db, current_user.id, wheat_amount):
        raise HTTPException(status_code=400, detail="Failed to consume wheat.")
    
    # Calculate loaves
    loaves = wheat_amount * KITCHEN_CONFIG["loaves_per_wheat"]
    
    # Start baking!
    now = datetime.utcnow()
    slot.status = OvenStatus.BAKING
    slot.wheat_used = wheat_amount
    slot.loaves_pending = loaves
    slot.started_at = now
    slot.ready_at = now + timedelta(hours=KITCHEN_CONFIG["baking_hours"])
    
    db.commit()
    
    import random
    flavor_text = random.choice(KITCHEN_CONFIG["flavor"]["loading"])
    
    return {
        "success": True,
        "message": f"Started baking {loaves} loaves of sourdough!",
        "flavor": flavor_text,
        "slot": slot_to_response(slot),
        "wheat_remaining": get_player_wheat_count(db, current_user.id),
        "ready_in_seconds": KITCHEN_CONFIG["baking_hours"] * 3600,
        "baking_hours": KITCHEN_CONFIG["baking_hours"],
    }


@router.post("/collect/{slot_index}")
def collect_bread(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Collect finished bread from an oven slot.
    Gives sourdough items and clears the slot for more baking.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_oven_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot has finished bread
    if slot.status == OvenStatus.EMPTY:
        raise HTTPException(status_code=400, detail="This oven is empty.")
    
    if slot.status == OvenStatus.BAKING:
        # Check if it's actually ready now
        check_and_update_oven_status(slot)
        if slot.status != OvenStatus.READY:
            remaining = int((slot.ready_at - datetime.utcnow()).total_seconds())
            hours = remaining // 3600
            minutes = (remaining % 3600) // 60
            raise HTTPException(
                status_code=400,
                detail=f"Still baking! Ready in {hours}h {minutes}m."
            )
    
    if slot.status != OvenStatus.READY:
        raise HTTPException(status_code=400, detail="Nothing to collect in this slot.")
    
    # Get the loaves
    loaves = slot.loaves_pending
    wheat_used = slot.wheat_used
    
    # Add sourdough to inventory
    add_to_inventory(db, current_user.id, KITCHEN_CONFIG["output_item_id"], loaves)
    
    # Log to kitchen history (for achievements)
    history = KitchenHistory(
        user_id=current_user.id,
        slot_index=slot_index,
        action="baked",
        wheat_used=wheat_used,
        loaves_produced=loaves,
        started_at=slot.started_at,
    )
    db.add(history)
    
    # Log to activity feed
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="baking",
        action_category="cooking",
        description=f"Baked {loaves} loaves of sourdough!",
        kingdom_id=None,
        amount=loaves,
        details={"item": "sourdough", "amount": loaves, "wheat_used": wheat_used},
        visibility="friends"
    )
    
    # Clear the slot
    slot.status = OvenStatus.EMPTY
    slot.wheat_used = 0
    slot.loaves_pending = 0
    slot.started_at = None
    slot.ready_at = None
    
    db.commit()
    
    import random
    flavor_text = random.choice(KITCHEN_CONFIG["flavor"]["ready"])
    
    return {
        "success": True,
        "message": f"Collected {loaves} loaves of delicious sourdough!",
        "flavor": flavor_text,
        "loaves_collected": loaves,
        "slot": slot_to_response(slot),
    }


@router.get("/config")
def get_kitchen_config():
    """Get kitchen configuration for frontend reference."""
    sourdough_config = RESOURCES.get(KITCHEN_CONFIG["output_item_id"], {})
    wheat_config = RESOURCES.get(KITCHEN_CONFIG["wheat_item_id"], {})
    
    return {
        "max_slots": KITCHEN_CONFIG["max_slots"],
        "baking_hours": KITCHEN_CONFIG["baking_hours"],
        "loaves_per_wheat": KITCHEN_CONFIG["loaves_per_wheat"],
        "wheat_item": {
            "id": KITCHEN_CONFIG["wheat_item_id"],
            "display_name": wheat_config.get("display_name", "Wheat"),
            "icon": wheat_config.get("icon", "leaf"),
            "color": wheat_config.get("color", "goldLight"),
        },
        "output_item": {
            "id": KITCHEN_CONFIG["output_item_id"],
            "display_name": sourdough_config.get("display_name", "Sourdough"),
            "icon": sourdough_config.get("icon", "cloud.fill"),
            "color": sourdough_config.get("color", "gold"),
        },
        "ui": KITCHEN_CONFIG["ui"],
        "flavor": KITCHEN_CONFIG["flavor"],
    }
