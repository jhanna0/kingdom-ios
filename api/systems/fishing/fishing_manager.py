"""
FISHING MANAGER
===============
Handles fishing session logic with pre-calculated rolls.

KEY DIFFERENCE FROM HUNTING:
- Backend calculates ALL rolls at once
- Returns array of roll results
- Frontend animates through them slowly
- Creates chill, AFK-friendly experience
"""

import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from enum import Enum

from .config import (
    FISH,
    CAST_DROP_TABLE,
    CAST_SHIFT_PER_SUCCESS,
    CAST_DROP_TABLE_DISPLAY,
    get_reel_drop_table,
    REEL_SHIFT_PER_SUCCESS,
    REEL_DROP_TABLE_DISPLAY,
    ROLL_HIT_CHANCE,
    ROLL_ANIMATION_DELAY_MS,
    PHASE_CONFIG,
    FishingPhase,
    get_fish_meat_reward,
    should_drop_pet_fish,
    get_fish_with_loot_preview,
    get_loot_config_for_fish,
)


@dataclass
class RollResult:
    """Result of a single roll."""
    round_number: int
    roll_value: int           # 1-100 display value
    is_success: bool
    is_critical: bool
    message: str
    slots_after: Dict[str, int] = field(default_factory=dict)  # Slot state AFTER this roll
    
    def to_dict(self) -> dict:
        return {
            "round": self.round_number,
            "roll": self.roll_value,
            "is_success": self.is_success,
            "is_critical": self.is_critical,
            "message": self.message,
            "slots_after": self.slots_after,  # For animating slot shifts
        }


@dataclass
class PhaseResult:
    """Complete result of a phase (cast or reel)."""
    phase: str
    rolls: List[RollResult]
    base_slots: Dict[str, int]       # Starting slots BEFORE any rolls
    final_slots: Dict[str, int]
    final_probabilities: Dict[str, float]
    master_roll: int
    outcome: str
    outcome_display: dict      # Full display info for outcome
    
    def to_dict(self) -> dict:
        return {
            "phase": self.phase,
            "rolls": [r.to_dict() for r in self.rolls],
            "base_slots": self.base_slots,  # Starting point for animation
            "final_slots": self.final_slots,
            "final_probabilities": {k: round(v, 3) for k, v in self.final_probabilities.items()},
            "master_roll": self.master_roll,
            "outcome": self.outcome,
            "outcome_display": self.outcome_display,
            "animation_delay_ms": ROLL_ANIMATION_DELAY_MS,
        }


@dataclass
class FishingSession:
    """
    A fishing session tracking accumulated catches.
    
    Unlike hunting, fishing sessions are lightweight and can span
    multiple cast/reel cycles. User collects all fish when done.
    """
    session_id: str
    player_id: int
    
    # Accumulated rewards
    total_meat: int = 0
    fish_caught: int = 0
    pet_fish_dropped: bool = False
    
    # Current state
    current_fish: Optional[str] = None  # Fish on the line (after cast)
    
    # Stats for display
    casts_attempted: int = 0
    successful_catches: int = 0
    fish_escaped: int = 0
    consecutive_catches: int = 0  # Resets on escape, used for streak bonus
    
    def to_dict(self) -> dict:
        return {
            "session_id": self.session_id,
            "total_meat": self.total_meat,
            "fish_caught": self.fish_caught,
            "pet_fish_dropped": self.pet_fish_dropped,
            "current_fish": self.current_fish,
            "current_fish_data": get_fish_with_loot_preview(self.current_fish) if self.current_fish else None,
            "stats": {
                "casts_attempted": self.casts_attempted,
                "successful_catches": self.successful_catches,
                "fish_escaped": self.fish_escaped,
                "consecutive_catches": self.consecutive_catches,
            },
        }


class FishingManager:
    """
    Manages fishing sessions and pre-calculates roll sequences.
    
    Usage:
        manager = FishingManager()
        
        # Start session
        session = manager.create_session(player_id, player_stats)
        
        # Cast (returns all rolls pre-calculated)
        cast_result = manager.execute_cast(session, building_stat)
        # Frontend animates through cast_result.rolls
        
        # If fish found, reel
        if session.current_fish:
            reel_result = manager.execute_reel(session, defense_stat)
            # Frontend animates through reel_result.rolls
        
        # Collect rewards when done
        rewards = manager.end_session(session)
    """
    
    def __init__(self, seed: Optional[int] = None):
        self.rng = random.Random(seed)
    
    def create_session(self, player_id: int) -> FishingSession:
        """Create a new fishing session."""
        import time
        session_id = f"fish_{player_id}_{int(time.time() * 1000)}"
        return FishingSession(
            session_id=session_id,
            player_id=player_id,
        )
    
    def execute_cast(self, session: FishingSession, building_stat: int) -> PhaseResult:
        """
        Execute the cast phase.
        
        Pre-calculates ALL rolls based on Building stat.
        Returns everything - frontend animates through the rolls.
        Each roll includes slots_after so frontend can animate slot shifts.
        """
        session.casts_attempted += 1
        session.current_fish = None  # Reset from any previous cast
        
        # Number of rolls = 1 + stat level
        num_rolls = 1 + building_stat
        
        # Save base slots BEFORE any shifts (for animation start point)
        base_slots = CAST_DROP_TABLE.copy()
        slots = CAST_DROP_TABLE.copy()
        
        # Pre-calculate all rolls
        rolls = []
        config = PHASE_CONFIG[FishingPhase.CASTING]
        
        for i in range(num_rolls):
            roll_value = self.rng.random()
            is_success = roll_value < ROLL_HIT_CHANCE
            is_critical = is_success and roll_value < (ROLL_HIT_CHANCE * 0.25)
            
            # Apply shift if success
            if is_success:
                multiplier = 2 if is_critical else 1
                self._shift_slots(slots, CAST_SHIFT_PER_SUCCESS, multiplier)
            
            # Determine message
            if is_critical:
                message = config["critical_effect"]
            elif is_success:
                message = config["success_effect"]
            else:
                message = config["failure_effect"]
            
            # Include slot state AFTER this roll (for animation)
            rolls.append(RollResult(
                round_number=i + 1,
                roll_value=int(roll_value * 100),
                is_success=is_success,
                is_critical=is_critical,
                message=message,
                slots_after=slots.copy(),  # Snapshot of slots after this roll
            ))
        
        # Master roll to determine outcome
        outcome, master_roll = self._roll_on_drop_table(slots, CAST_DROP_TABLE_DISPLAY)
        
        # Calculate final probabilities
        total = sum(slots.values())
        probabilities = {k: v / total for k, v in slots.items()} if total > 0 else {}
        
        # Get outcome display info
        outcome_display = next(
            (item for item in CAST_DROP_TABLE_DISPLAY if item["key"] == outcome),
            {"key": outcome, "name": outcome, "icon": "questionmark", "color": "inkMedium"}
        )
        
        # Update session state
        if outcome != "no_bite":
            session.current_fish = outcome
            outcome_display["fish_data"] = FISH.get(outcome, {})
        
        return PhaseResult(
            phase="cast",
            rolls=rolls,
            base_slots=base_slots,
            final_slots=slots,
            final_probabilities=probabilities,
            master_roll=master_roll,
            outcome=outcome,
            outcome_display=outcome_display,
        )
    
    def execute_reel(self, session: FishingSession, defense_stat: int) -> PhaseResult:
        """
        Execute the reel phase.
        
        Pre-calculates ALL rolls based on Defense stat.
        Only called if a fish is on the line (current_fish is set).
        Each roll includes slots_after so frontend can animate slot shifts.
        """
        if not session.current_fish:
            raise ValueError("No fish on the line to reel!")
        
        fish_id = session.current_fish
        fish_data = FISH.get(fish_id, {})
        
        # Number of rolls = 1 + stat level
        num_rolls = 1 + defense_stat
        
        # Get reel odds based on fish difficulty (rarer = harder)
        reel_table = get_reel_drop_table(fish_id)
        
        # Save base slots BEFORE any shifts (for animation start point)
        base_slots = reel_table.copy()
        slots = reel_table.copy()
        
        # Pre-calculate all rolls
        rolls = []
        config = PHASE_CONFIG[FishingPhase.REELING]
        
        for i in range(num_rolls):
            roll_value = self.rng.random()
            is_success = roll_value < ROLL_HIT_CHANCE
            is_critical = is_success and roll_value < (ROLL_HIT_CHANCE * 0.25)
            
            # Apply shift if success
            if is_success:
                multiplier = 2 if is_critical else 1
                self._shift_slots(slots, REEL_SHIFT_PER_SUCCESS, multiplier)
            
            # Determine message
            if is_critical:
                message = config["critical_effect"]
            elif is_success:
                message = config["success_effect"]
            else:
                message = config["failure_effect"]
            
            # Include slot state AFTER this roll (for animation)
            rolls.append(RollResult(
                round_number=i + 1,
                roll_value=int(roll_value * 100),
                is_success=is_success,
                is_critical=is_critical,
                message=message,
                slots_after=slots.copy(),  # Snapshot of slots after this roll
            ))
        
        # Master roll to determine outcome
        outcome, master_roll = self._roll_on_drop_table(slots, REEL_DROP_TABLE_DISPLAY)
        
        # Calculate final probabilities
        total = sum(slots.values())
        probabilities = {k: v / total for k, v in slots.items()} if total > 0 else {}
        
        # Get outcome display info
        outcome_display = next(
            (item for item in REEL_DROP_TABLE_DISPLAY if item["key"] == outcome),
            {"key": outcome, "name": outcome, "icon": "questionmark", "color": "inkMedium"}
        )
        
        # Process outcome
        if outcome == "caught":
            session.consecutive_catches += 1
            
            # Success! Add rewards
            meat = get_fish_meat_reward(fish_id)
            
            # Streak bonus: 3+ catches in a row = double meat
            if session.consecutive_catches >= 3:
                meat *= 2
            
            session.total_meat += meat
            session.fish_caught += 1
            session.successful_catches += 1
            
            # Check for pet fish drop
            pet_dropped = should_drop_pet_fish(fish_id)
            if pet_dropped:
                session.pet_fish_dropped = True
            
            outcome_display["meat_earned"] = meat
            outcome_display["streak_bonus"] = session.consecutive_catches >= 3
            outcome_display["consecutive_catches"] = session.consecutive_catches
            outcome_display["fish_data"] = fish_data
            outcome_display["rare_loot_dropped"] = pet_dropped  # Generic name
            # Only show popup when streak JUST activates (exactly 3), not on every subsequent catch
            if session.consecutive_catches == 3:
                outcome_display["show_streak_popup"] = True
                outcome_display["streak_info"] = {
                    "title": "HOT STREAK!",
                    "subtitle": "2x Meat",
                    "description": "3 catches in a row!",
                    "multiplier": 2,
                    "threshold": 3,
                    "icon": "flame.fill",
                    "color": "buttonDanger",
                    "dismiss_button": "Nice!",
                }
            
            # Include loot bar display data - all from backend config
            loot_config = get_loot_config_for_fish(fish_id)
            loot_drop_table = loot_config["drop_table"]
            total_slots = sum(loot_drop_table.values())
            
            # Calculate where the roll landed based on outcome
            if pet_dropped:
                # Landed in rare zone (top of bar)
                rare_slots = loot_drop_table.get("rare_loot", 0)
                loot_roll = total_slots - max(1, (rare_slots // 2))  # Middle of rare zone
            else:
                # Landed in meat zone
                meat_slots = loot_drop_table.get("meat", total_slots)
                loot_roll = meat_slots // 2  # Middle of meat zone
            
            # UI expects 1...100 for all phases, including loot (visual-only roll).
            if total_slots <= 0:
                loot_roll_percent = 50
            else:
                loot_roll_percent = int((loot_roll / total_slots) * 100)
                loot_roll_percent = max(1, min(100, loot_roll_percent))
            
            outcome_display["loot"] = {
                "drop_table": loot_drop_table,
                "drop_table_display": loot_config["drop_table_display"],
                "bar_title": loot_config["bar_title"],  # Dynamic from backend
                "rare_loot_name": loot_config["rare_loot_name"],
                "meat_earned": meat,
                "rare_loot_dropped": pet_dropped,
                "master_roll": loot_roll_percent,
            }
        else:
            # Escaped - reset streak
            session.consecutive_catches = 0
            session.fish_escaped += 1
            outcome_display["fish_data"] = fish_data
        
        # Clear current fish (either caught or escaped)
        session.current_fish = None
        
        return PhaseResult(
            phase="reel",
            rolls=rolls,
            base_slots=base_slots,
            final_slots=slots,
            final_probabilities=probabilities,
            master_roll=master_roll,
            outcome=outcome,
            outcome_display=outcome_display,
        )
    
    def end_session(self, session: FishingSession) -> dict:
        """
        End the fishing session and return final rewards.
        
        This is called when the player taps "Done" to collect all fish.
        """
        return {
            "total_meat": session.total_meat,
            "fish_caught": session.fish_caught,
            "pet_fish_dropped": session.pet_fish_dropped,
            "stats": {
                "casts_attempted": session.casts_attempted,
                "successful_catches": session.successful_catches,
                "fish_escaped": session.fish_escaped,
                "catch_rate": (
                    round(session.successful_catches / session.casts_attempted * 100, 1)
                    if session.casts_attempted > 0 else 0
                ),
            },
        }
    
    def _shift_slots(self, slots: Dict[str, int], shift_config: Dict[str, int], multiplier: int = 1) -> None:
        """Apply shift to drop table slots."""
        for key, shift in shift_config.items():
            if key in slots:
                slots[key] += shift * multiplier
                slots[key] = max(0, slots[key])  # Can't go negative
    
    def _roll_on_drop_table(self, slots: Dict[str, int], display_order: List[dict]) -> Tuple[str, int]:
        """
        Roll on the drop table and return (outcome, roll_value).
        
        Uses display_order to ensure consistent ordering (common → rare).
        """
        # Build ordered list from display config
        order = [item["key"] for item in display_order]
        
        total = sum(slots.values())
        if total == 0:
            return (order[0], 1)
        
        roll_value = self.rng.randint(1, total)
        
        cumulative = 0
        for outcome in order:
            slot_count = slots.get(outcome, 0)
            cumulative += slot_count
            if roll_value <= cumulative:
                # UI expects a 1...100 display roll. Clamp so it never returns 0.
                roll_percent = int((roll_value / total) * 100)
                roll_percent = max(1, min(100, roll_percent))
                return (outcome, roll_percent)
        
        return (order[0], 50)  # Fallback


# Singleton for convenience
_manager = FishingManager()

def get_manager() -> FishingManager:
    return _manager
