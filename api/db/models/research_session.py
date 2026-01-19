"""
Research Session - Persistent storage for research experiment sessions

Stores session data in PostgreSQL instead of Lambda memory so sessions
survive across Lambda invocations and scale horizontally.
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class ResearchSession(Base):
    """
    Represents a research experiment stored in PostgreSQL.
    
    Each experiment is stored with full details for history/analytics.
    """
    __tablename__ = "research_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Who ran this experiment
    user_id = Column(BigInteger, nullable=False, index=True)
    
    # Kingdom where research takes place (for stats tracking)
    kingdom_id = Column(String, nullable=True, index=True)
    
    # Full experiment result as JSONB - contains all phase data
    experiment_data = Column(JSONB, nullable=False)
    
    # Quick access fields (denormalized for queries)
    success = Column(Boolean, default=False, nullable=False)
    is_critical = Column(Boolean, default=False, nullable=False)
    blueprints_earned = Column(Integer, default=0, nullable=False)
    gp_earned = Column(Integer, default=0, nullable=False)
    
    # Phase 1 results
    main_tube_fill = Column(Integer, default=0, nullable=False)  # 0-100
    
    # Phase 2 results (crystallization)
    final_floor = Column(Integer, default=0, nullable=False)
    ceiling = Column(Integer, default=0, nullable=False)
    landed_tier = Column(String, nullable=True)
    
    # Player stats at time of experiment
    science_level = Column(Integer, default=0, nullable=False)
    philosophy_level = Column(Integer, default=0, nullable=False)
    building_level = Column(Integer, default=0, nullable=False)
    
    # Timing
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<ResearchSession(id={self.id}, user_id={self.user_id}, success={self.success}, blueprints={self.blueprints_earned})>"
