"""
Foraging Session - Persistent storage for foraging minigame sessions

Stores session data in PostgreSQL instead of Lambda memory so sessions
survive across Lambda invocations and scale horizontally.
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta

from ..base import Base


class ForagingSession(Base):
    """
    Represents a foraging session stored in PostgreSQL.
    
    Session state is stored as JSONB so the structure can evolve without migrations.
    Each player can have one active session at a time.
    
    Flow:
    1. Player calls /start -> status='active', session_data contains grids
    2. Player calls /collect -> status='collected', rewards given
    3. Player calls /end -> status='cancelled' (no rewards)
    4. Old sessions auto-expire after 1 hour
    """
    __tablename__ = "foraging_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Session identifier (e.g., "forage_123_1768007333119")
    session_id = Column(String, unique=True, nullable=False, index=True)
    
    # Who owns this session
    user_id = Column(BigInteger, nullable=False, index=True)
    
    # Kingdom where foraging takes place (for stats tracking)
    kingdom_id = Column(String, nullable=True, index=True)
    
    # Status: 'active', 'collected', 'cancelled', 'expired'
    status = Column(String, nullable=False, default='active', index=True)
    
    # Full session state as JSONB - contains round1, round2, etc.
    # Storing as JSONB means we don't need to migrate when session structure changes
    session_data = Column(JSONB, nullable=False)
    
    # Quick access fields (denormalized from session_data for queries)
    has_bonus_round = Column(Boolean, default=False, nullable=False)
    round1_won = Column(Boolean, default=False, nullable=False)
    round2_won = Column(Boolean, default=False, nullable=False)
    has_rare_drop = Column(Boolean, default=False, nullable=False)
    
    # Timing
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    collected_at = Column(DateTime, nullable=True)
    
    # Expiry - sessions auto-expire after this time (1 hour)
    expires_at = Column(DateTime, nullable=False, index=True)
    
    def __repr__(self):
        return f"<ForagingSession(session_id='{self.session_id}', status='{self.status}', user_id={self.user_id})>"
    
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
