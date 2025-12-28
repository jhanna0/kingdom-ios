"""
Pydantic models for request/response validation
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# Player models
class Player(BaseModel):
    id: str
    name: str
    gold: int = 0
    level: int = 1
    created_at: Optional[datetime] = None


class PlayerCreate(BaseModel):
    id: str
    name: str


class PlayerUpdate(BaseModel):
    gold: Optional[int] = None
    level: Optional[int] = None


# Kingdom models
class Kingdom(BaseModel):
    id: str
    name: str
    ruler_id: Optional[str] = None
    ruler_name: Optional[str] = None
    treasury: int = 0
    population: int = 0
    created_at: Optional[datetime] = None


class KingdomUpdate(BaseModel):
    ruler_id: Optional[str] = None
    ruler_name: Optional[str] = None
    treasury: Optional[int] = None
    population: Optional[int] = None


# Check-in models
class CheckInRequest(BaseModel):
    player_id: str
    kingdom_id: str
    latitude: float
    longitude: float


class CheckInRewards(BaseModel):
    gold: int
    experience: int


class CheckInResponse(BaseModel):
    success: bool
    message: str
    rewards: CheckInRewards


# City boundary models
class CityBoundaryResponse(BaseModel):
    osm_id: str
    name: str
    admin_level: int
    center_lat: float
    center_lon: float
    boundary: List[List[float]]  # Array of [lat, lon] pairs
    radius_meters: float
    cached: bool

