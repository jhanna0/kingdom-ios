"""
Kingdom history - Track every ruler and conquest for each city
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey
from datetime import datetime

from ..base import Base


class KingdomHistory(Base):
    """Historical record of kingdom rulers"""
    __tablename__ = "kingdom_history"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # Ruler info
    ruler_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    ruler_name = Column(String, nullable=False)
    
    # Empire info
    empire_id = Column(String, nullable=False)
    
    # How they got power
    event_type = Column(String, nullable=False)  # 'founded', 'coup', 'invasion', 'reconquest'
    
    # Timing
    started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)  # NULL = still ruling
    
    # Related events
    coup_id = Column(Integer, ForeignKey("coup_events.id"), nullable=True)
    invasion_id = Column(Integer, ForeignKey("invasion_events.id"), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    @property
    def is_current(self):
        """Is this ruler still in power?"""
        return self.ended_at is None
    
    @property
    def reign_duration_hours(self):
        """How long have/did they rule?"""
        end = self.ended_at or datetime.utcnow()
        delta = end - self.started_at
        return delta.total_seconds() / 3600
    
    def __repr__(self):
        return f"<KingdomHistory({self.ruler_name} ruled {self.kingdom_id} via {self.event_type})>"

