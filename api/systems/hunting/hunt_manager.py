"""
HUNT MANAGER
============
Orchestrates group hunting sessions.
Handles lobby creation, party management, phase execution, and rewards.
"""

import random
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from enum import Enum

from ..rolls import RollEngine, RollResult, GroupRollResult
from .config import (
    HuntPhase,
    HuntConfig,
    ANIMALS,
    ANIMAL_WEIGHTS_BY_TIER,
    DROP_TABLES,
    PHASE_CONFIG,
    TRACK_TIER_THRESHOLDS,
    FAITH_DROP_BONUS_PER_POINT,
    MEAT_MARKET_VALUE,
    NO_TRAIL_MEAT,
    ESCAPED_MEAT_PERCENT,
    # Drop tables for all phases
    TRACK_DROP_TABLE,
    TRACK_SHIFT_PER_SUCCESS,
    ATTACK_DROP_TABLE,
    ATTACK_SHIFT_PER_SUCCESS,
    ATTACK_DAMAGE,
    BLESSING_DROP_TABLE,
    BLESSING_SHIFT_PER_SUCCESS,
    BLESSING_BONUS,
    get_max_tier_from_track_score,
)


@dataclass
class HuntParticipant:
    """A player participating in a hunt"""
    player_id: int
    player_name: str
    stats: Dict[str, int]
    joined_at: datetime = field(default_factory=datetime.utcnow)
    is_ready: bool = False
    is_injured: bool = False
    
    # Results tracking
    total_contribution: float = 0.0
    successful_rolls: int = 0
    critical_rolls: int = 0
    meat_earned: int = 0
    items_earned: List[str] = field(default_factory=list)
    
    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "player_name": self.player_name,
            "stats": self.stats,
            "is_ready": self.is_ready,
            "is_injured": self.is_injured,
            "total_contribution": round(self.total_contribution, 2),
            "successful_rolls": self.successful_rolls,
            "critical_rolls": self.critical_rolls,
            "meat_earned": self.meat_earned,
            "items_earned": self.items_earned,
        }


@dataclass
class PhaseResult:
    """Result of a single hunt phase"""
    phase: HuntPhase
    group_roll: GroupRollResult
    phase_score: float
    outcome_message: str
    effects: Dict[str, any] = field(default_factory=dict)
    
    def to_dict(self) -> dict:
        return {
            "phase": self.phase.value,
            "phase_name": PHASE_CONFIG[self.phase]["display_name"],
            "icon": PHASE_CONFIG[self.phase]["icon"],
            "group_roll": self.group_roll.to_dict(),
            "phase_score": round(self.phase_score, 2),
            "outcome_message": self.outcome_message,
            "effects": self.effects,
        }


class HuntStatus(Enum):
    """Current status of a hunt session"""
    LOBBY = "lobby"           # Waiting for players
    IN_PROGRESS = "in_progress"  # Hunt is active
    COMPLETED = "completed"   # Hunt finished successfully
    FAILED = "failed"         # Hunt failed (no trail, escaped)
    CANCELLED = "cancelled"   # Hunt was cancelled


@dataclass
class PhaseRoundResult:
    """Result of a single roll within a phase"""
    round_number: int
    player_id: int
    player_name: str
    roll_value: int           # 1-100
    stat_value: int           # Player's stat
    is_success: bool
    is_critical: bool
    contribution: float       # Score contribution
    effect_message: str       # "Hit!", "Miss!", "Critical!"
    
    def to_dict(self) -> dict:
        return {
            "round": self.round_number,
            "player_id": self.player_id,
            "player_name": self.player_name,
            "roll": self.roll_value,
            "stat": self.stat_value,
            "is_success": self.is_success,
            "is_critical": self.is_critical,
            "contribution": round(self.contribution, 2),
            "message": self.effect_message,
        }


@dataclass
class PhaseState:
    """Tracks current phase progress for multi-roll system"""
    phase: HuntPhase
    rounds_completed: int = 0
    total_score: float = 0.0
    round_results: List[PhaseRoundResult] = field(default_factory=list)
    
    # Phase-specific tracking (legacy)
    damage_dealt: int = 0          # Strike phase
    animal_remaining_hp: int = 0    # Strike phase
    escape_risk: float = 0.0        # UNUSED - kept for compatibility
    blessing_bonus: float = 0.0     # UNUSED - now using drop table
    
    # DROP TABLE SYSTEM - same for all phases!
    # Track: which creature? Attack: how much damage? Blessing: what bonus?
    drop_table_slots: Dict[str, int] = field(default_factory=dict)
    
    # Probability state derived from slots (for UI display)
    creature_probabilities: Dict[str, float] = field(default_factory=dict)
    
    # Phase completion
    is_resolved: bool = False
    resolution_roll: Optional[int] = None  # The "master roll" value
    resolution_outcome: Optional[str] = None  # The chosen outcome key
    
    def to_dict(self) -> dict:
        return {
            "phase": self.phase.value,
            "rounds_completed": self.rounds_completed,
            "max_rolls": PHASE_CONFIG.get(self.phase, {}).get("max_rolls", 1),
            "total_score": round(self.total_score, 2),
            "round_results": [r.to_dict() for r in self.round_results],
            "damage_dealt": self.damage_dealt,
            "animal_remaining_hp": self.animal_remaining_hp,
            "escape_risk": round(self.escape_risk, 2),
            "blessing_bonus": round(self.blessing_bonus, 2),
            # Generic drop table info for all phases
            "drop_table_slots": self.drop_table_slots.copy(),
            "creature_probabilities": {k: round(v, 3) for k, v in self.creature_probabilities.items()},
            "is_resolved": self.is_resolved,
            "resolution_roll": self.resolution_roll,
            "resolution_outcome": self.resolution_outcome,
            "can_roll": self.can_roll(),
            "can_resolve": self.can_resolve(),
        }
    
    def can_roll(self) -> bool:
        """Check if more rolls are allowed"""
        if self.is_resolved:
            return False
        max_rolls = PHASE_CONFIG.get(self.phase, {}).get("max_rolls", 1)
        return self.rounds_completed < max_rolls
    
    def can_resolve(self) -> bool:
        """Check if phase can be resolved"""
        if self.is_resolved:
            return False
        min_rolls = PHASE_CONFIG.get(self.phase, {}).get("min_rolls", 1)
        return self.rounds_completed >= min_rolls
    
    def get_probabilities(self) -> Dict[str, float]:
        """Convert slots to probabilities"""
        total = sum(self.drop_table_slots.values())
        if total == 0:
            return {}
        return {k: v / total for k, v in self.drop_table_slots.items()}


@dataclass
class HuntSession:
    """A complete hunt session"""
    hunt_id: str
    kingdom_id: str
    created_by: int
    created_at: datetime = field(default_factory=datetime.utcnow)
    
    # Status
    status: HuntStatus = HuntStatus.LOBBY
    current_phase: HuntPhase = HuntPhase.LOBBY
    
    # Participants
    participants: Dict[int, HuntParticipant] = field(default_factory=dict)
    
    # Hunt progress
    animal_id: Optional[str] = None
    animal_data: Optional[dict] = None
    track_score: float = 0.0
    max_tier_unlocked: int = 0
    is_spooked: bool = False
    animal_escaped: bool = False
    
    # Multi-roll phase state
    current_phase_state: Optional[PhaseState] = None
    
    # Phase results
    phase_results: List[PhaseResult] = field(default_factory=list)
    
    # Rewards (Meat + Rare Items - NO GOLD from hunts!)
    total_meat: int = 0
    bonus_meat: int = 0  # From blessing bonus
    items_dropped: List[str] = field(default_factory=list)
    
    # Timing
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    def add_participant(self, player_id: int, player_name: str, stats: Dict[str, int]) -> bool:
        """Add a player to the hunt. Returns False if hunt is full."""
        if len(self.participants) >= HuntConfig.MAX_PARTY:
            return False
        if self.status != HuntStatus.LOBBY:
            return False
        
        self.participants[player_id] = HuntParticipant(
            player_id=player_id,
            player_name=player_name,
            stats=stats,
        )
        return True
    
    def remove_participant(self, player_id: int) -> bool:
        """Remove a player from the hunt."""
        if player_id in self.participants:
            del self.participants[player_id]
            return True
        return False
    
    def set_ready(self, player_id: int, ready: bool = True) -> bool:
        """Mark a player as ready."""
        if player_id in self.participants:
            self.participants[player_id].is_ready = ready
            return True
        return False
    
    def all_ready(self) -> bool:
        """Check if all participants are ready."""
        if not self.participants:
            return False
        return all(p.is_ready for p in self.participants.values())
    
    def get_participant_list(self) -> List[Dict]:
        """Get list of participants in roll format."""
        return [
            {
                "player_id": p.player_id,
                "player_name": p.player_name,
                "stats": p.stats,
            }
            for p in self.participants.values()
        ]
    
    def to_dict(self) -> dict:
        """Convert to JSON-serializable dict."""
        return {
            "hunt_id": self.hunt_id,
            "kingdom_id": self.kingdom_id,
            "created_by": self.created_by,
            "status": self.status.value,
            "current_phase": self.current_phase.value,
            "participants": {
                str(pid): p.to_dict() 
                for pid, p in self.participants.items()
            },
            "animal": {
                "id": self.animal_id,
                "name": self.animal_data["name"] if self.animal_data else None,
                "icon": self.animal_data["icon"] if self.animal_data else None,
                "tier": self.animal_data["tier"] if self.animal_data else None,
                "hp": self.animal_data["hp"] if self.animal_data else None,
            } if self.animal_id else None,
            "track_score": round(self.track_score, 2),
            "max_tier_unlocked": self.max_tier_unlocked,
            "is_spooked": self.is_spooked,
            "animal_escaped": self.animal_escaped,
            "phase_state": self.current_phase_state.to_dict() if self.current_phase_state else None,
            "phase_results": [pr.to_dict() for pr in self.phase_results],
            "rewards": {
                "meat": self.total_meat,
                "bonus_meat": self.bonus_meat,
                "total_meat": self.total_meat + self.bonus_meat,
                "meat_market_value": (self.total_meat + self.bonus_meat) * MEAT_MARKET_VALUE,
                "items": self.items_dropped,
            },
            "party_size": len(self.participants),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }


class HuntManager:
    """
    Manages hunt sessions and phase execution.
    
    Usage:
        manager = HuntManager()
        
        # Create a hunt
        session = manager.create_hunt("kingdom_123", creator_id=1)
        
        # Add participants
        session.add_participant(1, "Alice", {"intelligence": 5, "attack_power": 3, ...})
        session.add_participant(2, "Bob", {"intelligence": 3, "attack_power": 5, ...})
        
        # Start the hunt
        manager.start_hunt(session)
        
        # Execute phases
        track_result = manager.execute_phase(session, HuntPhase.TRACK)
        approach_result = manager.execute_phase(session, HuntPhase.APPROACH)
        strike_result = manager.execute_phase(session, HuntPhase.STRIKE)
        blessing_result = manager.execute_phase(session, HuntPhase.BLESSING)
        
        # Get final results
        final = manager.finalize_hunt(session)
    """
    
    def __init__(self, seed: Optional[int] = None):
        """
        Initialize the hunt manager.
        
        Args:
            seed: Optional random seed for testing
        """
        self.roll_engine = RollEngine(seed)
        self.rng = random.Random(seed)
        self._hunts: Dict[str, HuntSession] = {}
    
    def create_hunt(
        self,
        kingdom_id: str,
        creator_id: int,
        creator_name: str,
        creator_stats: Dict[str, int],
    ) -> HuntSession:
        """
        Create a new hunt session.
        
        Args:
            kingdom_id: The kingdom where the hunt takes place
            creator_id: Player ID of the hunt creator
            creator_name: Display name of creator
            creator_stats: Creator's stats dict
            
        Returns:
            New HuntSession in lobby status
        """
        hunt_id = f"hunt_{kingdom_id}_{int(time.time() * 1000)}"
        
        session = HuntSession(
            hunt_id=hunt_id,
            kingdom_id=kingdom_id,
            created_by=creator_id,
        )
        
        # Creator auto-joins
        session.add_participant(creator_id, creator_name, creator_stats)
        session.set_ready(creator_id, True)  # Creator is auto-ready
        
        self._hunts[hunt_id] = session
        return session
    
    def get_hunt(self, hunt_id: str) -> Optional[HuntSession]:
        """Get a hunt session by ID."""
        return self._hunts.get(hunt_id)
    
    def get_active_hunt_for_kingdom(self, kingdom_id: str) -> Optional[HuntSession]:
        """Get the active hunt in a kingdom, if any."""
        for hunt in self._hunts.values():
            if hunt.kingdom_id == kingdom_id and hunt.status in (HuntStatus.LOBBY, HuntStatus.IN_PROGRESS):
                return hunt
        return None
    
    def start_hunt(self, session: HuntSession) -> bool:
        """
        Start a hunt session (transition from lobby to tracking).
        
        Args:
            session: The hunt session to start
            
        Returns:
            True if started successfully
        """
        if session.status != HuntStatus.LOBBY:
            return False
        if len(session.participants) < HuntConfig.MIN_PARTY:
            return False
        
        session.status = HuntStatus.IN_PROGRESS
        session.current_phase = HuntPhase.TRACK
        session.started_at = datetime.utcnow()
        
        # Initialize first phase
        self._init_phase_state(session, HuntPhase.TRACK)
        
        return True
    
    # ============================================================
    # MULTI-ROLL PHASE SYSTEM
    # ============================================================
    
    def _init_phase_state(self, session: HuntSession, phase: HuntPhase) -> None:
        """Initialize state for a new phase with its drop table."""
        state = PhaseState(phase=phase)
        
        if phase == HuntPhase.TRACK:
            # Creature drop table
            state.drop_table_slots = TRACK_DROP_TABLE.copy()
        elif phase == HuntPhase.STRIKE:
            # Damage drop table
            state.drop_table_slots = ATTACK_DROP_TABLE.copy()
            if session.animal_data:
                state.animal_remaining_hp = session.animal_data.get("hp", 1)
        elif phase == HuntPhase.BLESSING:
            # Loot bonus drop table
            state.drop_table_slots = BLESSING_DROP_TABLE.copy()
        
        # Convert slots to probabilities for UI
        state.creature_probabilities = state.get_probabilities()
        
        session.current_phase_state = state
        session.current_phase = phase
    
    def execute_roll(self, session: HuntSession, player_id: int) -> dict:
        """
        Execute a single roll within the current phase.
        
        This is the core of the multi-roll system - each roll affects
        the phase state (shifts probabilities, deals damage, etc.)
        
        Returns:
            Roll result dict with updated phase state
        """
        state = session.current_phase_state
        if not state or not state.can_roll():
            return {"success": False, "message": "Cannot roll right now"}
        
        if player_id not in session.participants:
            return {"success": False, "message": "Player not in hunt"}
        
        participant = session.participants[player_id]
        config = PHASE_CONFIG.get(state.phase, {})
        stat_name = config.get("stat", "intelligence")
        stat_value = participant.stats.get(stat_name, 0)
        
        # Execute the roll
        roll_result = self.roll_engine.roll(
            player_id=player_id,
            player_name=participant.player_name,
            stat_name=stat_name,
            stat_value=stat_value,
        )
        
        # Create round result
        # roll_value is 0-1 float, convert to 1-100 int for display
        round_result = PhaseRoundResult(
            round_number=state.rounds_completed + 1,
            player_id=player_id,
            player_name=participant.player_name,
            roll_value=int(roll_result.roll_value * 100),
            stat_value=stat_value,
            is_success=roll_result.is_success,
            is_critical=roll_result.is_critical,
            contribution=roll_result.contribution,
            effect_message=self._get_roll_message(roll_result, config),
        )
        
        # Update phase state based on phase type
        phase_update = self._apply_roll_to_phase(session, state, round_result, config)
        
        # Update participant stats
        participant.total_contribution += roll_result.contribution
        if roll_result.is_success:
            participant.successful_rolls += 1
        if roll_result.is_critical:
            participant.critical_rolls += 1
        
        # Record round
        state.round_results.append(round_result)
        state.rounds_completed += 1
        state.total_score += roll_result.contribution
        
        return {
            "success": True,
            "roll_result": round_result.to_dict(),
            "phase_state": state.to_dict(),
            "phase_update": phase_update,
            "hunt": session.to_dict(),
        }
    
    def _get_roll_message(self, roll_result, config: dict) -> str:
        """Get the message for a roll result."""
        if roll_result.is_critical and roll_result.is_success:
            return config.get("critical_effect", "Critical!")
        elif roll_result.is_success:
            return config.get("success_effect", "Success!")
        elif roll_result.is_critical:
            return "Critical fail!"
        else:
            return config.get("failure_effect", "Miss!")
    
    def _apply_roll_to_phase(
        self, 
        session: HuntSession, 
        state: PhaseState, 
        roll: PhaseRoundResult,
        config: dict
    ) -> dict:
        """
        Apply a roll's effects to the phase state.
        
        ALL PHASES use the same drop table system:
        - TRACK: shifts creature probabilities
        - ATTACK: shifts damage outcome probabilities  
        - BLESSING: shifts loot bonus probabilities
        
        Returns update info for UI.
        """
        update = {"events": []}
        
        # ALL phases use the same drop table shift mechanic!
        if roll.is_success:
            multiplier = 2 if roll.is_critical else 1
            self._shift_drop_table(state, multiplier)
            update["shift_applied"] = True
            
            if roll.is_critical:
                update["events"].append("⚡ CRITICAL HIT!")
            else:
                update["events"].append("✓ Success!")
        else:
            update["shift_applied"] = False
            update["events"].append("✗ Miss!")
        
        # Always send updated probabilities
        update["new_probabilities"] = state.creature_probabilities.copy()
        update["drop_table_slots"] = state.drop_table_slots.copy()
        
        # Phase-specific HP tracking for Strike (visual only)
        if state.phase == HuntPhase.STRIKE:
            update["remaining_hp"] = state.animal_remaining_hp
            update["total_damage"] = state.damage_dealt
        
        return update
    
    
    def _shift_drop_table(self, state: PhaseState, multiplier: int = 1) -> None:
        """
        Shift the drop table slots based on roll success.
        Same system for ALL phases - RuneScape style!
        
        Success: Slots shift from common outcomes to rare outcomes
        Critical: 2x shift!
        """
        # Get the correct shift config for this phase
        if state.phase == HuntPhase.TRACK:
            shift_config = TRACK_SHIFT_PER_SUCCESS
        elif state.phase == HuntPhase.STRIKE:
            shift_config = ATTACK_SHIFT_PER_SUCCESS
        elif state.phase == HuntPhase.BLESSING:
            shift_config = BLESSING_SHIFT_PER_SUCCESS
        else:
            return
        
        # Apply shifts
        for outcome_key, shift in shift_config.items():
            if outcome_key in state.drop_table_slots:
                state.drop_table_slots[outcome_key] += shift * multiplier
                # Never go below 1 slot (always possible, just unlikely)
                state.drop_table_slots[outcome_key] = max(1, state.drop_table_slots[outcome_key])
        
        # Update probabilities for UI
        state.creature_probabilities = state.get_probabilities()
    
    def resolve_phase(self, session: HuntSession) -> dict:
        """
        Resolve/finalize the current phase.
        
        For TRACK: Performs the "master roll" to select creature
        For STRIKE: Already resolves per-roll (HP-based), this finalizes
        For BLESSING: Finalizes loot calculation
        
        Returns:
            Resolution result with outcome
        """
        state = session.current_phase_state
        if not state:
            return {"success": False, "message": "No active phase"}
        
        if not state.can_resolve():
            min_rolls = PHASE_CONFIG.get(state.phase, {}).get("min_rolls", 1)
            return {
                "success": False, 
                "message": f"Need at least {min_rolls} roll(s) before resolving"
            }
        
        result = {"success": True, "phase": state.phase.value}
        
        if state.phase == HuntPhase.TRACK:
            result.update(self._resolve_track_phase(session, state))
        elif state.phase == HuntPhase.STRIKE:
            result.update(self._resolve_strike_phase(session, state))
        elif state.phase == HuntPhase.BLESSING:
            result.update(self._resolve_blessing_phase(session, state))
        
        state.is_resolved = True
        
        # Create phase result for history
        from ..rolls import GroupRollResult, RollResult as EngineRollResult
        from ..rolls.engine import RollOutcome
        
        # Convert our round results to the old format for compatibility
        individual_rolls = []
        for rr in state.round_results:
            # Determine outcome from success/critical flags
            if rr.is_success and rr.is_critical:
                outcome = RollOutcome.CRITICAL_SUCCESS
            elif rr.is_success:
                outcome = RollOutcome.SUCCESS
            elif rr.is_critical:
                outcome = RollOutcome.CRITICAL_FAILURE
            else:
                outcome = RollOutcome.FAILURE
            
            individual_rolls.append(EngineRollResult(
                player_id=rr.player_id,
                player_name=rr.player_name,
                stat_name=PHASE_CONFIG[state.phase]["stat"],
                stat_value=rr.stat_value,
                roll_value=rr.roll_value / 100.0,  # Convert back to 0-1 range
                success_threshold=0.5,  # Approximate
                outcome=outcome,
                contribution=rr.contribution,
            ))
        
        group_roll = GroupRollResult(
            phase_name=state.phase.value,
            individual_rolls=individual_rolls,
            total_contribution=state.total_score,
            success_count=sum(1 for r in state.round_results if r.is_success),
            critical_count=sum(1 for r in state.round_results if r.is_critical),
            group_size=len(session.participants),
            group_bonus=0.0,  # Not used in multi-roll system
        )
        
        phase_result = PhaseResult(
            phase=state.phase,
            group_roll=group_roll,
            phase_score=state.total_score,
            outcome_message=result.get("message", "Phase complete"),
            effects=result.get("effects", {}),
        )
        session.phase_results.append(phase_result)
        
        result["phase_result"] = phase_result.to_dict()
        result["hunt"] = session.to_dict()
        
        return result
    
    def _resolve_track_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """Resolve tracking - do the master roll!"""
        # Master roll: random 0-100 that slides along the probability bar
        master_roll = self.rng.random()
        state.resolution_roll = int(master_roll * 100)
        
        session.track_score = state.total_score
        session.max_tier_unlocked = get_max_tier_from_track_score(state.total_score)
        
        # Select creature based on master roll and probabilities
        cumulative = 0
        selected_animal = None
        
        for animal_id, prob in state.creature_probabilities.items():
            cumulative += prob
            if master_roll <= cumulative and prob > 0:
                selected_animal = animal_id
                break
        
        # Fallback to a valid creature if something went wrong
        if not selected_animal:
            valid_animals = [aid for aid, p in state.creature_probabilities.items() if p > 0]
            if valid_animals:
                selected_animal = self.rng.choice(valid_animals)
            else:
                # Worst case - pick squirrel
                selected_animal = "squirrel"
        
        if state.total_score <= 0:
            # Failed tracking entirely
            return {
                "message": "No trail found. The forest is quiet...",
                "effects": {"no_trail": True, "master_roll": state.resolution_roll},
            }
        
        session.animal_id = selected_animal
        session.animal_data = ANIMALS[selected_animal].copy()
        
        return {
            "message": f"🎯 Master Roll landed on {session.animal_data['icon']} {session.animal_data['name']}!",
            "effects": {
                "animal_found": True,
                "master_roll": state.resolution_roll,
                "animal_id": selected_animal,
                "animal_name": session.animal_data["name"],
                "animal_icon": session.animal_data["icon"],
                "animal_tier": session.animal_data["tier"],
                "animal_hp": session.animal_data["hp"],
            },
            "master_roll": state.resolution_roll,
            "probabilities": state.creature_probabilities,
        }
    
    def _resolve_strike_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """
        Resolve strike phase using DROP TABLE!
        
        Each roll shifted the damage table. Now we roll on it to see final damage.
        Total damage from all resolution rolls determines kill/escape.
        """
        # MASTER ROLL on the damage table!
        master_roll = self.rng.randint(1, 100)
        state.resolution_roll = master_roll
        
        # Roll on table for each attack round
        animal_hp = session.animal_data.get("hp", 1)
        total_damage = 0
        damage_breakdown = []
        
        for i in range(state.rounds_completed):
            # Roll on the damage table
            outcome = self._roll_on_drop_table(state.drop_table_slots)
            damage = ATTACK_DAMAGE.get(outcome, 0)
            total_damage += damage
            damage_breakdown.append({"round": i + 1, "outcome": outcome, "damage": damage})
        
        state.resolution_outcome = "kill" if total_damage >= animal_hp else "escape"
        state.damage_dealt = total_damage
        state.animal_remaining_hp = max(0, animal_hp - total_damage)
        
        if total_damage >= animal_hp:
            # VICTORY! Animal slain
            return {
                "message": f"🎯 {session.animal_data['icon']} {session.animal_data['name']} slain! ({total_damage} damage)",
                "effects": {
                    "killed": True,
                    "damage_dealt": total_damage,
                    "overkill": total_damage - animal_hp,
                    "master_roll": master_roll,
                    "damage_breakdown": damage_breakdown,
                    "drop_table_slots": state.drop_table_slots.copy(),
                },
            }
        else:
            # Not enough damage - animal escapes (get partial meat from wounds)
            session.animal_escaped = True
            escaped_meat = int(session.animal_data.get("meat", 0) * ESCAPED_MEAT_PERCENT)
            session.total_meat = escaped_meat
            
            return {
                "message": f"The {session.animal_data['name']} took {total_damage} damage but escaped!",
                "effects": {
                    "escaped": True,
                    "damage_dealt": total_damage,
                    "remaining_hp": state.animal_remaining_hp,
                    "consolation_meat": escaped_meat,
                    "master_roll": master_roll,
                    "damage_breakdown": damage_breakdown,
                    "drop_table_slots": state.drop_table_slots.copy(),
                },
            }
    
    def _resolve_blessing_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """
        Resolve blessing phase using DROP TABLE!
        
        Roll on the loot bonus table to determine final loot multiplier.
        """
        # MASTER ROLL on the loot bonus table!
        master_roll = self.rng.randint(1, 100)
        state.resolution_roll = master_roll
        
        # Determine which bonus tier we got
        bonus_tier = self._roll_on_drop_table(state.drop_table_slots)
        bonus_amount = BLESSING_BONUS.get(bonus_tier, 0.0)
        state.resolution_outcome = bonus_tier
        state.blessing_bonus = bonus_amount
        
        # Apply loot with blessing bonus
        if not session.animal_escaped and session.animal_data:
            self._calculate_loot(session, bonus_amount)
        
        tier_messages = {
            "none": "The gods are silent... but you still claim your prize.",
            "small": f"✨ Minor blessing: +{int(bonus_amount * 100)}% loot!",
            "medium": f"🌟 Divine favor: +{int(bonus_amount * 100)}% loot!",
            "large": f"⚡ LEGENDARY BLESSING: +{int(bonus_amount * 100)}% loot!",
        }
        
        return {
            "message": tier_messages.get(bonus_tier, tier_messages["none"]),
            "effects": {
                "bonus_tier": bonus_tier,
                "blessing_bonus": bonus_amount,
                "items_dropped": session.items_dropped,
                "meat": session.total_meat,
                "bonus_meat": session.bonus_meat,
                "master_roll": master_roll,
                "drop_table_slots": state.drop_table_slots.copy(),
            },
        }
    
    def _roll_on_drop_table(self, slots: Dict[str, int]) -> str:
        """Roll 1-100 and find which outcome it lands on."""
        total = sum(slots.values())
        if total == 0:
            return list(slots.keys())[0]  # Fallback
        
        roll = self.rng.randint(1, total)
        cumulative = 0
        
        for outcome, slot_count in slots.items():
            cumulative += slot_count
            if roll <= cumulative:
                return outcome
        
        return list(slots.keys())[-1]  # Fallback to last
    
    def advance_to_next_phase(self, session: HuntSession) -> Optional[HuntPhase]:
        """
        Advance to the next phase after resolving current one.
        Returns the new phase, or None if hunt is complete.
        """
        phase_order = [HuntPhase.TRACK, HuntPhase.STRIKE, HuntPhase.BLESSING]
        current = session.current_phase
        
        # Check for early termination
        if current == HuntPhase.TRACK and session.track_score <= 0:
            return None  # Hunt failed
        if current == HuntPhase.STRIKE and session.animal_escaped:
            return None  # Animal escaped
        
        try:
            current_idx = phase_order.index(current)
            if current_idx < len(phase_order) - 1:
                next_phase = phase_order[current_idx + 1]
                self._init_phase_state(session, next_phase)
                return next_phase
        except ValueError:
            pass
        
        return None  # Hunt complete
    
    def execute_phase(self, session: HuntSession, phase: HuntPhase) -> PhaseResult:
        """
        Execute a hunt phase and record results.
        
        Args:
            session: The active hunt session
            phase: Which phase to execute
            
        Returns:
            PhaseResult with rolls and outcomes
        """
        if phase not in PHASE_CONFIG:
            raise ValueError(f"Invalid phase: {phase}")
        
        config = PHASE_CONFIG[phase]
        stat_name = config["stat"]
        
        # Perform group roll
        participants = session.get_participant_list()
        group_roll = self.roll_engine.group_roll(
            participants=participants,
            stat_name=stat_name,
            phase_name=config["name"],
        )
        
        # Update participant stats
        for roll in group_roll.individual_rolls:
            if roll.player_id in session.participants:
                p = session.participants[roll.player_id]
                p.total_contribution += roll.contribution
                if roll.is_success:
                    p.successful_rolls += 1
                if roll.is_critical:
                    p.critical_rolls += 1
        
        # Calculate phase-specific outcomes
        phase_score = group_roll.total_contribution
        effects = {}
        outcome_message = ""
        
        if phase == HuntPhase.TRACK:
            session.track_score = phase_score
            session.max_tier_unlocked = get_max_tier_from_track_score(phase_score)
            
            if phase_score <= 0:
                outcome_message = "No trail found. The forest is quiet today..."
                effects["no_trail"] = True
            else:
                tier = session.max_tier_unlocked
                outcome_message = f"Found tracks! (Tier {tier} animals available)"
                effects["tier_unlocked"] = tier
                
                # Select the animal
                self._select_animal(session)
                if session.animal_data:
                    outcome_message = f"You've found {session.animal_data['icon']} {session.animal_data['name']} tracks!"
        
        # APPROACH phase removed - was boring
        
        elif phase == HuntPhase.STRIKE:
            if not session.animal_data:
                outcome_message = "Nothing to hunt!"
                effects["no_target"] = True
            else:
                animal_hp = session.animal_data["hp"]
                damage = (
                    group_roll.success_count * config["damage_per_success"] +
                    group_roll.critical_count * config["damage_per_critical"]
                )
                
                effects["damage_dealt"] = damage
                effects["animal_hp"] = animal_hp
                
                if damage >= animal_hp:
                    outcome_message = f"🎯 {session.animal_data['name']} slain!"
                    effects["killed"] = True
                elif group_roll.success_rate < config["escape_threshold"]:
                    session.animal_escaped = True
                    outcome_message = f"The {session.animal_data['name']} escaped!"
                    effects["escaped"] = True
                else:
                    # Partial success - wounded but escaped (get some meat)
                    session.animal_escaped = True
                    session.total_meat = int(session.animal_data["meat"] * ESCAPED_MEAT_PERCENT)
                    outcome_message = f"The wounded {session.animal_data['name']} got away..."
                    effects["wounded_escape"] = True
                    effects["consolation_meat"] = session.total_meat
                
                # Counterattack check
                if self.rng.random() < config["counterattack_chance"]:
                    # Pick random participant to injure
                    victim = self.rng.choice(list(session.participants.keys()))
                    session.participants[victim].is_injured = True
                    effects["counterattack"] = victim
        
        elif phase == HuntPhase.BLESSING:
            blessing_score = phase_score
            bonus_multiplier = (
                group_roll.success_count * config["bonus_per_success"] +
                group_roll.critical_count * config["bonus_per_critical"]
            )
            effects["loot_bonus"] = bonus_multiplier
            
            if group_roll.critical_count > 0:
                outcome_message = "✨ The gods bestow their blessing!"
            elif group_roll.success_count > 0:
                outcome_message = "Your prayers are heard."
            else:
                outcome_message = "Silence from the heavens..."
            
            # Apply loot bonus and calculate drops
            if not session.animal_escaped and session.animal_data:
                self._calculate_loot(session, bonus_multiplier)
        
        # Create phase result
        result = PhaseResult(
            phase=phase,
            group_roll=group_roll,
            phase_score=phase_score,
            outcome_message=outcome_message,
            effects=effects,
        )
        
        session.phase_results.append(result)
        session.current_phase = phase
        
        return result
    
    def _select_animal(self, session: HuntSession, force_tier: Optional[int] = None) -> None:
        """Select an animal based on tracking score."""
        tier = force_tier if force_tier is not None else session.max_tier_unlocked
        
        # Get available animals for this tier
        weights = ANIMAL_WEIGHTS_BY_TIER.get(tier, ANIMAL_WEIGHTS_BY_TIER[0])
        
        # Weighted random selection
        total_weight = sum(weights.values())
        roll = self.rng.random() * total_weight
        
        cumulative = 0
        for animal_id, weight in weights.items():
            cumulative += weight
            if roll <= cumulative:
                session.animal_id = animal_id
                session.animal_data = ANIMALS[animal_id].copy()
                break
    
    def _calculate_loot(self, session: HuntSession, blessing_bonus: float) -> None:
        """Calculate and assign loot based on hunt results.
        
        Hunts drop MEAT (main reward) + RARE ITEMS (for bow crafting).
        NO GOLD DROPS - players can sell meat at market for gold.
        """
        if not session.animal_data:
            return
        
        animal = session.animal_data
        tier = animal["tier"]
        
        # Base meat reward
        session.total_meat = animal["meat"]
        
        # Blessing bonus adds extra meat!
        session.bonus_meat = int(session.total_meat * blessing_bonus)
        
        # Get drop table and apply blessing bonus to rare item chances
        drop_table = DROP_TABLES.get(tier, {})
        for item, base_chance in drop_table.items():
            modified_chance = min(1.0, base_chance + blessing_bonus)
            if self.rng.random() < modified_chance:
                session.items_dropped.append(item)
        
        # Distribute meat among participants
        party_size = len(session.participants)
        total_meat_reward = session.total_meat + session.bonus_meat
        meat_per_player = total_meat_reward // party_size
        
        for p in session.participants.values():
            # Contribution bonus (top contributors get slightly more meat)
            contribution_ratio = p.total_contribution / max(1, sum(
                pp.total_contribution for pp in session.participants.values()
            ))
            bonus = int(meat_per_player * contribution_ratio * 0.2)  # Up to 20% bonus
            
            p.meat_earned = meat_per_player + bonus
            p.items_earned = session.items_dropped.copy()  # Everyone gets all drops (for now)
    
    def finalize_hunt(self, session: HuntSession) -> dict:
        """
        Finalize the hunt and return complete results.
        
        Args:
            session: The hunt session to finalize
            
        Returns:
            Complete hunt results dict
        """
        session.completed_at = datetime.utcnow()
        
        if session.animal_escaped or session.track_score <= 0:
            session.status = HuntStatus.FAILED
        else:
            session.status = HuntStatus.COMPLETED
        
        # If no trail was found, no rewards (you found nothing!)
        if session.track_score <= 0:
            for p in session.participants.values():
                p.meat_earned = NO_TRAIL_MEAT
            session.total_meat = NO_TRAIL_MEAT
        
        session.current_phase = HuntPhase.RESULTS
        
        return session.to_dict()
    
    def cleanup_old_hunts(self, max_age_hours: int = 24) -> int:
        """Remove old completed hunts from memory."""
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        removed = 0
        
        for hunt_id in list(self._hunts.keys()):
            hunt = self._hunts[hunt_id]
            if hunt.completed_at and hunt.completed_at < cutoff:
                del self._hunts[hunt_id]
                removed += 1
        
        return removed


# ============================================================
# PROBABILITY PREVIEW (for UI)
# ============================================================

def get_hunt_probability_preview(player_stats: Dict[str, int]) -> dict:
    """
    Generate a probability preview for the hunt UI.
    Shows the player their chances at each phase.
    """
    from ..rolls.config import get_chance_display
    
    phases = {}
    for phase, config in PHASE_CONFIG.items():
        if phase == HuntPhase.LOBBY or phase == HuntPhase.RESULTS:
            continue
        
        stat_name = config["stat"]
        stat_value = player_stats.get(stat_name, 0)
        
        phases[phase.value] = {
            "phase_name": config["display_name"],
            "stat_used": stat_name,
            "stat_value": stat_value,
            "icon": config["icon"],
            "description": config["description"],
            **get_chance_display(stat_value),
        }
    
    return {
        "phases": phases,
        "animals": [
            {
                "id": animal_id,
                "name": data["name"],
                "icon": data["icon"],
                "tier": data["tier"],
                "meat": data["meat"],
                "hp": data["hp"],
                "required_tracking": TRACK_TIER_THRESHOLDS.get(data["tier"], 0),
            }
            for animal_id, data in ANIMALS.items()
        ],
    }

