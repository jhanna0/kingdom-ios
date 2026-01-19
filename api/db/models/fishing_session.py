"""
Fishing Session - Persistent storage for fishing minigame sessions

Stores session data in PostgreSQL instead of Lambda memory so sessions
survive across Lambda invocations and scale horizontally.
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime, timedelta

from ..base import Base


class FishingSession(Base):
    """
    Represents a fishing session stored in PostgreSQL.
    
    Session state is stored as JSONB so the structure can evolve without migrations.
    Each player can have one active session at a time.
    """
    __tablename__ = "fishing_sessions"
    
    # Matches existing DB schema
    fishing_id = Column(String, primary_key=True)
    created_by = Column(BigInteger, nullable=False, index=True)
    kingdom_id = Column(String, nullable=True, index=True)
    status = Column(String, nullable=False, default='active', index=True)
    session_data = Column(JSONB, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    
    def __repr__(self):
        return f"<FishingSession(fishing_id='{self.fishing_id}', status='{self.status}', created_by={self.created_by})>"
    
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
