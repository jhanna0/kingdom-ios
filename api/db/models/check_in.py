"""
CheckInHistory model - Track all check-ins
"""
from sqlalchemy import Column, String, Float, DateTime, Integer, BigInteger, ForeignKey
from datetime import datetime

from ..base import Base


class CheckInHistory(Base):
    """Track all check-ins for analytics and cooldown management"""
    __tablename__ = "checkin_history"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Location verification
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Rewards given
    gold_earned = Column(Integer, default=0)
    experience_earned = Column(Integer, default=0)
    
    # Timestamp
    checked_in_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<CheckInHistory(user_id='{self.user_id}', kingdom_id='{self.kingdom_id}')>"

