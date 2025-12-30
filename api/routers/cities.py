"""
City boundary endpoints

FAST LOADING - TWO ENDPOINTS:
- GET /cities/current - ONLY the city user is in (< 2s) - UNBLOCKS FRONTEND
- GET /cities/neighbors - Neighbor cities (call after UI is ready)
- GET /cities/{osm_id}/boundary - Lazy-load single boundary
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import List, Optional

from db import get_db
from db.models import User
from schemas import CityBoundaryResponse, BoundaryResponse
from services import city_service
from routers.auth import get_current_user_optional


router = APIRouter(prefix="/cities", tags=["cities"])


@router.get("/current", response_model=CityBoundaryResponse)
async def get_current_city(
    lat: float,
    lon: float,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    FAST - Get ONLY the city the user is currently in.
    
    Call this FIRST to unblock the frontend immediately (< 2 seconds).
    Then call /cities/neighbors to get surrounding cities.
    
    Returns:
    - The single city containing the user's location
    - Full boundary polygon
    - Full kingdom data (ruler, can_claim, buildings, etc.)
    """
    city = await city_service.get_current_city(db, lat, lon, current_user)
    
    if not city:
        raise HTTPException(status_code=404, detail="No city found at this location")
    
    return city


@router.get("/neighbors", response_model=List[CityBoundaryResponse])
async def get_neighbor_cities(
    lat: float,
    lon: float,
    radius: float = 30.0,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    Get neighbor cities (call AFTER /cities/current).
    
    This can be slower since the UI is already showing the current city.
    Excludes the current city from results.
    
    Returns:
    - List of neighboring cities
    - Full kingdom data for each
    - Boundaries included if cached, empty array if not
    """
    return await city_service.get_neighbor_cities(db, lat, lon, radius, current_user)


@router.get("/stats", response_model=dict)
async def get_city_stats(db: Session = Depends(get_db)):
    """Get cache statistics"""
    return city_service.get_city_stats(db)


@router.get("/{osm_id}/boundary", response_model=BoundaryResponse)
async def get_city_boundary(osm_id: str, db: Session = Depends(get_db)):
    """
    Lazy-load boundary for a single city.
    Call this to fill in neighbor polygons that weren't cached.
    """
    boundary = await city_service.get_city_boundary(db, osm_id)
    
    if not boundary:
        raise HTTPException(status_code=404, detail=f"Could not fetch boundary for city {osm_id}")
    
    return boundary


@router.get("/{osm_id}", response_model=CityBoundaryResponse)
async def get_city_by_id(osm_id: str, db: Session = Depends(get_db)):
    """Get a specific city from cache by its OSM ID"""
    city = city_service.get_city_by_id(db, osm_id)
    
    if not city:
        raise HTTPException(status_code=404, detail=f"City {osm_id} not found in cache")
    
    return city


# Legacy endpoint - combines current + neighbors (backward compat)
@router.get("", response_model=List[CityBoundaryResponse])
async def get_cities(
    lat: float,
    lon: float,
    radius: float = 30.0,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    LEGACY - Returns current city + neighbors together.
    
    For faster loading, use:
    1. GET /cities/current (fast, unblocks UI)
    2. GET /cities/neighbors (slower, loads in background)
    """
    cities = await city_service.get_cities_near_location(db, lat, lon, radius, current_user)
    
    if not cities:
        raise HTTPException(status_code=404, detail="No cities found in this area")
    
    return cities
