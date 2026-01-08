"""
ROLL ENGINE
===========
Core probability engine for the Kingdom game.
Handles individual rolls, group rolls, and weighted multi-stat rolls.

This engine is designed to be:
1. Deterministic when seeded (for testing)
2. Fair but exciting (criticals add drama)
3. Visible to players (probabilities are transparent)
"""

import random
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from enum import Enum

from .config import (
    ROLL_BASE_CHANCE,
    ROLL_SCALING_PER_LEVEL,
    ROLL_MIN_CHANCE,
    ROLL_MAX_CHANCE,
    CRITICAL_SUCCESS_THRESHOLD,
    CRITICAL_FAILURE_THRESHOLD,
    CRITICAL_SUCCESS_MULTIPLIER,
    CRITICAL_FAILURE_PENALTY,
    GROUP_SIZE_BONUS,
    SKILL_WEIGHTS,
    get_success_chance,
)


class RollOutcome(Enum):
    """Possible outcomes of a roll"""
    CRITICAL_SUCCESS = "critical_success"
    SUCCESS = "success"
    FAILURE = "failure"
    CRITICAL_FAILURE = "critical_failure"


@dataclass
class RollResult:
    """Result of a single roll"""
    player_id: int
    player_name: str
    stat_name: str
    stat_value: int
    roll_value: float  # The actual random number (0-1)
    success_threshold: float  # What they needed to roll under
    outcome: RollOutcome
    contribution: float  # How much this roll contributes to the phase
    
    @property
    def is_success(self) -> bool:
        return self.outcome in (RollOutcome.SUCCESS, RollOutcome.CRITICAL_SUCCESS)
    
    @property
    def is_critical(self) -> bool:
        return self.outcome in (RollOutcome.CRITICAL_SUCCESS, RollOutcome.CRITICAL_FAILURE)
    
    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "player_name": self.player_name,
            "stat_name": self.stat_name,
            "stat_value": self.stat_value,
            "roll_value": round(self.roll_value, 3),
            "success_threshold": round(self.success_threshold, 3),
            "outcome": self.outcome.value,
            "is_success": self.is_success,
            "is_critical": self.is_critical,
            "contribution": round(self.contribution, 2),
        }


@dataclass
class GroupRollResult:
    """Result of a group roll phase"""
    phase_name: str
    individual_rolls: List[RollResult]
    total_contribution: float
    success_count: int
    critical_count: int
    group_size: int
    group_bonus: float
    
    @property
    def average_contribution(self) -> float:
        if not self.individual_rolls:
            return 0.0
        return self.total_contribution / len(self.individual_rolls)
    
    @property
    def success_rate(self) -> float:
        if not self.individual_rolls:
            return 0.0
        return self.success_count / len(self.individual_rolls)
    
    def to_dict(self) -> dict:
        return {
            "phase_name": self.phase_name,
            "rolls": [r.to_dict() for r in self.individual_rolls],
            "total_contribution": round(self.total_contribution, 2),
            "success_count": self.success_count,
            "critical_count": self.critical_count,
            "group_size": self.group_size,
            "group_bonus": round(self.group_bonus, 3),
            "success_rate": round(self.success_rate, 3),
        }


class RollEngine:
    """
    Core dice/probability engine for Kingdom game.
    
    Usage:
        engine = RollEngine()
        
        # Single roll
        result = engine.roll(player_id=1, player_name="Alice", stat_name="intelligence", stat_value=5)
        
        # Group roll
        participants = [
            {"player_id": 1, "player_name": "Alice", "stats": {"intelligence": 5}},
            {"player_id": 2, "player_name": "Bob", "stats": {"intelligence": 3}},
        ]
        group_result = engine.group_roll(participants, stat_name="intelligence", phase_name="tracking")
    """
    
    def __init__(self, seed: Optional[int] = None):
        """
        Initialize the roll engine.
        
        Args:
            seed: Optional random seed for deterministic testing
        """
        self.rng = random.Random(seed)
    
    def _calculate_threshold(self, stat_value: int, group_bonus: float = 0.0) -> float:
        """
        Calculate the success threshold for a given stat value.
        Player needs to roll UNDER this value to succeed.
        """
        base = ROLL_BASE_CHANCE + (ROLL_SCALING_PER_LEVEL * stat_value)
        with_bonus = base + group_bonus
        return max(ROLL_MIN_CHANCE, min(ROLL_MAX_CHANCE, with_bonus))
    
    def _determine_outcome(self, roll_value: float, threshold: float) -> Tuple[RollOutcome, float]:
        """
        Determine the outcome and contribution of a roll.
        
        Returns:
            Tuple of (outcome, contribution)
        """
        # Check for critical first (based on raw roll value)
        if roll_value >= CRITICAL_SUCCESS_THRESHOLD:
            # Very high roll - if it's a success, it's critical
            if roll_value <= threshold:
                return RollOutcome.CRITICAL_SUCCESS, CRITICAL_SUCCESS_MULTIPLIER
            # High roll but still failed - just a regular failure
            return RollOutcome.FAILURE, 0.0
        
        if roll_value <= CRITICAL_FAILURE_THRESHOLD:
            # Very low roll - critical failure (actually helps in our system since low is bad?)
            # Wait - we need to clarify: do we roll UNDER threshold to succeed?
            # Standard approach: roll 0-1, if roll < threshold -> success
            # So roll of 0.05 with threshold 0.5 = success (good!)
            # Let me reconsider...
            
            # Actually, let's do it the intuitive way:
            # - Generate a roll 0-1
            # - Calculate threshold based on stat
            # - If roll <= threshold: SUCCESS
            # - Critical success: when roll is very close to threshold (lucky!)
            # - Critical failure: when roll is way above threshold (bad luck)
            pass
        
        # Standard success/failure
        if roll_value <= threshold:
            # Success! Contribution scales with how much "headroom" they had
            contribution = 1.0
            return RollOutcome.SUCCESS, contribution
        else:
            # Failure
            return RollOutcome.FAILURE, 0.0
    
    def roll(
        self,
        player_id: int,
        player_name: str,
        stat_name: str,
        stat_value: int,
        group_bonus: float = 0.0
    ) -> RollResult:
        """
        Perform a single roll for a player.
        
        Args:
            player_id: Player's database ID
            player_name: Display name
            stat_name: Name of the stat being checked
            stat_value: Current value of the stat (0-10)
            group_bonus: Additional bonus from group size
            
        Returns:
            RollResult with outcome details
        """
        # Calculate success threshold
        threshold = self._calculate_threshold(stat_value, group_bonus)
        
        # Generate random roll (0-1)
        roll_value = self.rng.random()
        
        # Determine outcome
        # New logic: 
        # - Roll <= threshold = success
        # - Roll is in bottom 5% of threshold = critical success
        # - Roll is in top 5% above threshold = critical failure
        
        if roll_value <= threshold:
            # Success!
            # Check for critical success (rolled in the "sweet spot" - top quarter of success range)
            if roll_value >= threshold * 0.75:
                outcome = RollOutcome.CRITICAL_SUCCESS
                contribution = CRITICAL_SUCCESS_MULTIPLIER
            else:
                outcome = RollOutcome.SUCCESS
                contribution = 1.0
        else:
            # Failure
            # Check for critical failure (rolled way above threshold)
            if roll_value >= 0.95:
                outcome = RollOutcome.CRITICAL_FAILURE
                contribution = -CRITICAL_FAILURE_PENALTY  # Negative contribution!
            else:
                outcome = RollOutcome.FAILURE
                contribution = 0.0
        
        return RollResult(
            player_id=player_id,
            player_name=player_name,
            stat_name=stat_name,
            stat_value=stat_value,
            roll_value=roll_value,
            success_threshold=threshold,
            outcome=outcome,
            contribution=contribution,
        )
    
    def group_roll(
        self,
        participants: List[Dict],
        stat_name: str,
        phase_name: str,
        activity_type: Optional[str] = None
    ) -> GroupRollResult:
        """
        Perform a roll for each participant in a group activity.
        
        Args:
            participants: List of {"player_id": int, "player_name": str, "stats": {stat: value}}
            stat_name: Which stat to roll against
            phase_name: Name of this phase (for display)
            activity_type: Optional activity key for weighted stats
            
        Returns:
            GroupRollResult with all individual rolls and totals
        """
        group_size = len(participants)
        group_bonus = GROUP_SIZE_BONUS.get(group_size, 0.0)
        
        individual_rolls = []
        total_contribution = 0.0
        success_count = 0
        critical_count = 0
        
        for participant in participants:
            player_id = participant["player_id"]
            player_name = participant["player_name"]
            stats = participant.get("stats", {})
            
            # Get stat value (default to 0 if not found)
            stat_value = stats.get(stat_name, 0)
            
            # If we have weighted stats for this activity, calculate weighted value
            if activity_type and activity_type in SKILL_WEIGHTS:
                weights = SKILL_WEIGHTS[activity_type]
                weighted_sum = 0.0
                weight_total = 0.0
                for skill, weight in weights.items():
                    weighted_sum += stats.get(skill, 0) * weight
                    weight_total += weight
                if weight_total > 0:
                    stat_value = weighted_sum / weight_total
            
            # Perform the roll
            result = self.roll(
                player_id=player_id,
                player_name=player_name,
                stat_name=stat_name,
                stat_value=int(stat_value),
                group_bonus=group_bonus,
            )
            
            individual_rolls.append(result)
            total_contribution += result.contribution
            
            if result.is_success:
                success_count += 1
            if result.is_critical:
                critical_count += 1
        
        return GroupRollResult(
            phase_name=phase_name,
            individual_rolls=individual_rolls,
            total_contribution=total_contribution,
            success_count=success_count,
            critical_count=critical_count,
            group_size=group_size,
            group_bonus=group_bonus,
        )
    
    def weighted_roll(
        self,
        player_id: int,
        player_name: str,
        stats: Dict[str, int],
        weights: Dict[str, float],
        group_bonus: float = 0.0
    ) -> RollResult:
        """
        Perform a roll using weighted combination of multiple stats.
        
        Args:
            stats: Dict of {stat_name: value}
            weights: Dict of {stat_name: weight} (should sum to 1.0)
            
        Returns:
            RollResult using weighted stat value
        """
        weighted_sum = 0.0
        weight_total = 0.0
        
        for stat_name, weight in weights.items():
            weighted_sum += stats.get(stat_name, 0) * weight
            weight_total += weight
        
        if weight_total > 0:
            effective_stat = weighted_sum / weight_total
        else:
            effective_stat = 0
        
        # Use the primary stat name for display
        primary_stat = max(weights.keys(), key=lambda k: weights[k]) if weights else "unknown"
        
        return self.roll(
            player_id=player_id,
            player_name=player_name,
            stat_name=primary_stat,
            stat_value=int(effective_stat),
            group_bonus=group_bonus,
        )


# ============================================================
# UTILITY FUNCTIONS
# ============================================================

def simulate_roll_distribution(stat_level: int, iterations: int = 10000) -> dict:
    """
    Simulate many rolls to show probability distribution.
    Useful for testing and displaying odds to players.
    """
    engine = RollEngine()
    outcomes = {
        "critical_success": 0,
        "success": 0,
        "failure": 0,
        "critical_failure": 0,
    }
    
    for _ in range(iterations):
        result = engine.roll(
            player_id=0,
            player_name="test",
            stat_name="test",
            stat_value=stat_level,
        )
        outcomes[result.outcome.value] += 1
    
    return {
        outcome: count / iterations
        for outcome, count in outcomes.items()
    }

