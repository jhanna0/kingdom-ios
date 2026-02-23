"""
CHICKEN COOP SYSTEM - Hatch rare eggs into chickens, care for them, collect eggs
=================================================================================
Hatch rare_egg → Wait 24h incubation → Name chicken → Care for happiness → Collect eggs!
Eggs give meat (95%) or rare_egg (5%). Unlocked at Tier 4 property (Beautiful Maison).

ALL LOGIC IS SERVER-SIDE! Frontend is a dumb renderer.
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel
import random

from db import get_db, User, Property
from db.models.chicken import ChickenSlot, ChickenStatus
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso, log_activity

router = APIRouter(prefix="/chicken", tags=["chicken"])


# ===== CHICKEN COOP CONFIG - Single source of truth =====

CHICKEN_CONFIG = {
    "max_slots": 4,
    "incubation_hours": 24,           # Time for egg to hatch
    
    # Stat decay (same for all stats)
    "decay_hours": 8,        # Every 8 hours
    "decay_amount": 10,      # Lose 10 points
    
    # Tamagotchi-style care actions (Feed, Play, Clean)
    # No cooldowns - user can do as much as they want
    "actions": {
        "feed": {
            "restore_amount": 10,
            "gold_cost": 10,
            "icon": "fork.knife",
            "label": "Feed",
            "stat": "hunger",
        },
        "play": {
            "restore_amount": 10,
            "gold_cost": 0,
            "icon": "heart.fill",
            "label": "Play",
            "stat": "happiness",
        },
        "clean": {
            "restore_amount": 10,
            "gold_cost": 0,
            "icon": "sparkles",
            "label": "Clean",
            "stat": "cleanliness",
        },
    },
    
    # Badge threshold - show badge when any stat below this
    "badge_threshold": 50,
    
    # Egg production
    "egg_interval_hours": 12,         # Lays egg every 12h if all stats good
    "min_stat_for_eggs": 50,          # All stats must be >= 50 to lay eggs
    "rare_egg_chance": 0.05,          # 5% chance egg becomes rare_egg
    "rare_egg_item_id": "rare_egg",   # Item consumed when hatching
    "meat_item_id": "meat",           # Item given when collecting eggs (95%)
    "max_name_length": 50,            # Max chicken name length
    
    # UI Config sent to frontend
    "ui": {
        "empty_slot": {
            "icon": "plus.circle.dashed",
            "color": "inkLight",
            "label": "Empty Nest",
        },
        "incubating_slot": {
            "icon": "oval.fill",
            "color": "imperialGold",
            "label": "Incubating",
        },
        "alive_slot": {
            "icon": "oval.fill",
            "color": "buttonWarning",
            "label": "Chicken",
        },
        "egg": {
            "icon": "oval.fill",
            "color": "parchmentLight",
        },
    },
}


# ===== CHICKEN NAME GENERATOR =====

CHICKEN_NAME_PREFIXES = [
    "Lady", "Sir", "Princess", "Duke", "Baron", "Captain", "Professor", "Dr.", "Lord", "Queen",
    "King", "Count", "Countess", "Mayor", "Chef", "Admiral", "General", "Duchess", "Prince"
]

CHICKEN_NAME_MIDDLES = [
    "Clucky", "Feathers", "Pecky", "Nugget", "Drumstick", "Waddles", "Fluffy", "Sunny",
    "Goldie", "Rusty", "Speckles", "Ginger", "Pepper", "Cinnamon", "Butterscotch",
    "Biscuit", "Noodle", "Pickles", "Waffles", "Pancake", "Muffin", "Cupcake",
    "Pebbles", "Sprout", "Chirpy", "Peep", "Henrietta", "Eggbert", "Yolko"
]

CHICKEN_NAME_SUFFIXES = [
    "McFluff", "von Egg", "the Brave", "the Wise", "Jr.", "III", "Esq.",
    "of the Coop", "the Magnificent", "the Fluffy", "the Great", "the Bold",
    "Feathersworth", "Cluckington", "the Peckish", "Eggsworth"
]


def generate_chicken_name() -> str:
    """Generate a fun random chicken name."""
    # 70% chance: Prefix + Middle (e.g., "Lady Clucky")
    # 30% chance: Middle + Suffix (e.g., "Nugget the Brave")
    if random.random() < 0.7:
        return f"{random.choice(CHICKEN_NAME_PREFIXES)} {random.choice(CHICKEN_NAME_MIDDLES)}"
    else:
        return f"{random.choice(CHICKEN_NAME_MIDDLES)} {random.choice(CHICKEN_NAME_SUFFIXES)}"


# ===== HELPER FUNCTIONS =====

def get_player_rare_egg_count(db: Session, user_id: int) -> int:
    """Get how many rare eggs the player has."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == CHICKEN_CONFIG["rare_egg_item_id"]
    ).first()
    return inv.quantity if inv else 0


def consume_rare_egg(db: Session, user_id: int) -> bool:
    """Consume one rare egg. Returns True if successful."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == CHICKEN_CONFIG["rare_egg_item_id"]
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


def check_and_update_slot_status(slot: ChickenSlot, db: Session = None) -> tuple[ChickenSlot, bool]:
    """
    Check and update chicken slot status based on time:
    - Incubating → Alive (after incubation_hours)
    - Alive → update stat decay and egg production
    
    Returns: (slot, just_hatched) - just_hatched is True if egg hatched this check
    """
    now = datetime.utcnow()
    just_hatched = False
    config = CHICKEN_CONFIG
    
    # Check incubation completion
    if slot.status == ChickenStatus.INCUBATING and slot.incubation_started_at:
        hatch_time = slot.incubation_started_at + timedelta(hours=config["incubation_hours"])
        if now >= hatch_time:
            slot.status = ChickenStatus.ALIVE
            slot.hatched_at = hatch_time
            # Auto-assign a name
            slot.name = generate_chicken_name()
            # Initialize all stats to 100
            slot.hunger = 100
            slot.happiness = 100
            slot.cleanliness = 100
            # Set initial action timestamps
            slot.last_fed_at = hatch_time
            slot.last_played_at = hatch_time
            slot.last_cleaned_at = hatch_time
            just_hatched = True
    
    # Update stat decay for alive chickens (Tamagotchi style - same rate for all)
    # Stats decay from 100 based on time since last action (not cumulative)
    if slot.status == ChickenStatus.ALIVE:
        decay_hours = config["decay_hours"]
        decay_amount = config["decay_amount"]
        
        # Decay hunger - calculate from 100 based on time since last fed
        if slot.last_fed_at:
            hours_since = (now - slot.last_fed_at).total_seconds() / 3600
            decay_periods = int(hours_since / decay_hours)
            slot.hunger = max(0, 100 - (decay_periods * decay_amount))
        
        # Decay happiness - calculate from 100 based on time since last played
        if slot.last_played_at:
            hours_since = (now - slot.last_played_at).total_seconds() / 3600
            decay_periods = int(hours_since / decay_hours)
            slot.happiness = max(0, 100 - (decay_periods * decay_amount))
        
        # Decay cleanliness - calculate from 100 based on time since last cleaned
        if slot.last_cleaned_at:
            hours_since = (now - slot.last_cleaned_at).total_seconds() / 3600
            decay_periods = int(hours_since / decay_hours)
            slot.cleanliness = max(0, 100 - (decay_periods * decay_amount))
    
    # Check egg production - all stats must be good
    min_stat = config["min_stat_for_eggs"]
    if (slot.status == ChickenStatus.ALIVE and 
        slot.hunger >= min_stat and 
        slot.happiness >= min_stat and 
        slot.cleanliness >= min_stat):
        last_egg_time = slot.last_egg_collected_at or slot.hatched_at
        if last_egg_time:
            hours_since_egg = (now - last_egg_time).total_seconds() / 3600
            new_eggs = int(hours_since_egg / config["egg_interval_hours"])
            if new_eggs > 0 and slot.eggs_available == 0:
                slot.eggs_available = min(new_eggs, 3)  # Cap at 3 uncollected eggs
    
    return slot, just_hatched


def get_or_create_chicken_slots(db: Session, user_id: int) -> list[ChickenSlot]:
    """Get existing chicken slots or create them if they don't exist."""
    slots = db.query(ChickenSlot).filter(
        ChickenSlot.user_id == user_id
    ).order_by(ChickenSlot.slot_index).all()
    
    # Create slots if they don't exist
    if len(slots) < CHICKEN_CONFIG["max_slots"]:
        for i in range(len(slots), CHICKEN_CONFIG["max_slots"]):
            new_slot = ChickenSlot(
                user_id=user_id,
                slot_index=i,
                status=ChickenStatus.EMPTY
            )
            db.add(new_slot)
            slots.append(new_slot)
        db.commit()
    
    # Check and update status for each slot
    hatched_slots = []
    for slot in slots:
        slot, just_hatched = check_and_update_slot_status(slot, db)
        if just_hatched:
            hatched_slots.append(slot)
        # Fix: Auto-generate name for any alive chicken without a name
        # (handles chickens that hatched before auto-naming was added)
        elif slot.status == ChickenStatus.ALIVE and slot.name is None:
            slot.name = generate_chicken_name()
    
    # Log activity for any newly hatched chickens
    for slot in hatched_slots:
        log_activity(
            db=db,
            user_id=user_id,
            action_type="chicken_hatched",
            action_category="chicken",
            description="A new chicken hatched in the coop!",
            kingdom_id=None,
            amount=1,
            details={"slot_index": slot.slot_index},
            visibility="friends"
        )
    
    db.commit()
    return slots


def slot_to_response(slot: ChickenSlot) -> dict:
    """Convert a chicken slot to a frontend-friendly response."""
    config = CHICKEN_CONFIG
    now = datetime.utcnow()
    
    base = {
        "slot_index": slot.slot_index,
        "status": slot.status.value,
    }
    
    if slot.status == ChickenStatus.EMPTY:
        return {
            **base,
            "icon": config["ui"]["empty_slot"]["icon"],
            "color": config["ui"]["empty_slot"]["color"],
            "label": config["ui"]["empty_slot"]["label"],
            "can_hatch": True,
            "can_name": False,
            "can_care": False,
            "can_collect": False,
            "can_release": False,
        }
    
    elif slot.status == ChickenStatus.INCUBATING:
        hatch_time = slot.incubation_started_at + timedelta(hours=config["incubation_hours"])
        seconds_until_hatch = max(0, int((hatch_time - now).total_seconds()))
        progress_percent = min(100, int(((now - slot.incubation_started_at).total_seconds() / (config["incubation_hours"] * 3600)) * 100))
        
        return {
            **base,
            "icon": config["ui"]["incubating_slot"]["icon"],
            "color": config["ui"]["incubating_slot"]["color"],
            "label": config["ui"]["incubating_slot"]["label"],
            "incubation_started_at": format_datetime_iso(slot.incubation_started_at),
            "hatch_time": format_datetime_iso(hatch_time),
            "seconds_until_hatch": seconds_until_hatch,
            "progress_percent": progress_percent,
            "can_hatch": False,
            "can_name": False,
            "can_care": False,
            "can_collect": False,
            "can_release": False,
        }
    
    elif slot.status == ChickenStatus.ALIVE:
        actions_config = config["actions"]
        min_stat = config["min_stat_for_eggs"]
        
        # Build actions array - disabled if stat is already at 100
        actions = []
        for action_id, action_cfg in actions_config.items():
            stat_name = action_cfg["stat"]
            current_stat = getattr(slot, stat_name, 0)
            actions.append({
                "id": action_id,
                "label": action_cfg["label"],
                "icon": action_cfg["icon"],
                "stat": action_cfg["stat"],
                "gold_cost": action_cfg["gold_cost"],
                "restore_amount": action_cfg["restore_amount"],
                "enabled": current_stat < 100,
            })
        
        # Calculate egg timing (only if no eggs available and all stats good)
        seconds_until_egg = 0
        all_stats_good = slot.hunger >= min_stat and slot.happiness >= min_stat and slot.cleanliness >= min_stat
        if slot.eggs_available == 0 and all_stats_good:
            last_egg_time = slot.last_egg_collected_at or slot.hatched_at
            if last_egg_time:
                next_egg_time = last_egg_time + timedelta(hours=config["egg_interval_hours"])
                if now < next_egg_time:
                    seconds_until_egg = max(0, int((next_egg_time - now).total_seconds()))
        
        # Overall status (all stats must be good for "happy")
        overall_status = "happy" if all_stats_good else "sad"
        
        # Check if any stat needs attention (below threshold)
        needs_attention = slot.hunger < config["badge_threshold"] or slot.happiness < config["badge_threshold"] or slot.cleanliness < config["badge_threshold"]
        
        return {
            **base,
            "icon": config["ui"]["alive_slot"]["icon"],
            "color": config["ui"]["alive_slot"]["color"],
            "label": slot.name or "Unnamed Chicken",
            "name": slot.name,
            "can_rename": True,
            
            # Tamagotchi stats
            "stats": {
                "hunger": slot.hunger,
                "happiness": slot.happiness,
                "cleanliness": slot.cleanliness,
            },
            "overall_status": overall_status,
            "needs_attention": needs_attention,
            "min_stat_for_eggs": min_stat,
            
            # Actions (always available, no cooldowns)
            "actions": actions,
            
            # Eggs
            "eggs_available": slot.eggs_available,
            "total_eggs_laid": slot.total_eggs_laid,
            "seconds_until_egg": seconds_until_egg,
            
            # Capabilities
            "can_hatch": False,
            "can_name": slot.name is None,
            "can_collect": slot.eggs_available > 0,
        }
    
    return base


# ===== API ENDPOINTS =====

@router.get("/status")
def get_chicken_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get chicken coop status - slots, happiness levels, eggs available.
    Frontend renders everything from this response.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check property requirement (tier 4+ = Beautiful Maison)
    coop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 4
    ).first()
    
    has_coop = coop_property is not None
    
    if not has_coop:
        return {
            "has_coop": False,
            "coop_requirement": "Build a Beautiful Maison (Tier 4) to unlock the chicken coop.",
            "slots": [],
            "rare_egg_count": get_player_rare_egg_count(db, current_user.id),
            "config": CHICKEN_CONFIG["ui"],
        }
    
    # Get or create chicken slots
    slots = get_or_create_chicken_slots(db, current_user.id)
    
    # Get rare egg count
    rare_egg_count = get_player_rare_egg_count(db, current_user.id)
    
    # Build slot responses
    slot_responses = [slot_to_response(slot) for slot in slots]
    
    # Count stats
    empty_count = sum(1 for s in slots if s.status == ChickenStatus.EMPTY)
    incubating_count = sum(1 for s in slots if s.status == ChickenStatus.INCUBATING)
    alive_count = sum(1 for s in slots if s.status == ChickenStatus.ALIVE)
    total_eggs = sum(s.eggs_available for s in slots if s.status == ChickenStatus.ALIVE)
    
    return {
        "has_coop": True,
        "coop_property": {
            "id": str(coop_property.id),
            "kingdom_name": coop_property.kingdom_name,
            "tier": coop_property.tier,
        },
        "slots": slot_responses,
        "rare_egg_count": rare_egg_count,
        "can_hatch": rare_egg_count > 0 and empty_count > 0,
        "stats": {
            "empty_slots": empty_count,
            "incubating": incubating_count,
            "alive_chickens": alive_count,
            "eggs_ready": total_eggs,
            "total_slots": CHICKEN_CONFIG["max_slots"],
        },
        "config": {
            **CHICKEN_CONFIG["ui"],
            "incubation_hours": CHICKEN_CONFIG["incubation_hours"],
            "egg_interval_hours": CHICKEN_CONFIG["egg_interval_hours"],
            "min_stat_for_eggs": CHICKEN_CONFIG["min_stat_for_eggs"],
            "badge_threshold": CHICKEN_CONFIG["badge_threshold"],
            "decay_hours": CHICKEN_CONFIG["decay_hours"],
            "decay_amount": CHICKEN_CONFIG["decay_amount"],
        },
    }


@router.post("/hatch/{slot_index}")
def hatch_egg(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Hatch a rare egg in a chicken slot.
    Consumes one rare_egg from inventory, starts incubation.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check property requirement
    coop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 4
    ).first()
    
    if not coop_property:
        raise HTTPException(status_code=400, detail="You need a Beautiful Maison (Tier 4+) to have a chicken coop.")
    
    # Validate slot index
    if slot_index < 0 or slot_index >= CHICKEN_CONFIG["max_slots"]:
        raise HTTPException(status_code=400, detail="Invalid slot index.")
    
    # Get the slot
    slots = get_or_create_chicken_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check slot is empty
    if slot.status != ChickenStatus.EMPTY:
        raise HTTPException(status_code=400, detail="This nest is not empty.")
    
    # Check player has rare eggs
    rare_egg_count = get_player_rare_egg_count(db, current_user.id)
    if rare_egg_count < 1:
        raise HTTPException(status_code=400, detail="You don't have any rare eggs. Find them while foraging!")
    
    # Consume rare egg
    if not consume_rare_egg(db, current_user.id):
        raise HTTPException(status_code=400, detail="Failed to consume rare egg.")
    
    # Start incubation
    slot.status = ChickenStatus.INCUBATING
    slot.incubation_started_at = datetime.utcnow()
    slot.hatched_at = None
    slot.name = None
    slot.happiness = 0
    slot.last_cared_at = None
    slot.care_cycles = 0
    slot.eggs_available = 0
    slot.total_eggs_laid = 0
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Egg is now incubating! It will hatch in {CHICKEN_CONFIG['incubation_hours']} hours.",
        "slot": slot_to_response(slot),
        "rare_eggs_remaining": get_player_rare_egg_count(db, current_user.id),
        "incubation_hours": CHICKEN_CONFIG["incubation_hours"],
    }


class NameChickenRequest(BaseModel):
    name: str


@router.post("/name/{slot_index}")
def name_chicken(
    slot_index: int,
    request: NameChickenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Name or rename a chicken.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_chicken_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check chicken is alive
    if slot.status != ChickenStatus.ALIVE:
        raise HTTPException(status_code=400, detail="No chicken to name in this slot.")
    
    # Validate name
    name = request.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name cannot be empty.")
    
    if len(name) > CHICKEN_CONFIG["max_name_length"]:
        raise HTTPException(status_code=400, detail=f"Name too long. Maximum {CHICKEN_CONFIG['max_name_length']} characters.")
    
    old_name = slot.name
    slot.name = name
    db.commit()
    
    if old_name:
        message = f"Renamed from {old_name} to {name}!"
    else:
        message = f"Your chicken is now named {name}!"
    
    return {
        "success": True,
        "message": message,
        "slot": slot_to_response(slot),
    }


class ActionRequest(BaseModel):
    action: str  # "feed", "play", or "clean"


@router.post("/action/{slot_index}")
def perform_action(
    slot_index: int,
    request: ActionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Perform a Tamagotchi-style action on a chicken.
    Actions: feed, play, clean
    No cooldowns - can do as much as you want (but costs gold for feed).
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    action_id = request.action.lower()
    if action_id not in CHICKEN_CONFIG["actions"]:
        raise HTTPException(status_code=400, detail=f"Invalid action. Must be: feed, play, or clean")
    
    action_cfg = CHICKEN_CONFIG["actions"][action_id]
    
    # Check gold cost
    gold_cost = action_cfg["gold_cost"]
    if gold_cost > 0 and state.gold < gold_cost:
        raise HTTPException(status_code=400, detail=f"Not enough gold. Need {gold_cost}g to {action_id}.")
    
    # Get the slot
    slots = get_or_create_chicken_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check chicken is alive
    if slot.status != ChickenStatus.ALIVE:
        raise HTTPException(status_code=400, detail="No chicken in this slot.")
    
    # Deduct gold if needed
    if gold_cost > 0:
        state.gold -= gold_cost
    
    # Apply the action
    stat_name = action_cfg["stat"]
    restore_amount = action_cfg["restore_amount"]
    
    if stat_name == "hunger":
        old_val = slot.hunger
        slot.hunger = min(100, slot.hunger + restore_amount)
        new_val = slot.hunger
        slot.last_fed_at = datetime.utcnow()
    elif stat_name == "happiness":
        old_val = slot.happiness
        slot.happiness = min(100, slot.happiness + restore_amount)
        new_val = slot.happiness
        slot.last_played_at = datetime.utcnow()
    elif stat_name == "cleanliness":
        old_val = slot.cleanliness
        slot.cleanliness = min(100, slot.cleanliness + restore_amount)
        new_val = slot.cleanliness
        slot.last_cleaned_at = datetime.utcnow()
    
    db.commit()
    
    chicken_name = slot.name or "Your chicken"
    gained = new_val - old_val
    
    # Build message
    if action_id == "feed":
        msg = f"{chicken_name} enjoyed the meal!" if gained > 0 else f"{chicken_name} is already full!"
    elif action_id == "play":
        msg = f"{chicken_name} had fun playing!" if gained > 0 else f"{chicken_name} is already happy!"
    elif action_id == "clean":
        msg = f"{chicken_name}'s coop is sparkling clean!" if gained > 0 else f"{chicken_name}'s coop is already clean!"
    
    return {
        "success": True,
        "message": msg,
        "action": action_id,
        "stat": stat_name,
        "gained": gained,
        "new_value": new_val,
        "gold_spent": gold_cost,
        "slot": slot_to_response(slot),
    }


@router.post("/collect/{slot_index}")
def collect_egg(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Collect eggs from a chicken.
    95% chance for meat, 5% chance for rare_egg.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get the slot
    slots = get_or_create_chicken_slots(db, current_user.id)
    slot = next((s for s in slots if s.slot_index == slot_index), None)
    
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found.")
    
    # Check chicken is alive with eggs
    if slot.status != ChickenStatus.ALIVE:
        raise HTTPException(status_code=400, detail="No chicken in this slot.")
    
    if slot.eggs_available <= 0:
        raise HTTPException(status_code=400, detail="No eggs to collect. Check back later!")
    
    # Collect all available eggs
    eggs_collected = slot.eggs_available
    meat_gained = 0
    rare_eggs_gained = 0
    
    for _ in range(eggs_collected):
        if random.random() < CHICKEN_CONFIG["rare_egg_chance"]:
            rare_eggs_gained += 1
        else:
            meat_gained += 1
    
    # Add to inventory
    if meat_gained > 0:
        add_to_inventory(db, current_user.id, CHICKEN_CONFIG["meat_item_id"], meat_gained)
    if rare_eggs_gained > 0:
        add_to_inventory(db, current_user.id, CHICKEN_CONFIG["rare_egg_item_id"], rare_eggs_gained)
    
    # Update slot
    slot.eggs_available = 0
    slot.last_egg_collected_at = datetime.utcnow()
    slot.total_eggs_laid += eggs_collected
    
    # Log activity
    chicken_name = slot.name or "chicken"
    log_activity(
        db=db,
        user_id=current_user.id,
        action_type="collect_eggs",
        action_category="chicken",
        description=f"Collected {eggs_collected} egg(s) from {chicken_name}!",
        kingdom_id=None,
        amount=eggs_collected,
        details={"meat": meat_gained, "rare_egg": rare_eggs_gained},
        visibility="friends"
    )
    
    db.commit()
    
    # Build result message
    rewards = []
    if meat_gained > 0:
        rewards.append(f"{meat_gained} meat")
    if rare_eggs_gained > 0:
        rewards.append(f"{rare_eggs_gained} rare egg{'s' if rare_eggs_gained > 1 else ''}!")
    
    return {
        "success": True,
        "message": f"Collected {eggs_collected} egg(s)! Got: {', '.join(rewards)}",
        "slot": slot_to_response(slot),
        "eggs_collected": eggs_collected,
        "meat_gained": meat_gained,
        "rare_eggs_gained": rare_eggs_gained,
    }


@router.get("/config")
def get_chicken_config():
    """Get chicken coop configuration for frontend reference."""
    return {
        "max_slots": CHICKEN_CONFIG["max_slots"],
        "incubation_hours": CHICKEN_CONFIG["incubation_hours"],
        "decay_hours": CHICKEN_CONFIG["decay_hours"],
        "decay_amount": CHICKEN_CONFIG["decay_amount"],
        "egg_interval_hours": CHICKEN_CONFIG["egg_interval_hours"],
        "min_stat_for_eggs": CHICKEN_CONFIG["min_stat_for_eggs"],
        "badge_threshold": CHICKEN_CONFIG["badge_threshold"],
        "rare_egg_chance": CHICKEN_CONFIG["rare_egg_chance"],
        "actions": CHICKEN_CONFIG["actions"],
        "ui": CHICKEN_CONFIG["ui"],
    }
