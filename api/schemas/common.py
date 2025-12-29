"""
Common/shared schemas
"""
from pydantic import BaseModel
from typing import List, Optional


class CheckInRequest(BaseModel):
    """Check-in request"""
    city_boundary_osm_id: str  # Kingdom OSM ID
    latitude: float
    longitude: float


class CheckInRewards(BaseModel):
    """Rewards from check-in"""
    gold: int
    experience: int


class CheckInResponse(BaseModel):
    """Check-in response"""
    success: bool
    message: str
    rewards: CheckInRewards


class KingdomData(BaseModel):
    """Kingdom data attached to a city"""
    id: str
    ruler_id: Optional[int] = None  # PostgreSQL integer user ID
    ruler_name: Optional[str] = None
    level: int
    population: int
    treasury_gold: int
    wall_level: int
    vault_level: int
    mine_level: int
    market_level: int
    farm_level: int = 0
    education_level: int = 0


class CityBoundaryResponse(BaseModel):
    """City boundary from OSM"""
    osm_id: str
    name: str
    admin_level: int
    center_lat: float
    center_lon: float
    boundary: List[List[float]]  # Array of [lat, lon] pairs
    radius_meters: float
    cached: bool
    is_current: bool = False  # True if user is currently inside this kingdom
    kingdom: Optional[KingdomData] = None  # NULL if unclaimed

