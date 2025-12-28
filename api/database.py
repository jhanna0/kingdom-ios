"""
Database configuration and models for Kingdom API
"""
from sqlalchemy import create_engine, Column, String, Float, Text, DateTime, Integer, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime
import os

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")

# Create engine
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Models

class CityBoundary(Base):
    """
    Stores city/town boundaries fetched from OpenStreetMap
    This allows all clients to share the same city data
    """
    __tablename__ = "city_boundaries"
    
    # Primary key - OSM relation ID (unique identifier from OpenStreetMap)
    osm_id = Column(String, primary_key=True, index=True)
    
    # City name
    name = Column(String, nullable=False, index=True)
    
    # Admin level (7=municipality, 8=town, etc.)
    admin_level = Column(Integer, nullable=False)
    
    # Center coordinates
    center_lat = Column(Float, nullable=False)
    center_lon = Column(Float, nullable=False)
    
    # Simplified boundary as GeoJSON (for efficient storage and transfer)
    # Stored as JSONB for fast queries and indexing
    boundary_geojson = Column(JSONB, nullable=False)
    
    # Metadata
    radius_meters = Column(Float, nullable=False)  # Approximate radius
    boundary_points_count = Column(Integer, nullable=False)  # Number of points in simplified boundary
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_accessed = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Usage tracking
    access_count = Column(Integer, default=0, nullable=False)
    
    # Optional: Store original OSM data for reference
    osm_metadata = Column(JSONB, nullable=True)
    
    def __repr__(self):
        return f"<CityBoundary(osm_id='{self.osm_id}', name='{self.name}')>"


class User(Base):
    """
    User accounts with authentication and game state
    Supports Apple Sign In
    """
    __tablename__ = "users"
    
    # Primary key
    id = Column(String, primary_key=True)  # UUID
    
    # Authentication - OAuth providers
    apple_user_id = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, nullable=True)
    
    # Profile
    display_name = Column(String, nullable=False)
    avatar_url = Column(String, nullable=True)
    
    # Hometown - their main city/kingdom
    hometown_kingdom_id = Column(String, nullable=True, index=True)
    
    # Game Stats
    gold = Column(Integer, default=100)  # Starting gold
    level = Column(Integer, default=1)
    experience = Column(Integer, default=0)
    
    # Reputation system
    reputation = Column(Integer, default=0)  # Can be positive or negative
    honor = Column(Integer, default=100)  # 0-100 scale
    
    # Activity tracking
    total_checkins = Column(Integer, default=0)
    total_conquests = Column(Integer, default=0)
    kingdoms_ruled = Column(Integer, default=0)
    
    # Premium/Subscription
    is_premium = Column(Boolean, default=False)
    premium_expires_at = Column(DateTime, nullable=True)
    
    # Account status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    last_login = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Additional game data (quests, inventory, etc.)
    game_data = Column(JSONB, nullable=True, default=dict)
    
    # Relationships
    kingdoms = relationship("UserKingdom", back_populates="user")
    
    # Unique constraint: display_name must be unique per hometown
    __table_args__ = (
        UniqueConstraint('display_name', 'hometown_kingdom_id', name='unique_name_per_hometown'),
    )
    
    def __repr__(self):
        return f"<User(id='{self.id}', display_name='{self.display_name}')>"


class Player(Base):
    """
    DEPRECATED: Legacy player model for backwards compatibility
    New code should use User model instead
    """
    __tablename__ = "players"
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    gold = Column(Integer, default=0)
    level = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Kingdom(Base):
    """Kingdom/City game state"""
    __tablename__ = "kingdoms"
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False, index=True)
    
    # Current ruler (nullable - kingdoms can be unclaimed)
    ruler_id = Column(String, ForeignKey("users.id"), nullable=True, index=True)
    
    # Reference to the city boundary
    city_boundary_osm_id = Column(String, nullable=True)
    
    # Location
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    
    # Game state
    population = Column(Integer, default=0)
    level = Column(Integer, default=1)
    treasury_gold = Column(Integer, default=0)
    
    # Defense/Attack stats
    defense_rating = Column(Integer, default=10)
    military_strength = Column(Integer, default=5)
    
    # Kingdom metadata
    description = Column(Text, nullable=True)
    kingdom_data = Column(JSONB, nullable=True, default=dict)  # Buildings, upgrades, etc.
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_activity = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user_kingdoms = relationship("UserKingdom", back_populates="kingdom")
    
    def __repr__(self):
        return f"<Kingdom(id='{self.id}', name='{self.name}')>"


class UserKingdom(Base):
    """
    Association table tracking user's relationship with kingdoms
    Tracks current ownership, history, reputation, etc.
    """
    __tablename__ = "user_kingdoms"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
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
    
    # Unique constraint: one relationship per user-kingdom pair
    __table_args__ = (
        UniqueConstraint('user_id', 'kingdom_id', name='unique_user_kingdom'),
    )
    
    # Relationships
    user = relationship("User", back_populates="kingdoms")
    kingdom = relationship("Kingdom", back_populates="user_kingdoms")
    
    def __repr__(self):
        return f"<UserKingdom(user_id='{self.user_id}', kingdom_id='{self.kingdom_id}', is_ruler={self.is_ruler})>"


class CheckInHistory(Base):
    """Track all check-ins for analytics and cooldown management"""
    __tablename__ = "checkin_history"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Location verification
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Rewards given
    gold_earned = Column(Integer, default=0)
    experience_earned = Column(Integer, default=0)
    
    # Timestamp
    checked_in_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<CheckInHistory(user_id='{self.user_id}', kingdom_id='{self.kingdom_id}')>"


# Create all tables
def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created")


# Dependency to get database session
def get_db():
    """Get database session for request"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


