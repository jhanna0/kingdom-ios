"""
RESEARCH SYSTEM
"""

from .config import (
    get_research_config,
    ResearchPhase,
    RESEARCH_GOLD_COST,
    FILL_CONFIG,
    COOKING_CONFIG,
)
from .research_manager import ResearchManager

__all__ = [
    "ResearchManager",
    "get_research_config",
    "ResearchPhase",
    "RESEARCH_GOLD_COST",
    "FILL_CONFIG",
    "COOKING_CONFIG",
]
