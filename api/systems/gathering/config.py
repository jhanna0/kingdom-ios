"""
GATHERING SYSTEM CONFIGURATION
==============================
All tunable values for the gathering system in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

TIERS (color-coded results):
- BLACK (nothing): Failed gather, 0 resources
- BROWN (common): Basic gather, 1 resource
- GREEN (good): Good gather, 2 resources
- GOLD (jackpot): Lucky gather, 3 resources
"""

from typing import Dict, List
from dataclasses import dataclass


# ============================================================
# RESOURCE TYPE DEFINITIONS
# ============================================================
# Each resource has an icon (SF Symbol) and display name
# Resources are stored in player_inventory table (not PlayerState columns)

RESOURCE_TYPES = {
    "wood": {
        "id": "wood",
        "name": "Wood",
        "icon": "tree.fill",
        "description": "Chop trees for lumber",
        "item_id": "wood",       # Item ID in player_inventory table
        "visual_type": "tree",   # Frontend uses this to pick shape/animation
        "action_verb": "Chop",   # Frontend displays "Chop Wood"
    },
    "stone": {
        "id": "stone",
        "name": "Stone",
        "icon": "square.stack.3d.up.fill",
        "description": "Quarry rocks for stone",
        "item_id": "stone",      # Item ID in player_inventory table
        "visual_type": "rock",   # Frontend uses this to pick shape/animation
        "action_verb": "Mine",   # Frontend displays "Mine Stone"
    },
    "iron": {
        "id": "iron",
        "name": "Iron",
        "icon": "mountain.2.fill",
        "description": "Mine rocks for ore",
        "item_id": "iron",       # Item ID in player_inventory table
        "visual_type": "rock",   # Frontend uses this to pick shape/animation
        "action_verb": "Mine",   # Frontend displays "Mine Iron"
    },
}


# ============================================================
# GATHER TIER DEFINITIONS
# ============================================================
# Each tier has a color (for frontend display) and amount

GATHER_TIERS = {
    "black": {
        "name": "Nothing",
        "amount": 0,
        "color": "inkDark",       # Theme: black
        "message": "Nothing found...",
        "haptic": None,
    },
    "brown": {
        "name": "Common",
        "amount": 1,
        "color": "buttonPrimary", # Theme: primary brown
        "message": "Found some!",
        "haptic": "medium",
    },
    "green": {
        "name": "Good",
        "amount": 2,
        "color": "buttonSuccess", # Theme: success green
        "message": "Nice find!",
        "haptic": "heavy",
    },
    "gold": {
        "name": "Jackpot",
        "amount": 3,
        "color": "buttonWarning", # Theme: warning gold
        "message": "Jackpot!",
        "haptic": "heavy",
    },
}

# Order matters for probability calculation (cumulative)
TIER_ORDER = ["black", "brown", "green", "gold"]


# ============================================================
# TIER PROBABILITIES
# ============================================================
# Base probabilities for each tier (must sum to 1.0)

TIER_PROBABILITIES = {
    "black": 0.15,   # 15% chance - nothing
    "brown": 0.45,   # 45% chance - 1 resource
    "green": 0.35,   # 35% chance - 2 resources
    "gold": 0.05,    # 5% chance - 3 resources
}


# ============================================================
# BUILDING LEVEL PROBABILITY SCALING
# ============================================================
# Higher building level reduces black/brown chance and increases green/gold chance
# Level 1: 15% black, 45% brown, 35% green, 5% gold
# Level 5: 0% black, 35% brown, 50% green, 15% gold
# Each level above 1:
#   - Removes 3.75% from black (until 0%)
#   - Removes 2.5% from brown
#   - Adds 3.75% to green
#   - Adds 2.5% to gold

BLACK_REDUCTION_PER_LEVEL = 0.0375  # 3.75% reduction per level above 1
BROWN_REDUCTION_PER_LEVEL = 0.025   # 2.5% reduction per level above 1
GOLD_INCREASE_PER_LEVEL = 0.025     # 2.5% increase per level above 1


# ============================================================
# CONFIG CLASS
# ============================================================

@dataclass
class GatherConfig:
    """Programmatic access to gathering configuration"""
    
    RESOURCES = RESOURCE_TYPES
    TIERS = GATHER_TIERS
    TIER_ORDER = TIER_ORDER
    PROBABILITIES = TIER_PROBABILITIES
    
    @classmethod
    def get_resource(cls, resource_type: str) -> dict:
        """Get resource config by type"""
        return cls.RESOURCES.get(resource_type)
    
    @classmethod
    def get_tier(cls, tier_name: str) -> dict:
        """Get tier config by name"""
        return cls.TIERS.get(tier_name)
    
    @classmethod
    def get_all_resources(cls) -> List[dict]:
        """Get all resource configs for frontend"""
        return [
            {
                "id": r["id"],
                "name": r["name"],
                "icon": r["icon"],
                "description": r["description"],
                "visual_type": r["visual_type"],
                "action_verb": r["action_verb"],
            }
            for r in cls.RESOURCES.values()
        ]
    
    @classmethod
    def get_tier_display_info(cls) -> List[dict]:
        """Get tier info for frontend legend display"""
        return [
            {
                "tier": tier,
                "name": cls.TIERS[tier]["name"],
                "amount": cls.TIERS[tier]["amount"],
                "color": cls.TIERS[tier]["color"],
                "probability": int(cls.PROBABILITIES[tier] * 100),
            }
            for tier in cls.TIER_ORDER
        ]
