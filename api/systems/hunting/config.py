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
# - base_gold: Base gold reward
# - meat: Amount of meat (converts to gold at 2g per meat)

ANIMALS = {
    "squirrel": {
        "name": "Squirrel",
        "tier": 0,
        "icon": "🐿️",
        "track_threshold": 0,     # Always findable
        "hp": 1,
        "danger": 0,
        "base_gold": 5,
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
        "base_gold": 8,
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
        "base_gold": 25,
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
        "base_gold": 50,
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
        "base_gold": 100,
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
        "base_gold": 150,
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
TRACK_DROP_TABLE = {
    "squirrel": 35,   # Common - 35 slots
    "rabbit": 30,     # Common - 30 slots  
    "deer": 20,       # Uncommon - 20 slots
    "boar": 10,       # Rare - 10 slots
    "bear": 4,        # Very Rare - 4 slots
    "moose": 1,       # Legendary - 1 slot
}  # Total: 100 slots

TRACK_SHIFT_PER_SUCCESS = {
    "squirrel": -5,   # Lose 5 slots
    "rabbit": -4,     # Lose 4 slots
    "deer": +3,       # Gain 3 slots
    "boar": +3,       # Gain 3 slots
    "bear": +2,       # Gain 2 slots
    "moose": +1,      # Gain 1 slot
}

# --- ATTACK: How much damage will you deal? ---
ATTACK_DROP_TABLE = {
    "miss": 35,       # Miss - 0 damage
    "graze": 30,      # Graze - 1 damage
    "hit": 25,        # Solid hit - 2 damage
    "crit": 10,       # Critical - 3 damage
}  # Total: 100 slots

ATTACK_SHIFT_PER_SUCCESS = {
    "miss": -8,       # Less likely to miss
    "graze": -4,      # Less likely to graze
    "hit": +7,        # More likely to hit solid
    "crit": +5,       # More likely to crit
}

ATTACK_DAMAGE = {
    "miss": 0,
    "graze": 1,
    "hit": 2,
    "crit": 3,
}

# --- BLESSING: How good is your loot bonus? ---
BLESSING_DROP_TABLE = {
    "none": 40,       # No bonus
    "small": 35,      # +10% bonus
    "medium": 20,     # +25% bonus  
    "large": 5,       # +50% bonus
}  # Total: 100 slots

BLESSING_SHIFT_PER_SUCCESS = {
    "none": -10,      # Less likely no bonus
    "small": -5,      # Less likely small
    "medium": +8,     # More likely medium
    "large": +7,      # More likely large
}

BLESSING_BONUS = {
    "none": 0.0,
    "small": 0.10,
    "medium": 0.25,
    "large": 0.50,
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
# DROP TABLE CONFIGURATION
# ============================================================
# Loot chances are modified by faith_score from the Blessing phase
# Format: {"item": base_chance} where chance is 0-1

DROP_TABLES = {
    # Tier 0 - Small game
    0: {
        "small_pelt": 0.8,       # 80% base chance
        "lucky_rabbit_foot": 0.05,
    },
    # Tier 1 - Medium game
    1: {
        "quality_pelt": 0.6,
        "antler_fragment": 0.3,
        "venison_steak": 0.9,
    },
    # Tier 2 - Dangerous game
    2: {
        "boar_tusk": 0.5,
        "thick_hide": 0.7,
        "boar_meat": 1.0,
    },
    # Tier 3 - Big game
    3: {
        "bear_claw": 0.6,
        "bear_pelt": 0.5,
        "bear_meat": 1.0,
        "trophy_head": 0.1,    # Rare!
    },
    # Tier 4 - Legendary game
    4: {
        "moose_antlers": 0.5,
        "legendary_pelt": 0.4,
        "moose_meat": 1.0,
        "trophy_head": 0.2,
        "hunters_glory": 0.05,  # Very rare collectible
    },
}

# Faith bonus to drop chances (per blessing_score point)
FAITH_DROP_BONUS_PER_POINT = 0.05  # +5% per faith success


# ============================================================
# PHASE CONFIGURATION
# ============================================================
# Each phase uses different stats and has different effects

class HuntPhase(Enum):
    LOBBY = "lobby"
    TRACK = "track"
    # APPROACH removed - was boring and frustrating, just caused spooking
    STRIKE = "strike"
    BLESSING = "blessing"
    RESULTS = "results"


PHASE_CONFIG = {
    HuntPhase.TRACK: {
        "name": "Track",
        "display_name": "Tracking",
        "stat": "intelligence",
        "icon": "magnifyingglass",
        "description": "Scout the area - successes shift odds toward rare creatures!",
        "success_effect": "Found fresh tracks!",
        "failure_effect": "The trail goes cold...",
        "critical_effect": "Discovered a prime hunting ground!",
        # Multi-roll configuration
        "max_rolls": 5,           # Max scout rolls before forced resolution
        "min_rolls": 1,           # Must roll at least once
        "roll_label": "Scout",    # Button text for prep rolls
        "resolve_label": "Master Roll",  # Button text for resolution
        # Uses DROP TABLE system - see BASE_DROP_TABLE and SLOTS_SHIFT_PER_SUCCESS
    },
    # APPROACH phase removed - was boring and just caused spooking frustration
    HuntPhase.STRIKE: {
        "name": "Strike",
        "display_name": "Combat",
        "stat": "attack_power",
        "icon": "bolt.fill",
        "description": "Attack the beast - keep striking until it falls!",
        "success_effect": "Clean hit!",
        "failure_effect": "Miss!",
        "critical_effect": "Perfect strike!",
        # Multi-roll configuration: fight until HP=0 or out of rolls
        "max_rolls": 5,           # Max combat rounds - animal escapes if you run out
        "min_rolls": 1,           # Must attack at least once
        "roll_label": "Strike!",  # Button text
        "resolve_label": None,    # No manual resolve - auto-ends when HP=0
        # Scoring: deal damage until HP reaches 0
        "score_type": "damage",
        "damage_per_success": 1,
        "damage_per_critical": 2,
        "counterattack_chance": 0.08,      # 8% chance animal fights back on miss (just flavor)
    },
    HuntPhase.BLESSING: {
        "name": "Blessing",
        "display_name": "Blessing",
        "stat": "faith",
        "icon": "sparkles",
        "description": "Pray for better loot - each prayer stacks!",
        "success_effect": "The gods smile upon you!",
        "failure_effect": "Your prayers go unanswered...",
        "critical_effect": "Divine favor!",
        # Multi-roll configuration
        "max_rolls": 3,           # Max prayers
        "min_rolls": 1,           # Must pray at least once
        "roll_label": "Pray",     # Button text
        "resolve_label": "Claim Rewards",  # Button text for resolution
        # Scoring: improves loot quality (stacks)
        "score_type": "loot_bonus",
        "bonus_per_success": 0.1,  # +10% loot chance per success
        "bonus_per_critical": 0.25,  # +25% for criticals
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
NO_TRAIL_GOLD = 2          # Gold if tracking fails completely
ESCAPED_GOLD_PERCENT = 0.3  # 30% of normal gold if animal escapes


# ============================================================
# MEAT TO GOLD CONVERSION
# ============================================================
MEAT_TO_GOLD_RATIO = 2  # 1 meat = 2 gold


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

