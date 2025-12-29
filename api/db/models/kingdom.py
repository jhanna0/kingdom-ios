"""
Kingdom model - City/territory game state
"""
from sqlalchemy import Column, String, Float, Text, DateTime, Integer, BigInteger, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class Kingdom(Base):
    """Kingdom/City game state"""
    __tablename__ = "kingdoms"
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False, index=True)
    
    # Current ruler (nullable - kingdoms can be unclaimed)
    ruler_id = Column(BigInteger, ForeignKey("users.id"), nullable=True, index=True)
    
    # Reference to the city boundary
    city_boundary_osm_id = Column(String, nullable=True)
    
    # Game state
    population = Column(Integer, default=0)
    level = Column(Integer, default=1)
    treasury_gold = Column(Integer, default=0)
    checked_in_players = Column(Integer, default=0)
    
    # Buildings
    wall_level = Column(Integer, default=0)
    vault_level = Column(Integer, default=0)
    mine_level = Column(Integer, default=0)  # Unlocks material availability for purchase
    market_level = Column(Integer, default=0)  # Passive income + material purchase hub
    farm_level = Column(Integer, default=0)  # Speeds up contract completion
    education_level = Column(Integer, default=0)  # Reduces training actions required
    
    # Tax & Income
    tax_rate = Column(Integer, default=10)  # 0-100%
    last_income_collection = Column(DateTime, default=datetime.utcnow)
    weekly_unique_check_ins = Column(Integer, default=0)
    total_income_collected = Column(Integer, default=0)
    income_history = Column(JSONB, default=list)
    
    # Subject reward distribution
    subject_reward_rate = Column(Integer, default=15)  # 0-50%
    last_reward_distribution = Column(DateTime, default=datetime.utcnow)
    total_rewards_distributed = Column(Integer, default=0)
    distribution_history = Column(JSONB, default=list)
    
    # Daily quests
    active_quests = Column(JSONB, default=list)
    
    # Alliances & Wars
    allies = Column(JSONB, default=list)  # List of kingdom IDs
    enemies = Column(JSONB, default=list)  # List of kingdom IDs
    
    # Defense/Attack stats
    defense_rating = Column(Integer, default=10)
    military_strength = Column(Integer, default=5)
    
    # Kingdom metadata
    description = Column(Text, nullable=True)
    kingdom_data = Column(JSONB, nullable=True, default=dict)  # Extensible data
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_activity = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user_kingdoms = relationship("UserKingdom", back_populates="kingdom")
    contracts = relationship("Contract", back_populates="kingdom")
    
    def __repr__(self):
        return f"<Kingdom(id='{self.id}', name='{self.name}')>"


class UserKingdom(Base):
    """
    Association table tracking user's relationship with kingdoms
    Tracks current ownership, history, reputation, etc.
    """
    __tablename__ = "user_kingdoms"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Relationship type
    is_ruler = Column(Boolean, default=False)  # Currently ruling this kingdom
    is_subject = Column(Boolean, default=False)  # Living in this kingdom under another ruler
    
    # History tracking
    times_conquered = Column(Integer, default=0)
    times_lost = Column(Integer, default=0)
    total_reign_duration_hours = Column(Float, default=0.0)
    
    # Reputation with this specific kingdom
    local_reputation = Column(Integer, default=0)
    
    # Statistics
    checkins_count = Column(Integer, default=0)
    last_checkin = Column(DateTime, nullable=True)
    gold_earned = Column(Integer, default=0)
    gold_spent = Column(Integer, default=0)
    
    # Timestamps
    first_visited = Column(DateTime, default=datetime.utcnow)
    became_ruler_at = Column(DateTime, nullable=True)
    lost_rulership_at = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="kingdoms")
    kingdom = relationship("Kingdom", back_populates="user_kingdoms")
    
    def __repr__(self):
        return f"<UserKingdom(user_id='{self.user_id}', kingdom_id='{self.kingdom_id}', is_ruler={self.is_ruler})>"

