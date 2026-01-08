"""
DEPRECATED: Use action_config.py instead
This file is kept for backwards compatibility during migration
"""

# Import all constants from the new centralized config
from .action_config import (
    WORK_BASE_COOLDOWN,
    PATROL_COOLDOWN,
    FARM_COOLDOWN,
    SABOTAGE_COOLDOWN,
    TRAINING_COOLDOWN,
    CRAFTING_BASE_COOLDOWN,
    SCOUT_COOLDOWN,
    SCOUT_COST,
    HEIST_PERCENT,
    MIN_HEIST_AMOUNT,
    FARM_GOLD_REWARD,
    PATROL_GOLD_REWARD,
    PATROL_REPUTATION_REWARD,
    PATROL_DURATION_MINUTES
)

