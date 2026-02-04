"""
Kitchen History - Tracks baking events for achievements
"""
from sqlalchemy import Column, Integer, BigInteger, DateTime, String
from datetime import datetime

from ..base import Base


class KitchenHistory(Base):
    """
    Tracks baking events for achievement progress.
    
    Actions logged:
    - "baked": Player collected finished bread from oven
    """
    __tablename__ = "kitchen_history"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    slot_index = Column(Integer, nullable=False)
    action = Column(String, nullable=False)  # "baked"
    
    # Baking details
    wheat_used = Column(Integer, default=0)
    loaves_produced = Column(Integer, default=0)
    
    # Timestamps
    started_at = Column(DateTime, nullable=True)  # When baking started
    completed_at = Column(DateTime, default=datetime.utcnow, nullable=False)  # When collected
    
    def __repr__(self):
        return f"<KitchenHistory(user_id={self.user_id}, action={self.action}, loaves={self.loaves_produced})>"
