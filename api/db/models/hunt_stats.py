"""
Hunt Stats - Per-kingdom hunting statistics for leaderboards
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class HuntStats(Base):
    """
    Per-kingdom hunting statistics for a player.
    Used for hunt leaderboards.
    """
    __tablename__ = "hunt_stats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # Stats
    hunts_completed = Column(Integer, default=0, nullable=False)
    
    # Kills per creature type: {"squirrel": 5, "rabbit": 3, "deer": 1, ...}
    creature_kills = Column(JSONB, default=dict, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # One row per user per kingdom
    __table_args__ = (
        UniqueConstraint('user_id', 'kingdom_id', name='uq_hunt_stats_user_kingdom'),
    )
    
    def __repr__(self):
        return f"<HuntStats(user={self.user_id}, kingdom={self.kingdom_id}, hunts={self.hunts_completed})>"
