"""
Common/shared schemas
"""
from pydantic import BaseModel
from typing import List, Optional

# Building colors for frontend - matches BuildingConfig colors
BUILDING_COLORS = {
    "wall": "#6B949C",  # Steel blue
    "vault": "#D4AF37",  # Imperial gold
    "mine": "#8C7359",  # Brown
    "market": "#50C878",  # Royal emerald
    "farm": "#8C9973",  # Sage green
    "education": "#7851A9",  # Royal purple
    "lumbermill": "#73593F"  # Dark brown
}


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


class BuildingData(BaseModel):
    """Building data with metadata - FULLY DYNAMIC from backend"""
    type: str  # e.g. "wall", "vault", "mine"
    display_name: str  # e.g. "Walls", "Vault"
    icon: str  # SF Symbol name
    color: str  # Hex color code
    category: str  # "economy", "defense", "civic"
    description: str  # Building description
    level: int  # Current building level
    max_level: int  # Maximum level


class KingdomData(BaseModel):
    """Kingdom data attached to a city"""
    id: str
    ruler_id: Optional[int] = None  # PostgreSQL integer user ID
    ruler_name: Optional[str] = None
    level: int
    population: int  # Currently present players (LIVE COUNT)
    active_citizens: int = 0  # Active citizens (hometown residents, LIVE COUNT)
    treasury_gold: int
    
    # DYNAMIC BUILDINGS - All building data with metadata
    buildings: List['BuildingData'] = []
    
    # Legacy building levels (kept for backwards compatibility)
    wall_level: int
    vault_level: int
    mine_level: int
    market_level: int
    farm_level: int = 0
    education_level: int = 0
    lumbermill_level: int = 0  # FULLY DYNAMIC - add new buildings without iOS changes
    
    travel_fee: int = 10
    can_claim: bool = False  # Backend determines if current user can claim this kingdom
    can_declare_war: bool = False  # Backend determines if current user can declare war on this kingdom
    can_form_alliance: bool = False  # Backend determines if current user can form alliance with this kingdom
    is_allied: bool = False  # True if this kingdom is allied with any of user's kingdoms
    is_enemy: bool = False  # True if this kingdom is at war with any of user's kingdoms


class CityBoundaryResponse(BaseModel):
    """City boundary from OSM - full response with boundary polygon"""
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


class CityQuickResponse(BaseModel):
    """
    Fast city response - centers only, no boundaries.
    Used for initial app load to show city markers quickly.
    Boundaries can be loaded lazily via /cities/{osm_id}/boundary
    """
    osm_id: str
    name: str
    admin_level: int = 8
    center_lat: float
    center_lon: float
    radius_meters: float = 5000.0  # Default estimate if not cached
    distance_meters: float = 0.0  # Distance from query point
    is_current: bool = False  # True if user is currently inside this city
    has_boundary_cached: bool = False  # True if full boundary is in DB
    kingdom: Optional[KingdomData] = None


class BoundaryResponse(BaseModel):
    """Lazy-loaded boundary polygon for a city"""
    osm_id: str
    name: str
    boundary: List[List[float]]  # Array of [lat, lon] pairs
    radius_meters: float
    from_cache: bool  # True if served from DB, False if fetched from OSM

