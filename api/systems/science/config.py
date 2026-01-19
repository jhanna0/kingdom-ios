"""
SCIENCE MINIGAME CONFIGURATION
==============================
All tunable values for the high/low guessing game in ONE place.

DESIGN:
- Player sees a number (1-100) and guesses HIGH or LOW
- Get it right → streak continues, up to MAX_GUESSES
- Final round awards a blueprint, earlier rounds award gold

Science skill boosts gold rewards.
"""

from typing import Dict
from routers.resources import RESOURCES


# ============================================================
# HELPER: Get item display from RESOURCES
# ============================================================

def _get_resource(item_id: str) -> dict:
    """Get item config from RESOURCES - single source of truth."""
    return RESOURCES.get(item_id, {})


# ============================================================
# GAME CONFIGURATION
# ============================================================

MIN_NUMBER = 1          # Lowest possible number
MAX_NUMBER = 100        # Highest possible number
MAX_GUESSES = 4         # Max rounds - change here to adjust
ENTRY_COST = 10         # Gold cost to start a trial


# ============================================================
# REWARD CONFIGURATION
# ============================================================

def _build_reward_config() -> Dict[int, dict]:
    """
    Build reward config dynamically based on MAX_GUESSES.
    
    Pattern:
    - Rounds 1 to (MAX-1): increasing gold rewards
    - Final round (MAX): blueprint only
    """
    config = {}
    
    for streak in range(1, MAX_GUESSES + 1):
        if streak == MAX_GUESSES:
            # Final round = blueprint
            config[streak] = {
                "gold": 0,
                "gold_per_science_tier": 0,
                "blueprint": 1,
                "message": "EUREKA! A breakthrough discovery!",
            }
        else:
            # Earlier rounds = gold (scales up)
            base_gold = 4 * streak  # 5, 10, 15, 20...
            config[streak] = {
                "gold": base_gold,
                "gold_per_science_tier": streak,  # +1, +2, +3... per science level
                "blueprint": 0,
                "message": "A promising result!" if streak == 1 else "Your hypothesis was correct!",
            }
    
    return config


REWARD_CONFIG = _build_reward_config()

# Blueprint item config (from resources)
BLUEPRINT_ITEM = "blueprint"
BLUEPRINT_CONFIG = {
    "item": BLUEPRINT_ITEM,
    "display_name": _get_resource(BLUEPRINT_ITEM).get("display_name", "Blueprint"),
    "icon": _get_resource(BLUEPRINT_ITEM).get("icon", "doc.fill"),
    "color": _get_resource(BLUEPRINT_ITEM).get("color", "royalBlue"),
}

# Gold item config
GOLD_CONFIG = {
    "item": "gold",
    "display_name": "Gold",
    "icon": "dollarsign.circle.fill",
    "color": "imperialGold",
}


# ============================================================
# UI CONFIGURATION
# ============================================================

# Skill used for this minigame
SKILL_CONFIG = {
    "skill": "science",
    "display_name": "Science",
    "icon": "flask.fill",
}

# Display strings
UI_STRINGS = {
    "title": "THE LABORATORY",
    "subtitle": "Test your scientific intuition!",
    "instruction": "Will the next number be HIGHER or LOWER?",
    "streak_label": "Streak",
    "high_button": "HIGHER",
    "low_button": "LOWER",
    "correct": "Correct!",
    "wrong": "Wrong! The number was {number}",
    "collect_prompt": "Collect your reward or risk it all?",
    "final_win": "Perfect prediction! You've earned a Blueprint!",
}

# Visual theming
THEME_CONFIG = {
    "background_color": "parchmentDark",
    "card_color": "parchment",
    "accent_color": "royalBlue",
    "number_color": "inkDark",
    "streak_colors": {
        0: "inkMedium",
        1: "buttonSuccess",
        2: "imperialGold",
        3: "royalBlue",
    },
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_reward_for_streak(streak: int, science_level: int = 0) -> dict:
    """
    Get reward configuration for a given streak.
    
    Args:
        streak: Number of correct guesses (1, 2, or 3)
        science_level: Player's science skill level
    
    Returns:
        Dict with gold, blueprint, and message
    """
    if streak not in REWARD_CONFIG:
        return {"gold": 0, "blueprint": 0, "message": "No reward"}
    
    config = REWARD_CONFIG[streak]
    base_gold = config["gold"]
    bonus_gold = config["gold_per_science_tier"] * science_level
    
    return {
        "gold": base_gold + bonus_gold,
        "blueprint": config["blueprint"],
        "message": config["message"],
    }


def get_science_probabilities(science_level: int = 0) -> dict:
    """
    Get any probability adjustments based on science skill.
    
    Currently, science just boosts gold rewards.
    Could add things like:
    - Hint about the next number range
    - Better odds on edge cases
    - etc.
    """
    return {
        "gold_multiplier": 1.0 + (science_level * 0.1),  # +10% gold per level
        "hint_enabled": science_level >= 3,  # Could show hints at T3+
    }


def calculate_gold_reward(streak: int, science_level: int = 0) -> int:
    """Calculate total gold reward including science bonus."""
    if streak not in REWARD_CONFIG:
        return 0
    
    config = REWARD_CONFIG[streak]
    base = config["gold"]
    bonus = config["gold_per_science_tier"] * science_level
    return base + bonus
