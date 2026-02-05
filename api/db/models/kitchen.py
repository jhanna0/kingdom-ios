"""
Kitchen System - Oven slots for baking wheat into sourdough bread

Players can load wheat into oven slots, wait for baking, then collect sourdough.
- 1 wheat = 12 loaves of sourdough (a dozen)
- Oven can hold 4 batches at a time
- Each batch takes 3 hours to bake
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Enum as SQLEnum
from datetime import datetime
import enum

from ..base import Base


class OvenStatus(enum.Enum):
    """Status of an oven slot."""
    EMPTY = "empty"       # No dough, ready to load
    BAKING = "baking"     # Dough is in the oven, cooking
    READY = "ready"       # Bread is done, ready to collect


class OvenSlot(Base):
    """
    Represents a single oven slot owned by a player.
    
    Each player can have multiple slots (up to max_slots from config).
    """
    __tablename__ = "oven_slots"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    slot_index = Column(Integer, nullable=False)  # 0-3 for 4 slots
    
    status = Column(SQLEnum(OvenStatus, name='oven_status', values_callable=lambda x: [e.value for e in x]), nullable=False, default=OvenStatus.EMPTY)
    
    # Baking details
    wheat_used = Column(Integer, default=0)  # How much wheat was used
    loaves_pending = Column(Integer, default=0)  # How many loaves will be produced (wheat * 12)
    
    # Timing
    started_at = Column(DateTime, nullable=True)  # When baking started
    ready_at = Column(DateTime, nullable=True)  # When baking will be complete
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<OvenSlot(user_id={self.user_id}, slot={self.slot_index}, status={self.status.value})>"
    
    @property
    def is_empty(self) -> bool:
        return self.status == OvenStatus.EMPTY
    
    @property
    def is_baking(self) -> bool:
        return self.status == OvenStatus.BAKING
    
    @property
    def is_ready(self) -> bool:
        return self.status == OvenStatus.READY
