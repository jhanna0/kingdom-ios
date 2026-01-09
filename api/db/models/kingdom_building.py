"""
Kingdom Building model - Stores building levels per kingdom
This replaces individual columns (wall_level, vault_level, etc.)
"""
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime

from ..base import Base


class KingdomBuilding(Base):
    """Kingdom building levels - replaces individual columns"""
    __tablename__ = "kingdom_buildings"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id", ondelete="CASCADE"), nullable=False, index=True)
    building_type = Column(String, nullable=False, index=True)  # e.g., "wall", "vault", "mine", "townhall"
    level = Column(Integer, nullable=False, default=0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    kingdom = relationship("Kingdom", back_populates="buildings")
    
    # Unique constraint: one row per kingdom per building type
    __table_args__ = (
        UniqueConstraint('kingdom_id', 'building_type', name='unique_kingdom_building'),
    )
    
    def __repr__(self):
        return f"<KingdomBuilding(kingdom_id='{self.kingdom_id}', building_type='{self.building_type}', level={self.level})>"
