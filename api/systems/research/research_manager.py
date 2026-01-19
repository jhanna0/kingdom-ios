"""
RESEARCH MANAGER
================
Phase 1: PREPARATION - 3 reagent tubes, each fills then selects amount
Phase 2: SYNTHESIS - Infusions raise purity level, higher = better quality
         Final purity determines result tier.
         
FINAL INFUSION: Last dramatic moment with boosted gains before reveal.

ALL CONFIG IS SENT TO FRONTEND - NO HARDCODING ON CLIENT.
"""

import random
from dataclasses import dataclass
from typing import List, Optional

from .config import (
    PREPARATION_CONFIG,
    SYNTHESIS_CONFIG,
)


@dataclass
class Infusion:
    """One infusion attempt on a reagent tube."""
    value: int              # 1-100 (NOT called "roll")
    stable: bool            # Was reaction stable?
    fill_added: float       # How much this added
    total_fill: float       # Total fill after this


@dataclass 
class ReagentResult:
    """Result for one reagent tube."""
    name: str
    infusions: List[Infusion]
    final_fill: float           # Fill level after infusions (0-1)
    amount_selected: int        # Selected amount (1 to final_fill%)
    contribution: float         # How much this contributes to potential (0-1)
    
    def to_dict(self):
        return {
            "name": self.name,
            "infusions": [
                {
                    "value": inf.value,
                    "stable": inf.stable,
                    "fill_added": round(inf.fill_added, 3),
                    "total_fill": round(inf.total_fill, 3),
                }
                for inf in self.infusions
            ],
            "final_fill": round(self.final_fill, 3),
            "amount_selected": self.amount_selected,
            "contribution": round(self.contribution, 3),
        }


@dataclass
class SynthesisInfusion:
    """One infusion in the synthesis phase."""
    value: int              # 1-100
    stable: bool            # Was reaction stable?
    quality: Optional[str]  # "weak", "fair", "good", "strong", "perfect" or None
    purity_gained: int      # How much purity raised
    purity_after: int       # Purity level after this infusion
    is_final: bool          # Is this the final dramatic infusion?
    
    def to_dict(self):
        return {
            "value": self.value,
            "stable": self.stable,
            "quality": self.quality,
            "purity_gained": self.purity_gained,
            "purity_after": self.purity_after,
            "is_final": self.is_final,
        }


@dataclass
class ResearchResult:
    """Complete research result."""
    # Phase 1: Preparation
    reagents: List[ReagentResult]
    potential: int              # Max possible purity (from Phase 1)
    
    # Phase 2: Synthesis
    synthesis_infusions: List[SynthesisInfusion]
    final_purity: int           # Achieved purity level
    total_infusions: int
    result_tier_id: Optional[str]
    
    # Final Infusion (dramatic ending)
    final_infusion: Optional[SynthesisInfusion]
    
    # Outcome
    success: bool
    is_eureka: bool
    blueprints: int
    gp: int
    title: str
    message: str
    
    def to_dict(self):
        return {
            "phase1_preparation": {
                "reagents": [r.to_dict() for r in self.reagents],
                "potential": self.potential,
                "config": PREPARATION_CONFIG,
            },
            "phase2_synthesis": {
                "infusions": [inf.to_dict() for inf in self.synthesis_infusions],
                "final_infusion": self.final_infusion.to_dict() if self.final_infusion else None,
                "final_purity": self.final_purity,
                "potential": self.potential,
                "total_infusions": self.total_infusions,
                "result_tier_id": self.result_tier_id,
                "config": SYNTHESIS_CONFIG,
            },
            "outcome": {
                "success": self.success,
                "is_eureka": self.is_eureka,
                "blueprints": self.blueprints,
                "gp": self.gp,
                "title": self.title,
                "message": self.message,
                "tier_id": self.result_tier_id,
            },
        }


class ResearchManager:
    
    def run_experiment(self, science: int, philosophy: int, building: int) -> ResearchResult:
        # Phase 1: Preparation - measure reagents
        reagents, potential = self._run_preparation_phase(science)
        
        # Phase 2: Synthesis - purify through infusions
        infusions, purity_before_final = self._run_synthesis_phase(philosophy, potential)
        
        # Final Infusion - dramatic ending with boosted stakes
        final_inf, final_purity = self._run_final_infusion(purity_before_final, potential)
        
        # Determine result tier based on final purity
        tier_id = self._find_tier(final_purity)
        
        # Outcome
        success, is_eureka, blueprints, gp, title, msg = self._determine_outcome(tier_id)
        
        return ResearchResult(
            reagents=reagents,
            potential=potential,
            synthesis_infusions=infusions,
            final_purity=final_purity,
            total_infusions=len(infusions) + (1 if final_inf else 0),
            result_tier_id=tier_id,
            final_infusion=final_inf,
            success=success,
            is_eureka=is_eureka,
            blueprints=blueprints,
            gp=gp,
            title=title,
            message=msg,
        )
    
    def _run_preparation_phase(self, science: int) -> tuple:
        """Phase 1: Prepare reagents by filling tubes."""
        cfg = PREPARATION_CONFIG
        infusions_per_tube = cfg["base_infusions"] + (cfg["infusions_per_stat"] * science)
        threshold = cfg["stable_threshold"]
        stable_amount = cfg["stable_fill_amount"]
        volatile_amount = cfg["volatile_fill_amount"]
        reagent_names = cfg["reagent_names"]
        
        reagents = []
        total_contribution = 0.0
        
        for name in reagent_names:
            infusions = []
            tube_fill = 0.0
            
            for _ in range(infusions_per_tube):
                value = random.randint(1, 100)
                stable = value >= threshold
                fill_added = stable_amount if stable else volatile_amount
                tube_fill = min(1.0, tube_fill + fill_added)
                
                infusions.append(Infusion(
                    value=value,
                    stable=stable,
                    fill_added=fill_added,
                    total_fill=tube_fill,
                ))
            
            # Select amount from filled range
            fill_pct = max(1, int(tube_fill * 100))
            amount_selected = random.randint(1, fill_pct)
            contribution = amount_selected / 100.0
            total_contribution += contribution
            
            reagents.append(ReagentResult(
                name=name,
                infusions=infusions,
                final_fill=tube_fill,
                amount_selected=amount_selected,
                contribution=contribution,
            ))
        
        # Potential is capped at 100
        potential = min(100, int(total_contribution * 100))
        return reagents, potential
    
    def _run_synthesis_phase(self, philosophy: int, potential: int) -> tuple:
        """Phase 2: Synthesis infusions raise purity."""
        cfg = SYNTHESIS_CONFIG
        num_infusions = cfg["base_infusions"] + (cfg["infusions_per_stat"] * philosophy)
        threshold = cfg["stable_threshold"]
        purity_gains = cfg["purity_gains"]
        volatile_gain = cfg["volatile_purity_gain"]
        
        infusions = []
        purity = 0
        
        for _ in range(num_infusions):
            value = random.randint(1, 100)
            stable = value >= threshold
            
            # Calculate purity gain
            purity_gained = 0
            quality = None
            
            if stable:
                # Find matching gain range - NO GAPS!
                for gain_range in purity_gains:
                    if gain_range["min_value"] <= value <= gain_range["max_value"]:
                        purity_gained = random.randint(gain_range["gain_min"], gain_range["gain_max"])
                        quality = gain_range["quality"]
                        break
            else:
                # Volatile still gives small progress - never feel stuck!
                purity_gained = volatile_gain
            
            # Purity can't exceed potential
            purity = min(potential, purity + purity_gained)
            
            infusions.append(SynthesisInfusion(
                value=value,
                stable=stable,
                quality=quality,
                purity_gained=purity_gained,
                purity_after=purity,
                is_final=False,
            ))
        
        return infusions, purity
    
    def _run_final_infusion(self, purity_before: int, potential: int) -> tuple:
        """Final dramatic infusion with boosted stakes."""
        cfg = SYNTHESIS_CONFIG
        final_cfg = cfg["final_infusion"]
        
        if not final_cfg["enabled"]:
            return None, purity_before
        
        threshold = cfg["stable_threshold"]
        purity_gains = cfg["purity_gains"]
        volatile_gain = cfg["volatile_purity_gain"]
        multiplier = final_cfg["gain_multiplier"]
        
        value = random.randint(1, 100)
        stable = value >= threshold
        
        # Calculate base gain
        base_gain = 0
        quality = None
        
        if stable:
            for gain_range in purity_gains:
                if gain_range["min_value"] <= value <= gain_range["max_value"]:
                    base_gain = random.randint(gain_range["gain_min"], gain_range["gain_max"])
                    quality = gain_range["quality"]
                    break
        else:
            base_gain = volatile_gain
        
        # Apply multiplier for final infusion
        purity_gained = int(base_gain * multiplier)
        
        # Final purity, capped at potential
        final_purity = min(potential, purity_before + purity_gained)
        
        final_inf = SynthesisInfusion(
            value=value,
            stable=stable,
            quality=quality,
            purity_gained=purity_gained,
            purity_after=final_purity,
            is_final=True,
        )
        
        return final_inf, final_purity
    
    def _find_tier(self, purity: int) -> Optional[str]:
        """Find result tier based on purity."""
        for tier in SYNTHESIS_CONFIG["result_tiers"]:
            if tier["min_purity"] <= purity <= tier["max_purity"]:
                return tier["id"]
        return None
    
    def _determine_outcome(self, tier_id: str) -> tuple:
        """Determine rewards from tier."""
        tier = None
        for t in SYNTHESIS_CONFIG["result_tiers"]:
            if t["id"] == tier_id:
                tier = t
                break
        
        if not tier:
            # Fallback to unstable
            tier = SYNTHESIS_CONFIG["result_tiers"][-1]
        
        is_eureka = tier["id"] == "eureka"
        blueprints = tier["blueprints"]
        gp = random.randint(tier["gp_min"], tier["gp_max"])
        title = tier["title"]
        message = tier["description"]
        success = blueprints > 0
        
        return success, is_eureka, blueprints, gp, title, message
