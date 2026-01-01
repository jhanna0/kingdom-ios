"""
Invasion model - External conquest between cities
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class InvasionEvent(Base):
    """Invasion event tracking"""
    __tablename__ = "invasion_events"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Geography
    attacking_from_kingdom_id = Column(String, nullable=False, index=True)
    target_kingdom_id = Column(String, nullable=False, index=True)
    
    # Leadership
    initiator_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    initiator_name = Column(String, nullable=False)
    
    # Status
    status = Column(String, nullable=False, default='declared')  # 'declared', 'resolved'
    
    # Timing
    declared_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    battle_time = Column(DateTime, nullable=False)
    resolved_at = Column(DateTime, nullable=True)
    
    # Participants
    attackers = Column(JSONB, default=list)
    defenders = Column(JSONB, default=list)
    
    # Combat results
    attacker_victory = Column(Boolean, nullable=True)
    attacker_strength = Column(Integer, nullable=True)
    defender_strength = Column(Integer, nullable=True)
    total_defense_with_walls = Column(Integer, nullable=True)
    loot_distributed = Column(Integer, nullable=True)
    
    # Cost tracking
    cost_per_attacker = Column(Integer, default=100)
    total_cost_paid = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Helper methods
    def get_attacker_ids(self):
        """Get list of attacker player IDs"""
        return self.attackers if self.attackers else []
    
    def get_defender_ids(self):
        """Get list of defender player IDs"""
        return self.defenders if self.defenders else []
    
    def add_attacker(self, player_id: int):
        """Add player to attackers"""
        attackers = self.get_attacker_ids()
        if player_id not in attackers:
            attackers.append(player_id)
            self.attackers = attackers
    
    def add_defender(self, player_id: int):
        """Add player to defenders"""
        defenders = self.get_defender_ids()
        if player_id not in defenders:
            defenders.append(player_id)
            self.defenders = defenders
    
    @property
    def is_resolved(self):
        """Check if invasion has been resolved"""
        return self.status == 'resolved'
    
    @property
    def should_resolve(self):
        """Check if invasion should be resolved (battle time passed)"""
        if self.is_resolved:
            return False
        return datetime.utcnow() >= self.battle_time
    
    @property
    def time_remaining_seconds(self):
        """Get seconds until battle"""
        if self.is_resolved:
            return 0
        delta = self.battle_time - datetime.utcnow()
        return max(0, int(delta.total_seconds()))
    
    @property
    def can_join(self):
        """Check if players can still join"""
        return not self.is_resolved and datetime.utcnow() < self.battle_time
    
    def __repr__(self):
        return f"<InvasionEvent(id={self.id}, {self.attacking_from_kingdom_id} -> {self.target_kingdom_id}, status='{self.status}')>"



