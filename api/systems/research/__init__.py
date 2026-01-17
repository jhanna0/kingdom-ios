"""
RESEARCH SYSTEM
===============
Three-phase minigame for discovering blueprints.
"""

from .config import (
    get_research_config,
    ResearchPhase,
    RESEARCH_GOLD_COST,
    FILL_CONFIG,
    STABILIZE_CONFIG,
    BUILD_CONFIG,
    REWARDS,
)
from .research_manager import ResearchManager

__all__ = [
    "ResearchManager",
    "get_research_config",
    "ResearchPhase",
    "RESEARCH_GOLD_COST",
    "FILL_CONFIG",
    "STABILIZE_CONFIG",
    "BUILD_CONFIG",
    "REWARDS",
]
