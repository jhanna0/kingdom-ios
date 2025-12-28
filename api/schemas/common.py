"""
Common/shared schemas
"""
from pydantic import BaseModel
from typing import List


class CheckInRequest(BaseModel):
    """Check-in request"""
    player_id: str
    kingdom_id: str
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

