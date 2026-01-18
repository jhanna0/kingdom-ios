"""
FORAGING SYSTEM
===============
Scratch-ticket style minigame where players reveal bushes to find wheat.
Find 3 wheat to win!
"""

from .config import (
    GRID_SIZE,
    MAX_REVEALS,
    MATCHES_TO_WIN,
    BUSH_TYPES,
    BUSH_DISPLAY,
    REWARD_CONFIG,
    ANIMATION_TIMING,
    PHASE_CONFIG,
    TARGET_TYPE,
)
from .foraging_manager import ForagingManager, ForagingSession

__all__ = [
    "GRID_SIZE",
    "MAX_REVEALS",
    "MATCHES_TO_WIN",
    "BUSH_TYPES",
    "BUSH_DISPLAY",
    "REWARD_CONFIG",
    "ANIMATION_TIMING",
    "PHASE_CONFIG",
    "TARGET_TYPE",
    "ForagingManager",
    "ForagingSession",
]
