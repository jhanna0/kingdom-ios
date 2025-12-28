"""
Property model - Player-owned properties
"""
from sqlalchemy import Column, String, DateTime, Integer, ForeignKey
from datetime import datetime

from ..base import Base


class Property(Base):
    """
    Player-owned properties (houses, shops, personal mines)
    """
    __tablename__ = "properties"
    
    id = Column(String, primary_key=True)
    type = Column(String, nullable=False)  # house, shop, personal_mine
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    kingdom_name = Column(String, nullable=False)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    owner_name = Column(String, nullable=False)
    
    tier = Column(Integer, default=1)  # 1-5
    purchased_at = Column(DateTime, default=datetime.utcnow)
    last_upgraded = Column(DateTime, nullable=True)
    last_income_collection = Column(DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f"<Property(id='{self.id}', type='{self.type}', tier={self.tier})>"

