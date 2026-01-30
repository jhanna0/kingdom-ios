"""
Garden History - Track all garden planting, harvesting, and discarding events
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime
from datetime import datetime

from ..base import Base


class GardenHistory(Base):
    """
    Logs every garden action for historical tracking.
    
    Actions:
    - planted: User planted a seed (records the predetermined plant_type)
    - harvested: User harvested wheat
    - discarded: User cleared weeds, flowers, or dead plants
    - died: Plant died from not being watered
    """
    __tablename__ = "garden_history"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    slot_index = Column(Integer, nullable=False)
    
    # What happened
    action = Column(String(20), nullable=False)  # planted, harvested, discarded, died
    
    # What plant was involved
    plant_type = Column(String(20), nullable=True)  # weed, flower, wheat
    flower_color = Column(String(20), nullable=True)  # hex color for flowers
    flower_rarity = Column(String(20), nullable=True)  # common, uncommon, rare
    
    # Rewards (for harvests)
    wheat_gained = Column(Integer, nullable=True)
    
    # Timestamps
    planted_at = Column(DateTime, nullable=True)  # When seed was originally planted
    action_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<GardenHistory(user_id={self.user_id}, action={self.action}, plant_type={self.plant_type})>"
