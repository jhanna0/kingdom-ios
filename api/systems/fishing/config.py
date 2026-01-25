"""
FISHING SYSTEM CONFIGURATION
============================
All tunable values for the fishing system in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

PHASES:
1. CAST (Building) - Multiple rolls shift odds toward finding better fish
2. REEL (Defense) - Multiple rolls shift odds toward successfully landing the fish
3. LOOT (Faith) - Multiple rolls shift odds toward better loot (more meat, pet fish)

KEY DESIGN: Backend pre-calculates ALL rolls, frontend animates them slowly.
This creates a chill, AFK-friendly experience.
"""

from enum import Enum
from typing import Dict, List, Optional


# ============================================================
# TIMING CONFIGURATION
# ============================================================

# How long frontend should wait between animating each roll (ms)
# Note: Frontend controls actual animation timing
ROLL_ANIMATION_DELAY_MS = 400

# Base chance per roll to succeed (same as hunting)
ROLL_HIT_CHANCE = 0.15  # 15% flat chance per roll


# ============================================================
# FISH DEFINITIONS
# ============================================================
# Each fish has:
# - tier: Difficulty/reward tier (0-4)
# - meat_min/meat_max: Meat reward range
# - icon: Emoji for display

FISH = {
    "minnow": {
        "name": "Minnow",
        "tier": 0,
        "icon": "🐟",
        "meat_min": 1,
        "meat_max": 1,
        "description": "A tiny fish. Easy catch.",
    },
    "bass": {
        "name": "Bass",
        "tier": 1,
        "icon": "🐟",
        "meat_min": 2,
        "meat_max": 3,
        "description": "A common lake fish.",
    },
    "salmon": {
        "name": "Salmon",
        "tier": 2,
        "icon": "🐠",
        "meat_min": 3,
        "meat_max": 4,
        "description": "A prized river fish.",
    },
    "catfish": {
        "name": "Catfish",
        "tier": 3,
        "icon": "🐡",
        "meat_min": 4,
        "meat_max": 5,
        "description": "A bottom-dwelling heavyweight.",
    },
    "legendary_carp": {
        "name": "Legendary Carp",
        "tier": 4,
        "icon": "🎣",
        "meat_min": 5,
        "meat_max": 8,
        "description": "The stuff of legends. Ancient and massive.",
    },
}


# ============================================================
# DROP TABLES - RuneScape style!
# ============================================================
# Each outcome has "slots" out of 100. Successful rolls shift slots.
# Same proven system as hunting!

# --- CAST PHASE: What fish will you find? (Building stat) ---
# ALL outcomes on the bar including "no_bite" (failure)
CAST_DROP_TABLE = {
    "no_bite": 33,           # FAILURE - nothing bites
    "minnow": 27,            # Tier 0 - common
    "bass": 22,              # Tier 1 - common
    "salmon": 12,            # Tier 2 - uncommon
    "catfish": 5,            # Tier 3 - rare
    "legendary_carp": 1,     # Tier 4 - legendary
}  # Total: 100 slots

CAST_SHIFT_PER_SUCCESS = {
    "no_bite": -10,          # Each success: shrink fail zone
    "minnow": -3,            # Shrink common
    "bass": +2,              # Slight gain
    "salmon": +4,            # Good gain
    "catfish": +4,           # Good gain
    "legendary_carp": +3,    # Gain (builds up)
}

# DISPLAY CONFIG for cast drop table - sent to frontend
# Order matters - this is the order on the bar (bottom to top for vertical)
# Using theme-compatible colors (will be mapped in iOS)
CAST_DROP_TABLE_DISPLAY = [
    {"key": "no_bite", "icon": "xmark", "name": "Nothing", "color": "inkMedium"},
    {"key": "minnow", "icon": "fish.fill", "name": "Minnow", "color": "disabled"},
    {"key": "bass", "icon": "fish.fill", "name": "Bass", "color": "territoryNeutral1"},
    {"key": "salmon", "icon": "fish.fill", "name": "Salmon", "color": "territoryAllied"},
    {"key": "catfish", "icon": "fish.fill", "name": "Catfish", "color": "royalBlue"},
    {"key": "legendary_carp", "icon": "fish.fill", "name": "Legend", "color": "gold"},
]


# --- REEL PHASE: Will you land the fish? (Defense stat) ---
# Catch difficulty scales with fish tier!
# Rarer fish = harder to land = more rolls needed

# Base reel odds (before fish difficulty applied)
REEL_BASE_CAUGHT = 50
REEL_BASE_ESCAPED = 50

# Difficulty modifier per fish tier (reduces "caught" slots)
# Higher tier = harder to catch
REEL_DIFFICULTY_BY_TIER = {
    0: 0,    # Minnow: no penalty (50/50)
    1: 5,    # Bass: -5 caught (45/55)
    2: 10,   # Salmon: -10 caught (40/60)
    3: 15,   # Catfish: -15 caught (35/65)
    4: 25,   # Legendary: -25 caught (25/75) - HARD!
}

def get_reel_drop_table(fish_id: str) -> dict:
    """Get reel drop table adjusted for fish difficulty."""
    fish = FISH.get(fish_id, {})
    tier = fish.get("tier", 0)
    difficulty = REEL_DIFFICULTY_BY_TIER.get(tier, 0)
    
    caught = max(10, REEL_BASE_CAUGHT - difficulty)  # Min 10%
    escaped = 100 - caught
    
    return {"escaped": escaped, "caught": caught}

REEL_SHIFT_PER_SUCCESS = {
    "escaped": -8,           # Each success: shrink escape zone
    "caught": +8,            # Each success: grow catch zone
}

# DISPLAY CONFIG for reel drop table
# Using cohesive fishing colors (not harsh red/green)
REEL_DROP_TABLE_DISPLAY = [
    {"key": "escaped", "icon": "arrow.uturn.backward", "name": "Escaped", "color": "inkMedium"},
    {"key": "caught", "icon": "checkmark.circle.fill", "name": "Caught!", "color": "territoryAllied"},
]


# ============================================================
# LOOT DROP TABLE - Simple, no adjustments
# ============================================================
# Backend rolls once after catch. Frontend displays result.
# Two outcomes: meat (always) and rare_loot (pet fish for rare fish)

LOOT_DROP_TABLE = {
    "meat": 100,      # Always get meat
}

# For rare-eligible fish, this is the rare loot section
# Backend calculates based on fish tier
LOOT_DROP_TABLE_DISPLAY = [
    {"key": "meat", "icon": "flame.fill", "name": "Meat", "color": "territoryAllied"},
    {"key": "rare_loot", "icon": "sparkles", "name": "Rare!", "color": "gold"},
]


# ============================================================
# PET FISH CONFIGURATION
# ============================================================

# Pet fish ONLY drops from rare fish (catfish and legendary_carp)
PET_FISH_ELIGIBLE = ["catfish", "legendary_carp"]

# Chance of pet_fish drop when catching an eligible fish
# These should be RARE - a flex, not a guarantee
PET_FISH_DROP_CHANCE = {
    "catfish": 0.002,         # 0.2% chance from catfish (1 in 500)
    "legendary_carp": 0.005,  # 0.5% chance from legendary (1 in 200)
}


# ============================================================
# PHASE CONFIGURATION
# ============================================================

class FishingPhase(Enum):
    IDLE = "idle"
    CASTING = "casting"
    REELING = "reeling"
    LOOTING = "looting"


PHASE_CONFIG = {
    FishingPhase.CASTING: {
        "name": "Cast",
        "display_name": "Casting",
        "stat": "building",
        "stat_display_name": "Building",
        "icon": "figure.fishing",
        "description": "Cast your line - patience finds better fish!",
        "success_effect": "Something's interested...",
        "failure_effect": "The water is still...",
        "critical_effect": "A big one's circling!",
        # DISPLAY CONFIG
        "stat_icon": "hammer.fill",
        "roll_button_label": "Wait",
        "roll_button_icon": "hourglass",
        "phase_color": "royalBlue",
        "drop_table_title": "FISH ODDS",
        "min_rolls": 1,
    },
    FishingPhase.REELING: {
        "name": "Reel",
        "display_name": "Reeling",
        "stat": "defense",
        "stat_display_name": "Defense",
        "icon": "arrow.up.circle.fill",
        "description": "Reel it in - hold on tight!",
        "success_effect": "Got a good grip!",
        "failure_effect": "It's pulling hard!",
        "critical_effect": "Perfect tension!",
        # DISPLAY CONFIG
        "stat_icon": "shield.fill",
        "roll_button_label": "Pull",
        "roll_button_icon": "arrow.up",
        "phase_color": "buttonSuccess",
        "drop_table_title": "CATCH ODDS",
        "min_rolls": 1,
    },
    FishingPhase.LOOTING: {
        "name": "Loot",
        "display_name": "Loot",
        "stat": None,  # Not skill based
        "stat_display_name": None,
        "icon": "sparkles",
        "description": "Collect your rewards!",
        "success_effect": "Nice find!",
        "failure_effect": "Just meat.",
        "critical_effect": "Jackpot!",
        # DISPLAY CONFIG
        "stat_icon": None,  # No stat for loot
        "roll_button_label": "Collect",
        "roll_button_icon": "archivebox.fill",
        "phase_color": "gold",
        "drop_table_title": "LOOT",
        "min_rolls": 0,  # No rolls - just display result
    },
}


# ============================================================
# TIER DISPLAY CONFIG - sent to frontend for loot bar
# ============================================================
# Maps fish tier to display color (same colors as CAST_DROP_TABLE_DISPLAY)

TIER_DISPLAY = {
    0: {"color": "disabled", "name": "Common"},
    1: {"color": "territoryNeutral1", "name": "Common"},
    2: {"color": "territoryAllied", "name": "Uncommon"},
    3: {"color": "royalBlue", "name": "Rare"},
    4: {"color": "gold", "name": "Legendary"},
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_fish_meat_reward(fish_id: str) -> int:
    """Get random meat reward for a fish type."""
    import random
    fish = FISH.get(fish_id)
    if not fish:
        return 1
    return random.randint(fish["meat_min"], fish["meat_max"])


def should_drop_pet_fish(fish_id: str) -> bool:
    """Roll for pet fish drop. Only rare fish can become pets!"""
    import random
    if fish_id not in PET_FISH_ELIGIBLE:
        return False  # Common fish can't be pets
    chance = PET_FISH_DROP_CHANCE.get(fish_id, 0)
    return random.random() < chance


def get_loot_drop_table_for_fish(fish_id: str) -> dict:
    """
    Get the loot drop table slots for a specific fish.
    
    For rare-eligible fish: shows meat section + rare_loot section
    For other fish: shows only meat section
    
    Returns slots dict for the loot bar display.
    """
    fish = FISH.get(fish_id, {})
    meat_min = fish.get("meat_min", 1)
    meat_max = fish.get("meat_max", 2)
    
    # Meat section size based on meat range (visual only)
    meat_slots = (meat_min + meat_max) * 10  # Scales with meat value
    
    if fish_id in PET_FISH_ELIGIBLE:
        # Rare eligible: show rare_loot section
        rare_chance = PET_FISH_DROP_CHANCE.get(fish_id, 0)
        rare_slots = int(rare_chance * 100)  # e.g., 2% = 2 slots
        return {
            "meat": meat_slots,
            "rare_loot": rare_slots,
        }
    else:
        # Not rare eligible: just meat
        return {
            "meat": 100,
        }


def get_loot_config_for_fish(fish_id: str) -> dict:
    """
    Get full loot configuration for a fish.
    
    Returns:
        - drop_table: slot sizes
        - drop_table_display: display items
        - bar_title: what to show at top of bar
        - rare_loot_name: what the rare drop is called (if any)
    """
    fish = FISH.get(fish_id, {})
    tier = fish.get("tier", 0)
    tier_display = TIER_DISPLAY.get(tier, TIER_DISPLAY[0])
    meat_min = fish.get("meat_min", 1)
    meat_max = fish.get("meat_max", 2)
    
    display = [
        {
            "key": "meat",
            "icon": "flame.fill",
            "name": f"{meat_min}-{meat_max} Meat",
            "color": tier_display["color"],
        },
    ]
    
    has_rare = fish_id in PET_FISH_ELIGIBLE
    rare_loot_name = None
    bar_title = "LOOT"
    
    if has_rare:
        rare_chance = int(PET_FISH_DROP_CHANCE.get(fish_id, 0) * 100)
        rare_loot_name = "Pet Fish"
        bar_title = "PET FISH"  # Dynamic title from backend
        display.append({
            "key": "rare_loot",
            "icon": "fish.circle.fill",
            "name": f"{rare_chance}% {rare_loot_name}",
            "color": "gold",
        })
    
    return {
        "drop_table": get_loot_drop_table_for_fish(fish_id),
        "drop_table_display": display,
        "bar_title": bar_title,
        "rare_loot_name": rare_loot_name,
        "has_rare": has_rare,
    }


def get_fish_with_loot_preview(fish_id: str) -> Optional[dict]:
    """
    Get complete fish data with loot preview info for frontend.
    
    TEMPLATE SYSTEM: Backend sends ALL display data!
    Frontend is a dumb template - no hardcoded values.
    
    Returns dict with:
    - All base fish data (name, tier, icon, meat_min, meat_max, description)
    - Loot preview (pet_fish_chance, can_drop_pet, tier_color, tier_name)
    """
    fish = FISH.get(fish_id)
    if not fish:
        return None
    
    tier = fish.get("tier", 0)
    tier_display = TIER_DISPLAY.get(tier, TIER_DISPLAY[0])
    
    # Pet fish eligibility and chance
    can_drop_pet = fish_id in PET_FISH_ELIGIBLE
    pet_fish_chance = PET_FISH_DROP_CHANCE.get(fish_id, 0) if can_drop_pet else 0
    
    return {
        # Base fish data
        "name": fish.get("name"),
        "tier": tier,
        "icon": fish.get("icon"),
        "meat_min": fish.get("meat_min"),
        "meat_max": fish.get("meat_max"),
        "description": fish.get("description"),
        # Loot preview - ALL display data from backend!
        "loot_preview": {
            "meat_min": fish.get("meat_min"),
            "meat_max": fish.get("meat_max"),
            "can_drop_pet": can_drop_pet,
            "pet_fish_chance": int(pet_fish_chance * 100),  # As percentage
            "tier_color": tier_display["color"],
            "tier_name": tier_display["name"],
        },
    }
