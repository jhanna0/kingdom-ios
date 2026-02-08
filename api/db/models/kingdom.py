"""
Kingdom model - City/territory game state
"""
from sqlalchemy import Column, String, Float, Text, DateTime, Integer, BigInteger, Boolean, ForeignKey, UniqueConstraint
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
    ruler_started_at = Column(DateTime, nullable=True)  # When current ruler took power
    
    # Empire/faction system
    empire_id = Column(String, nullable=True, index=True)  # Which empire controls this city
    original_kingdom_id = Column(String, nullable=True)  # Original city identity (for reconquest)
    
    # Reference to the city boundary
    city_boundary_osm_id = Column(String, nullable=True)
    
    # Game state
    population = Column(Integer, default=0)
    level = Column(Integer, default=1)
    # Treasury stored as float for precise tax calculations; convert to int when sending to frontend
    treasury_gold = Column(Float, default=0.0)
    checked_in_players = Column(Integer, default=0)
    
    # Buildings - NOW STORED IN kingdom_buildings TABLE!
    # Legacy columns kept for backward compatibility during migration
    # TODO: Remove these columns after refactoring all code to use buildings relationship
    wall_level = Column(Integer, default=0)
    vault_level = Column(Integer, default=0)
    mine_level = Column(Integer, default=0)  # Unlocks material availability for purchase
    market_level = Column(Integer, default=0)  # Passive income + material purchase hub
    farm_level = Column(Integer, default=0)  # Speeds up contract completion
    education_level = Column(Integer, default=0)  # Reduces training actions required
    lumbermill_level = Column(Integer, default=0)  # Unlocks wood gathering
    townhall_level = Column(Integer, default=1)  # Unlocks group hunting - ALL kingdoms start at level 1
    
    # Tax & Income
    tax_rate = Column(Integer, default=10)  # 0-100%
    travel_fee = Column(Integer, default=10)  # Gold charged when entering kingdom
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
    buildings = relationship("KingdomBuilding", back_populates="kingdom", cascade="all, delete-orphan")
    
    # Helper methods for building access
    def get_building_level(self, building_type: str) -> int:
        """Get building level from buildings relationship (new way)"""
        for building in self.buildings:
            if building.building_type == building_type:
                return building.level
        return 0
    
    def set_building_level(self, building_type: str, level: int):
        """Set building level in buildings relationship (new way)"""
        for building in self.buildings:
            if building.building_type == building_type:
                building.level = level
                building.updated_at = datetime.utcnow()
                return
        # Create new building if it doesn't exist
        from .kingdom_building import KingdomBuilding
        new_building = KingdomBuilding(
            kingdom_id=self.id,
            building_type=building_type,
            level=level
        )
        self.buildings.append(new_building)
    
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
    
    # History tracking
    times_conquered = Column(Integer, default=0)
    total_reign_duration_hours = Column(Float, default=0.0)
    
    # Reputation with this specific kingdom (Float for philosophy bonus precision, convert to int for frontend)
    local_reputation = Column(Float, default=0.0)
    
    # Statistics
    checkins_count = Column(Integer, default=0)
    last_checkin = Column(DateTime, nullable=True)
    gold_earned = Column(Integer, default=0)
    gold_spent = Column(Integer, default=0)
    
    # Timestamps
    first_visited = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="kingdoms")
    kingdom = relationship("Kingdom", back_populates="user_kingdoms")
    
    # Unique constraint: One UserKingdom record per user-kingdom pair
    __table_args__ = (
        UniqueConstraint('user_id', 'kingdom_id', name='unique_user_kingdom'),
    )
    
    def __repr__(self):
        return f"<UserKingdom(user_id='{self.user_id}', kingdom_id='{self.kingdom_id}')>"

