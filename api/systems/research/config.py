"""
RESEARCH SYSTEM CONFIGURATION
=============================
Three-phase minigame to discover blueprints.

PHASE 1: FILL (Science stat)
- Multiple pours fill the test tube
- Each roll = one pour, HIT = more liquid
- Need to reach minimum fill level to proceed

PHASE 2: STABILIZE (Philosophy stat)  
- Liquid bubbles and shakes
- Rolls determine if mixture stabilizes or explodes
- Visual: bubbling then settling or boom

PHASE 3: BUILD (Building stat)
- Tap to construct the invention
- Backend pre-calculates all tap results
- Frontend animates as user taps

Backend calculates ALL outcomes. Frontend just animates.
"""

from enum import Enum


# ============================================================
# TIMING - Frontend uses these for animation pacing
# ============================================================

POUR_ANIMATION_MS = 1500      # Time per pour animation
STABILIZE_ANIMATION_MS = 3000  # Time for stabilize phase
TAP_ANIMATION_MS = 200        # Time per tap result


# ============================================================
# COST
# ============================================================

RESEARCH_GOLD_COST = 25


# ============================================================
# PHASE 1: FILL
# ============================================================
# Each roll = one pour. HIT = big pour, MISS = small pour.
# Total fill level determines if you can proceed.

FILL_CONFIG = {
    "stat": "science",
    "stat_display_name": "Science",
    "base_rolls": 5,           # Everyone gets 5 pours minimum
    "rolls_per_stat": 1,       # +1 pour per Science level
    "hit_chance": 0.40,        # 40% chance per pour to be a "good" pour
    "hit_fill_amount": 0.15,   # Good pour adds 15% fill
    "miss_fill_amount": 0.05,  # Bad pour adds 5% fill
    "min_fill_to_proceed": 0.50,  # Need 50% fill to proceed to phase 2
    "phase_color": "royalBlue",
}


# ============================================================
# PHASE 2: STABILIZE
# ============================================================
# Liquid bubbles. Rolls determine if it stabilizes.
# If total hits >= threshold, it stabilizes. Otherwise boom.

STABILIZE_CONFIG = {
    "stat": "philosophy", 
    "stat_display_name": "Philosophy",
    "base_rolls": 3,           # Everyone gets 3 stabilize attempts
    "rolls_per_stat": 1,       # +1 attempt per Philosophy level
    "hit_chance": 0.35,        # 35% chance per roll
    "hits_needed": 1,          # Need at least 1 hit to stabilize
    "phase_color": "buttonWarning",
}


# ============================================================
# PHASE 3: BUILD  
# ============================================================
# User taps to build. Backend pre-calculates all tap outcomes.
# Each tap = one chance to progress. Need enough progress to succeed.

BUILD_CONFIG = {
    "stat": "building_skill",
    "stat_display_name": "Building", 
    "base_taps": 8,            # Everyone gets 8 taps
    "taps_per_stat": 2,        # +2 taps per Building level
    "hit_chance": 0.45,        # 45% chance per tap to progress
    "progress_per_hit": 15,    # Each hit = 15% progress
    "progress_needed": 100,    # Need 100% to succeed
    "phase_color": "buttonSuccess",
}


# ============================================================
# REWARDS
# ============================================================

REWARDS = {
    "fail_phase1": {
        "blueprints": 0,
        "gp_min": 5,
        "gp_max": 10,
        "message": "Not enough reagent collected.",
    },
    "fail_phase2": {
        "blueprints": 0,
        "gp_min": 8,
        "gp_max": 15,
        "message": "BOOM! The mixture exploded.",
    },
    "fail_phase3": {
        "blueprints": 0,
        "gp_min": 12,
        "gp_max": 20,
        "message": "Couldn't complete the invention.",
    },
    "success": {
        "blueprints": 1,
        "gp_min": 0,
        "gp_max": 5,
        "message": "Blueprint discovered!",
    },
    "critical": {
        "blueprints": 2,
        "gp_min": 10,
        "gp_max": 20,
        "message": "BREAKTHROUGH! Rare discovery!",
    },
}

# Critical success if all 3 phases had above-average performance
CRITICAL_THRESHOLD = 0.7  # 70%+ success rate across phases = critical


# ============================================================
# PHASES ENUM
# ============================================================

class ResearchPhase(Enum):
    IDLE = "idle"
    FILLING = "filling"
    STABILIZING = "stabilizing"
    BUILDING = "building"
    COMPLETE = "complete"


# ============================================================
# MASTER CONFIG (sent to frontend)
# ============================================================

def get_research_config():
    """Get full config for frontend."""
    return {
        "gold_cost": RESEARCH_GOLD_COST,
        "phases": {
            "fill": {
                **FILL_CONFIG,
                "animation_ms": POUR_ANIMATION_MS,
            },
            "stabilize": {
                **STABILIZE_CONFIG,
                "animation_ms": STABILIZE_ANIMATION_MS,
            },
            "build": {
                **BUILD_CONFIG,
                "animation_ms": TAP_ANIMATION_MS,
            },
        },
        "rewards": REWARDS,
        "ui": {
            "title": "Research Lab",
            "icon": "flask.fill",
        },
    }
