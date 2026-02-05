"""
CityBoundary model - OSM city/town boundary data
"""
from sqlalchemy import Column, String, Float, DateTime, Integer
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


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
    
    # Original boundary as GeoJSON (full detail from OSM)
    boundary_geojson = Column(JSONB, nullable=False)
    
    # Pre-computed simplified boundary (Visvalingam-Whyatt algorithm, ~250 points)
    # This is what gets returned to clients for efficient data transfer
    simplified_boundary_geojson = Column(JSONB, nullable=True)
    
    # Metadata
    radius_meters = Column(Float, nullable=False)  # Approximate radius
    boundary_points_count = Column(Integer, nullable=False)  # Number of points in original boundary
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_accessed = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Usage tracking
    access_count = Column(Integer, default=0, nullable=False)
    
    # Neighbor caching - stores CANDIDATES from OSM, re-filtered dynamically based on cached boundaries
    neighbor_ids = Column(JSONB, nullable=True)  # List of candidate cities [{osm_id, name, center_lat, center_lon, admin_level}, ...]
    neighbors_updated_at = Column(DateTime, nullable=True)  # When candidates were last fetched from OSM
    
    # Weather caching - hourly weather data per city
    weather_data = Column(JSONB, nullable=True)  # Current weather data
    weather_cached_at = Column(DateTime, nullable=True)  # When weather was last fetched
    
    # Optional: Store original OSM data for reference
    osm_metadata = Column(JSONB, nullable=True)
    
    def __repr__(self):
        return f"<CityBoundary(osm_id='{self.osm_id}', name='{self.name}')>"

