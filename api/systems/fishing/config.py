"""
FISHING SYSTEM CONFIGURATION
============================
All tunable values for the fishing system in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

PHASES:
1. CAST (Building) - Multiple rolls shift odds toward finding better fish
2. REEL (Defense) - Multiple rolls shift odds toward successfully landing the fish

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
        "meat_max": 2,
        "description": "A tiny fish. Easy catch.",
    },
    "bass": {
        "name": "Bass",
        "tier": 1,
        "icon": "🐟",
        "meat_min": 2,
        "meat_max": 4,
        "description": "A common lake fish.",
    },
    "salmon": {
        "name": "Salmon",
        "tier": 2,
        "icon": "🐠",
        "meat_min": 3,
        "meat_max": 6,
        "description": "A prized river fish.",
    },
    "catfish": {
        "name": "Catfish",
        "tier": 3,
        "icon": "🐡",
        "meat_min": 4,
        "meat_max": 8,
        "description": "A bottom-dwelling heavyweight.",
    },
    "legendary_carp": {
        "name": "Legendary Carp",
        "tier": 4,
        "icon": "🎣",
        "meat_min": 6,
        "meat_max": 12,
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
    "no_bite": 35,           # FAILURE - nothing bites
    "minnow": 30,            # Tier 0 - common
    "bass": 20,              # Tier 1 - common
    "salmon": 10,            # Tier 2 - uncommon
    "catfish": 4,            # Tier 3 - rare
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
# Simple two-outcome: escaped vs caught
REEL_DROP_TABLE = {
    "escaped": 40,           # Fish gets away
    "caught": 60,            # Successfully landed!
}  # Total: 100 slots

REEL_SHIFT_PER_SUCCESS = {
    "escaped": -12,          # Each success: shrink escape zone
    "caught": +12,           # Each success: grow catch zone
}

# DISPLAY CONFIG for reel drop table
REEL_DROP_TABLE_DISPLAY = [
    {"key": "escaped", "icon": "arrow.uturn.backward", "name": "Escaped", "color": "buttonDanger"},
    {"key": "caught", "icon": "checkmark.circle.fill", "name": "Caught!", "color": "buttonSuccess"},
]


# ============================================================
# RARE DROP CONFIGURATION
# ============================================================

# Chance of pet_fish drop on ANY successful catch
PET_FISH_DROP_CHANCE = 0.01  # 1%

# Bonus chance for legendary fish
PET_FISH_LEGENDARY_BONUS = 0.01  # +1% (total 2% for legendary)


# ============================================================
# PHASE CONFIGURATION
# ============================================================

class FishingPhase(Enum):
    IDLE = "idle"
    CASTING = "casting"
    REELING = "reeling"


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
    """Roll for pet fish drop."""
    import random
    chance = PET_FISH_DROP_CHANCE
    if fish_id == "legendary_carp":
        chance += PET_FISH_LEGENDARY_BONUS
    return random.random() < chance
