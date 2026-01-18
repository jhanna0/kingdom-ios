from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from ..base import Base


class KingdomIntelligence(Base):
    """
    Intelligence gathered on enemy kingdoms through scouting.
    
    This table only stores WHICH intel tier we have on a kingdom.
    Actual data is fetched LIVE based on the tier when displaying.
    
    - T1 (basic_intel): Population & citizen count
    - T2 (military_intel): Attack power, defense power, wall level  
    - T3 (building_intel): All building levels
    
    Each tier has its own record with its own expiry time.
    """
    __tablename__ = "kingdom_intelligence"
    __table_args__ = (
        UniqueConstraint('kingdom_id', 'gatherer_kingdom_id', 'intelligence_level', 
                        name='unique_intel_per_kingdom_tier'),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Target kingdom being scouted
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Source kingdom that gathered the intel (home kingdom of the spy)
    gatherer_kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # The spy who gathered this intel (for badges/achievements)
    gatherer_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    
    # Intel tier (1=basic, 2=military, 3=building)
    intelligence_level = Column(Integer, nullable=False)
    
    # Timestamps
    gathered_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False, index=True)
    
    # Relationships
    target_kingdom = relationship("Kingdom", foreign_keys=[kingdom_id])
    gatherer_kingdom = relationship("Kingdom", foreign_keys=[gatherer_kingdom_id])
    gatherer = relationship("User", foreign_keys=[gatherer_id])
