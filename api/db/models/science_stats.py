"""
Science Stats - Player statistics for science minigame
Tracks experiments, correct guesses, blueprints earned, etc.
"""
from sqlalchemy import Column, Integer, BigInteger, DateTime
from datetime import datetime

from ..base import Base


class ScienceStats(Base):
    """
    Science minigame statistics for a player.
    Used for tracking progress and potential leaderboards.
    """
    __tablename__ = "science_stats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, unique=True, index=True)
    
    # Game stats
    experiments_completed = Column(Integer, default=0, nullable=False)
    total_guesses = Column(Integer, default=0, nullable=False)
    correct_guesses = Column(Integer, default=0, nullable=False)
    
    # Streak tracking
    best_streak = Column(Integer, default=0, nullable=False)  # Highest streak ever
    perfect_games = Column(Integer, default=0, nullable=False)  # 3/3 correct
    
    # Rewards earned
    total_gold_earned = Column(Integer, default=0, nullable=False)
    total_blueprints_earned = Column(Integer, default=0, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<ScienceStats(user={self.user_id}, experiments={self.experiments_completed}, blueprints={self.total_blueprints_earned})>"
    
    def to_dict(self) -> dict:
        return {
            "experiments_completed": self.experiments_completed,
            "total_guesses": self.total_guesses,
            "correct_guesses": self.correct_guesses,
            "accuracy": round(self.correct_guesses / max(1, self.total_guesses) * 100, 1),
            "best_streak": self.best_streak,
            "perfect_games": self.perfect_games,
            "total_gold_earned": self.total_gold_earned,
            "total_blueprints_earned": self.total_blueprints_earned,
        }
