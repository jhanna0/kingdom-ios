"""
RESEARCH SYSTEM
===============
Phase 1: PREPARATION - Measure and mix reagents
Phase 2: SYNTHESIS - Purify through infusions
"""

from .config import (
    get_research_config,
    ResearchPhase,
    RESEARCH_GOLD_COST,
    PREPARATION_CONFIG,
    SYNTHESIS_CONFIG,
)
from .research_manager import ResearchManager

__all__ = [
    "ResearchManager",
    "get_research_config",
    "ResearchPhase",
    "RESEARCH_GOLD_COST",
    "PREPARATION_CONFIG",
    "SYNTHESIS_CONFIG",
]
