"""
GATHERING SYSTEM
================
Simple click-to-gather resource collection.
Players tap to gather wood (trees) or iron (rocks).
Each tap rolls for 0-3 resources with color-coded feedback.
"""

from .config import (
    RESOURCE_TYPES,
    GATHER_TIERS,
    TIER_PROBABILITIES,
    GatherConfig,
)
from .gather_manager import GatherManager, GatherResult

__all__ = [
    "RESOURCE_TYPES",
    "GATHER_TIERS",
    "TIER_PROBABILITIES",
    "GatherConfig",
    "GatherManager",
    "GatherResult",
]
