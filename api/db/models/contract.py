"""
Contract model - Building contracts for kingdom infrastructure
"""
from sqlalchemy import Column, String, Float, DateTime, Integer, BigInteger, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class Contract(Base):
    """
    Building contracts for kingdom infrastructure
    EVE Online-inspired work contracts
    """
    __tablename__ = "contracts"
    
    id = Column(String, primary_key=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    kingdom_name = Column(String, nullable=False)
    
    # What's being built
    building_type = Column(String, nullable=False)
    building_level = Column(Integer, nullable=False)
    
    # Time requirements (legacy, for reference)
    base_population = Column(Integer, default=0)
    base_hours_required = Column(Float, nullable=False)
    work_started_at = Column(DateTime, nullable=True)
    
    # Action requirements (new system)
    total_actions_required = Column(Integer, nullable=False, default=1000)
    actions_completed = Column(Integer, default=0)
    action_contributions = Column(JSONB, default=dict)  # {user_id: action_count}
    
    # Rewards
    reward_pool = Column(Integer, default=0)
    
    # Workers (stored as JSONB list of player IDs)
    workers = Column(JSONB, default=list)
    
    # Status
    created_by = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    status = Column(String, default="open")  # open, in_progress, completed, cancelled
    
    # Relationships
    kingdom = relationship("Kingdom", back_populates="contracts")
    creator = relationship("User", back_populates="contracts", foreign_keys=[created_by])
    
    def __repr__(self):
        return f"<Contract(id='{self.id}', building='{self.building_type}', status='{self.status}')>"

