"""
Garden System - Personal garden slots for planting, watering, and harvesting

Players can have up to 6 garden slots, each with its own plant status.
Plants must be watered every 8 hours for 4 cycles to grow.
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Enum as SQLEnum
from datetime import datetime
import enum

from ..base import Base


class PlantStatus(enum.Enum):
    """Status of a garden slot."""
    EMPTY = "empty"           # No plant, can plant
    GROWING = "growing"       # Plant is growing, needs watering
    DEAD = "dead"             # Plant died from not being watered
    READY = "ready"           # Fully grown, waiting to be harvested/cleared


class PlantType(enum.Enum):
    """Type of plant after fully grown."""
    WEED = "weed"     # Common - clear it
    FLOWER = "flower"  # Pretty - clear or leave it
    WHEAT = "wheat"    # Harvest for wheat items


class GardenSlot(Base):
    """
    Represents a single garden slot owned by a player.
    
    Each player can have multiple slots (up to max_slots from config).
    """
    __tablename__ = "garden_slots"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    slot_index = Column(Integer, nullable=False)  # 0-5 for 6 slots
    
    status = Column(SQLEnum(PlantStatus, name='plant_status', values_callable=lambda x: [e.value for e in x]), nullable=False, default=PlantStatus.EMPTY)
    plant_type = Column(SQLEnum(PlantType, name='plant_type', values_callable=lambda x: [e.value for e in x]), nullable=True)  # Set when plant is ready
    
    # Growing progress
    planted_at = Column(DateTime, nullable=True)
    last_watered_at = Column(DateTime, nullable=True)
    watering_cycles = Column(Integer, default=0)  # How many times watered
    
    # Flower customization
    flower_color = Column(String, nullable=True)  # Theme color name
    flower_rarity = Column(String, nullable=True)  # common, uncommon, rare
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<GardenSlot(user_id={self.user_id}, slot={self.slot_index}, status={self.status.value})>"
    
    @property
    def is_empty(self) -> bool:
        return self.status == PlantStatus.EMPTY
    
    @property
    def is_growing(self) -> bool:
        return self.status == PlantStatus.GROWING
    
    @property
    def is_ready(self) -> bool:
        return self.status == PlantStatus.READY
