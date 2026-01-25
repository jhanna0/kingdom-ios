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

# Hunting Permit (for visitors)
HUNTING_PERMIT_COST = 10               # Gold cost to buy a permit
HUNTING_PERMIT_DURATION_MINUTES = 10   # How long the permit lasts


# ============================================================
# ANIMAL DEFINITIONS
# ============================================================
# Each animal has:
# - tier: Difficulty/reward tier (0-4)
# - track_threshold: Minimum tracking score to encounter
# - hp: How much "progress" needed to kill
# - danger: How much danger it poses (affects injury)
# - meat: Max meat dropped (actual drop is level to 2x level, where level = tier + 1)

ANIMALS = {
    "squirrel": {
        "name": "Squirrel",
        "tier": 0,
        "icon": "🐿️",
        "track_threshold": 0,     # Always findable
        "hp": 1,
        "danger": 0,
        "meat": 3,                # Level 1: drops 1-3 meat
        "description": "A quick little critter. Easy prey.",
    },
    "rabbit": {
        "name": "Rabbit",
        "tier": 1,
        "icon": "🐰",
        "track_threshold": 0.5,
        "hp": 1,
        "danger": 0,
        "meat": 3,                # Level 2: drops 2-3 meat
        "description": "Fast but fragile. Common in meadows.",
        "rare_items": ["lucky_rabbits_foot"],
    },
    "deer": {
        "name": "Deer",
        "tier": 2,
        "icon": "🦌",
        "track_threshold": 1.5,
        "hp": 2,
        "danger": 1,
        "meat": 8,                # Boosted: 3-7 meat
        "description": "Graceful and alert. A worthy hunt.",
        "rare_items": ["fur"],    # Deer drops fur on RARE only
    },
    "boar": {
        "name": "Wild Boar",
        "tier": 3,
        "icon": "🐗",
        "track_threshold": 2.5,
        "hp": 3,
        "danger": 3,
        "meat": 12,               # Boosted: 4-12 meat
        "description": "Aggressive when cornered. Dangerous tusks.",
        "rare_items": ["fur"],    # Boar drops fur on RARE only
    },
    "bear": {
        "name": "Bear",
        "tier": 4,
        "icon": "🐻",
        "track_threshold": 3.5,
        "hp": 5,
        "danger": 5,
        "meat": 16,               # Boosted: 5-16 meat
        "description": "The king of the forest. Approach with caution.",
        "rare_items": ["sinew"],  # Bear drops sinew
    },
    "moose": {
        "name": "Moose",
        "tier": 5,
        "icon": "🫎",
        "track_threshold": 4.5,
        "hp": 6,
        "danger": 4,
        "meat": 22,               # Boosted: 6-20 meat
        "description": "Massive and unpredictable. Legendary game.",
        "rare_items": ["sinew"],  # Moose drops sinew
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
    "no_trail": 24,   # FAILURE - no creature found! Reduced from 30
    "squirrel": 22,   # Common - 22 slots (was 28)
    "rabbit": 24,     # Common - 24 slots
    "deer": 17,       # Uncommon - 17 slots (was 12)
    "boar": 9,        # Rare - 9 slots (was 4)
    "bear": 4,        # Very Rare - 4 slots (was 2)
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
# Colors are carefully chosen for visual appeal and readability
TRACK_DROP_TABLE_DISPLAY = [
    {"key": "no_trail", "icon": "●", "name": "Lost", "color": "#8B4513"},      # Saddle brown - failure
    {"key": "squirrel", "icon": "●", "name": "Squirrel", "color": "#A0826D"},  # Warm taupe - common
    {"key": "rabbit", "icon": "●", "name": "Rabbit", "color": "#C4A77D"},      # Wheat - common
    {"key": "deer", "icon": "●", "name": "Deer", "color": "#5D9B5D"},          # Forest green - uncommon
    {"key": "boar", "icon": "●", "name": "Boar", "color": "#4A7BA7"},          # Steel blue - rare
    {"key": "bear", "icon": "●", "name": "Bear", "color": "#8B5A8B"},          # Plum purple - epic
    {"key": "moose", "icon": "●", "name": "Moose", "color": "#CD853F"},        # Peru gold - legendary
]

ATTACK_DROP_TABLE_DISPLAY = [
    {"key": "scare", "icon": "●", "name": "Fled", "color": "#B85450"},   # Muted red - bad
    {"key": "miss", "icon": "●", "name": "Miss", "color": "#8B7355"},    # Khaki brown - neutral
    {"key": "hit", "icon": "●", "name": "Hit!", "color": "#5D9B5D"},     # Forest green - good!
]

BLESSING_DROP_TABLE_DISPLAY = [
    {"key": "nothing", "icon": "●", "name": "Scraps", "color": "#6B5344"},     # Dark brown - minimal loot
    {"key": "common", "icon": "●", "name": "Meat", "color": "#A0826D"},        # Warm taupe - basic
    {"key": "uncommon", "icon": "●", "name": "Bonus!", "color": "#D2691E"},    # Chocolate orange - bonus meat
    {"key": "rare", "icon": "●", "name": "Rare!", "color": "#8B5A8B"},         # Plum purple - animal's rare_items!
]

# --- ATTACK: Three sections - Scare / Miss / Hit ---
# Only HIT kills! Scare and Miss both = animal escapes (just visual variety)
# Higher tier = smaller HIT section

# Base tables by animal tier
# REBALANCED: Slightly smaller scare/miss zones = more successful hunts
# Trade-off: rare loot is harder to get (see BLESSING_DROP_TABLE)
ATTACK_DROP_TABLE_BY_TIER = {
    0: {"scare": 18, "miss": 22, "hit": 60},   # Squirrel - 60% hit (was 55)
    1: {"scare": 20, "miss": 25, "hit": 55},   # Rabbit - 55% hit (was 50)
    2: {"scare": 22, "miss": 28, "hit": 50},   # Deer - 50% hit (was 45)
    3: {"scare": 25, "miss": 30, "hit": 45},   # Boar - 45% hit (was 40)
    4: {"scare": 28, "miss": 37, "hit": 35},   # Bear - 35% hit (was 30)
    5: {"scare": 32, "miss": 43, "hit": 25},   # Moose - 25% hit (was 20)
}

# Default for unknown tiers
ATTACK_DROP_TABLE = {"scare": 22, "miss": 28, "hit": 50}

ATTACK_SHIFT_PER_SUCCESS = {
    "scare": -5,      # Each success: shrink scare
    "miss": -5,       # Each success: shrink miss
    "hit": +10,       # Each success: grow hit
}
# Example on Boar (40% base):
# 0 successes: 40% hit
# 1 success: 50% hit
# 2 successes: 60% hit
# 3 successes: 70% hit

# --- BLESSING: Nothing vs Common vs Uncommon vs Rare loot ---
# Four-tier system: prayers shift odds from nothing → meat → fur → sinew
# Common creatures (tier 0-1) have higher chance of no loot
# Rare creatures (tier 3-4) are almost guaranteed loot
#
# !!! CRITICAL: If you add/remove tiers here, you MUST also update !!!
# !!! BLESSING_ORDER in hunt_manager.py _roll_on_drop_table() !!!
# !!! Missing tiers cause drops to go to the WRONG tier. Game-breaking bug. !!!
#
# REBALANCED: Smaller uncommon/rare = rare loot is actually rare
# Trade-off: hunt success rate is higher (see ATTACK_DROP_TABLE_BY_TIER)
BLESSING_DROP_TABLE = {
    "nothing": 30,    # No loot at all
    "common": 62,     # Just meat
    "uncommon": 5,    # Meat + fur
    "rare": 3,        # Meat + sinew
}  # Total: 100 slots

# REBALANCED: Lower shifts = harder to earn rare loot through prayers
BLESSING_SHIFT_PER_SUCCESS = {
    "nothing": -5,    # Each success: shrink nothing zone (was -8)
    "common": -1,     # Each success: slight loss from common (was -2)
    "uncommon": +3,   # Each success: gain fur slots (was +5)
    "rare": +3,       # Each success: gain sinew slots (was +5)
}
# 0 successes: 30% nothing, 62% meat, 5% fur, 3% sinew
# 1 success: 25% nothing, 61% meat, 8% fur, 6% sinew  
# 2 successes: 20% nothing, 60% meat, 11% fur, 9% sinew
# 3 successes: 15% nothing, 59% meat, 14% fur, 12% sinew

# Animal tier modifies the base drop table before blessing starts
# Higher tier = less "nothing" slots, slightly better loot odds
# But rare should still feel RARE even on big game
# NOTE: Use large negative values to prevent prayers from adding slots back!
BLESSING_TIER_ADJUSTMENTS = {
    0: {"nothing": +5, "common": +25, "uncommon": -100, "rare": -100},  # Squirrel: NEVER fur/sinew
    1: {"nothing": +5, "common": +25, "uncommon": -100, "rare": 0},     # Rabbit: no fur, but rare = rabbit foot
    2: {"nothing": -5, "common": +5, "uncommon": 0, "rare": 0},         # Deer: fur possible
    3: {"nothing": -8, "common": +5, "uncommon": +3, "rare": 0},        # Boar: 8% fur, 3% rare
    4: {"nothing": -10, "common": +5, "uncommon": +3, "rare": +2},      # Bear: 8% fur, 5% rare
    5: {"nothing": -12, "common": +5, "uncommon": +4, "rare": +3},      # Moose: 9% fur, 6% rare
}

# Legacy - kept for backwards compatibility but not used
BLESSING_BONUS = {
    "common": 0.0,
    "uncommon": 0.5,  # Guarantees fur drop
    "rare": 1.0,      # Guarantees sinew drop
}

# Legacy aliases for backwards compatibility
BASE_DROP_TABLE = TRACK_DROP_TABLE
SLOTS_SHIFT_PER_SUCCESS = TRACK_SHIFT_PER_SUCCESS

# Critical success = 2x the shift!
# Failed roll = no shift (you just didn't find better tracks)

# Legacy - keeping for backwards compatibility
ANIMAL_WEIGHTS_BY_TIER = {
    0: {"squirrel": 100},
    1: {"rabbit": 100},
    2: {"deer": 100},
    3: {"boar": 100},
    4: {"bear": 100},
    5: {"moose": 100},
}


# ============================================================
# LOOT CONFIGURATION
# ============================================================
# Two-tier loot system:
# - COMMON: Just meat (always)
# - RARE: Meat + Sinew (determined by blLOOT_TIERSessing phase master roll)
#
# The blessing phase shifts odds from common to rare.
# Sinew is used to craft hunting bow (10 wood + 3 sinew)
# Gold drops equal to meat earned (gold is taxed by kingdom).

# What drops for each loot tier (applied after blessing resolution)
# Items come from animal's rare_items config (only on "rare" rolls)
LOOT_TIERS = {
    "nothing": {"meat_bonus": 0.5},   # 50% meat
    "common": {"meat_bonus": 1.0},    # 100% meat
    "uncommon": {"meat_bonus": 1.15}, # 115% meat
    "rare": {"meat_bonus": 1.25},     # 125% meat + animal's rare_items
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
        "roll_button_label": "Search",
        "roll_button_icon": "binoculars.fill",
        "resolve_button_label": "Follow",
        "resolve_button_icon": "arrow.right.circle.fill",
        "phase_color": "royalBlue",  # Theme color for this phase
        "drop_table_title": "CREATURE ODDS",
        "drop_table_title_resolving": "FOLLOWING TRAIL",
        "drop_table_display_type": "creatures",
        "master_roll_icon": "leaf.fill",
        # Roll configuration
        "min_rolls": 1,
    },
    HuntPhase.STRIKE: {
        "name": "Strike",
        "display_name": "The Hunt",
        "stat": "attack_power",
        "stat_display_name": "Attack",
        "icon": "scope",
        "description": "Take aim and bring down your quarry!",
        "success_effect": "Clean hit!",
        "failure_effect": "Miss!",
        "critical_effect": "Perfect strike!",
        # DISPLAY CONFIG
        "stat_icon": "bolt.fill",
        "roll_button_label": "Aim",
        "roll_button_icon": "scope",
        "resolve_button_label": "Shoot",
        "resolve_button_icon": "target",
        "phase_color": "buttonDanger",  # Red for combat
        "drop_table_title": "HIT ODDS",
        "drop_table_title_resolving": "TAKING THE SHOT",
        "drop_table_display_type": "damage",
        "master_roll_icon": "scope",
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
        "resolve_button_label": "Show Loot",
        "resolve_button_icon": "archivebox.fill",
        "phase_color": "regalPurple",  # Purple for faith
        "drop_table_title": "LOOT ODDS",
        "drop_table_title_resolving": "REVEALING LOOT",
        "drop_table_display_type": "blessing",
        "master_roll_icon": "sparkles",
        # Loot display info - sent to frontend
        "uncommon_item_name": "Bonus Meat",
        "uncommon_item_icon": "plus.circle.fill",
        "rare_item_name": "Rare Drop",
        "rare_item_icon": "sparkles",
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
    0: 0,    # Tier 0 (squirrel) - always available
    1: 0,    # Tier 1 (rabbit) - always available
    2: 1,    # Tier 2 (deer) - need 1 success
    3: 2,    # Tier 3 (boar) - need 2 successes
    4: 3,    # Tier 4 (bear) - need 3 successes
    5: 5,    # Tier 5 (moose) - need 5 successes (full party rolling well)
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

# Hunt streak bonus - 3 successful hunts in a row = double meat
HUNT_STREAK_THRESHOLD = 3   # Number of consecutive successes needed
HUNT_STREAK_MEAT_MULTIPLIER = 2  # Meat multiplier when streak is active


# ============================================================
# MEAT VALUE (for market selling)
# ============================================================
MEAT_MARKET_VALUE = 1  # 1 meat = 1 gold (gold is awarded directly from hunts now)


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

