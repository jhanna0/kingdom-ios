"""
Science Session - Persistent storage for science minigame sessions

Stores session data in PostgreSQL so sessions survive Lambda restarts.
ALL numbers are pre-calculated at start and stored here!
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta

from ..base import Base


class ScienceSession(Base):
    """
    Represents a science minigame session stored in PostgreSQL.
    
    Session state is stored as JSONB so structure can evolve without migrations.
    Each player can have one active session at a time.
    
    CRITICAL: All game numbers are pre-calculated and stored in session_data!
    Frontend calculates NOTHING - backend validates all guesses.
    
    Flow:
    1. Player calls /start -> status='active', session_data has all pre-calc'd numbers
    2. Player calls /guess -> backend validates, updates state
    3. Player calls /collect -> status='collected', rewards given
    4. Player calls /end -> status='cancelled' (no rewards)
    """
    __tablename__ = "science_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Session identifier (e.g., "science_123_1768007333119")
    session_id = Column(String, unique=True, nullable=False, index=True)
    
    # Who owns this session
    user_id = Column(BigInteger, nullable=False, index=True)
    
    # Status: 'active', 'collected', 'cancelled', 'expired'
    status = Column(String, nullable=False, default='active', index=True)
    
    # Full session state as JSONB - contains ALL pre-calculated numbers!
    # This includes the rounds array with hidden_number and correct_answer
    session_data = Column(JSONB, nullable=False)
    
    # Quick access fields (denormalized for queries)
    current_streak = Column(Integer, default=0, nullable=False)
    final_streak = Column(Integer, default=0, nullable=False)
    gold_earned = Column(Integer, default=0, nullable=False)
    blueprint_earned = Column(Integer, default=0, nullable=False)
    
    # Timing
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    collected_at = Column(DateTime, nullable=True)
    
    # Expiry - sessions auto-expire after this time (1 hour)
    expires_at = Column(DateTime, nullable=False, index=True)
    
    def __repr__(self):
        return f"<ScienceSession(session_id='{self.session_id}', status='{self.status}', streak={self.current_streak})>"
    
    @property
    def is_active(self) -> bool:
        """Check if session is still active"""
        return self.status == 'active' and datetime.utcnow() < self.expires_at
    
    @property
    def is_expired(self) -> bool:
        """Check if session has expired"""
        return datetime.utcnow() > self.expires_at
    
    @classmethod
    def default_expiry(cls) -> datetime:
        """Get default expiry time (1 hour from now)"""
        return datetime.utcnow() + timedelta(hours=1)
