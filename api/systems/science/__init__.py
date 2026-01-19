"""
SCIENCE MINIGAME SYSTEM
=======================
High/Low guessing game that tests your scientific intuition!

Player sees a number and guesses if the next will be higher or lower.
Get 1 right → Gold, 2 right → More gold, 3 right → Blueprint!
"""

from .science_manager import ScienceManager, get_manager
from .config import (
    MIN_NUMBER,
    MAX_NUMBER,
    MAX_GUESSES,
    REWARD_CONFIG,
    get_science_probabilities,
)
