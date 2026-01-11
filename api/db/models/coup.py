"""
Coup event models - Political uprising mechanics (V2)

Two-phase coup system:
- Phase 1 (Pledge): 12 hours - citizens pledge to attackers or defenders
- Phase 2 (Battle): Territory conquest with tug-of-war mechanics

Phase is COMPUTED from time, not stored:
- resolved_at IS NULL AND now < pledge_end_time → 'pledge'
- resolved_at IS NULL AND now >= pledge_end_time → 'battle'
- resolved_at IS NOT NULL → 'resolved'

Battle phase:
- 3 territories: Coupers Territory, Crowns Territory, Throne Room
- Players fight every 10 minutes (cooldown-based)
- Win condition: Capture Throne Room + 1 other territory

No cronjob needed. Fully idempotent.
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey, Float
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.orm.attributes import flag_modified
from datetime import datetime, timedelta
from typing import List, Optional
from enum import Enum

from ..base import Base


# ============================================================
# BATTLE CONSTANTS - Import from central config
# ============================================================
from systems.coup.config import (
    SIZE_EXPONENT_BASE,
    LEADERSHIP_DAMPENING_PER_TIER,
    HIT_MULTIPLIER,
    INJURE_MULTIPLIER,
    INJURE_PUSH_MULTIPLIER,
    BATTLE_ACTION_COOLDOWN_MINUTES,
    INJURY_DURATION_MINUTES,
    TERRITORY_COUPERS,
    TERRITORY_CROWNS,
    TERRITORY_THRONE,
    TERRITORY_STARTING_BARS,
    TERRITORY_DISPLAY_NAMES,
    TERRITORY_ICONS,
)


class RollOutcome(str, Enum):
    """Possible outcomes when rolling in battle"""
    MISS = "miss"
    HIT = "hit"
    INJURE = "injure"


class CoupEvent(Base):
    """
    Coup attempt with time-based phase computation.
    
    Flow:
    1. Player initiates coup → pledge_end_time = now + 12h
    2. Pledge phase: citizens pick sides (computed: now < pledge_end_time)
    3. Battle phase: awaiting resolution (computed: now >= pledge_end_time)
    4. Resolution: resolved_at set, attacker_victory determined
    
    Cooldowns:
    - Player: 30 days between coup attempts
    - Kingdom: 7 days between coups
    """
    __tablename__ = "coup_events"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, nullable=False, index=True)
    initiator_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    initiator_name = Column(String, nullable=False)
    
    # Timing
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    pledge_end_time = Column(DateTime, nullable=False, index=True)  # start_time + 12h
    
    # Participants
    attackers = Column(JSONB, default=list)
    defenders = Column(JSONB, default=list)
    
    # Resolution - resolved_at being set = coup is done
    resolved_at = Column(DateTime, nullable=True, index=True)
    attacker_victory = Column(Boolean, nullable=True)
    attacker_strength = Column(Integer, nullable=True)
    defender_strength = Column(Integer, nullable=True)
    total_defense_with_walls = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # DEPRECATED columns kept for backward compat (can be removed later)
    status = Column(String, nullable=True, index=True)  # Ignored - use resolved_at
    battle_end_time = Column(DateTime, nullable=True)   # Ignored - battle has no fixed end
    
    def __repr__(self):
        return f"<CoupEvent(id={self.id}, kingdom='{self.kingdom_id}', phase='{self.current_phase}')>"
    
    # === Phase (computed from time) ===
    
    @property
    def current_phase(self) -> str:
        """'pledge', 'battle', or 'resolved' - computed from time"""
        if self.resolved_at is not None:
            return 'resolved'
        if datetime.utcnow() < self.pledge_end_time:
            return 'pledge'
        return 'battle'
    
    @property
    def is_pledge_phase(self) -> bool:
        return self.resolved_at is None and datetime.utcnow() < self.pledge_end_time
    
    @property
    def is_battle_phase(self) -> bool:
        return self.resolved_at is None and datetime.utcnow() >= self.pledge_end_time
    
    @property
    def is_resolved(self) -> bool:
        return self.resolved_at is not None
    
    @property
    def can_resolve(self) -> bool:
        """Can resolve once pledge phase is over"""
        return self.is_battle_phase
    
    @property
    def time_remaining_seconds(self) -> int:
        """Seconds until pledge ends. 0 if in battle or resolved."""
        if not self.is_pledge_phase:
            return 0
        remaining = (self.pledge_end_time - datetime.utcnow()).total_seconds()
        return max(0, int(remaining))
    
    # === Participants ===
    
    def get_attacker_ids(self) -> List[int]:
        return self.attackers if self.attackers else []
    
    def get_defender_ids(self) -> List[int]:
        return self.defenders if self.defenders else []
    
    def add_attacker(self, player_id: int) -> None:
        attackers = self.get_attacker_ids()
        if player_id not in attackers:
            attackers.append(player_id)
            self.attackers = attackers
    
    def add_defender(self, player_id: int) -> None:
        defenders = self.get_defender_ids()
        if player_id not in defenders:
            defenders.append(player_id)
            self.defenders = defenders
    
    def resolve(self, attacker_won: bool) -> None:
        """Mark resolved. Idempotent."""
        if self.resolved_at is not None:
            return
        self.attacker_victory = attacker_won
        self.resolved_at = datetime.utcnow()
    
    # === Legacy compat ===
    
    @property
    def is_pledge_open(self) -> bool:
        return self.is_pledge_phase
    
    @property
    def is_voting_open(self) -> bool:
        return self.is_pledge_phase
    
    @property
    def should_resolve(self) -> bool:
        return self.can_resolve
    
    @property
    def pledge_time_remaining_seconds(self) -> int:
        return self.time_remaining_seconds
    
    @property
    def battle_time_remaining_seconds(self) -> int:
        return 0
    
    @property
    def is_active(self) -> bool:
        return self.resolved_at is None
    
    def advance_to_battle(self, battle_duration_hours: int = 12) -> None:
        pass  # No-op, phase is computed


class CoupTerritory(Base):
    """
    Territory control for coup battles.
    
    Each coup has 3 territories with tug-of-war bars:
    - coupers_territory: Starts at 25 (attackers favored)
    - crowns_territory: Starts at 75 (defenders favored)
    - throne_room: Starts at 50 (neutral, key objective)
    
    Bar range: 0-100
    - 0 = Attackers captured
    - 100 = Defenders captured
    """
    __tablename__ = "coup_territories"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    coup_id = Column(Integer, ForeignKey("coup_events.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)  # coupers_territory, crowns_territory, throne_room
    
    # Tug-of-war bar (0-100)
    control_bar = Column(Float, nullable=False, default=50.0)
    
    # Capture status
    captured_by = Column(String(20), nullable=True)  # 'attackers', 'defenders', or NULL
    captured_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<CoupTerritory(coup={self.coup_id}, name='{self.territory_name}', bar={self.control_bar})>"
    
    @property
    def display_name(self) -> str:
        return TERRITORY_DISPLAY_NAMES.get(self.territory_name, self.territory_name)
    
    @property
    def icon(self) -> str:
        return TERRITORY_ICONS.get(self.territory_name, "mappin")
    
    @property
    def is_captured(self) -> bool:
        return self.captured_by is not None
    
    def apply_push(self, side: str, push_amount: float) -> Optional[str]:
        """
        Apply push to the bar. Returns winner if captured, None otherwise.
        
        Attackers push toward 0, Defenders push toward 100.
        """
        if self.is_captured:
            return None  # Already captured
        
        old_bar = self.control_bar
        
        if side == "attackers":
            self.control_bar = max(0.0, self.control_bar - push_amount)
        else:  # defenders
            self.control_bar = min(100.0, self.control_bar + push_amount)
        
        self.updated_at = datetime.utcnow()
        
        # Check for capture
        if self.control_bar <= 0:
            self.control_bar = 0.0
            self.captured_by = "attackers"
            self.captured_at = datetime.utcnow()
            return "attackers"
        elif self.control_bar >= 100:
            self.control_bar = 100.0
            self.captured_by = "defenders"
            self.captured_at = datetime.utcnow()
            return "defenders"
        
        return None
    
    def to_dict(self) -> dict:
        return {
            "name": self.territory_name,
            "display_name": self.display_name,
            "icon": self.icon,
            "control_bar": round(self.control_bar, 2),
            "captured_by": self.captured_by,
            "captured_at": self.captured_at.isoformat() if self.captured_at else None,
        }


class CoupBattleAction(Base):
    """
    Log of each battle action (fight) in a coup.
    
    Tracks roll results, bar movement, and injuries inflicted.
    """
    __tablename__ = "coup_battle_actions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    coup_id = Column(Integer, ForeignKey("coup_events.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)
    side = Column(String(20), nullable=False)  # 'attackers' or 'defenders'
    
    # Roll results
    roll_count = Column(Integer, nullable=False)
    rolls = Column(JSONB, default=list)  # [{value: 0.45, outcome: "hit"}, ...]
    best_outcome = Column(String(20), nullable=False)  # 'miss', 'hit', 'injure'
    
    # Bar movement
    push_amount = Column(Float, nullable=False, default=0.0)
    bar_before = Column(Float, nullable=False)
    bar_after = Column(Float, nullable=False)
    
    # Injury tracking (if best_outcome is 'injure')
    injured_player_id = Column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Timestamp
    performed_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<CoupBattleAction(coup={self.coup_id}, player={self.player_id}, outcome='{self.best_outcome}')>"
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "player_id": self.player_id,
            "territory": self.territory_name,
            "side": self.side,
            "roll_count": self.roll_count,
            "rolls": self.rolls,
            "best_outcome": self.best_outcome,
            "push_amount": round(self.push_amount, 4),
            "bar_before": round(self.bar_before, 2),
            "bar_after": round(self.bar_after, 2),
            "injured_player_id": self.injured_player_id,
            "performed_at": self.performed_at.isoformat(),
        }


class CoupInjury(Base):
    """
    Track injured players who must sit out their next action.
    
    Injury expires after one missed action OR after 20 minutes.
    """
    __tablename__ = "coup_injuries"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    coup_id = Column(Integer, ForeignKey("coup_events.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    injured_by_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    injury_action_id = Column(Integer, ForeignKey("coup_battle_actions.id", ondelete="SET NULL"), nullable=True)
    
    # Timing
    injured_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)  # injured_at + 20 minutes
    cleared_at = Column(DateTime, nullable=True)  # Set when player takes action
    
    def __repr__(self):
        return f"<CoupInjury(coup={self.coup_id}, player={self.player_id}, expired={self.is_expired})>"
    
    @property
    def is_expired(self) -> bool:
        """Check if injury has expired (by time)"""
        return datetime.utcnow() >= self.expires_at
    
    @property
    def is_cleared(self) -> bool:
        """Check if injury was cleared by taking an action"""
        return self.cleared_at is not None
    
    @property
    def is_active(self) -> bool:
        """Check if injury is currently preventing action"""
        return not self.is_expired and not self.is_cleared
    
    def clear(self) -> None:
        """Mark injury as cleared (player took action)"""
        self.cleared_at = datetime.utcnow()


class CoupFightSession(Base):
    """
    In-progress fight session (like HuntSession).
    
    Persists the state of a fight so player can resume if they exit:
    - Created when player taps "FIGHT HERE" on a territory
    - Updated as player does rolls one by one
    - Deleted when player resolves (applies push, sets cooldown)
    
    One active session per player per coup.
    """
    __tablename__ = "coup_fight_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    coup_id = Column(Integer, ForeignKey("coup_events.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)
    side = Column(String(20), nullable=False)  # 'attackers' or 'defenders'
    
    # Roll configuration
    max_rolls = Column(Integer, nullable=False)
    rolls = Column(JSONB, default=list)  # [{value: 45.2, outcome: "hit"}, ...]
    
    # Combat stats snapshot
    hit_chance = Column(Integer, nullable=False)  # 0-100 percentage
    enemy_avg_defense = Column(Float, nullable=False)
    
    # Bar snapshot at start
    bar_before = Column(Float, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<CoupFightSession(coup={self.coup_id}, player={self.player_id}, territory='{self.territory_name}')>"
    
    @property
    def rolls_completed(self) -> int:
        """Number of rolls done so far"""
        return len(self.rolls) if self.rolls else 0
    
    @property
    def rolls_remaining(self) -> int:
        """Number of rolls left"""
        return max(0, self.max_rolls - self.rolls_completed)
    
    @property
    def can_roll(self) -> bool:
        """Can player roll again?"""
        return self.rolls_remaining > 0
    
    @property
    def best_outcome(self) -> str:
        """Best outcome from rolls so far"""
        if not self.rolls:
            return "miss"
        outcomes = [r.get("outcome", "miss") for r in self.rolls]
        if "injure" in outcomes:
            return "injure"
        if "hit" in outcomes:
            return "hit"
        return "miss"
    
    def add_roll(self, value: float, outcome: str) -> None:
        """Add a roll result"""
        if self.rolls is None:
            self.rolls = []
        self.rolls.append({"value": value, "outcome": outcome})
        flag_modified(self, "rolls")
        self.updated_at = datetime.utcnow()
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "coup_id": self.coup_id,
            "player_id": self.player_id,
            "territory_name": self.territory_name,
            "side": self.side,
            "max_rolls": self.max_rolls,
            "rolls": self.rolls or [],
            "rolls_completed": self.rolls_completed,
            "rolls_remaining": self.rolls_remaining,
            "hit_chance": self.hit_chance,
            "bar_before": self.bar_before,
            "best_outcome": self.best_outcome,
            "can_roll": self.can_roll,
        }
