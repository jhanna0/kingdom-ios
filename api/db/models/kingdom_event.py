"""
Kingdom Events - Activity feed for kingdoms
"""
from sqlalchemy import Column, String, Integer, DateTime, Text, ForeignKey
from datetime import datetime

from ..base import Base


class KingdomEvent(Base):
    __tablename__ = "kingdom_events"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
