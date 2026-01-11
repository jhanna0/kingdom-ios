"""
Unified Battle Model - Coups and Invasions combined

Two types of battles:
- 'coup': Internal power struggle (same empire)
- 'invasion': External conquest (empire changes)

Both use the same mechanics:
- Two-phase: pledge (12h for coups, 2h for invasions) → battle (territory conquest)
- 3 territories with tug-of-war bars
- Roll-by-roll fight sessions
- Win condition: First to capture 2 of 3 territories

The ONLY difference:
- Coup: empire_id stays same, just ruler changes
- Invasion: empire_id changes to attacker's empire, ruler changes
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey, Float
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.orm.attributes import flag_modified
from datetime import datetime, timedelta
from typing import List, Optional
from enum import Enum

from ..base import Base


def _format_datetime_iso(dt: datetime) -> str:
    """Format datetime for iOS compatibility - strips microseconds, adds Z suffix"""
    if dt is None:
        return None
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        return iso_str + 'Z'
    return iso_str


# ============================================================
# BATTLE CONSTANTS - Import from central config
# ============================================================
from systems.battle.config import (
    SIZE_EXPONENT_BASE,
    LEADERSHIP_DAMPENING_PER_TIER,
    HIT_MULTIPLIER,
    INJURE_MULTIPLIER,
    INJURE_PUSH_MULTIPLIER,
    BATTLE_ACTION_COOLDOWN_MINUTES,
    INJURY_DURATION_MINUTES,
    # Coup territories
    TERRITORY_COUPERS,
    TERRITORY_CROWNS,
    TERRITORY_THRONE,
    COUP_TERRITORY_STARTING_BARS,
    COUP_TERRITORY_DISPLAY_NAMES,
    COUP_TERRITORY_ICONS,
    # Invasion territories
    TERRITORY_NORTH,
    TERRITORY_SOUTH,
    TERRITORY_EAST,
    TERRITORY_WEST,
    TERRITORY_CAPITOL,
    INVASION_TERRITORY_STARTING_BARS,
    INVASION_TERRITORY_DISPLAY_NAMES,
    INVASION_TERRITORY_ICONS,
    # Helpers
    get_display_names_for_type,
    get_icons_for_type,
)


class BattleType(str, Enum):
    """Types of battles"""
    COUP = "coup"
    INVASION = "invasion"


class RollOutcome(str, Enum):
    """Possible outcomes when rolling in battle"""
    MISS = "miss"
    HIT = "hit"
    INJURE = "injure"


class Battle(Base):
    """
    Unified battle event - handles both coups and invasions.
    
    Flow:
    1. Player initiates → pledge_end_time = now + duration
    2. Pledge phase: citizens pick sides
    3. Battle phase: territory conquest with tug-of-war
    4. Resolution: resolved_at set, winner determined
    
    Type differences:
    - Coup: pledge_duration = 12h, internal, empire_id stays same
    - Invasion: pledge_duration = 2h, external, empire_id changes
    """
    __tablename__ = "battles"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # TYPE: 'coup' or 'invasion'
    type = Column(String(20), nullable=False, index=True)
    
    # TARGET KINGDOM (the kingdom being fought over)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # For INVASIONS: Where the attack originates (NULL for coups)
    attacking_from_kingdom_id = Column(String, nullable=True, index=True)
    
    # INITIATOR
    initiator_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    initiator_name = Column(String, nullable=False)
    
    # TIMING
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    pledge_end_time = Column(DateTime, nullable=False, index=True)
    
    # PARTICIPANTS (JSONB - also in battle_participants table)
    attackers = Column(JSONB, default=list)
    defenders = Column(JSONB, default=list)
    
    # Relationship to participants table
    participants = relationship("BattleParticipant", backref="battle", lazy="joined", cascade="all, delete-orphan")
    
    # RESOLUTION
    resolved_at = Column(DateTime, nullable=True, index=True)
    attacker_victory = Column(Boolean, nullable=True)
    winner_side = Column(String(20), nullable=True)
    
    # COMBAT STATS
    attacker_strength = Column(Integer, nullable=True)
    defender_strength = Column(Integer, nullable=True)
    total_defense_with_walls = Column(Integer, nullable=True)
    
    # REWARDS
    gold_per_winner = Column(Integer, nullable=True)
    loot_distributed = Column(Integer, nullable=True)
    
    # INVASION COST TRACKING
    cost_per_attacker = Column(Integer, nullable=True)
    total_cost_paid = Column(Integer, nullable=True)
    
    # INVASION: Wall defense
    wall_defense_applied = Column(Integer, nullable=True)  # Wall bonus used
    
    # RULER CHANGE TRACKING
    old_ruler_id = Column(BigInteger, nullable=True)
    
    # DEPRECATED
    status = Column(String, nullable=True)
    
    # TIMESTAMPS
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Battle(id={self.id}, type='{self.type}', kingdom='{self.kingdom_id}', phase='{self.current_phase}')>"
    
    # === Type Helpers ===
    
    @property
    def is_coup(self) -> bool:
        return self.type == BattleType.COUP.value
    
    @property
    def is_invasion(self) -> bool:
        return self.type == BattleType.INVASION.value
    
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
        """Get attacker user IDs from participants table."""
        if self.participants:
            return [p.user_id for p in self.participants if p.side == "attackers"]
        return self.attackers if self.attackers else []
    
    def get_defender_ids(self) -> List[int]:
        """Get defender user IDs from participants table."""
        if self.participants:
            return [p.user_id for p in self.participants if p.side == "defenders"]
        return self.defenders if self.defenders else []
    
    def add_participant(self, player_id: int, side: str) -> None:
        """Add a participant to the battle."""
        for p in self.participants:
            if p.user_id == player_id:
                return  # Already in battle
        
        participant = BattleParticipant(
            battle_id=self.id,
            user_id=player_id,
            side=side
        )
        self.participants.append(participant)
        
        # Also update legacy JSONB for backward compat
        if side == "attackers":
            if not self.attackers:
                self.attackers = []
            if player_id not in self.attackers:
                self.attackers = self.attackers + [player_id]
        else:
            if not self.defenders:
                self.defenders = []
            if player_id not in self.defenders:
                self.defenders = self.defenders + [player_id]
    
    def add_attacker(self, player_id: int) -> None:
        self.add_participant(player_id, "attackers")
    
    def add_defender(self, player_id: int) -> None:
        self.add_participant(player_id, "defenders")
    
    def resolve(self, attacker_won: bool) -> None:
        """Mark resolved. Idempotent."""
        if self.resolved_at is not None:
            return
        self.attacker_victory = attacker_won
        self.winner_side = "attackers" if attacker_won else "defenders"
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
    def is_active(self) -> bool:
        return self.resolved_at is None
    
    @property
    def can_join(self) -> bool:
        """
        Can players still join this battle?
        
        Both coups and invasions allow joining anytime while active.
        The router enforces specific requirements:
        - Coup: Need reputation in the kingdom
        - Invasion: Need to have visited the kingdom at least once
        """
        return self.is_active  # Can join anytime until resolved


class BattleParticipant(Base):
    """Tracks which players are on which side in a battle."""
    __tablename__ = "battle_participants"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    battle_id = Column(Integer, ForeignKey("battles.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    side = Column(String(20), nullable=False)  # 'attackers' or 'defenders'
    pledged_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<BattleParticipant(battle={self.battle_id}, user={self.user_id}, side='{self.side}')>"


class BattleTerritory(Base):
    """
    Territory control for battles.
    
    Each battle has 3 territories with tug-of-war bars:
    - coupers_territory: Starts at 50 (neutral)
    - crowns_territory: Starts at 50 (neutral)
    - throne_room: Starts at 50 (neutral, key objective)
    
    Bar range: 0-100
    - 0 = Attackers captured
    - 100 = Defenders captured
    """
    __tablename__ = "battle_territories"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    battle_id = Column(Integer, ForeignKey("battles.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)
    
    control_bar = Column(Float, nullable=False, default=50.0)
    captured_by = Column(String(20), nullable=True)
    captured_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<BattleTerritory(battle={self.battle_id}, name='{self.territory_name}', bar={self.control_bar})>"
    
    @property
    def display_name(self) -> str:
        # Check both coup and invasion display names
        if self.territory_name in COUP_TERRITORY_DISPLAY_NAMES:
            return COUP_TERRITORY_DISPLAY_NAMES[self.territory_name]
        if self.territory_name in INVASION_TERRITORY_DISPLAY_NAMES:
            return INVASION_TERRITORY_DISPLAY_NAMES[self.territory_name]
        return self.territory_name
    
    @property
    def icon(self) -> str:
        # Check both coup and invasion icons
        if self.territory_name in COUP_TERRITORY_ICONS:
            return COUP_TERRITORY_ICONS[self.territory_name]
        if self.territory_name in INVASION_TERRITORY_ICONS:
            return INVASION_TERRITORY_ICONS[self.territory_name]
        return "mappin"
    
    @property
    def is_captured(self) -> bool:
        return self.captured_by is not None
    
    def apply_push(self, side: str, push_amount: float) -> Optional[str]:
        """
        Apply push to the bar. Returns winner if captured, None otherwise.
        
        Attackers push toward 0, Defenders push toward 100.
        """
        if self.is_captured:
            return None
        
        if side == "attackers":
            self.control_bar = max(0.0, self.control_bar - push_amount)
        else:
            self.control_bar = min(100.0, self.control_bar + push_amount)
        
        self.updated_at = datetime.utcnow()
        
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
            "captured_at": _format_datetime_iso(self.captured_at) if self.captured_at else None,
        }


class BattleAction(Base):
    """Log of each battle action (fight)."""
    __tablename__ = "battle_actions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    battle_id = Column(Integer, ForeignKey("battles.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)
    side = Column(String(20), nullable=False)
    
    roll_count = Column(Integer, nullable=False)
    rolls = Column(JSONB, default=list)
    best_outcome = Column(String(20), nullable=False)
    
    push_amount = Column(Float, nullable=False, default=0.0)
    bar_before = Column(Float, nullable=False)
    bar_after = Column(Float, nullable=False)
    
    injured_player_id = Column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    performed_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<BattleAction(battle={self.battle_id}, player={self.player_id}, outcome='{self.best_outcome}')>"


class BattleInjury(Base):
    """Track injured players who must sit out."""
    __tablename__ = "battle_injuries"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    battle_id = Column(Integer, ForeignKey("battles.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    injured_by_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    injury_action_id = Column(Integer, ForeignKey("battle_actions.id", ondelete="SET NULL"), nullable=True)
    
    injured_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    cleared_at = Column(DateTime, nullable=True)
    
    def __repr__(self):
        return f"<BattleInjury(battle={self.battle_id}, player={self.player_id})>"
    
    @property
    def is_expired(self) -> bool:
        return datetime.utcnow() >= self.expires_at
    
    @property
    def is_active(self) -> bool:
        return not self.is_expired and self.cleared_at is None


class FightSession(Base):
    """In-progress fight session (persists so player can resume)."""
    __tablename__ = "fight_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    battle_id = Column(Integer, ForeignKey("battles.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    territory_name = Column(String(50), nullable=False)
    side = Column(String(20), nullable=False)
    
    max_rolls = Column(Integer, nullable=False)
    rolls = Column(JSONB, default=list)
    
    hit_chance = Column(Integer, nullable=False)
    enemy_avg_defense = Column(Float, nullable=False)
    
    bar_before = Column(Float, nullable=False)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<FightSession(battle={self.battle_id}, player={self.player_id})>"
    
    @property
    def rolls_completed(self) -> int:
        return len(self.rolls) if self.rolls else 0
    
    @property
    def rolls_remaining(self) -> int:
        return max(0, self.max_rolls - self.rolls_completed)
    
    @property
    def can_roll(self) -> bool:
        return self.rolls_remaining > 0
    
    @property
    def best_outcome(self) -> str:
        if not self.rolls:
            return "miss"
        outcomes = [r.get("outcome", "miss") for r in self.rolls]
        if "injure" in outcomes:
            return "injure"
        if "hit" in outcomes:
            return "hit"
        return "miss"
    
    def add_roll(self, value: float, outcome: str) -> None:
        if self.rolls is None:
            self.rolls = []
        self.rolls.append({"value": value, "outcome": outcome})
        flag_modified(self, "rolls")
        self.updated_at = datetime.utcnow()
