"""
RESEARCH SYSTEM CONFIGURATION
=============================
Phase 1: Fill tube via mini bars (science stat affects rolls)
Phase 2: Land marker within filled range (philosophy stat affects attempts)

ALL CONFIG SENT TO FRONTEND - NO HARDCODING ON CLIENT.
"""

from enum import Enum


RESEARCH_GOLD_COST = 25


FILL_CONFIG = {
    "stat": "science",
    "stat_display_name": "Science",
    "base_rolls": 2,
    "rolls_per_stat": 1,
    "hit_threshold": 61,
    "hit_fill_amount": 0.20,
    "miss_fill_amount": 0.05,
    "mini_bar_names": ["COMPOSURE", "CALCULATION", "PRECISION"],
}


COOKING_CONFIG = {
    "stat": "philosophy", 
    "stat_display_name": "Philosophy",
    "base_attempts": 1,
    "attempts_per_stat": 1,
    "reward_tiers": [
        {
            "id": "critical",
            "min_percent": 80,
            "max_percent": 100,
            "label": "CRITICAL",
            "description": "Rare Discovery!",
            "blueprints": 2,
            "gp_min": 10,
            "gp_max": 20,
        },
        {
            "id": "success",
            "min_percent": 60,
            "max_percent": 79,
            "label": "SUCCESS",
            "description": "Blueprint Discovered",
            "blueprints": 1,
            "gp_min": 0,
            "gp_max": 5,
        },
        {
            "id": "fail",
            "min_percent": 0,
            "max_percent": 59,
            "label": "FAIL",
            "description": "Reagent quality too low",
            "blueprints": 0,
            "gp_min": 8,
            "gp_max": 15,
        },
    ],
}


class ResearchPhase(Enum):
    IDLE = "idle"
    FILLING = "filling"
    COOKING = "cooking"
    COMPLETE = "complete"


def get_research_config():
    """Full config for frontend."""
    return {
        "gold_cost": RESEARCH_GOLD_COST,
        "phase1_fill": FILL_CONFIG,
        "phase2_cooking": COOKING_CONFIG,
    }
