"""
Foraging Stats - Per-kingdom foraging statistics for leaderboards
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, UniqueConstraint
from datetime import datetime

from ..base import Base


class ForagingStats(Base):
    """
    Per-kingdom foraging statistics for a player.
    Used for foraging leaderboards and highscores.
    
    Tracks aggregate stats - individual session history is in ForagingSession.
    """
    __tablename__ = "foraging_stats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # Core stats
    forages_completed = Column(Integer, default=0, nullable=False)
    
    # Round 1 stats (berries)
    berries_found = Column(Integer, default=0, nullable=False)
    round1_wins = Column(Integer, default=0, nullable=False)
    
    # Bonus round stats
    bonus_rounds_triggered = Column(Integer, default=0, nullable=False)
    
    # Round 2 stats (seeds)
    seeds_found = Column(Integer, default=0, nullable=False)
    round2_wins = Column(Integer, default=0, nullable=False)
    
    # Rare drops
    rare_eggs_found = Column(Integer, default=0, nullable=False)
    
    # Streaks (for highscores)
    current_win_streak = Column(Integer, default=0, nullable=False)
    best_win_streak = Column(Integer, default=0, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # One row per user per kingdom
    __table_args__ = (
        UniqueConstraint('user_id', 'kingdom_id', name='uq_foraging_stats_user_kingdom'),
    )
    
    def __repr__(self):
        return f"<ForagingStats(user={self.user_id}, kingdom={self.kingdom_id}, forages={self.forages_completed})>"
    
    @property
    def win_rate(self) -> float:
        """Calculate overall win rate (any reward)"""
        if self.forages_completed == 0:
            return 0.0
        total_wins = self.round1_wins + self.round2_wins + self.rare_eggs_found
        # Cap at 100% - a single forage can have multiple wins
        return min(1.0, total_wins / self.forages_completed)
    
    @property
    def bonus_round_rate(self) -> float:
        """Calculate how often bonus rounds trigger"""
        if self.forages_completed == 0:
            return 0.0
        return self.bonus_rounds_triggered / self.forages_completed
