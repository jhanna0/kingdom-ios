"""
GARDEN SYSTEM - Personal Tamagotchi-style garden unlocked at Tier 2 property (House)
=====================================================================================
Plant seeds → Water within 20 hours (available after 4h) for 4 cycles → Harvest!
Results: Weeds (common), Flowers (keep forever), Wheat (1-2 harvest)

ALL LOGIC IS SERVER-SIDE! Frontend is a dumb renderer.
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import datetime, timedelta
from typing import Optional
import random

from db import get_db, User, Property
from db.models.garden import GardenSlot, PlantStatus, PlantType
from db.models.garden_history import GardenHistory
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.resources import RESOURCES
from routers.actions.utils import format_datetime_iso, log_activity

router = APIRouter(prefix="/garden", tags=["garden"])


# ===== GARDEN CONFIG - Single source of truth =====
# Change these values here and the whole system adapts!

GARDEN_CONFIG = {
    "max_slots": 6,
    "min_watering_hours": 4,  # Can water after this many hours
    "death_timer_hours": 20,  # Plant dies after this many hours without water
    "watering_cycles_required": 4,  # Water this many times to grow
    "seed_item_id": "wheat_seed",  # Item consumed when planting
    
    # Harvest outcomes and probabilities (must sum to 1.0)
    "outcomes": {
        "weed": {
            "probability": 0.40,  # 50% chance
            "display_name": "Weeds",
            "icon": "leaf.fill",
            "color": "inkMedium",
            "description": "Just some weeds. Discard them.",
            "reward_item": None,
            "reward_amount": 0,
        },
        "flower": {
            "probability": 0.35,  # 35% chance
            "display_name": "Flower",
            "icon": "camera.macro",
            "color": "buttonDanger",  # Default pink/red
            "description": "A beautiful flower for your garden. Nice to look at!",
            "reward_item": None,
            "reward_amount": 0,
            # Color tiers with rarity - hex colors for unique flower look
            "color_tiers": {
                "common": {
                    "probability": 0.60,
                    "colors": ["#FF69B4", "#FF6B6B", "#98D8AA"],  # Hot pink, Coral red, Soft green
                    "rarity_color": "#888888",  # Gray
                },
                "uncommon": {
                    "probability": 0.30,
                    "colors": ["#FFD93D", "#FF8C42", "#DDA0DD"],  # Sunny yellow, Warm orange, Plum
                    "rarity_color": "#CC9933",  # Gold
                },
                "rare": {
                    "probability": 0.10,
                    "colors": ["#00BFFF"],  # Deep sky blue - rarest
                    "rarity_color": "#00BFFF",  # Blue
                },
            },
        },
        "wheat": {
            "probability": 0.25,  # 15% chance
            # icon, color, display_name, description pulled from RESOURCES["wheat"]
            "reward_item": "wheat",
            "reward_amount_min": 1,
            "reward_amount_max": 2,
        },
    },
    
    # UI Config sent to frontend
    "ui": {
        "empty_slot": {
            "icon": "plus.circle.dashed",
            "color": "inkLight",
            "label": "Empty",
        },
        "growing_slot": {
            "icon": "leaf.fill",
            "color": "buttonSuccess",
            "label": "Growing",
        },
        "dead_slot": {
            "icon": "xmark.circle.fill",
            "color": "buttonDanger", 
            "label": "Dead",
        },
        "watering_can": {
            "icon": "drop.fill",
            "color": "royalBlue",
        },
    },
}


def get_player_seed_count(db: Session, user_id: int) -> int:
    """Get how many seeds the player has."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == GARDEN_CONFIG["seed_item_id"]
    ).first()
    return inv.quantity if inv else 0


def consume_seed(db: Session, user_id: int) -> bool:
    """Consume one seed. Returns True if successful."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == GARDEN_CONFIG["seed_item_id"]
    ).first()
    
    if not inv or inv.quantity < 1:
        return False
    
    inv.quantity -= 1
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


def check_and_update_slot_status(slot: GardenSlot, db: Session = None) -> GardenSlot:
    """
    Check if a growing slot has died from not being watered.
    Updates the slot status if needed.
    """
    if slot.status != PlantStatus.GROWING:
        return slot
    
    # Check if watering window has passed
    watering_deadline = slot.last_watered_at + timedelta(hours=GARDEN_CONFIG["death_timer_hours"])
    if datetime.utcnow() > watering_deadline:
        slot.status = PlantStatus.DEAD
        
        # Log the death event
        if db:
            history = GardenHistory(
                user_id=slot.user_id,
                slot_index=slot.slot_index,
                action="died",
                plant_type=slot.plant_type.value if slot.plant_type else None,
                flower_color=slot.flower_color,
                flower_rarity=slot.flower_rarity,
                planted_at=slot.planted_at
            )
            db.add(history)
    
    return slot


def get_or_create_garden_slots(db: Session, user_id: int) -> list[GardenSlot]:
    """Get existing garden slots or create them if they don't exist."""
    slots = db.query(GardenSlot).filter(
        GardenSlot.user_id == user_id
    ).order_by(GardenSlot.slot_index).all()
    
    # Create slots if they don't exist
    if len(slots) < GARDEN_CONFIG["max_slots"]:
        for i in range(len(slots), GARDEN_CONFIG["max_slots"]):
            new_slot = GardenSlot(
                user_id=user_id,
                slot_index=i,
                status=PlantStatus.EMPTY
            )
            db.add(new_slot)
            slots.append(new_slot)
        db.commit()
    
    # Check and update status for each slot
    for slot in slots:
        check_and_update_slot_status(slot, db)
    
    db.commit()
    return slots


def slot_to_response(slot: GardenSlot) -> dict:
    """Convert a garden slot to a frontend-friendly response."""
    config = GARDEN_CONFIG
    
    base = {
        "slot_index": slot.slot_index,
        "status": slot.status.value,
    }
    
    if slot.status == PlantStatus.EMPTY:
        return {
            **base,
            "icon": config["ui"]["empty_slot"]["icon"],
            "color": config["ui"]["empty_slot"]["color"],
            "label": config["ui"]["empty_slot"]["label"],
            "can_plant": True,
            "can_water": False,
            "can_harvest": False,
            "can_discard": False,
        }
    
    elif slot.status == PlantStatus.GROWING:
        # Calculate watering deadline and if can water
        watering_deadline = slot.last_watered_at + timedelta(hours=config["death_timer_hours"])
        next_water_available = slot.last_watered_at + timedelta(hours=config["min_watering_hours"])
        can_water_now = datetime.utcnow() >= next_water_available
        
        # Calculate seconds until next water for notifications
        if can_water_now:
            seconds_until_water = 0
        else:
            seconds_until_water = int((next_water_available - datetime.utcnow()).total_seconds())
        
        progress_percent = int((slot.watering_cycles / config["watering_cycles_required"]) * 100)
        
        return {
            **base,
            "icon": config["ui"]["growing_slot"]["icon"],
            "color": config["ui"]["growing_slot"]["color"],  # Generic green - no spoilers!
            "label": f"Growing ({slot.watering_cycles}/{config['watering_cycles_required']})",
            "watering_cycles": slot.watering_cycles,
            "watering_cycles_required": config["watering_cycles_required"],
            "progress_percent": progress_percent,
            "last_watered_at": format_datetime_iso(slot.last_watered_at) if slot.last_watered_at else None,
            "watering_deadline": format_datetime_iso(watering_deadline),
            "seconds_until_water": seconds_until_water,  # For notification scheduling
            "can_water": can_water_now,
            "can_plant": False,
            "can_harvest": False,
            "can_discard": False,
            # NO PREVIEW! Keep it a mystery until fully grown!
        }
    
    elif slot.status == PlantStatus.DEAD:
        return {
            **base,
            "icon": config["ui"]["dead_slot"]["icon"],
            "color": config["ui"]["dead_slot"]["color"],
            "label": config["ui"]["dead_slot"]["label"],
            "can_plant": False,
            "can_water": False,
            "can_harvest": False,
            "can_discard": True,  # Can clear the dead plant
        }
    
    elif slot.status == PlantStatus.READY:
        # Plant is ready to harvest - show what it became
        outcome_config = config["outcomes"].get(slot.plant_type.value, {})
        
        # Pull icon/color/display from RESOURCES if this is a resource item, else use outcome_config
        resource_config = RESOURCES.get(slot.plant_type.value, {})
        icon = outcome_config.get("icon") or resource_config.get("icon", "leaf.fill")
        color = outcome_config.get("color") or resource_config.get("color", "buttonSuccess")
        display_name = outcome_config.get("display_name") or resource_config.get("display_name", "Ready")
        description = outcome_config.get("description") or resource_config.get("description", "")
        
        # Get rarity color from config
        rarity_color = None
        if slot.flower_rarity and "color_tiers" in outcome_config:
            tier = outcome_config["color_tiers"].get(slot.flower_rarity, {})
            rarity_color = tier.get("rarity_color")
        
        return {
            **base,
            "plant_type": slot.plant_type.value,
            "icon": icon,
            "color": slot.flower_color or color,
            "label": display_name,
            "description": description,
            "rarity": slot.flower_rarity,
            "rarity_color": rarity_color,
            "can_plant": False,
            "can_water": False,
            "can_harvest": slot.plant_type in [PlantType.WHEAT],
            "can_discard": slot.plant_type in [PlantType.WEED, PlantType.FLOWER],
        }
    
    return base


@router.get("/status")
def get_garden_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get garden status - slots, seeds owned, what can be done.
    Frontend renders everything from this response.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check property requirement (tier 2+ = house)
    garden_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 2
    ).first()
    
    has_garden = garden_property is not None
    
    if not has_garden:
        return {
            "has_garden": False,
            "garden_requirement": "Build a house (Tier 2) to unlock your garden.",
            "slots": [],
            "seed_count": 0,
            "config": GARDEN_CONFIG["ui"],
        }
    
    # Get or create garden slots
    slots = get_or_create_garden_slots(db, current_user.id)
    
    # Get seed count
    seed_count = get_player_seed_count(db, current_user.id)
    
    # Build slot responses
    slot_responses = [slot_to_response(slot) for slot in slots]
    
    # Count stats for display
    empty_count = sum(1 for s in slots if s.status == PlantStatus.EMPTY)
    growing_count = sum(1 for s in slots if s.status == PlantStatus.GROWING)
    flower_count = sum(1 for s in slots if s.status == PlantStatus.READY and s.plant_type == PlantType.FLOWER)
    
    return {
        "has_garden": True,
        "garden_property": {
            "id": str(garden_property.id),
            "kingdom_name": garden_property.kingdom_name,
            "tier": garden_property.tier,
        },
        "slots": slot_responses,
        "seed_count": seed_count,
        "can_plant": seed_count > 0 and empty_count > 0,
        "stats": {
            "empty_slots": empty_count,
            "growing_plants": growing_count,
            "flowers": flower_count,
            "total_slots": GARDEN_CONFIG["max_slots"],
        },
        "config": {
            **GARDEN_CONFIG["ui"],
            "min_watering_hours": GARDEN_CONFIG["min_watering_hours"],
            "death_timer_hours": GARDEN_CONFIG["death_timer_hours"],
            "watering_cycles_required": GARDEN_CONFIG["watering_cycles_required"],
        },
    }


@router.post("/plant/{slot_index}")
def plant_seed(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Plant a seed in a garden slot.
    Consumes one seed from inventory.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check property requirement (tier 2+ = house)
    garden_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 2
    ).first()
    
    if not garden_property:
        raise HTTPException(status_code=400, detail="You need a house (Tier 2+) to have a garden.")
    
    # Validate slot index
    if slot_index < 0 or slot_index >= GARDEN_CONFIG["max_slots"]:
        raise HTTPException(status_code=400, detail="Invalid slot index.")
    
    # Get the slot
    slots = get_or_create_garden_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot is empty
    if slot.status != PlantStatus.EMPTY:
        raise HTTPException(status_code=400, detail="This slot is not empty.")
    
    # Check player has seeds
    seed_count = get_player_seed_count(db, current_user.id)
    if seed_count < 1:
        raise HTTPException(status_code=400, detail="You don't have any seeds. Find them while foraging!")
    
    # Consume seed
    if not consume_seed(db, current_user.id):
        raise HTTPException(status_code=400, detail="Failed to consume seed.")
    
    # Plant the seed - outcome determined when fully grown
    slot.status = PlantStatus.GROWING
    slot.planted_at = datetime.utcnow()
    slot.last_watered_at = datetime.utcnow()  # Initial "watering" when planted
    slot.watering_cycles = 0
    slot.plant_type = None
    slot.flower_color = None
    slot.flower_rarity = None
    
    # Log the planting event
    history = GardenHistory(
        user_id=current_user.id,
        slot_index=slot_index,
        action="planted",
        planted_at=slot.planted_at
    )
    db.add(history)
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Planted a seed! Water it within {GARDEN_CONFIG['death_timer_hours']} hours to keep it alive.",
        "slot": slot_to_response(slot),
        "seeds_remaining": get_player_seed_count(db, current_user.id),
        # For notification scheduling
        "next_water_in_seconds": GARDEN_CONFIG["min_watering_hours"] * 3600,
        "min_watering_hours": GARDEN_CONFIG["min_watering_hours"],
        "death_timer_hours": GARDEN_CONFIG["death_timer_hours"],
    }


@router.post("/water/{slot_index}")
def water_plant(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Water a growing plant.
    Must be done within the watering window or the plant dies.
    After enough watering cycles, the plant is ready to harvest.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_garden_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot is growing
    if slot.status != PlantStatus.GROWING:
        if slot.status == PlantStatus.DEAD:
            raise HTTPException(status_code=400, detail="This plant has died. Clear it to plant again.")
        raise HTTPException(status_code=400, detail="Nothing to water in this slot.")
    
    # Check if watering is available
    min_water_time = slot.last_watered_at + timedelta(hours=GARDEN_CONFIG["min_watering_hours"])
    if datetime.utcnow() < min_water_time:
        remaining = (min_water_time - datetime.utcnow()).total_seconds()
        hours = int(remaining // 3600)
        minutes = int((remaining % 3600) // 60)
        raise HTTPException(
            status_code=429,
            detail=f"Your plant doesn't need water yet. Check back in {hours}h {minutes}m."
        )
    
    # Water the plant
    slot.last_watered_at = datetime.utcnow()
    slot.watering_cycles += 1
    
    # Check if plant is now fully grown
    if slot.watering_cycles >= GARDEN_CONFIG["watering_cycles_required"]:
        # Determine what plant it becomes NOW
        roll = random.random()
        cumulative = 0
        determined_type = PlantType.WEED
        determined_color = None
        determined_rarity = None
        
        for outcome_type, outcome_config in GARDEN_CONFIG["outcomes"].items():
            cumulative += outcome_config["probability"]
            if roll <= cumulative:
                determined_type = PlantType(outcome_type)
                if outcome_type == "flower" and "color_tiers" in outcome_config:
                    rarity_roll = random.random()
                    rarity_cumulative = 0
                    for rarity, tier_config in outcome_config["color_tiers"].items():
                        rarity_cumulative += tier_config["probability"]
                        if rarity_roll <= rarity_cumulative:
                            determined_rarity = rarity
                            determined_color = random.choice(tier_config["colors"])
                            break
                break
        
        slot.status = PlantStatus.READY
        slot.plant_type = determined_type
        slot.flower_color = determined_color
        slot.flower_rarity = determined_rarity
        
        # Log the grown event (for achievements)
        history = GardenHistory(
            user_id=current_user.id,
            slot_index=slot_index,
            action="grown",
            plant_type=determined_type.value,
            flower_color=determined_color,
            flower_rarity=determined_rarity,
            planted_at=slot.planted_at
        )
        db.add(history)
        
        outcome_config = GARDEN_CONFIG["outcomes"].get(determined_type.value, {})
        resource_config = RESOURCES.get(determined_type.value, {})
        display_name = outcome_config.get("display_name") or resource_config.get("display_name", "something")
        message = f"Your plant is fully grown! It's {display_name}!"
        next_water_in_seconds = None
    else:
        cycles_left = GARDEN_CONFIG["watering_cycles_required"] - slot.watering_cycles
        message = f"Watered! {cycles_left} more watering{'s' if cycles_left > 1 else ''} until fully grown."
        # Calculate when next watering is available (for notification scheduling)
        next_water_in_seconds = GARDEN_CONFIG["min_watering_hours"] * 3600
    
    db.commit()
    
    return {
        "success": True,
        "message": message,
        "slot": slot_to_response(slot),
        "is_fully_grown": slot.status == PlantStatus.READY,
        "plant_type": slot.plant_type.value if slot.plant_type else None,
        # For notification scheduling
        "next_water_in_seconds": next_water_in_seconds,
        "min_watering_hours": GARDEN_CONFIG["min_watering_hours"],
        "death_timer_hours": GARDEN_CONFIG["death_timer_hours"],
    }


@router.post("/harvest/{slot_index}")
def harvest_plant(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Harvest a ready wheat plant.
    Gives wheat items and clears the slot for replanting.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_garden_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot has harvestable plant
    if slot.status != PlantStatus.READY:
        raise HTTPException(status_code=400, detail="Nothing to harvest in this slot.")
    
    if slot.plant_type != PlantType.WHEAT:
        raise HTTPException(status_code=400, detail="Only wheat can be harvested. Flowers stay as decorations, weeds should be discarded.")
    
    # Calculate wheat amount
    wheat_config = GARDEN_CONFIG["outcomes"]["wheat"]
    wheat_amount = random.randint(
        wheat_config.get("reward_amount_min", 1),
        wheat_config.get("reward_amount_max", 2)
    )
    
    # Add wheat to inventory
    add_to_inventory(db, current_user.id, "wheat", wheat_amount)
    
    # Log the harvest event
    history = GardenHistory(
        user_id=current_user.id,
        slot_index=slot_index,
        action="harvested",
        plant_type="wheat",
        planted_at=slot.planted_at,
        wheat_gained=wheat_amount
    )
    db.add(history)
    
    # Log to activity feed
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="harvest",
        action_category="gardening",
        description="Harvested wheat from the garden!",
        kingdom_id=None,
        amount=None,
        details={"item": "wheat", "amount": wheat_amount},
        visibility="friends"
    )
    
    # Clear the slot
    slot.status = PlantStatus.EMPTY
    slot.plant_type = None
    slot.flower_color = None
    slot.flower_rarity = None
    slot.planted_at = None
    slot.last_watered_at = None
    slot.watering_cycles = 0
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Harvested {wheat_amount} wheat! The slot is now empty for replanting.",
        "wheat_gained": wheat_amount,
        "slot": slot_to_response(slot),
    }


@router.post("/discard/{slot_index}")
def discard_plant(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Discard a dead plant, weeds, or a decoration.
    Clears the slot for replanting.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_garden_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot has something to discard
    discardable_statuses = [PlantStatus.DEAD]
    discardable_ready = slot.status == PlantStatus.READY and slot.plant_type in [PlantType.WEED, PlantType.FLOWER]
    
    if slot.status not in discardable_statuses and not discardable_ready:
        raise HTTPException(status_code=400, detail="Nothing to discard in this slot.")
    
    was_flower = slot.plant_type == PlantType.FLOWER
    was_dead = slot.status == PlantStatus.DEAD
    
    # Log the discard event
    history = GardenHistory(
        user_id=current_user.id,
        slot_index=slot_index,
        action="discarded",
        plant_type=slot.plant_type.value if slot.plant_type else None,
        flower_color=slot.flower_color,
        flower_rarity=slot.flower_rarity,
        planted_at=slot.planted_at
    )
    db.add(history)
    
    # Clear the slot
    slot.status = PlantStatus.EMPTY
    slot.plant_type = None
    slot.flower_color = None
    slot.flower_rarity = None
    slot.planted_at = None
    slot.last_watered_at = None
    slot.watering_cycles = 0
    
    db.commit()
    
    if was_flower:
        message = "Cleared the flower. The slot is now empty for replanting."
    elif was_dead:
        message = "Cleared the dead plant. Ready for replanting!"
    else:
        message = "Cleared the slot. Ready for replanting!"
    
    return {
        "success": True,
        "message": message,
        "slot": slot_to_response(slot),
    }


@router.get("/config")
def get_garden_config():
    """Get garden configuration for frontend reference."""
    outcomes_response = {}
    for k, v in GARDEN_CONFIG["outcomes"].items():
        # Pull from RESOURCES if this is a resource item, else use outcome config
        resource_config = RESOURCES.get(k, {})
        outcomes_response[k] = {
            "display_name": v.get("display_name") or resource_config.get("display_name", k),
            "icon": v.get("icon") or resource_config.get("icon", "leaf.fill"),
            "color": v.get("color") or resource_config.get("color", "buttonSuccess"),
            "description": v.get("description") or resource_config.get("description", ""),
        }
    
    return {
        "max_slots": GARDEN_CONFIG["max_slots"],
        "min_watering_hours": GARDEN_CONFIG["min_watering_hours"],
        "death_timer_hours": GARDEN_CONFIG["death_timer_hours"],
        "watering_cycles_required": GARDEN_CONFIG["watering_cycles_required"],
        "seed_item_id": GARDEN_CONFIG["seed_item_id"],
        "outcomes": outcomes_response,
        "ui": GARDEN_CONFIG["ui"],
    }
