"""
Property model - Player-owned properties
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, ForeignKey
from datetime import datetime

from ..base import Base


class Property(Base):
    """
    Player-owned property - ONE per kingdom with 5-tier progression
    Players buy land (T1) in a kingdom, then upgrade through tiers
    T1: Land (travel benefits)
    T2: House (residence)
    T3: Workshop (crafting)
    T4: Beautiful Property (tax exemption)
    T5: Estate (conquest protection)
    """
    __tablename__ = "properties"
    
    id = Column(String, primary_key=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    kingdom_name = Column(String, nullable=False)
    owner_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    owner_name = Column(String, nullable=False)
    
    tier = Column(Integer, default=1)  # 1-5
    location = Column(String, nullable=True)  # "north", "south", "east", "west"
    purchased_at = Column(DateTime, default=datetime.utcnow)
    last_upgraded = Column(DateTime, nullable=True)
    
    def __repr__(self):
        return f"<Property(id='{self.id}', tier={self.tier}, kingdom='{self.kingdom_name}')>"

