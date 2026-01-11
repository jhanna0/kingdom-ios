"""
Coup event models - Political uprising mechanics (V2)

Two-phase coup system:
- Phase 1 (Pledge): 12 hours - citizens pledge to attackers or defenders
- Phase 2 (Battle): continues until resolution (no fixed duration)

Phase is COMPUTED from time, not stored:
- resolved_at IS NULL AND now < pledge_end_time → 'pledge'
- resolved_at IS NULL AND now >= pledge_end_time → 'battle'
- resolved_at IS NOT NULL → 'resolved'

No cronjob needed. Fully idempotent.
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta
from typing import List

from ..base import Base


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
