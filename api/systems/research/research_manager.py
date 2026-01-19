"""
RESEARCH MANAGER
================
Phase 1: 3 mini bars - each fills then selects reagent amount
Phase 2: CRYSTALLIZATION - Rolls raise floor threshold, higher rolls = more gain
         Final floor = your result tier.

ALL CONFIG IS SENT TO FRONTEND - NO HARDCODING ON CLIENT.
"""

import random
from dataclasses import dataclass
from typing import List, Optional

from .config import (
    FILL_CONFIG,
    COOKING_CONFIG,
)


@dataclass
class MiniRoll:
    """One roll on a mini bar."""
    roll: int           # 1-100
    hit: bool
    fill_added: float   # How much this roll added
    total_fill: float   # Total fill after this roll


@dataclass
class MiniBarResult:
    """Result for one mini bar."""
    name: str
    rolls: List[MiniRoll]
    final_fill: float       # Fill level after rolls (0-1)
    reagent_select: int     # Selected reagent amount (1 to final_fill%)
    contribution: float     # How much this contributes to main tube (0-1)
    
    def to_dict(self):
        return {
            "name": self.name,
            "rolls": [
                {
                    "roll": r.roll,
                    "hit": r.hit,
                    "fill_added": round(r.fill_added, 3),
                    "total_fill": round(r.total_fill, 3),
                }
                for r in self.rolls
            ],
            "final_fill": round(self.final_fill, 3),
            "reagent_select": self.reagent_select,
            "contribution": round(self.contribution, 3),
        }


@dataclass
class CrystallizationRoll:
    """One roll in the crystallization phase."""
    roll: int           # 1-100
    hit: bool           # Did it meet threshold?
    floor_gain: int     # How much floor raised (0 if miss)
    floor_after: int    # Floor level after this roll
    
    def to_dict(self):
        return {
            "roll": self.roll,
            "hit": self.hit,
            "floor_gain": self.floor_gain,
            "floor_after": self.floor_after,
        }


@dataclass
class ResearchResult:
    """Complete research result."""
    # Phase 1: Fill
    mini_bars: List[MiniBarResult]
    main_tube_fill: float
    
    # Phase 2: Crystallization
    crystal_rolls: List[CrystallizationRoll]
    final_floor: int        # Best floor reached (floor only goes up)
    ceiling: int            # Max possible (from Phase 1 fill)
    total_rolls: int
    landed_tier_id: Optional[str]
    
    # Outcome
    success: bool
    is_critical: bool
    blueprints: int
    gp: int
    message: str
    
    def to_dict(self):
        return {
            "phase1_fill": {
                "mini_bars": [mb.to_dict() for mb in self.mini_bars],
                "main_tube_fill": round(self.main_tube_fill, 3),
                "config": FILL_CONFIG,
            },
            "phase2_cooking": {
                "crystallization_rolls": [r.to_dict() for r in self.crystal_rolls],
                "final_floor": self.final_floor,
                "ceiling": self.ceiling,
                "total_rolls": self.total_rolls,
                "landed_tier_id": self.landed_tier_id,
                "config": COOKING_CONFIG,
            },
            "outcome": {
                "success": self.success,
                "is_critical": self.is_critical,
                "blueprints": self.blueprints,
                "gp": self.gp,
                "message": self.message,
            },
        }


class ResearchManager:
    
    def run_experiment(self, science: int, philosophy: int, building: int) -> ResearchResult:
        # Phase 1: Fill
        mini_bars, main_fill = self._run_fill_phase(science)
        
        # Phase 2: Crystallization - rolls raise floor, final floor = result
        ceiling = int(main_fill * 100)
        crystal_rolls, final_floor, tier_id = self._run_crystallization_phase(philosophy, ceiling)
        
        # Outcome based on final floor
        success, critical, blueprints, gp, msg = self._determine_outcome(final_floor, tier_id)
        
        return ResearchResult(
            mini_bars=mini_bars,
            main_tube_fill=main_fill,
            crystal_rolls=crystal_rolls,
            final_floor=final_floor,
            ceiling=ceiling,
            total_rolls=len(crystal_rolls),
            landed_tier_id=tier_id,
            success=success,
            is_critical=critical,
            blueprints=blueprints,
            gp=gp,
            message=msg,
        )
    
    def _run_fill_phase(self, science: int) -> tuple:
        """Phase 1: Fill the tube via mini bars."""
        base = FILL_CONFIG["base_rolls"]
        per_stat = FILL_CONFIG["rolls_per_stat"]
        rolls_per_bar = base + (per_stat * science)
        threshold = FILL_CONFIG["hit_threshold"]
        hit_amount = FILL_CONFIG["hit_fill_amount"]
        miss_amount = FILL_CONFIG["miss_fill_amount"]
        bar_names = FILL_CONFIG["mini_bar_names"]
        
        mini_bars = []
        total_contribution = 0.0
        
        for name in bar_names:
            rolls = []
            bar_fill = 0.0
            
            for i in range(rolls_per_bar):
                roll = random.randint(1, 100)
                hit = roll >= threshold
                fill_added = hit_amount if hit else miss_amount
                bar_fill = min(1.0, bar_fill + fill_added)
                
                rolls.append(MiniRoll(
                    roll=roll,
                    hit=hit,
                    fill_added=fill_added,
                    total_fill=bar_fill,
                ))
            
            # Select reagent: random within filled range
            bar_fill_pct = max(1, int(bar_fill * 100))
            reagent_select = random.randint(1, bar_fill_pct)
            contribution = reagent_select / 100.0
            total_contribution += contribution
            
            mini_bars.append(MiniBarResult(
                name=name,
                rolls=rolls,
                final_fill=bar_fill,
                reagent_select=reagent_select,
                contribution=contribution,
            ))
        
        main_fill = min(1.0, total_contribution)
        return mini_bars, main_fill
    
    def _run_crystallization_phase(self, philosophy: int, ceiling: int) -> tuple:
        """Phase 2: Crystallization rolls raise floor threshold."""
        base_rolls = COOKING_CONFIG["base_rolls"]
        rolls_per_stat = COOKING_CONFIG["rolls_per_stat"]
        num_rolls = base_rolls + (rolls_per_stat * philosophy)
        threshold = COOKING_CONFIG["hit_threshold"]
        gain_ranges = COOKING_CONFIG["floor_gain_ranges"]
        
        crystal_rolls = []
        floor = 0
        
        for i in range(num_rolls):
            roll = random.randint(1, 100)
            hit = roll >= threshold
            
            # Calculate floor gain based on roll value
            floor_gain = 0
            if hit:
                for gain_range in gain_ranges:
                    if gain_range["min_roll"] <= roll <= gain_range["max_roll"]:
                        floor_gain = random.randint(gain_range["gain_min"], gain_range["gain_max"])
                        break
            
            # Floor can't exceed ceiling
            floor = min(ceiling, floor + floor_gain)
            
            crystal_rolls.append(CrystallizationRoll(
                roll=roll,
                hit=hit,
                floor_gain=floor_gain,
                floor_after=floor,
            ))
        
        # Final floor is the result (floor only goes up, so final = best)
        final_floor = floor
        
        # Find tier based on final floor
        tier_id = None
        for tier in COOKING_CONFIG["reward_tiers"]:
            if tier["min_percent"] <= final_floor <= tier["max_percent"]:
                tier_id = tier["id"]
                break
        
        return crystal_rolls, final_floor, tier_id
    
    def _determine_outcome(self, best_landing, tier_id):
        """Determine rewards from landing."""
        tier = None
        for t in COOKING_CONFIG["reward_tiers"]:
            if t["id"] == tier_id:
                tier = t
                break
        
        if not tier:
            tier = COOKING_CONFIG["reward_tiers"][-1]
        
        is_critical = tier["id"] == "critical"
        blueprints = tier["blueprints"]
        gp = random.randint(tier["gp_min"], tier["gp_max"])
        message = tier["description"]
        success = blueprints > 0
        
        return success, is_critical, blueprints, gp, message
