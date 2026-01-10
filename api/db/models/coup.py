"""
Coup event models - Political uprising mechanics (V2)

Two-phase coup system:
- Phase 1 (Pledge): 12 hours - citizens pledge to attackers or defenders
- Phase 2 (Battle): 12 hours - active combat participation (mechanics TBD)
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta
from typing import List

from ..base import Base


class CoupEvent(Base):
    """
    Represents a coup attempt with two phases:
    
    Flow:
    1. Player initiates coup (needs T3 leadership, 500+ kingdom rep)
    2. Pledge phase (12h): citizens pick a side (attackers/defenders)
    3. Battle phase (12h): active combat (mechanics TBD)
    4. Resolution: winner determined, rewards/penalties applied
    
    Cooldowns:
    - Player: 30 days between coup attempts
    - Kingdom: 7 days between coups (no overlapping)
    """
    __tablename__ = "coup_events"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, nullable=False, index=True)
    initiator_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    initiator_name = Column(String, nullable=False)
    
    # Status: 'pledge', 'battle', 'resolved'
    status = Column(String, nullable=False, default='pledge', index=True)
    
    # Timing
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    pledge_end_time = Column(DateTime, nullable=False, index=True)  # When pledge phase ends
    battle_end_time = Column(DateTime, nullable=True, index=True)   # When battle phase ends (set when battle starts)
    
    # Participants (JSONB arrays of player IDs as integers)
    attackers = Column(JSONB, default=list)  # List of player IDs
    defenders = Column(JSONB, default=list)  # List of player IDs
    
    # Resolution data
    attacker_victory = Column(Boolean, nullable=True)
    attacker_strength = Column(Integer, nullable=True)
    defender_strength = Column(Integer, nullable=True)
    total_defense_with_walls = Column(Integer, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<CoupEvent(id={self.id}, kingdom='{self.kingdom_id}', status='{self.status}')>"
    
    # === Phase checks ===
    
    @property
    def is_pledge_phase(self) -> bool:
        """Check if currently in pledge phase"""
        return self.status == 'pledge'
    
    @property
    def is_battle_phase(self) -> bool:
        """Check if currently in battle phase"""
        return self.status == 'battle'
    
    @property
    def is_resolved(self) -> bool:
        """Check if coup has been resolved"""
        return self.status == 'resolved'
    
    @property
    def is_pledge_open(self) -> bool:
        """Check if pledging is still allowed"""
        return self.status == 'pledge' and datetime.utcnow() < self.pledge_end_time
    
    @property
    def should_advance_to_battle(self) -> bool:
        """Check if pledge phase has ended and should move to battle"""
        return self.status == 'pledge' and datetime.utcnow() >= self.pledge_end_time
    
    @property
    def should_resolve(self) -> bool:
        """Check if battle phase has ended and should resolve"""
        if self.status != 'battle':
            return False
        if self.battle_end_time is None:
            return False
        return datetime.utcnow() >= self.battle_end_time
    
    # === Time remaining ===
    
    @property
    def pledge_time_remaining_seconds(self) -> int:
        """Get seconds remaining in pledge phase"""
        if self.status != 'pledge':
            return 0
        remaining = (self.pledge_end_time - datetime.utcnow()).total_seconds()
        return max(0, int(remaining))
    
    @property
    def battle_time_remaining_seconds(self) -> int:
        """Get seconds remaining in battle phase"""
        if self.status != 'battle' or self.battle_end_time is None:
            return 0
        remaining = (self.battle_end_time - datetime.utcnow()).total_seconds()
        return max(0, int(remaining))
    
    @property
    def time_remaining_seconds(self) -> int:
        """Get seconds remaining in current phase"""
        if self.status == 'pledge':
            return self.pledge_time_remaining_seconds
        elif self.status == 'battle':
            return self.battle_time_remaining_seconds
        return 0
    
    # Legacy compatibility
    @property
    def is_voting_open(self) -> bool:
        """Legacy: Check if voting period is still active (same as is_pledge_open)"""
        return self.is_pledge_open
    
    def get_attacker_ids(self) -> List[int]:
        """Get list of attacker player IDs"""
        return self.attackers if self.attackers else []
    
    def get_defender_ids(self) -> List[int]:
        """Get list of defender player IDs"""
        return self.defenders if self.defenders else []
    
    def add_attacker(self, player_id: int) -> None:
        """Add a player to attackers"""
        attackers = self.get_attacker_ids()
        if player_id not in attackers:
            attackers.append(player_id)
            self.attackers = attackers
    
    def add_defender(self, player_id: int) -> None:
        """Add a player to defenders"""
        defenders = self.get_defender_ids()
        if player_id not in defenders:
            defenders.append(player_id)
            self.defenders = defenders
    
    # === Phase transitions ===
    
    def advance_to_battle(self, battle_duration_hours: int = 12) -> None:
        """
        Transition from pledge phase to battle phase.
        Locks sides and starts the battle timer.
        """
        if self.status != 'pledge':
            raise ValueError(f"Cannot advance to battle from status '{self.status}'")
        
        self.status = 'battle'
        self.battle_end_time = datetime.utcnow() + timedelta(hours=battle_duration_hours)
    
    def resolve(self, attacker_won: bool) -> None:
        """
        Mark the coup as resolved with the outcome.
        """
        if self.status == 'resolved':
            raise ValueError("Coup is already resolved")
        
        self.status = 'resolved'
        self.attacker_victory = attacker_won
        self.resolved_at = datetime.utcnow()
