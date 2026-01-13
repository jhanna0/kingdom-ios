"""
Duel System - 1v1 PvP Combat in Town Hall
"""
from .config import (
    DUEL_HIT_MULTIPLIER,
    DUEL_CRITICAL_MULTIPLIER,
    DUEL_PUSH_BASE,
    DUEL_TURN_TIMEOUT_SECONDS,
    DUEL_INVITATION_TIMEOUT_MINUTES,
    calculate_duel_hit_chance,
    calculate_duel_push,
)
from .duel_manager import DuelManager

__all__ = [
    "DuelManager",
    "DUEL_HIT_MULTIPLIER",
    "DUEL_CRITICAL_MULTIPLIER",
    "DUEL_PUSH_BASE",
    "DUEL_TURN_TIMEOUT_SECONDS",
    "DUEL_INVITATION_TIMEOUT_MINUTES",
    "calculate_duel_hit_chance",
    "calculate_duel_push",
]
