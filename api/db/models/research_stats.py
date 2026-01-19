"""
Research Stats - Per-user research statistics for leaderboards
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, UniqueConstraint
from datetime import datetime

from ..base import Base


class ResearchStats(Base):
    """
    Per-kingdom research statistics for a player.
    Used for research leaderboards and tracking progress.
    
    Tracks aggregate stats - individual session history is in ResearchSession.
    """
    __tablename__ = "research_stats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # Core stats
    experiments_completed = Column(Integer, default=0, nullable=False)
    experiments_succeeded = Column(Integer, default=0, nullable=False)
    
    # Blueprint stats
    total_blueprints_earned = Column(Integer, default=0, nullable=False)
    
    # GP stats
    total_gp_earned = Column(Integer, default=0, nullable=False)
    
    # Tier breakdown
    critical_hits = Column(Integer, default=0, nullable=False)
    excellent_hits = Column(Integer, default=0, nullable=False)
    good_hits = Column(Integer, default=0, nullable=False)
    poor_hits = Column(Integer, default=0, nullable=False)
    failures = Column(Integer, default=0, nullable=False)
    
    # Best results (highscores)
    best_floor = Column(Integer, default=0, nullable=False)
    best_ceiling = Column(Integer, default=0, nullable=False)
    most_blueprints_single = Column(Integer, default=0, nullable=False)
    
    # Streaks
    current_success_streak = Column(Integer, default=0, nullable=False)
    best_success_streak = Column(Integer, default=0, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # One row per user per kingdom
    __table_args__ = (
        UniqueConstraint('user_id', 'kingdom_id', name='uq_research_stats_user_kingdom'),
    )
    
    def __repr__(self):
        return f"<ResearchStats(user={self.user_id}, kingdom={self.kingdom_id}, experiments={self.experiments_completed})>"
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate (experiments with blueprints)"""
        if self.experiments_completed == 0:
            return 0.0
        return self.experiments_succeeded / self.experiments_completed
    
    @property
    def avg_blueprints_per_experiment(self) -> float:
        """Calculate average blueprints per experiment"""
        if self.experiments_completed == 0:
            return 0.0
        return self.total_blueprints_earned / self.experiments_completed
    
    @property
    def critical_rate(self) -> float:
        """Calculate critical hit rate"""
        if self.experiments_completed == 0:
            return 0.0
        return self.critical_hits / self.experiments_completed
