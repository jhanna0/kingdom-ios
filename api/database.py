"""
Database configuration and models for Kingdom API
"""
from sqlalchemy import create_engine, Column, String, Float, Text, DateTime, Integer, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
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


class Player(Base):
    """Player accounts"""
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
    ruler_id = Column(String, nullable=True)
    
    # Reference to the city boundary
    city_boundary_osm_id = Column(String, nullable=True)
    
    # Game state
    population = Column(Integer, default=0)
    level = Column(Integer, default=1)
    treasury_gold = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


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


