"""
Chicken Coop System - Hatch rare eggs into chickens, care for them, collect eggs

Players can have up to 4 chicken slots in their coop (unlocked at Tier 4 property).
Chickens need care (happiness) to lay eggs. Eggs convert to meat (95%) or rare_egg (5%).
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Enum as SQLEnum
from datetime import datetime
import enum

from ..base import Base


class ChickenStatus(enum.Enum):
    """Status of a chicken slot."""
    EMPTY = "empty"           # No chicken, can hatch
    INCUBATING = "incubating" # Egg is incubating, waiting to hatch
    ALIVE = "alive"           # Chicken is alive and can lay eggs


class ChickenSlot(Base):
    """
    Represents a single chicken slot in a player's coop.
    
    Each player can have up to 4 slots (max_slots from config).
    """
    __tablename__ = "chicken_slots"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    slot_index = Column(Integer, nullable=False)  # 0-3 for 4 slots
    
    status = Column(
        SQLEnum(ChickenStatus, name='chicken_status', values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=ChickenStatus.EMPTY
    )
    
    # Player-chosen name (one-time only, set after hatching)
    name = Column(String(50), nullable=True)
    
    # Incubation tracking
    incubation_started_at = Column(DateTime, nullable=True)
    hatched_at = Column(DateTime, nullable=True)
    
    # Tamagotchi-style stats (0-100 each)
    hunger = Column(Integer, default=100)      # Feed action restores this
    happiness = Column(Integer, default=100)   # Play action restores this
    cleanliness = Column(Integer, default=100) # Clean action restores this
    
    # Last action timestamps for cooldowns
    last_fed_at = Column(DateTime, nullable=True)
    last_played_at = Column(DateTime, nullable=True)
    last_cleaned_at = Column(DateTime, nullable=True)
    
    # Legacy field (keeping for backwards compat, will be removed)
    last_cared_at = Column(DateTime, nullable=True)
    care_cycles = Column(Integer, default=0)
    
    # Egg production
    last_egg_collected_at = Column(DateTime, nullable=True)
    eggs_available = Column(Integer, default=0)  # Uncollected eggs
    total_eggs_laid = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<ChickenSlot(user_id={self.user_id}, slot={self.slot_index}, status={self.status.value}, name={self.name})>"
    
    @property
    def is_empty(self) -> bool:
        return self.status == ChickenStatus.EMPTY
    
    @property
    def is_incubating(self) -> bool:
        return self.status == ChickenStatus.INCUBATING
    
    @property
    def is_alive(self) -> bool:
        return self.status == ChickenStatus.ALIVE
    
    @property
    def needs_name(self) -> bool:
        """Returns True if chicken is alive but hasn't been named yet."""
        return self.status == ChickenStatus.ALIVE and self.name is None
