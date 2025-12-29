from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from ..base import Base


class KingdomIntelligence(Base):
    """Intelligence gathered on enemy kingdoms through scouting"""
    __tablename__ = "kingdom_intelligence"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Target and gatherer
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False)
    gatherer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    gatherer_kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False)
    gatherer_name = Column(String, nullable=False)
    
    # Intelligence data (snapshot)
    wall_level = Column(Integer, nullable=False)
    total_attack_power = Column(Integer, nullable=False)
    total_defense_power = Column(Integer, nullable=False)
    active_citizen_count = Column(Integer, nullable=False)
    population_estimate = Column(Integer, nullable=False)
    treasury_estimate = Column(Integer, nullable=True)
    building_levels = Column(JSON, nullable=True)
    top_players = Column(JSON, nullable=True)
    
    # Metadata
    intelligence_level = Column(Integer, nullable=False)
    gathered_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    
    # Relationships
    target_kingdom = relationship("Kingdom", foreign_keys=[kingdom_id])
    gatherer = relationship("User", foreign_keys=[gatherer_id])
    gatherer_kingdom = relationship("Kingdom", foreign_keys=[gatherer_kingdom_id])

