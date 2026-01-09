"""
HUNTING SYSTEM CONFIGURATION
============================
All tunable values for the hunting system in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

PHASES:
1. TRACK (Intelligence) - Multiple scout rolls shift creature probabilities, 
   then a "Master Roll" determines which creature appears
2. STRIKE (Attack) - Multiple combat rounds to chip away at animal HP
3. BLESSING (Faith) - Multiple prayer attempts that stack loot bonuses

MULTI-ROLL SYSTEM:
Each phase allows multiple "prep rolls" that affect the final outcome.
Players control when to roll and when to resolve the phase.
"""

from enum import Enum
from typing import Dict, List, Optional


# ============================================================
# HUNT TIMING CONFIGURATION
# ============================================================

HUNT_LOBBY_TIMEOUT_SECONDS = 120       # Max time to wait in lobby
HUNT_PHASE_DURATION_SECONDS = 12       # How long each phase lasts (for UI drama & roll reveals)
HUNT_RESULTS_DISPLAY_SECONDS = 15      # How long to show final results
HUNT_COOLDOWN_MINUTES = 30             # Cooldown between hunts

MIN_PARTY_SIZE = 1                     # Solo hunting allowed
MAX_PARTY_SIZE = 5                     # Maximum hunters


# ============================================================
# ANIMAL DEFINITIONS
# ============================================================
# Each animal has:
# - tier: Difficulty/reward tier (0-4)
# - track_threshold: Minimum tracking score to encounter
# - hp: How much "progress" needed to kill
# - danger: How much danger it poses (affects injury)
# - meat: Amount of meat dropped (main hunting reward!)

ANIMALS = {
    "squirrel": {
        "name": "Squirrel",
        "tier": 0,
        "icon": "🐿️",
        "track_threshold": 0,     # Always findable
        "hp": 1,
        "danger": 0,
        "meat": 1,
        "description": "A quick little critter. Easy prey.",
    },
    "rabbit": {
        "name": "Rabbit",
        "tier": 0,
        "icon": "🐰",
        "track_threshold": 0.5,
        "hp": 1,
        "danger": 0,
        "meat": 2,
        "description": "Fast but fragile. Common in meadows.",
    },
    "deer": {
        "name": "Deer",
        "tier": 1,
        "icon": "🦌",
        "track_threshold": 1.5,
        "hp": 2,
        "danger": 1,
        "meat": 8,
        "description": "Graceful and alert. A worthy hunt.",
    },
    "boar": {
        "name": "Wild Boar",
        "tier": 2,
        "icon": "🐗",
        "track_threshold": 2.5,
        "hp": 3,
        "danger": 3,
        "meat": 15,
        "description": "Aggressive when cornered. Dangerous tusks.",
    },
    "bear": {
        "name": "Bear",
        "tier": 3,
        "icon": "🐻",
        "track_threshold": 3.5,
        "hp": 5,
        "danger": 5,
        "meat": 25,
        "description": "The king of the forest. Approach with caution.",
    },
    "moose": {
        "name": "Moose",
        "tier": 4,
        "icon": "🫎",
        "track_threshold": 4.5,
        "hp": 6,
        "danger": 4,
        "meat": 35,
        "description": "Massive and unpredictable. Legendary game.",
    },
}

# ============================================================
# DROP TABLES - RuneScape style! SAME SYSTEM FOR ALL PHASES!
# ============================================================
# Each outcome has "slots" out of 100. Successful rolls shift slots
# from bad outcomes to good outcomes. Simple and visual!

# --- TRACKING: Which creature will you find? ---
# ALL outcomes must be ON THE BAR! Including "no trail" (failure)
TRACK_DROP_TABLE = {
    "no_trail": 40,   # FAILURE - no creature found! Start with big fail section
    "squirrel": 25,   # Common - 25 slots
    "rabbit": 20,     # Common - 20 slots  
    "deer": 10,       # Uncommon - 10 slots
    "boar": 4,        # Rare - 4 slots
    "bear": 1,        # Very Rare - 1 slot
    "moose": 0,       # Legendary - 0 slots (must earn it!)
}  # Total: 100 slots

TRACK_SHIFT_PER_SUCCESS = {
    "no_trail": -8,   # Each success shrinks the fail zone!
    "squirrel": -2,   # Shrink common
    "rabbit": +1,     # Slight gain
    "deer": +3,       # Good gain
    "boar": +3,       # Good gain
    "bear": +2,       # Gain
    "moose": +1,      # Gain (starts at 0, builds up)
}

# DISPLAY CONFIG for drop table items - sent to frontend!
# Order matters - this is the order they appear on the bar (left to right)
TRACK_DROP_TABLE_DISPLAY = [
    {"key": "no_trail", "icon": "❌", "name": "Lost", "color": "#665544"},
    {"key": "squirrel", "icon": "🐿️", "name": "Squirrel", "color": "#888888"},
    {"key": "rabbit", "icon": "🐰", "name": "Rabbit", "color": "#888888"},
    {"key": "deer", "icon": "🦌", "name": "Deer", "color": "#4CAF50"},
    {"key": "boar", "icon": "🐗", "name": "Boar", "color": "#FF9800"},
    {"key": "bear", "icon": "🐻", "name": "Bear", "color": "#F44336"},
    {"key": "moose", "icon": "🫎", "name": "Moose", "color": "#9C27B0"},
]

ATTACK_DROP_TABLE_DISPLAY = [
    {"key": "scare", "icon": "😱", "name": "Scare", "color": "#CC6666"},
    {"key": "miss", "icon": "💨", "name": "Miss", "color": "#AAAAAA"},
    {"key": "hit", "icon": "⚔️", "name": "Hit!", "color": "#4CAF50"},
]

BLESSING_DROP_TABLE_DISPLAY = [
    {"key": "common", "icon": "📦", "name": "Common", "color": "#888888"},
    {"key": "rare", "icon": "✨", "name": "Rare!", "color": "#DAB24D"},
]

# --- ATTACK: Three sections - Scare / Miss / Hit ---
# Only HIT kills! Scare and Miss both = animal escapes (just visual variety)
# Higher tier = smaller HIT section

# Base tables by animal tier
ATTACK_DROP_TABLE_BY_TIER = {
    0: {"scare": 20, "miss": 20, "hit": 60},   # Squirrel/Rabbit - 60% hit
    1: {"scare": 25, "miss": 30, "hit": 45},   # Deer - 45% hit
    2: {"scare": 30, "miss": 35, "hit": 35},   # Boar - 35% hit
    3: {"scare": 35, "miss": 40, "hit": 25},   # Bear - 25% hit
    4: {"scare": 40, "miss": 45, "hit": 15},   # Moose - 15% hit (legendary!)
}

# Default for unknown tiers
ATTACK_DROP_TABLE = {"scare": 30, "miss": 30, "hit": 40}

ATTACK_SHIFT_PER_SUCCESS = {
    "scare": -5,      # Each success: shrink scare
    "miss": -5,       # Each success: shrink miss
    "hit": +10,       # Each success: grow hit
}
# Example on Boar (35% base):
# 0 successes: 35% hit
# 1 success: 45% hit
# 2 successes: 55% hit
# 3 successes: 65% hit
# 5 successes (max): 85% hit

# --- BLESSING: Common vs Rare loot ---
# Simple 2-tier system: faith shifts odds from common to rare
BLESSING_DROP_TABLE = {
    "common": 97,     # Just meat - very likely by default
    "rare": 3,        # Meat + sinew - ultra rare base chance!
}  # Total: 100 slots

BLESSING_SHIFT_PER_SUCCESS = {
    "common": -8,     # Each success: lose 8 common slots
    "rare": +8,       # Each success: gain 8 rare slots
}
# 0 successes: 3% rare
# 1 success: 11% rare  
# 2 successes: 19% rare
# 3 successes: 27% rare
# 3 crits: 51% rare (6 effective successes)

# Legacy - kept for backwards compatibility but not used
BLESSING_BONUS = {
    "common": 0.0,
    "rare": 1.0,  # Guarantees sinew drop
}

# Legacy aliases for backwards compatibility
BASE_DROP_TABLE = TRACK_DROP_TABLE
SLOTS_SHIFT_PER_SUCCESS = TRACK_SHIFT_PER_SUCCESS

# Critical success = 2x the shift!
# Failed roll = no shift (you just didn't find better tracks)

# Legacy - keeping for backwards compatibility
ANIMAL_WEIGHTS_BY_TIER = {
    0: {"squirrel": 60, "rabbit": 40},
    1: {"rabbit": 30, "deer": 70},
    2: {"deer": 40, "boar": 60},
    3: {"boar": 30, "bear": 70},
    4: {"bear": 40, "moose": 60},
}


# ============================================================
# LOOT CONFIGURATION
# ============================================================
# Two-tier loot system:
# - COMMON: Just meat (always)
# - RARE: Meat + Sinew (determined by blessing phase master roll)
#
# The blessing phase shifts odds from common to rare.
# Sinew is used to craft hunting bow (10 wood + 3 sinew)
# NO GOLD DROPS! Meat can be sold at market for gold if needed.

# What drops for each loot tier (applied after blessing resolution)
LOOT_TIERS = {
    "common": {
        "items": [],  # No bonus items, just meat
    },
    "rare": {
        "items": ["sinew"],  # Sinew drops!
    },
}

# Legacy - kept for backwards compatibility
DROP_TABLES = {
    0: {},
    1: {},
    2: {},
    3: {},
    4: {},
}

# Faith bonus to drop chances (per blessing_score point)
FAITH_DROP_BONUS_PER_POINT = 0.05  # +5% per faith success


# ============================================================
# PHASE CONFIGURATION
# ============================================================
# Each phase uses different stats and has different effects
#
# TEMPLATE SYSTEM: Backend sends ALL display data to frontend!
# This allows the same iOS views to be reused for other minigames
# (fishing, mining, combat arenas, etc.)

class HuntPhase(Enum):
    LOBBY = "lobby"
    TRACK = "track"
    # APPROACH removed - was boring and frustrating, just caused spooking
    STRIKE = "strike"
    BLESSING = "blessing"
    RESULTS = "results"


# NEW SYSTEM: Stat level = number of rolls!
# Hit chance is FLAT (from rolls/config.py ROLL_HIT_CHANCE)
# This config defines the DISPLAY data for frontend templating

PHASE_CONFIG = {
    HuntPhase.TRACK: {
        "name": "Track",
        "display_name": "Tracking",
        "stat": "intelligence",
        "stat_display_name": "Intelligence",
        "icon": "magnifyingglass",
        "description": "Scout the area - successes shift odds toward rare creatures!",
        "success_effect": "Found fresh tracks!",
        "failure_effect": "The trail goes cold...",
        "critical_effect": "Discovered a prime hunting ground!",
        # DISPLAY CONFIG - sent to frontend for templating
        "stat_icon": "brain.head.profile",
        "roll_button_label": "Scout",
        "roll_button_icon": "binoculars.fill",
        "resolve_button_label": "Master Roll",
        "resolve_button_icon": "target",
        "phase_color": "royalBlue",  # Theme color for this phase
        "drop_table_title": "CREATURE ODDS",
        "drop_table_title_resolving": "MASTER ROLL",
        "drop_table_display_type": "creatures",  # How frontend renders the bar
        # Roll configuration
        "min_rolls": 1,           # Must roll at least once
        # max_rolls is now DYNAMIC based on player's stat level!
    },
    # APPROACH phase removed - was boring and just caused spooking frustration
    HuntPhase.STRIKE: {
        "name": "Strike",
        "display_name": "Combat",
        "stat": "attack_power",
        "stat_display_name": "Attack",
        "icon": "bolt.fill",
        "description": "Attack the beast - shift odds toward a killing blow!",
        "success_effect": "Clean hit!",
        "failure_effect": "Miss!",
        "critical_effect": "Perfect strike!",
        # DISPLAY CONFIG
        "stat_icon": "bolt.fill",
        "roll_button_label": "Strike!",
        "roll_button_icon": "bolt.fill",
        "resolve_button_label": "Finish Hunt",
        "resolve_button_icon": "checkmark.circle.fill",
        "phase_color": "buttonDanger",  # Red for combat
        "drop_table_title": "DAMAGE ODDS",
        "drop_table_title_resolving": "FINAL DAMAGE",
        "drop_table_display_type": "damage",
        # Roll configuration  
        "min_rolls": 1,
        # Legacy scoring (kept for backwards compat)
        "score_type": "damage",
        "damage_per_success": 1,
        "damage_per_critical": 2,
        "counterattack_chance": 0.08,
    },
    HuntPhase.BLESSING: {
        "name": "Blessing",
        "display_name": "Blessing",
        "stat": "faith",
        "stat_display_name": "Faith",
        "icon": "sparkles",
        "description": "Pray for better loot - each prayer shifts the odds!",
        "success_effect": "The gods smile upon you!",
        "failure_effect": "Your prayers go unanswered...",
        "critical_effect": "Divine favor!",
        # DISPLAY CONFIG
        "stat_icon": "sparkles",
        "roll_button_label": "Pray",
        "roll_button_icon": "hands.sparkles.fill",
        "resolve_button_label": "Claim Loot",
        "resolve_button_icon": "gift.fill",
        "phase_color": "regalPurple",  # Purple for faith
        "drop_table_title": "LOOT BONUS ODDS",
        "drop_table_title_resolving": "LOOT ROLL",
        "drop_table_display_type": "blessing",
        # Roll configuration
        "min_rolls": 1,
        # Legacy scoring
        "score_type": "loot_bonus",
        "bonus_per_success": 0.1,
        "bonus_per_critical": 0.25,
    },
}


# ============================================================
# INJURY SYSTEM
# ============================================================
# Injuries apply temporary debuffs

INJURY_DEBUFF_DURATION_MINUTES = 30
INJURY_ATTACK_PENALTY = 1  # -1 attack while injured
INJURY_DEFENSE_PENALTY = 1  # -1 defense while injured


# ============================================================
# SCORING & THRESHOLDS
# ============================================================

# Track phase: How many successes needed for each tier
TRACK_TIER_THRESHOLDS = {
    0: 0,    # Tier 0 (squirrel/rabbit) - always available
    1: 1,    # Tier 1 (deer) - need 1 success
    2: 2,    # Tier 2 (boar) - need 2 successes
    3: 3,    # Tier 3 (bear) - need 3 successes
    4: 5,    # Tier 4 (moose) - need 5 successes (full party rolling well)
}

# How tracking score maps to tier (including partial scores)
def get_max_tier_from_track_score(track_score: float) -> int:
    """
    Determine the maximum animal tier based on tracking success.
    """
    for tier in sorted(TRACK_TIER_THRESHOLDS.keys(), reverse=True):
        if track_score >= TRACK_TIER_THRESHOLDS[tier]:
            return tier
    return 0


# Consolation rewards for failed hunts
NO_TRAIL_MEAT = 0           # No meat if tracking fails completely
ESCAPED_MEAT_PERCENT = 0.3  # 30% of normal meat if animal escapes (wounded it at least)


# ============================================================
# MEAT VALUE (for market selling)
# ============================================================
MEAT_MARKET_VALUE = 2  # 1 meat sells for 2 gold at market


# ============================================================
# CONFIG CLASS (for programmatic access)
# ============================================================

class HuntConfig:
    """Programmatic access to hunt configuration"""
    
    # Timing
    LOBBY_TIMEOUT = HUNT_LOBBY_TIMEOUT_SECONDS
    PHASE_DURATION = HUNT_PHASE_DURATION_SECONDS
    RESULTS_DURATION = HUNT_RESULTS_DISPLAY_SECONDS
    COOLDOWN = HUNT_COOLDOWN_MINUTES
    
    # Party
    MIN_PARTY = MIN_PARTY_SIZE
    MAX_PARTY = MAX_PARTY_SIZE
    
    # Animals
    ANIMALS = ANIMALS
    ANIMAL_WEIGHTS = ANIMAL_WEIGHTS_BY_TIER
    
    # Drops
    DROP_TABLES = DROP_TABLES
    FAITH_BONUS = FAITH_DROP_BONUS_PER_POINT
    
    # Phases
    PHASES = PHASE_CONFIG
    
    # Scoring
    TIER_THRESHOLDS = TRACK_TIER_THRESHOLDS
    
    @classmethod
    def get_animal(cls, animal_id: str) -> Optional[dict]:
        return cls.ANIMALS.get(animal_id)
    
    @classmethod
    def get_animals_for_tier(cls, tier: int) -> List[str]:
        return [
            animal_id for animal_id, data in cls.ANIMALS.items()
            if data["tier"] == tier
        ]
    
    @classmethod
    def get_drop_table(cls, tier: int) -> dict:
        return cls.DROP_TABLES.get(tier, {})

