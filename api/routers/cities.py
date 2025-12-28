"""
City boundary endpoints
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import List

from db import get_db
from schemas import CityBoundaryResponse
from services import city_service


router = APIRouter(prefix="/cities", tags=["cities"])


@router.get("", response_model=List[CityBoundaryResponse])
async def get_cities(
    lat: float,
    lon: float,
    radius: float = 30.0,
    db: Session = Depends(get_db)
):
    """
    SMART city boundary lookup with accurate boundaries.
    
    Strategy:
    1. Check database for cached cities in this area (FAST - no OSM call!)
    2. If not enough cached, do FAST OSM query to get city IDs/centers
    3. For missing cities, fetch ACCURATE boundaries one-by-one
    4. Cache everything for next time
    
    This keeps boundaries accurate while being much faster on repeat visits!
    
    Parameters:
    - lat: Latitude of search center
    - lon: Longitude of search center
    - radius: Search radius in kilometers (default: 30km)
    
    Returns:
    - List of city boundaries with accurate coordinates
    """
    cities = await city_service.get_cities_near_location(db, lat, lon, radius)
    
    if not cities:
        raise HTTPException(status_code=404, detail="No cities found in this area")
    
    return cities


@router.get("/{osm_id}", response_model=CityBoundaryResponse)
async def get_city_by_id(osm_id: str, db: Session = Depends(get_db)):
    """
    Get a specific city boundary by its OSM ID
    
    Parameters:
    - osm_id: OpenStreetMap relation ID
    
    Returns:
    - City boundary with coordinates
    """
    city = city_service.get_city_by_id(db, osm_id)
    
    if not city:
        raise HTTPException(status_code=404, detail=f"City {osm_id} not found")
    
    return city


@router.get("/stats", response_model=dict)
async def get_city_stats(db: Session = Depends(get_db)):
    """
    Get statistics about cached cities
    
    Returns:
    - total_cached: Number of cities in database
    - top_accessed: Top 10 most accessed cities
    """
    return city_service.get_city_stats(db)

