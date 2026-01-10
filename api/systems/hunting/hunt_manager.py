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
from ..rolls.config import ROLL_HIT_CHANCE
from routers.actions.utils import log_activity
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
    TRACK_DROP_TABLE_DISPLAY,
    ATTACK_DROP_TABLE,
    ATTACK_DROP_TABLE_BY_TIER,
    ATTACK_SHIFT_PER_SUCCESS,
    ATTACK_DROP_TABLE_DISPLAY,
    BLESSING_DROP_TABLE,
    BLESSING_SHIFT_PER_SUCCESS,
    BLESSING_DROP_TABLE_DISPLAY,
    LOOT_TIERS,
    get_max_tier_from_track_score,
)


def _format_datetime_iso(dt: datetime) -> str:
    """Format datetime as ISO8601 with Z suffix for iOS compatibility"""
    if dt is None:
        return None
    # Strip microseconds - Swift's .iso8601 decoder can't parse them
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        return iso_str + 'Z'
    return iso_str


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
    """
    Tracks current phase progress for multi-roll system.
    
    TEMPLATE SYSTEM: This sends ALL display data to frontend!
    Frontend is a dumb template - no hardcoded phase logic.
    This allows reuse for other minigames (fishing, mining, etc.)
    """
    phase: HuntPhase
    rounds_completed: int = 0
    total_score: float = 0.0
    round_results: List[PhaseRoundResult] = field(default_factory=list)
    
    # NEW SYSTEM: max_rolls = player's stat level for this phase
    max_rolls: int = 1
    stat_value: int = 0  # Player's stat value (also = max_rolls)
    
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
        """
        Convert to dict for API response.
        TEMPLATE SYSTEM: Include ALL display data for frontend!
        Frontend is a DUMB TEMPLATE - no hardcoded logic!
        """
        config = PHASE_CONFIG.get(self.phase, {})
        hit_chance_percent = int(ROLL_HIT_CHANCE * 100)
        
        # Get the correct drop table display config for this phase
        if self.phase == HuntPhase.TRACK:
            drop_table_display = TRACK_DROP_TABLE_DISPLAY
        elif self.phase == HuntPhase.STRIKE:
            drop_table_display = ATTACK_DROP_TABLE_DISPLAY
        elif self.phase == HuntPhase.BLESSING:
            drop_table_display = BLESSING_DROP_TABLE_DISPLAY
        else:
            drop_table_display = []
        
        return {
            # Core state
            "phase": self.phase.value,
            "rounds_completed": self.rounds_completed,
            "max_rolls": self.max_rolls,
            "total_score": round(self.total_score, 2),
            "round_results": [r.to_dict() for r in self.round_results],
            
            # TEMPLATE DISPLAY DATA - frontend reads these directly!
            "display": {
                "phase_name": config.get("display_name", self.phase.value),
                "phase_icon": config.get("icon", "questionmark"),
                "description": config.get("description", ""),
                "phase_color": config.get("phase_color", "inkMedium"),
                # Stat info
                "stat_name": config.get("stat", ""),
                "stat_display_name": config.get("stat_display_name", "Skill"),
                "stat_icon": config.get("stat_icon", "star.fill"),
                "stat_value": self.stat_value,
                # Hit chance - FLAT, not scaled!
                "hit_chance": hit_chance_percent,
                # Roll/resolve buttons
                "roll_button_label": config.get("roll_button_label", "Roll"),
                "roll_button_icon": config.get("roll_button_icon", "dice.fill"),
                "resolve_button_label": config.get("resolve_button_label", "Resolve"),
                "resolve_button_icon": config.get("resolve_button_icon", "checkmark"),
                # Drop table display - FULL CONFIG FROM BACKEND!
                "drop_table_title": config.get("drop_table_title", "ODDS"),
                "drop_table_title_resolving": config.get("drop_table_title_resolving", "ROLLING"),
                "drop_table_items": drop_table_display,  # Full display config for each item!
                # Master roll marker icon - varies by phase/skill
                "master_roll_icon": config.get("master_roll_icon", "scope"),
                # Roll messages
                "success_message": config.get("success_effect", "Success!"),
                "failure_message": config.get("failure_effect", "Miss!"),
                "critical_message": config.get("critical_effect", "Critical!"),
            },
            
            # Legacy fields (kept for backwards compat)
            "damage_dealt": self.damage_dealt,
            "animal_remaining_hp": self.animal_remaining_hp,
            "escape_risk": round(self.escape_risk, 2),
            "blessing_bonus": round(self.blessing_bonus, 2),
            
            # Generic drop table info for all phases
            "drop_table_slots": self.drop_table_slots.copy(),
            "creature_probabilities": {k: round(v, 3) for k, v in self.creature_probabilities.items()},
            
            # Phase completion
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
        return self.rounds_completed < self.max_rolls
    
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
    
    def _build_animal_dict(self) -> Optional[dict]:
        """Build animal dict with rare_drop info for tier 2+ animals."""
        if not self.animal_data:
            return None
        
        # Get rare drop info (same logic as /hunts/config endpoint)
        rare_drop = None
        tier = self.animal_data.get("tier", 0)
        if tier >= 2:
            # Import RESOURCES here to avoid circular import
            from routers.resources import RESOURCES
            rare_items = LOOT_TIERS.get("rare", {}).get("items", [])
            if rare_items:
                item_id = rare_items[0]
                item_config = RESOURCES.get(item_id, {})
                rare_drop = {
                    "item_id": item_id,
                    "item_name": item_config.get("display_name", item_id.title()),
                    "item_icon": item_config.get("icon", "cube.fill"),
                }
        
        return {
            "id": self.animal_id,
            "name": self.animal_data.get("name"),
            "icon": self.animal_data.get("icon"),
            "tier": tier,
            "hp": self.animal_data.get("hp"),
            "meat": self.animal_data.get("meat"),
            "rare_drop": rare_drop,
        }
    
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
            "animal": self._build_animal_dict() if self.animal_id else None,
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
            "created_at": _format_datetime_iso(self.created_at) if self.created_at else None,
            "started_at": _format_datetime_iso(self.started_at) if self.started_at else None,
            "completed_at": _format_datetime_iso(self.completed_at) if self.completed_at else None,
        }


class HuntManager:
    """
    Manages hunt sessions and phase execution.
    
    NOW WITH POSTGRESQL PERSISTENCE!
    Hunts are stored in the database so they survive Lambda instance restarts.
    
    Usage:
        manager = HuntManager()
        
        # Create a hunt (pass db session for persistence)
        session = manager.create_hunt(db, "kingdom_123", creator_id=1, ...)
        
        # Start the hunt
        manager.start_hunt(db, session)
        
        # Execute phases
        result = manager.execute_roll(db, session, player_id)
        
        # Get hunt by ID
        session = manager.get_hunt(db, hunt_id)
    """
    
    def __init__(self, seed: Optional[int] = None):
        """
        Initialize the hunt manager.
        
        Args:
            seed: Optional random seed for testing
        """
        self.roll_engine = RollEngine(seed)
        self.rng = random.Random(seed)
        # NOTE: Hunts are now stored in PostgreSQL, not in memory!
        # The old self._hunts dict is gone.
    
    def create_hunt(
        self,
        db,  # SQLAlchemy Session
        kingdom_id: str,
        creator_id: int,
        creator_name: str,
        creator_stats: Dict[str, int],
    ) -> HuntSession:
        """
        Create a new hunt session and save to database.
        
        Args:
            db: SQLAlchemy database session
            kingdom_id: The kingdom where the hunt takes place
            creator_id: Player ID of the hunt creator
            creator_name: Display name of creator
            creator_stats: Creator's stats dict
            
        Returns:
            New HuntSession in lobby status
        """
        from .persistence import save_hunt
        
        hunt_id = f"hunt_{kingdom_id}_{int(time.time() * 1000)}"
        
        session = HuntSession(
            hunt_id=hunt_id,
            kingdom_id=kingdom_id,
            created_by=creator_id,
        )
        
        # Creator auto-joins
        session.add_participant(creator_id, creator_name, creator_stats)
        session.set_ready(creator_id, True)  # Creator is auto-ready
        
        # Save to database
        save_hunt(db, session)
        
        return session
    
    def get_hunt(self, db, hunt_id: str) -> Optional[HuntSession]:
        """Get a hunt session by ID from database."""
        from .persistence import load_hunt
        return load_hunt(db, hunt_id)
    
    def get_active_hunt_for_kingdom(self, db, kingdom_id: str) -> Optional[HuntSession]:
        """Get the active hunt in a kingdom, if any."""
        from .persistence import get_active_hunt_for_kingdom
        return get_active_hunt_for_kingdom(db, kingdom_id)
    
    def get_active_hunt_for_player(self, db, player_id: int) -> Optional[HuntSession]:
        """Get the active hunt for a player (as creator or participant)."""
        from .persistence import get_active_hunt_for_player
        return get_active_hunt_for_player(db, player_id)
    
    def save_hunt(self, db, session: HuntSession) -> None:
        """Save hunt session to database after modifications."""
        from .persistence import save_hunt
        save_hunt(db, session)
    
    def start_hunt(self, db, session: HuntSession) -> bool:
        """
        Start a hunt session (transition from lobby to tracking).
        
        Args:
            db: SQLAlchemy database session
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
        
        # Save to database
        self.save_hunt(db, session)
        
        return True
    
    # ============================================================
    # MULTI-ROLL PHASE SYSTEM
    # ============================================================
    
    def _init_phase_state(self, session: HuntSession, phase: HuntPhase) -> None:
        """
        Initialize state for a new phase with its drop table.
        
        NEW SYSTEM: max_rolls = sum of all participants' stat levels for this phase!
        More skilled party = more attempts to shift the odds.
        """
        config = PHASE_CONFIG.get(phase, {})
        stat_name = config.get("stat", "intelligence")
        
        # Calculate max_rolls from party's combined stat levels
        # Each player contributes (1 + skill_level) rolls
        combined_stat = 0
        total_rolls = 0
        for participant in session.participants.values():
            stat_value = participant.stats.get(stat_name, 0)
            combined_stat += stat_value  # Actual stat for display
            total_rolls += 1 + stat_value  # 1 + skill_level per player for rolls
        
        # Ensure at least 1 roll
        max_rolls = max(1, total_rolls)
        
        state = PhaseState(
            phase=phase,
            max_rolls=max_rolls,
            stat_value=combined_stat,  # Actual combined stat for display
        )
        
        if phase == HuntPhase.TRACK:
            # Creature drop table
            state.drop_table_slots = TRACK_DROP_TABLE.copy()
        elif phase == HuntPhase.STRIKE:
            # Attack drop table - based on animal tier!
            # Higher tier = smaller HIT section (harder to kill)
            tier = session.animal_data.get("tier", 0) if session.animal_data else 0
            state.drop_table_slots = ATTACK_DROP_TABLE_BY_TIER.get(tier, ATTACK_DROP_TABLE).copy()
        elif phase == HuntPhase.BLESSING:
            # Loot bonus drop table
            state.drop_table_slots = BLESSING_DROP_TABLE.copy()
        
        # Convert slots to probabilities for UI
        state.creature_probabilities = state.get_probabilities()
        
        session.current_phase_state = state
        session.current_phase = phase
    
    def execute_roll(self, db, session: HuntSession, player_id: int) -> dict:
        """
        Execute a single roll within the current phase.
        
        NEW SYSTEM: Flat hit chance (15%), stat level = number of rolls!
        This creates exciting variance - each roll is hard but you get many attempts.
        
        Args:
            db: SQLAlchemy database session
            session: The hunt session
            player_id: ID of the player rolling
        
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
        
        # NEW SYSTEM: Flat hit chance, not scaled by stat!
        # Stat level determines NUMBER of rolls, not success chance
        roll_value = self.rng.random()
        is_success = roll_value < ROLL_HIT_CHANCE
        
        # Critical: top 25% of successes are critical (extra shift!)
        is_critical = is_success and roll_value < (ROLL_HIT_CHANCE * 0.25)
        
        # Contribution for tracking purposes
        contribution = 1.5 if is_critical else (1.0 if is_success else 0.0)
        
        # Create round result
        # Convert roll to 1-100 for display
        round_result = PhaseRoundResult(
            round_number=state.rounds_completed + 1,
            player_id=player_id,
            player_name=participant.player_name,
            roll_value=int(roll_value * 100),
            stat_value=stat_value,
            is_success=is_success,
            is_critical=is_critical,
            contribution=contribution,
            effect_message=self._get_roll_message_simple(is_success, is_critical, config),
        )
        
        # Update phase state based on phase type
        phase_update = self._apply_roll_to_phase(session, state, round_result, config)
        
        # Update participant stats
        participant.total_contribution += contribution
        if is_success:
            participant.successful_rolls += 1
        if is_critical:
            participant.critical_rolls += 1
        
        # Record round
        state.round_results.append(round_result)
        state.rounds_completed += 1
        state.total_score += contribution
        
        # Save to database
        self.save_hunt(db, session)
        
        return {
            "success": True,
            "roll_result": round_result.to_dict(),
            "phase_state": state.to_dict(),
            "phase_update": phase_update,
            "hunt": session.to_dict(),
        }
    
    def _get_roll_message(self, roll_result, config: dict) -> str:
        """Get the message for a roll result (legacy - uses RollResult object)."""
        if roll_result.is_critical and roll_result.is_success:
            return config.get("critical_effect", "Critical!")
        elif roll_result.is_success:
            return config.get("success_effect", "Success!")
        elif roll_result.is_critical:
            return "Critical fail!"
        else:
            return config.get("failure_effect", "Miss!")
    
    def _get_roll_message_simple(self, is_success: bool, is_critical: bool, config: dict) -> str:
        """Get the message for a roll result (new flat-chance system)."""
        if is_critical:
            return config.get("critical_effect", "Critical!")
        elif is_success:
            return config.get("success_effect", "Success!")
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
    
    def resolve_phase(self, db, session: HuntSession) -> dict:
        """
        Resolve/finalize the current phase.
        
        For TRACK: Performs the "master roll" to select creature
        For STRIKE: Already resolves per-roll (HP-based), this finalizes
        For BLESSING: Finalizes loot calculation
        
        Args:
            db: SQLAlchemy database session
            session: The hunt session
        
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
        
        # Broadcast rare loot drops to friends' activity feeds
        if state.phase == HuntPhase.BLESSING and result.get("effects", {}).get("is_rare"):
            self._broadcast_rare_loot(db, session)
        
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
        
        # Save to database
        self.save_hunt(db, session)
        
        result["phase_result"] = phase_result.to_dict()
        result["hunt"] = session.to_dict()
        
        return result
    
    def _resolve_track_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """
        Resolve tracking using DROP TABLE!
        
        ALL outcomes are ON THE BAR:
        - no_trail: Failed to find anything
        - squirrel, rabbit, deer, boar, bear, moose: Found that creature
        
        Master roll lands on one section - what you see is what you get!
        """
        # MASTER ROLL on the drop table
        outcome, master_roll = self._roll_on_drop_table(state.drop_table_slots)
        
        state.resolution_roll = master_roll
        state.resolution_outcome = outcome
        
        session.track_score = state.total_score
        session.max_tier_unlocked = get_max_tier_from_track_score(state.total_score)
        
        # Calculate probabilities for display
        total_slots = sum(state.drop_table_slots.values())
        
        # Check if we landed on "no_trail" (failure section)
        if outcome == "no_trail":
            no_trail_chance = state.drop_table_slots.get("no_trail", 0) / total_slots if total_slots > 0 else 0
            return {
                "message": "❌ Trail lost... The forest reveals nothing.",
                "effects": {
                    "no_trail": True,
                    "outcome": outcome,
                    "no_trail_chance": round(no_trail_chance, 3),
                    "master_roll": master_roll,
                    "drop_table_slots": state.drop_table_slots.copy(),
                },
            }
        
        # We found a creature!
        if outcome not in ANIMALS:
            # Fallback - shouldn't happen but just in case
            outcome = "squirrel"
        
        session.animal_id = outcome
        session.animal_data = ANIMALS[outcome].copy()
        
        animal_chance = state.drop_table_slots.get(outcome, 0) / total_slots if total_slots > 0 else 0
        
        return {
            "message": f"🎯 Master Roll landed on {session.animal_data['icon']} {session.animal_data['name']}!",
            "effects": {
                "animal_found": True,
                "outcome": outcome,
                "animal_chance": round(animal_chance, 3),
                "master_roll": master_roll,
                "animal_id": outcome,
                "animal_name": session.animal_data["name"],
                "animal_icon": session.animal_data["icon"],
                "animal_tier": session.animal_data["tier"],
                "animal_hp": session.animal_data["hp"],
                "drop_table_slots": state.drop_table_slots.copy(),
            },
        }
    
    def _resolve_strike_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """
        Resolve strike phase using DROP TABLE!
        
        Three sections: SCARE / MISS / HIT
        Only HIT kills. Scare and Miss both = animal escapes.
        """
        # MASTER ROLL - returns (outcome, roll_value)
        outcome, master_roll = self._roll_on_drop_table(state.drop_table_slots)
        
        state.resolution_roll = master_roll
        state.resolution_outcome = outcome
        
        # Calculate hit chance for display
        total_slots = sum(state.drop_table_slots.values())
        hit_slots = state.drop_table_slots.get("hit", 0)
        hit_chance = hit_slots / total_slots if total_slots > 0 else 0
        
        if outcome == "hit":
            # VICTORY! Animal slain
            return {
                "message": f"🎯 {session.animal_data['icon']} {session.animal_data['name']} slain!",
                "effects": {
                    "killed": True,
                    "outcome": outcome,
                    "hit_chance": round(hit_chance, 3),
                    "master_roll": master_roll,
                    "drop_table_slots": state.drop_table_slots.copy(),
                },
            }
        else:
            # SCARE or MISS - animal escapes
            session.animal_escaped = True
            escaped_meat = int(session.animal_data.get("meat", 0) * ESCAPED_MEAT_PERCENT)
            session.total_meat = escaped_meat
            
            if outcome == "scare":
                message = f"💨 The {session.animal_data['name']} got spooked and fled!"
            else:  # miss
                message = f"😤 You missed! The {session.animal_data['name']} escaped!"
            
            return {
                "message": message,
                "effects": {
                    "escaped": True,
                    "outcome": outcome,
                    "hit_chance": round(hit_chance, 3),
                    "consolation_meat": escaped_meat,
                    "master_roll": master_roll,
                    "drop_table_slots": state.drop_table_slots.copy(),
                },
            }
    
    def _resolve_blessing_phase(self, session: HuntSession, state: PhaseState) -> dict:
        """
        Resolve blessing phase using DROP TABLE!
        
        Simple 2-tier system: Common vs Rare
        Your faith rolls shifted the odds. Master roll determines which tier you get.
        """
        # MASTER ROLL - returns (outcome, roll_value)
        loot_tier, master_roll = self._roll_on_drop_table(state.drop_table_slots)
        
        state.resolution_roll = master_roll
        state.resolution_outcome = loot_tier
        
        # Calculate current rare chance for display
        total_slots = sum(state.drop_table_slots.values())
        rare_slots = state.drop_table_slots.get("rare", 0)
        rare_chance = rare_slots / total_slots if total_slots > 0 else 0
        
        # Apply loot based on tier
        if not session.animal_escaped and session.animal_data:
            self._calculate_loot(session, loot_tier)
        
        # Build message based on outcome
        if loot_tier == "rare":
            items_str = ", ".join(session.items_dropped) if session.items_dropped else "Sinew"
            message = f"✨ RARE LOOT! You found: {items_str}!"
        else:
            message = f"Common loot. ({int(rare_chance * 100)}% chance was rare)"
        
        return {
            "message": message,
            "effects": {
                "loot_tier": loot_tier,
                "is_rare": loot_tier == "rare",
                "rare_chance": round(rare_chance, 3),
                "items_dropped": session.items_dropped,
                "meat": session.total_meat,
                "bonus_meat": session.bonus_meat,
                "master_roll": master_roll,
                "drop_table_slots": state.drop_table_slots.copy(),
            },
        }
    
    def _roll_on_drop_table(self, slots: Dict[str, int], roll_value: Optional[int] = None) -> Tuple[str, int]:
        """
        Roll on the drop table and return (outcome, roll_value).
        
        If roll_value is provided, use it. Otherwise generate a random one.
        Returns both so the frontend can display where the roll landed.
        
        IMPORTANT: We iterate in EXPLICIT order (common → rare) so that:
        - LOW rolls = COMMON outcomes (no_trail, squirrel)
        - HIGH rolls = RARE outcomes (bear, moose)
        
        This is necessary because PostgreSQL JSONB doesn't preserve dict key order!
        """
        # Define explicit iteration order for each phase's drop table
        # Common outcomes FIRST (low rolls), rare outcomes LAST (high rolls)
        TRACK_ORDER = ["no_trail", "squirrel", "rabbit", "deer", "boar", "bear", "moose"]
        ATTACK_ORDER = ["scare", "miss", "hit"]  # Bad → Good
        BLESSING_ORDER = ["nothing", "common", "rare"]  # Nothing → Common → Rare
        
        # Determine which order to use based on the keys present
        if "no_trail" in slots:
            order = TRACK_ORDER
        elif "scare" in slots:
            order = ATTACK_ORDER
        elif "common" in slots:
            order = BLESSING_ORDER
        else:
            # Fallback: use whatever keys are in slots
            order = list(slots.keys())
        
        total = sum(slots.values())
        if total == 0:
            return (order[0], 1)  # Fallback
        
        # Use provided roll or generate one
        if roll_value is None:
            roll_value = self.rng.randint(1, total)
        
        cumulative = 0
        for outcome in order:
            slot_count = slots.get(outcome, 0)
            cumulative += slot_count
            if roll_value <= cumulative:
                # Convert roll to 1-100 scale for display
                roll_percent = int((roll_value / total) * 100)
                return (outcome, roll_percent)
        
        return (order[0], 50)  # Fallback to WORST outcome (first in order)
    
    def advance_to_next_phase(self, db, session: HuntSession) -> Optional[HuntPhase]:
        """
        Advance to the next phase after resolving current one.
        
        Args:
            db: SQLAlchemy database session
            session: The hunt session
            
        Returns:
            The new phase, or None if hunt is complete.
        """
        phase_order = [HuntPhase.TRACK, HuntPhase.STRIKE, HuntPhase.BLESSING]
        current = session.current_phase

        # Check for early termination
        # Track: if no animal was found (master roll landed on no_trail), hunt ends
        if current == HuntPhase.TRACK and not session.animal_id:
            return None  # No creature found - hunt ends
        # Strike: if animal escaped (miss/scare), hunt ends
        if current == HuntPhase.STRIKE and session.animal_escaped:
            return None  # Animal escaped
        
        try:
            current_idx = phase_order.index(current)
            if current_idx < len(phase_order) - 1:
                next_phase = phase_order[current_idx + 1]
                self._init_phase_state(session, next_phase)
                # Save to database
                self.save_hunt(db, session)
                return next_phase
        except ValueError:
            pass
        
        return None  # Hunt complete
    
    def execute_phase(self, db, session: HuntSession, phase: HuntPhase) -> PhaseResult:
        """
        Execute a hunt phase and record results (LEGACY - single roll system).
        
        Args:
            db: SQLAlchemy database session
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
            # Legacy single-roll blessing - use success count to determine loot tier
            # More successes = higher chance of rare
            rare_chance = 0.03 + (group_roll.success_count * 0.08) + (group_roll.critical_count * 0.16)
            rare_chance = min(0.5, rare_chance)  # Cap at 50%
            
            loot_tier = "rare" if self.rng.random() < rare_chance else "common"
            effects["loot_tier"] = loot_tier
            effects["rare_chance"] = round(rare_chance, 3)
            
            # Apply loot
            if not session.animal_escaped and session.animal_data:
                self._calculate_loot(session, loot_tier)
            
            # Include items in effects so frontend can show them
            effects["items_dropped"] = session.items_dropped.copy()
            effects["total_meat"] = session.total_meat + session.bonus_meat
            effects["bonus_meat"] = session.bonus_meat
            
            # Set outcome message based on loot tier
            if loot_tier == "rare":
                item_names = [item.replace("_", " ").title() for item in session.items_dropped]
                outcome_message = f"✨ RARE LOOT! You found: {', '.join(item_names)}!"
                effects["loot_success"] = True
            else:
                outcome_message = f"Common loot. ({int(rare_chance * 100)}% chance was rare)"
        
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
        
        # Save to database
        self.save_hunt(db, session)
        
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
    
    def _calculate_loot(self, session: HuntSession, loot_tier: str) -> None:
        """Calculate and assign loot based on hunt results.

        Two-tier system:
        - COMMON: Just meat
        - RARE: Meat + Sinew (only for tier 2+ animals: boar, bear, moose)

        NO GOLD DROPS - players can sell meat at market for gold.
        """
        if not session.animal_data:
            return

        animal = session.animal_data
        animal_tier = animal.get("tier", 0)

        # Base meat reward (always)
        session.total_meat = animal["meat"]

        # Rare tier gives bonus meat too!
        if loot_tier == "rare":
            session.bonus_meat = int(session.total_meat * 0.25)  # +25% bonus meat for rare
            # Sinew only drops from tier 2+ animals (boar, bear, moose)
            if animal_tier >= 2:
                rare_items = LOOT_TIERS.get("rare", {}).get("items", [])
                session.items_dropped.extend(rare_items)
        else:
            session.bonus_meat = 0
        
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
    
    def _broadcast_rare_loot(self, db, session: HuntSession) -> None:
        """
        Broadcast rare loot drop to all participants' activity feeds.
        This shows up in their friends' activity feeds!
        """
        if not session.items_dropped:
            return
        
        animal_name = session.animal_data.get("name", "creature") if session.animal_data else "creature"
        animal_icon = session.animal_data.get("icon", "🎯") if session.animal_data else "🎯"
        items_str = ", ".join([item.replace("_", " ").title() for item in session.items_dropped])
        
        # Log activity for each participant so their friends see it
        for participant in session.participants.values():
            log_activity(
                db=db,
                user_id=participant.player_id,
                action_type="rare_loot",
                action_category="hunt",
                description=f"Found rare loot hunting {animal_icon} {animal_name}: {items_str}!",
                kingdom_id=session.kingdom_id,
                amount=None,
                details={
                    "hunt_id": session.hunt_id,
                    "animal_name": animal_name,
                    "animal_icon": animal_icon,
                    "items": session.items_dropped,
                    "party_size": len(session.participants),
                    "total_meat": session.total_meat + session.bonus_meat,
                },
                visibility="friends"
            )
    
    def finalize_hunt(self, db, session: HuntSession) -> dict:
        """
        Finalize the hunt and return complete results.

        Args:
            db: SQLAlchemy database session
            session: The hunt session to finalize

        Returns:
            Complete hunt results dict
        """
        session.completed_at = datetime.utcnow()

        # Hunt fails if: no animal found OR animal escaped
        if not session.animal_id or session.animal_escaped:
            session.status = HuntStatus.FAILED
            # No animal found = no rewards
            for p in session.participants.values():
                p.meat_earned = NO_TRAIL_MEAT
            session.total_meat = NO_TRAIL_MEAT
        else:
            session.status = HuntStatus.COMPLETED

        session.current_phase = HuntPhase.RESULTS

        # Save to database
        self.save_hunt(db, session)

        return session.to_dict()
    
    def cleanup_old_hunts(self, db) -> int:
        """Remove expired hunts from database."""
        from .persistence import cleanup_expired_hunts
        return cleanup_expired_hunts(db)


# ============================================================
# PROBABILITY PREVIEW (for UI)
# ============================================================

def get_hunt_probability_preview(player_stats: Dict[str, int]) -> dict:
    """
    Generate a probability preview for the hunt UI.
    
    NEW SYSTEM: Shows player their stat value = number of rolls,
    and the flat hit chance per roll.
    """
    hit_chance_percent = int(ROLL_HIT_CHANCE * 100)
    
    phases = {}
    for phase, config in PHASE_CONFIG.items():
        if phase == HuntPhase.LOBBY or phase == HuntPhase.RESULTS:
            continue
        
        stat_name = config["stat"]
        stat_value = player_stats.get(stat_name, 0)
        max_rolls = 1 + stat_value  # 1 + skill_level = number of rolls
        
        # Calculate probability of at least one success
        # P(at least 1) = 1 - P(all fail) = 1 - (1 - hit_chance)^rolls
        prob_all_fail = (1 - ROLL_HIT_CHANCE) ** max_rolls
        prob_at_least_one = 1 - prob_all_fail
        
        phases[phase.value] = {
            "phase_name": config["display_name"],
            "stat_used": stat_name,
            "stat_display_name": config.get("stat_display_name", stat_name),
            "stat_value": stat_value,
            "max_rolls": max_rolls,
            "hit_chance_per_roll": hit_chance_percent,
            "prob_at_least_one_success": int(prob_at_least_one * 100),
            "icon": config["icon"],
            "description": config["description"],
            # Display info
            "roll_button_label": config.get("roll_button_label", "Roll"),
            "phase_color": config.get("phase_color", "inkMedium"),
        }
    
    return {
        "phases": phases,
        "hit_chance_per_roll": hit_chance_percent,
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

