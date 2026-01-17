"""
RESEARCH MANAGER
================
Phase 1: 3 mini bars (COMPOSURE, CALCULATION, PRECISION)
Each mini bar gets rolls, then master roll.
3 master rolls fill the main tube.
"""

import random
from dataclasses import dataclass
from typing import List

from .config import (
    FILL_CONFIG,
    STABILIZE_CONFIG,
    BUILD_CONFIG,
    REWARDS,
    CRITICAL_THRESHOLD,
)


# Mini bar names
MINI_BAR_NAMES = ["COMPOSURE", "CALCULATION", "PRECISION"]


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
    master_roll: int        # Master roll 1-100
    master_hit: bool
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
            "master_roll": self.master_roll,
            "master_hit": self.master_hit,
            "contribution": round(self.contribution, 3),
        }


@dataclass
class StabilizeRoll:
    """One roll in stabilize phase."""
    roll_number: int
    roll: int
    hit: bool
    
    def to_dict(self):
        return {
            "roll_number": self.roll_number,
            "roll": self.roll,
            "hit": self.hit,
        }


@dataclass
class TapResult:
    """One tap in build phase."""
    tap_number: int
    hit: bool
    progress_added: int
    total_progress: int
    
    def to_dict(self):
        return {
            "tap_number": self.tap_number,
            "hit": self.hit,
            "progress_added": self.progress_added,
            "total_progress": self.total_progress,
        }


@dataclass
class ResearchResult:
    """Complete research result."""
    # Phase 1: Fill (3 mini bars)
    mini_bars: List[MiniBarResult]
    main_tube_fill: float
    fill_success: bool
    
    # Phase 2: Stabilize
    stabilize_rolls: List[StabilizeRoll]
    stabilize_hits: int
    stabilize_success: bool
    
    # Phase 3: Build
    taps: List[TapResult]
    final_progress: int
    build_success: bool
    
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
                "success": self.fill_success,
                "min_required": FILL_CONFIG["min_fill_to_proceed"],
            },
            "phase2_stabilize": {
                "rolls": [r.to_dict() for r in self.stabilize_rolls],
                "total_hits": self.stabilize_hits,
                "success": self.stabilize_success,
                "hits_needed": STABILIZE_CONFIG["hits_needed"],
            },
            "phase3_build": {
                "taps": [t.to_dict() for t in self.taps],
                "final_progress": self.final_progress,
                "success": self.build_success,
                "progress_needed": BUILD_CONFIG["progress_needed"],
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
        # Phase 1: Fill with 3 mini bars
        mini_bars, main_fill, fill_success = self._run_fill_phase(science)
        
        # Phase 2: Stabilize (only if fill succeeded)
        if fill_success:
            stab_rolls, stab_hits, stab_success = self._run_stabilize_phase(philosophy)
        else:
            stab_rolls, stab_hits, stab_success = [], 0, False
        
        # Phase 3: Build (only if stabilize succeeded)
        if stab_success:
            taps, progress, build_success = self._run_build_phase(building)
        else:
            taps, progress, build_success = [], 0, False
        
        # Outcome
        success, critical, blueprints, gp, msg = self._determine_outcome(
            fill_success, stab_success, build_success, mini_bars
        )
        
        return ResearchResult(
            mini_bars=mini_bars,
            main_tube_fill=main_fill,
            fill_success=fill_success,
            stabilize_rolls=stab_rolls,
            stabilize_hits=stab_hits,
            stabilize_success=stab_success,
            taps=taps,
            final_progress=progress,
            build_success=build_success,
            success=success,
            is_critical=critical,
            blueprints=blueprints,
            gp=gp,
            message=msg,
        )
    
    def _run_fill_phase(self, science: int) -> tuple:
        """Phase 1: 3 mini bars, each with rolls then master roll."""
        rolls_per_bar = 2 + science  # 2 base + science level
        hit_chance = FILL_CONFIG["hit_chance"]
        threshold = int((1 - hit_chance) * 100) + 1  # e.g. 40% = need 61+ to hit
        
        mini_bars = []
        total_contribution = 0.0
        
        for name in MINI_BAR_NAMES:
            # Roll to fill this mini bar
            rolls = []
            bar_fill = 0.0
            
            for i in range(rolls_per_bar):
                roll = random.randint(1, 100)
                hit = roll >= threshold
                fill_added = 0.20 if hit else 0.05  # HIT = 20%, MISS = 5%
                bar_fill = min(1.0, bar_fill + fill_added)
                
                rolls.append(MiniRoll(
                    roll=roll,
                    hit=hit,
                    fill_added=fill_added,
                    total_fill=bar_fill,
                ))
            
            # Master roll on this mini bar
            master_roll = random.randint(1, 100)
            # Higher bar fill = higher chance master roll succeeds
            master_threshold = int((1 - bar_fill) * 100) + 1
            master_hit = master_roll >= master_threshold
            
            # Contribution to main tube
            if master_hit:
                contribution = bar_fill * 0.4  # Up to 40% per bar if full
            else:
                contribution = bar_fill * 0.15  # Only 15% if master miss
            
            total_contribution += contribution
            
            mini_bars.append(MiniBarResult(
                name=name,
                rolls=rolls,
                final_fill=bar_fill,
                master_roll=master_roll,
                master_hit=master_hit,
                contribution=contribution,
            ))
        
        main_fill = min(1.0, total_contribution)
        success = main_fill >= FILL_CONFIG["min_fill_to_proceed"]
        
        return mini_bars, main_fill, success
    
    def _run_stabilize_phase(self, philosophy: int) -> tuple:
        """Phase 2: Stabilize rolls."""
        num_rolls = STABILIZE_CONFIG["base_rolls"] + philosophy
        hit_chance = STABILIZE_CONFIG["hit_chance"]
        threshold = int((1 - hit_chance) * 100) + 1
        
        rolls = []
        hits = 0
        
        for i in range(num_rolls):
            roll = random.randint(1, 100)
            hit = roll >= threshold
            if hit:
                hits += 1
            
            rolls.append(StabilizeRoll(
                roll_number=i + 1,
                roll=roll,
                hit=hit,
            ))
        
        success = hits >= STABILIZE_CONFIG["hits_needed"]
        return rolls, hits, success
    
    def _run_build_phase(self, building: int) -> tuple:
        """Phase 3: Tap to build."""
        num_taps = BUILD_CONFIG["base_taps"] + (BUILD_CONFIG["taps_per_stat"] * building)
        hit_chance = BUILD_CONFIG["hit_chance"]
        progress_per_hit = BUILD_CONFIG["progress_per_hit"]
        needed = BUILD_CONFIG["progress_needed"]
        
        taps = []
        progress = 0
        
        for i in range(num_taps):
            hit = random.random() < hit_chance
            added = progress_per_hit if hit else 0
            progress = min(needed, progress + added)
            
            taps.append(TapResult(
                tap_number=i + 1,
                hit=hit,
                progress_added=added,
                total_progress=progress,
            ))
            
            if progress >= needed:
                break
        
        return taps, progress, progress >= needed
    
    def _determine_outcome(self, fill_ok, stab_ok, build_ok, mini_bars):
        if not fill_ok:
            r = REWARDS["fail_phase1"]
            return False, False, 0, random.randint(r["gp_min"], r["gp_max"]), r["message"]
        
        if not stab_ok:
            r = REWARDS["fail_phase2"]
            return False, False, 0, random.randint(r["gp_min"], r["gp_max"]), r["message"]
        
        if not build_ok:
            r = REWARDS["fail_phase3"]
            return False, False, 0, random.randint(r["gp_min"], r["gp_max"]), r["message"]
        
        # Critical if all 3 mini bar master rolls hit
        all_master_hits = all(mb.master_hit for mb in mini_bars)
        
        if all_master_hits:
            r = REWARDS["critical"]
        else:
            r = REWARDS["success"]
        
        return True, all_master_hits, r["blueprints"], random.randint(r["gp_min"], r["gp_max"]), r["message"]
