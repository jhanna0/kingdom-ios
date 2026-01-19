"""
RESEARCH SYSTEM CONFIGURATION
=============================
Phase 1: PREPARATION - Measure and mix reagents (science stat)
Phase 2: SYNTHESIS - Purify the mixture through infusions (philosophy stat)
         Each infusion raises purity. Final purity = your result tier.

ALL CONFIG SENT TO FRONTEND - NO HARDCODING ON CLIENT.

THEMATIC LANGUAGE:
- "roll" -> "infusion"
- "hit/miss" -> "stable/volatile"  
- "floor" -> "purity"
- "ceiling" -> "potential"
- "FAIL" -> "UNSTABLE"
- "SUCCESS" -> "STABLE"
- "CRITICAL" -> "EUREKA"
"""

from enum import Enum


RESEARCH_GOLD_COST = 25


# Phase 1: Preparation (filling reagent tubes)
PREPARATION_CONFIG = {
    "stat": "science",
    "stat_display_name": "Science",
    "base_infusions": 2,
    "infusions_per_stat": 1,
    "stable_threshold": 55,         # 55+ = stable reaction
    "stable_fill_amount": 0.22,     # Stable adds more
    "volatile_fill_amount": 0.08,   # Volatile still adds something
    "reagent_names": ["ESSENCE", "COMPOUND", "CATALYST"],
    
    # Feedback for frontend
    "stable_label": "Stable",
    "volatile_label": "Volatile",
}


# Phase 2: Synthesis (crystallization/purification)
SYNTHESIS_CONFIG = {
    "stat": "philosophy", 
    "stat_display_name": "Philosophy",
    "base_infusions": 3,            # Keep it snappy
    "infusions_per_stat": 1,        # +1 per philosophy
    "stable_threshold": 45,         # Lower = more stable reactions
    
    # Purity gains - NO GAPS! Every stable infusion gives something
    # Higher quality infusions give more purity
    "purity_gains": [
        {"min_value": 45, "max_value": 54, "gain_min": 4, "gain_max": 7, "quality": "weak"},
        {"min_value": 55, "max_value": 64, "gain_min": 7, "gain_max": 11, "quality": "fair"},
        {"min_value": 65, "max_value": 74, "gain_min": 11, "gain_max": 15, "quality": "good"},
        {"min_value": 75, "max_value": 84, "gain_min": 15, "gain_max": 19, "quality": "strong"},
        {"min_value": 85, "max_value": 100, "gain_min": 19, "gain_max": 25, "quality": "perfect"},
    ],
    
    # Even volatile reactions give tiny progress (never feel stuck)
    "volatile_purity_gain": 2,
    
    # FINAL INFUSION - dramatic ending with boosted stakes
    "final_infusion": {
        "enabled": True,
        "gain_multiplier": 1.5,     # Final infusion gains are 1.5x
        "label": "Final Synthesis",
        "description": "One last infusion to seal the compound...",
    },
    
    # Progressive feedback messages for frontend
    "progress_messages": {
        "starting": "Beginning synthesis...",
        "low": "Mixture unstable...",
        "warming": "Crystals forming...",
        "close": "Almost pure!",
        "excellent": "Purity rising!",
    },
    
    # Result tiers - thematic names, easier thresholds
    "result_tiers": [
        {
            "id": "eureka",
            "min_purity": 75,
            "max_purity": 100,
            "label": "EUREKA",
            "title": "Breakthrough!",
            "description": "A rare discovery emerges from the mixture!",
            "blueprints": 2,
            "gp_min": 10,
            "gp_max": 20,
            "color": "imperialGold",
            "icon": "sparkles",
        },
        {
            "id": "stable",
            "min_purity": 50,
            "max_purity": 74,
            "label": "STABLE",
            "title": "Compound Achieved",
            "description": "The synthesis yields a stable compound.",
            "blueprints": 1,
            "gp_min": 2,
            "gp_max": 8,
            "color": "buttonSuccess",
            "icon": "checkmark.seal.fill",
        },
        {
            "id": "unstable",
            "min_purity": 0,
            "max_purity": 49,
            "label": "UNSTABLE",
            "title": "Mixture Dissipated",
            "description": "The compound couldn't hold together.",
            "blueprints": 0,
            "gp_min": 5,
            "gp_max": 12,
            "color": "inkMedium",
            "icon": "wind",
        },
    ],
    
    # Thematic labels for frontend
    "stable_label": "Stable",
    "volatile_label": "Volatile",
    "purity_label": "Purity",
    "potential_label": "Potential",
}


class ResearchPhase(Enum):
    IDLE = "idle"
    PREPARATION = "preparation"     # Was "filling"
    SYNTHESIS = "synthesis"         # Was "cooking"  
    FINAL = "final"                 # NEW: final dramatic infusion
    COMPLETE = "complete"


def get_research_config():
    """Full config for frontend."""
    return {
        "gold_cost": RESEARCH_GOLD_COST,
        "phase1_preparation": PREPARATION_CONFIG,
        "phase2_synthesis": SYNTHESIS_CONFIG,
    }
