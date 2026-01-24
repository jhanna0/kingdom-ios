"""
Property model - Player-owned properties
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, ForeignKey
from datetime import datetime, timezone

from ..base import Base


class Property(Base):
    """
    Player-owned property - ONE per kingdom with 5-tier progression
    Players buy land (T1) in a kingdom, then upgrade through tiers
    T1: Land (travel benefits)
    T2: House (residence + fortification unlocked)
    T3: Workshop (crafting)
    T4: Beautiful Property (tax exemption)
    T5: Estate (50% base fortification)
    
    Fortification:
    - Unlocked at T2 (House)
    - Sacrifice weapons/armor to increase %
    - Decays 1% per day (lazy decay)
    - T5 has 50% base that doesn't decay
    - Protects property tier during kingdom conquest
    """
    __tablename__ = "properties"
    
    id = Column(String, primary_key=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    kingdom_name = Column(String, nullable=False)
    owner_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    owner_name = Column(String, nullable=False)
    
    tier = Column(Integer, default=1)  # 1-5
    location = Column(String, nullable=True)  # "north", "south", "east", "west"
    purchased_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    last_upgraded = Column(DateTime, nullable=True)
    
    # Fortification system (gear sink)
    fortification_percent = Column(Integer, default=0, nullable=False)  # 0-100%
    fortification_last_decay_at = Column(DateTime, nullable=True)  # For lazy decay
    
    def __repr__(self):
        return f"<Property(id='{self.id}', tier={self.tier}, kingdom='{self.kingdom_name}')>"
    
    @property
    def fortification_unlocked(self) -> bool:
        """Fortification unlocks at T2 (House)"""
        return self.tier >= 2
    
    @property
    def base_fortification(self) -> int:
        """T5 estates have 50% base fortification that doesn't decay"""
        return 50 if self.tier >= 5 else 0
    
    @property
    def effective_fortification(self) -> int:
        """Current fortification (includes base)"""
        return max(self.base_fortification, self.fortification_percent)

