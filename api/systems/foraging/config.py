"""
FORAGING SYSTEM CONFIGURATION
=============================
All tunable values for the foraging minigame in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

DESIGN:
- 4x4 grid of bushes (16 total)
- Player reveals up to 5 bushes
- Match 3 of the same type to win
- Backend pre-calculates entire grid before session starts
- Frontend just "reveals" for theatrical effect

KEY: Backend has ALL the strings, odds, rewards, colors.
Frontend is a DUMB RENDERER.
"""

from typing import Dict, List


# ============================================================
# GRID CONFIGURATION
# ============================================================

GRID_SIZE = 4           # 4x4 grid = 16 bushes
MAX_REVEALS = 5         # Player can reveal up to 5 bushes
MATCHES_TO_WIN = 3      # Need 3 matching to win


# ============================================================
# BUSH TYPES - What's hiding under each bush
# ============================================================
# Each bush type has:
# - name: Display name
# - icon: SF Symbol
# - color: Theme color name (mapped in iOS)
# - reward_multiplier: Multiplies base reward
# - weight: Probability weight for placement

BUSH_TYPES = {
    "wheat": {
        "name": "Seed",
        "icon": "circle.fill",
        "color": "gold",
        "is_target": True,  # This is what we're looking for!
        "weight": 40,
    },
    "rock": {
        "name": "Rock",
        "icon": "circle.fill",
        "color": "inkMedium",
        "is_target": False,  # Distraction
        "weight": 25,
    },
    "weed": {
        "name": "Weed",
        "icon": "leaf",
        "color": "buttonSuccess",
        "is_target": False,  # Distraction
        "weight": 20,
    },
    "twig": {
        "name": "Twig",
        "icon": "minus",
        "color": "buttonWarning",
        "is_target": False,  # Distraction
        "weight": 15,
    },
}

# Display config for frontend - ONLY what it needs to render
# Backend logic (weight, is_target, etc) stays in BUSH_TYPES
BUSH_DISPLAY = [
    {"key": k, "name": v["name"], "icon": v["icon"], "color": v["color"]}
    for k, v in BUSH_TYPES.items()
]

# The target type to match for a win
TARGET_TYPE = "wheat"


# ============================================================
# REWARD CONFIGURATION
# ============================================================

REWARD_CONFIG = {
    # Base wheat_seed reward for a 3-match
    "base_reward": 1,
    
    # Bonus per additional match beyond 3 (if you get 4 or 5 matches)
    "bonus_per_extra_match": 1,
    
    # Item rewarded
    "reward_item": "wheat_seed",
    "reward_item_display_name": "Wheat Seed",
    "reward_item_icon": "circle.fill",
    "reward_item_color": "gold",
}


# ============================================================
# WIN PROBABILITY TUNING - EASY TO ADJUST!
# ============================================================
# This is the MAIN knob to control win rate.
# 
# How it works:
# - Each game, we roll to see if we "seed" a guaranteed winning cluster of wheat
# - If seeded, player CAN win (but still needs to find the wheat)
# - If not seeded, grid is random and winning is very unlikely
#
# Examples:
#   0.10 = ~10% win rate (hard, good for valuable rewards)
#   0.25 = ~25% win rate (moderate)
#   0.50 = ~50% win rate (casual/easy)
#   0.65 = ~65% win rate (very easy)

WIN_RATE_CONFIG = {
    # ⚠️ MAIN TUNING KNOB - Chance to seed a winnable grid
    "cluster_probability": 0.10,   # 10% chance = ~10% win rate
    
    # How many wheat to guarantee when seeded (should match MATCHES_TO_WIN)
    "guaranteed_cluster_size": 3,
}


# ============================================================
# ANIMATION TIMING (sent to frontend)
# ============================================================

ANIMATION_TIMING = {
    "reveal_delay_ms": 200,        # Delay before bush reveals
    "match_glow_duration_ms": 600, # How long match highlight shows
    "result_delay_ms": 800,        # Delay before showing result
    "warmup_pulse_ms": 300,        # "Warming up" effect duration
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
        "instruction": "{revealed}/{max} revealed",  # Formatted by backend
        "button_text": None,  # No button during selection
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
        "subtitle": "+{reward} {item_name}",  # Formatted by backend
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
}


# ============================================================
# GRID DISPLAY CONFIG
# ============================================================

GRID_CONFIG = {
    "bush_hidden_icon": "leaf.fill",         # Green leaf for unrevealed bushes
    "bush_hidden_color": "buttonSuccess",    # Green color
    "bush_selected_color": "gold",
    "match_glow_color": "imperialGold",
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_bush_type_weights() -> Dict[str, int]:
    """Get weights for random bush type selection."""
    return {k: v["weight"] for k, v in BUSH_TYPES.items()}


def is_target_type(bush_type: str) -> bool:
    """Check if this bush type is the target (wheat)."""
    return bush_type == TARGET_TYPE


def calculate_reward(match_count: int) -> int:
    """
    Calculate wheat_seed reward for finding wheat.
    
    Args:
        match_count: How many wheat found (3, 4, or 5)
    
    Returns:
        Number of wheat_seed to award
    """
    base = REWARD_CONFIG["base_reward"]
    extra_matches = max(0, match_count - MATCHES_TO_WIN)
    bonus = extra_matches * REWARD_CONFIG["bonus_per_extra_match"]
    
    return base + bonus
