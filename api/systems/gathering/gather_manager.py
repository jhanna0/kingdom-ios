"""
GATHER MANAGER
==============
Handles resource gathering roll execution.
Simple and stateless - each gather is independent.
"""

import random
from dataclasses import dataclass
from typing import Optional

from .config import (
    RESOURCE_TYPES,
    GATHER_TIERS,
    TIER_ORDER,
    TIER_PROBABILITIES,
    BLACK_REDUCTION_PER_LEVEL,
    BROWN_REDUCTION_PER_LEVEL,
    GOLD_INCREASE_PER_LEVEL,
)


@dataclass
class GatherResult:
    """Result of a single gather action"""
    resource_type: str       # "wood" or "iron"
    tier: str                # "black", "brown", "green", "gold"
    amount: int              # 0, 1, 2, or 3
    color: str               # Hex color for frontend
    message: str             # Display message
    new_total: int           # Player's new total after gathering
    haptic: Optional[str]    # "medium", "heavy", or None
    
    def to_dict(self) -> dict:
        """Convert to JSON-serializable dict"""
        resource_config = RESOURCE_TYPES.get(self.resource_type, {})
        return {
            "success": True,
            "resource_type": self.resource_type,
            "resource_name": resource_config.get("name", self.resource_type),
            "resource_icon": resource_config.get("icon", "questionmark"),
            "tier": self.tier,
            "amount": self.amount,
            "color": self.color,
            "message": self.message,
            "new_total": self.new_total,
            "haptic": self.haptic,
        }


class GatherManager:
    """
    Manages resource gathering rolls.
    
    Stateless - each gather is an independent roll.
    Uses simple weighted random for tier selection.
    
    Usage:
        manager = GatherManager()
        result = manager.gather("wood", current_wood=50)
        # result.amount = how much gathered (0-3)
        # result.tier = "black"/"brown"/"green"/"gold"
    """
    
    def __init__(self, seed: Optional[int] = None):
        """
        Initialize the gather manager.
        
        Args:
            seed: Optional random seed for testing
        """
        self.rng = random.Random(seed)
    
    def gather(self, resource_type: str, current_amount: int = 0, building_level: int = 1) -> GatherResult:
        """
        Execute a single gather action.
        
        Args:
            resource_type: "wood", "stone", or "iron"
            current_amount: Player's current amount of this resource
            building_level: Level of the relevant building (lumbermill for wood, mine for stone/iron)
            
        Returns:
            GatherResult with tier, amount, and new total
        """
        # Validate resource type
        if resource_type not in RESOURCE_TYPES:
            raise ValueError(f"Invalid resource type: {resource_type}")
        
        # Roll for tier (building level affects probabilities)
        tier = self._roll_tier(building_level)
        tier_config = GATHER_TIERS[tier]
        
        # Calculate new total
        amount = tier_config["amount"]
        new_total = current_amount + amount
        
        return GatherResult(
            resource_type=resource_type,
            tier=tier,
            amount=amount,
            color=tier_config["color"],
            message=tier_config["message"],
            new_total=new_total,
            haptic=tier_config.get("haptic"),
        )
    
    def _roll_tier(self, building_level: int = 1) -> str:
        """
        Roll for a gather tier using weighted random.
        
        Building level affects probabilities:
        - Level 1: 15% black, 45% brown, 35% green, 5% gold
        - Level 5: 0% black, 35% brown, 50% green, 15% gold
        Each level above 1:
          - Reduces black by 3.75% (until 0%)
          - Reduces brown by 2.5%
          - Increases green by 3.75%
          - Increases gold by 2.5%
        
        Args:
            building_level: Level of the building (1-5)
            
        Returns:
            Tier name: "black", "brown", "green", or "gold"
        """
        # Clamp building level to valid range
        level = max(1, min(5, building_level))
        
        # Calculate adjusted probabilities based on building level
        levels_above_base = level - 1
        black_reduction = levels_above_base * BLACK_REDUCTION_PER_LEVEL
        brown_reduction = levels_above_base * BROWN_REDUCTION_PER_LEVEL
        gold_increase = levels_above_base * GOLD_INCREASE_PER_LEVEL
        
        adjusted_probs = {
            "black": max(0, TIER_PROBABILITIES["black"] - black_reduction),
            "brown": TIER_PROBABILITIES["brown"] - brown_reduction,
            "green": TIER_PROBABILITIES["green"] + black_reduction,
            "gold": TIER_PROBABILITIES["gold"] + gold_increase,
        }
        
        roll = self.rng.random()  # 0.0 to 1.0
        
        cumulative = 0.0
        for tier in TIER_ORDER:
            cumulative += adjusted_probs[tier]
            if roll < cumulative:
                return tier
        
        # Fallback (shouldn't happen if probabilities sum to 1.0)
        return TIER_ORDER[-1]
    
    def get_resource_info(self, resource_type: str) -> Optional[dict]:
        """Get info about a resource type for display"""
        return RESOURCE_TYPES.get(resource_type)


# Singleton instance for convenience
_default_manager = None

def get_gather_manager() -> GatherManager:
    """Get the default gather manager instance"""
    global _default_manager
    if _default_manager is None:
        _default_manager = GatherManager()
    return _default_manager
