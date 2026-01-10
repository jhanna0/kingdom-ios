"""
Hunt session models - Persistent storage for hunting minigame sessions
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Text
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime
from typing import Optional

from ..base import Base


class HuntSession(Base):
    """
    Represents a hunt session stored in PostgreSQL.
    
    Hunt state is stored as JSONB so the structure can evolve without migrations.
    Each player can have one active hunt at a time.
    
    Flow:
    1. Player creates hunt -> status='lobby'
    2. Hunt starts -> status='in_progress'  
    3. Hunt completes -> status='completed' or 'failed'
    4. Old hunts auto-expire after 24 hours
    """
    __tablename__ = "hunt_sessions"
    
    # Primary key is the hunt_id string (e.g., "hunt_170182_1768007333119")
    hunt_id = Column(String, primary_key=True)
    
    # Who created this hunt
    created_by = Column(BigInteger, nullable=False, index=True)
    
    # Kingdom where hunt takes place (optional - hunts don't require a kingdom)
    kingdom_id = Column(String, nullable=True, index=True)
    
    # Status: 'lobby', 'in_progress', 'completed', 'failed', 'cancelled'
    status = Column(String, nullable=False, default='lobby', index=True)
    
    # Full hunt state as JSONB - this is the HuntSession dataclass serialized
    # Storing as JSONB means we don't need to migrate when hunt structure changes
    session_data = Column(JSONB, nullable=False)
    
    # Timing
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Expiry - hunts auto-delete after this time (for cleanup)
    expires_at = Column(DateTime, nullable=False, index=True)
    
    def __repr__(self):
        return f"<HuntSession(hunt_id='{self.hunt_id}', status='{self.status}', created_by={self.created_by})>"
    
    @property
    def is_active(self) -> bool:
        """Check if hunt is still active (lobby or in_progress)"""
        return self.status in ('lobby', 'in_progress')
    
    @property
    def is_expired(self) -> bool:
        """Check if hunt has expired"""
        return datetime.utcnow() > self.expires_at
