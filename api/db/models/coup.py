"""
Coup event models - Political uprising mechanics
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta
from typing import List

from ..base import Base


class CoupEvent(Base):
    """
    Represents a coup attempt with 2-hour voting period
    
    Flow:
    1. Player initiates coup (costs 50g, needs 300+ rep)
    2. 2-hour voting window opens
    3. All checked-in players pick a side
    4. Battle auto-resolves after 2 hours
    5. Attackers need 25% advantage to win (no walls for internal coups)
    """
    __tablename__ = "coup_events"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, nullable=False, index=True)
    initiator_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    initiator_name = Column(String, nullable=False)
    
    # Status: 'voting', 'resolved'
    status = Column(String, nullable=False, default='voting', index=True)
    
    # Timing
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    end_time = Column(DateTime, nullable=False, index=True)
    
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
    
    @property
    def is_voting_open(self) -> bool:
        """Check if voting period is still active"""
        return self.status == 'voting' and datetime.utcnow() < self.end_time
    
    @property
    def is_resolved(self) -> bool:
        """Check if coup has been resolved"""
        return self.status == 'resolved'
    
    @property
    def should_resolve(self) -> bool:
        """Check if coup should be auto-resolved"""
        return self.status == 'voting' and datetime.utcnow() >= self.end_time
    
    @property
    def time_remaining_seconds(self) -> int:
        """Get seconds remaining in voting period"""
        if self.status != 'voting':
            return 0
        remaining = (self.end_time - datetime.utcnow()).total_seconds()
        return max(0, int(remaining))
    
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



