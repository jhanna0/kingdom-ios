"""
FISHING SYSTEM
==============
A chill, single-screen fishing minigame.
- Building stat affects Cast phase (finding fish)
- Defense stat affects Reel phase (landing fish)
- Rewards: Meat + rare Pet Fish trophy
"""

from .config import (
    FISH,
    CAST_DROP_TABLE,
    CAST_SHIFT_PER_SUCCESS,
    get_reel_drop_table,
    REEL_SHIFT_PER_SUCCESS,
    FishingPhase,
)
from .fishing_manager import FishingManager, FishingSession
