"""
FORAGING SYSTEM CONFIGURATION
=============================
All tunable values for the foraging minigame in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

DESIGN:
- Two-round foraging system!
- ROUND 1 (Main): Find berries (food) with 10% chance
  - Also has 5% chance to find a "seed trail" → triggers bonus round!
- ROUND 2 (Bonus): New grid slides in from right, 10% chance of seed drop

KEY: Backend has ALL the strings, odds, rewards, colors.
Frontend is a DUMB RENDERER.

IMPORTANT: Item display configs (icon, color, name) come from RESOURCES - single source of truth!
"""

from typing import Dict, List
from routers.resources import RESOURCES


# ============================================================
# HELPER: Get item display from RESOURCES
# ============================================================

def _get_resource(item_id: str) -> dict:
    """Get item config from RESOURCES - single source of truth."""
    return RESOURCES.get(item_id, {})


# ============================================================
# GRID CONFIGURATION
# ============================================================

GRID_SIZE = 4           # 4x4 grid = 16 bushes
MAX_REVEALS = 5         # Player can reveal up to 5 bushes
MATCHES_TO_WIN = 3      # Need 3 matching to win


# ============================================================
# ROUND 1: MAIN FORAGING (Berries + Seed Trail)
# ============================================================

ROUND1_BUSH_TYPES = {
    "berries": {
        "name": _get_resource("berries").get("display_name", "Berries"),
        "icon": _get_resource("berries").get("icon", "seal.fill"),
        "color": _get_resource("berries").get("color", "buttonDanger"),
        "is_target": True,
        "weight": 40,
    },
    "seed_trail": {
        "name": "Seed Trail",
        "icon": "arrow.triangle.turn.up.right.diamond.fill",
        "color": "gold",
        "is_target": False,
        "is_seed_trail": True,
        "label": "BONUS",
        "weight": 0,
    },
    "rock": {
        "name": "Rock",
        "icon": "circle.fill",
        "color": "inkMedium",
        "is_target": False,
        "weight": 30,
    },
    "weed": {
        "name": "Weed",
        "icon": "leaf",
        "color": "buttonSuccess",
        "is_target": False,
        "weight": 20,
    },
    "twig": {
        "name": "Twig",
        "icon": "minus",
        "color": "buttonWarning",
        "is_target": False,
        "weight": 10,
    },
}

# Round 1 target type
ROUND1_TARGET_TYPE = "berries"

# Round 1 reward - reads from RESOURCES
ROUND1_REWARD_ITEM = "berries"
ROUND1_REWARD_CONFIG = {
    "base_reward": 1,
    "bonus_per_extra_match": 1,
    "reward_item": ROUND1_REWARD_ITEM,
    "reward_item_display_name": _get_resource(ROUND1_REWARD_ITEM).get("display_name"),
    "reward_item_icon": _get_resource(ROUND1_REWARD_ITEM).get("icon"),
    "reward_item_color": _get_resource(ROUND1_REWARD_ITEM).get("color"),
}

# Round 1 probabilities
ROUND1_WIN_CONFIG = {
    "cluster_probability": 0.10,
    "guaranteed_cluster_size": 3,
    "seed_trail_probability": 0.05,
    "seed_trail_cluster_size": 3,
    "seed_trail_tease_probability": 0.20,
}


# ============================================================
# ROUND 2: BONUS ROUND (Seeds + Rare Egg!)
# ============================================================

ROUND2_BUSH_TYPES = {
    "wheat": {
        "name": _get_resource("wheat_seed").get("display_name", "Seed"),
        "icon": _get_resource("wheat_seed").get("icon", "leaf.fill"),
        "color": _get_resource("wheat_seed").get("color", "gold"),
        "is_target": True,
        "weight": 40,
    },
    "rare_egg": {
        "name": _get_resource("rare_egg").get("display_name", "Rare Egg"),
        "icon": _get_resource("rare_egg").get("icon", "oval.fill"),
        "color": _get_resource("rare_egg").get("color", "imperialGold"),
        "is_target": False,
        "is_rare_drop": True,
        "label": "Rare Egg",
        "weight": 0,
    },
    "dirt": {
        "name": "Dirt",
        "icon": "square.fill",
        "color": "brown",
        "is_target": False,
        "weight": 25,
    },
    "pebble": {
        "name": "Pebble",
        "icon": "circle.fill",
        "color": "inkMedium",
        "is_target": False,
        "weight": 20,
    },
    "moss": {
        "name": "Moss",
        "icon": "leaf.circle",
        "color": "buttonSuccess",
        "is_target": False,
        "weight": 15,
    },
}

# Round 2 target type
ROUND2_TARGET_TYPE = "wheat"

# Round 2 reward - reads from RESOURCES
ROUND2_REWARD_ITEM = "wheat_seed"
ROUND2_REWARD_CONFIG = {
    "base_reward": 1,
    "bonus_per_extra_match": 1,
    "reward_item": ROUND2_REWARD_ITEM,
    "reward_item_display_name": _get_resource(ROUND2_REWARD_ITEM).get("display_name"),
    "reward_item_icon": _get_resource(ROUND2_REWARD_ITEM).get("icon"),
    "reward_item_color": _get_resource(ROUND2_REWARD_ITEM).get("color"),
}

# Round 2 probabilities
ROUND2_WIN_CONFIG = {
    "cluster_probability": 0.10,
    "guaranteed_cluster_size": 3,
    "seed_tease_probability": 0.20,
    "egg_tease_probability": 0.10,
}

# Round 2 RARE DROP - reads from RESOURCES
ROUND2_RARE_ITEM = "rare_egg"
ROUND2_RARE_DROP_CONFIG = {
    "probability": 0.01,
    "reward_item": ROUND2_RARE_ITEM,
    "reward_item_display_name": _get_resource(ROUND2_RARE_ITEM).get("display_name"),
    "reward_item_icon": _get_resource(ROUND2_RARE_ITEM).get("icon"),
    "reward_item_color": _get_resource(ROUND2_RARE_ITEM).get("color"),
}


# ============================================================
# LEGACY CONFIG (for backwards compatibility)
# ============================================================

# These map to Round 1 for now
BUSH_TYPES = ROUND1_BUSH_TYPES
TARGET_TYPE = ROUND1_TARGET_TYPE
REWARD_CONFIG = ROUND1_REWARD_CONFIG
WIN_RATE_CONFIG = ROUND1_WIN_CONFIG

# Display config for frontend
BUSH_DISPLAY = [
    {"key": k, "name": v["name"], "icon": v["icon"], "color": v["color"]}
    for k, v in ROUND1_BUSH_TYPES.items()
    if not v.get("is_seed_trail", False)  # Don't show seed_trail in legend
]


# ============================================================
# ANIMATION TIMING (sent to frontend)
# ============================================================

ANIMATION_TIMING = {
    "reveal_delay_ms": 200,        # Delay before bush reveals
    "match_glow_duration_ms": 600, # How long match highlight shows
    "result_delay_ms": 800,        # Delay before showing result
    "warmup_pulse_ms": 300,        # "Warming up" effect duration
    "round_transition_ms": 600,    # Slide out/in for bonus round
}


# ============================================================
# UI STRINGS - ALL from backend, no hardcoding!
# ============================================================

PHASE_CONFIG = {
    "idle": {
        "title": "Foraging",
        "subtitle": "Tap bushes to reveal what's hiding!",
        "instruction": "Find 3 matching to win",
        "button_text": "Start Foraging",
        "button_icon": "leaf.fill",
    },
    "selecting": {
        "title": "Foraging",
        "subtitle": "Tap bushes to reveal!",
        "instruction": "{revealed}/{max} revealed",
        "button_text": None,
        "button_icon": None,
    },
    "revealing": {
        "title": "Revealing...",
        "subtitle": "Checking for matches",
        "instruction": None,
        "button_text": None,
        "button_icon": None,
    },
    "won": {
        "title": "Match Found!",
        "subtitle": "+{reward} {item_name}",
        "instruction": "You found 3 matching {type_name}!",
        "button_text": "Collect",
        "button_icon": "checkmark.circle.fill",
    },
    "lost": {
        "title": "No Match",
        "subtitle": "Better luck next time!",
        "instruction": "You didn't find 3 matching items",
        "button_text": "Try Again",
        "button_icon": "arrow.counterclockwise",
    },
    # Bonus round specific
    "seed_trail_found": {
        "title": "Seed Trail!",
        "subtitle": "You found a trail of seeds...",
        "instruction": "Follow it to the bonus round!",
        "button_text": "Follow Trail",
        "button_icon": "arrow.triangle.turn.up.right.diamond.fill",
    },
    "bonus_round": {
        "title": "BONUS ROUND",
        "subtitle": "Find seeds hidden in the earth!",
        "instruction": "This is your chance for seeds!",
        "button_text": None,
        "button_icon": None,
    },
}


# ============================================================
# GRID DISPLAY CONFIG
# ============================================================

GRID_CONFIG = {
    # Round 1 (berries)
    "bush_hidden_icon": "leaf.fill",
    "bush_hidden_color": "buttonSuccess",
    "bush_selected_color": "gold",
    "match_glow_color": "imperialGold",
    
    # Round 2 (bonus) - different aesthetic
    "bonus_hidden_icon": "sparkle",
    "bonus_hidden_color": "gold",
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_bush_type_weights(round_num: int = 1) -> Dict[str, int]:
    """Get weights for random bush type selection."""
    bush_types = ROUND1_BUSH_TYPES if round_num == 1 else ROUND2_BUSH_TYPES
    return {k: v["weight"] for k, v in bush_types.items() if v["weight"] > 0}


def get_round_config(round_num: int) -> dict:
    """Get configuration for a specific round."""
    if round_num == 1:
        return {
            "bush_types": ROUND1_BUSH_TYPES,
            "target_type": ROUND1_TARGET_TYPE,
            "reward_config": ROUND1_REWARD_CONFIG,
            "win_config": ROUND1_WIN_CONFIG,
            "hidden_icon": GRID_CONFIG["bush_hidden_icon"],
            "hidden_color": GRID_CONFIG["bush_hidden_color"],
        }
    else:
        return {
            "bush_types": ROUND2_BUSH_TYPES,
            "target_type": ROUND2_TARGET_TYPE,
            "reward_config": ROUND2_REWARD_CONFIG,
            "win_config": ROUND2_WIN_CONFIG,
            "hidden_icon": GRID_CONFIG["bonus_hidden_icon"],
            "hidden_color": GRID_CONFIG["bonus_hidden_color"],
        }


def is_target_type(bush_type: str, round_num: int = 1) -> bool:
    """Check if this bush type is the target for the given round."""
    target = ROUND1_TARGET_TYPE if round_num == 1 else ROUND2_TARGET_TYPE
    return bush_type == target


def calculate_reward(match_count: int, round_num: int = 1) -> int:
    """
    Calculate reward for matching.
    
    Args:
        match_count: How many targets found (3, 4, or 5)
        round_num: Which round (1 = berries, 2 = seeds)
    
    Returns:
        Number of items to award
    """
    config = ROUND1_REWARD_CONFIG if round_num == 1 else ROUND2_REWARD_CONFIG
    base = config["base_reward"]
    extra_matches = max(0, match_count - MATCHES_TO_WIN)
    bonus = extra_matches * config["bonus_per_extra_match"]
    
    return base + bonus
