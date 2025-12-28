"""
City service - Business logic for city boundary lookups
"""
from sqlalchemy.orm import Session
from typing import List, Tuple
from datetime import datetime
import math
import asyncio

from db import CityBoundary
from schemas import CityBoundaryResponse
from osm_service import (
    fetch_nearby_city_ids,
    fetch_city_boundary_by_id,
    fetch_cities_from_osm
)


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in meters (Haversine formula)"""
    R = 6371000  # Earth's radius in meters
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c


def _get_nearby_cached_cities(
    db: Session, 
    lat: float, 
    lon: float, 
    radius: float
) -> List[Tuple[CityBoundary, float]]:
    """
    Get cached cities near a location using bounding box optimization.
    Returns list of (city, distance) tuples sorted by distance.
    """
    # Use bounding box to filter candidates (MUCH faster than loading all cities)
    # Approximate: 1 degree latitude ≈ 111km
    lat_delta = (radius / 111.0) * 1.2  # Add 20% margin
    lon_delta = (radius / (111.0 * math.cos(math.radians(lat)))) * 1.2  # Adjust for latitude
    
    # Query only cities within bounding box
    candidates = db.query(CityBoundary).filter(
        CityBoundary.center_lat.between(lat - lat_delta, lat + lat_delta),
        CityBoundary.center_lon.between(lon - lon_delta, lon + lon_delta)
    ).all()
    
    print(f"   📦 Found {len(candidates)} candidates in bounding box")
    
    # Calculate exact distances for candidates only
    nearby_cached = []
    for city in candidates:
        distance = _calculate_distance(lat, lon, city.center_lat, city.center_lon)
        if distance <= radius * 1000:
            nearby_cached.append((city, distance))
    
    nearby_cached.sort(key=lambda x: x[1])
    print(f"   ✅ {len(nearby_cached)} cities within {radius}km radius")
    
    return nearby_cached


async def get_cities_near_location(
    db: Session,
    lat: float,
    lon: float,
    radius: float = 30.0
) -> List[CityBoundaryResponse]:
    """
    SMART city boundary lookup with accurate boundaries.
    
    Strategy:
    1. Check database for cached cities in this area (FAST - no OSM call!)
    2. If not enough cached, do FAST OSM query to get city IDs/centers
    3. For missing cities, fetch ACCURATE boundaries one-by-one
    4. Cache everything for next time
    
    This keeps boundaries accurate while being much faster on repeat visits!
    """
    print(f"🔍 City lookup request: lat={lat}, lon={lon}, radius={radius}km")
    
    # STEP 1: Check database for cities we already have nearby
    print(f"💾 Checking database for cached cities...")
    nearby_cached = _get_nearby_cached_cities(db, lat, lon, radius)
    
    # If we have 15+ cached cities, just use those (SUPER FAST!)
    if len(nearby_cached) >= 15:
        print(f"✅ Found {len(nearby_cached)} cached cities - NO OSM CALL NEEDED!")
        
        # Update access stats
        for city, _ in nearby_cached[:35]:
            city.access_count += 1
            city.last_accessed = datetime.utcnow()
        db.commit()
        
        return [
            CityBoundaryResponse(
                osm_id=city.osm_id,
                name=city.name,
                admin_level=city.admin_level,
                center_lat=city.center_lat,
                center_lon=city.center_lon,
                boundary=city.boundary_geojson["coordinates"],
                radius_meters=city.radius_meters,
                cached=True
            )
            for city, _ in nearby_cached[:35]
        ]
    
    # STEP 2: Not enough cached - do FAST query to get city IDs
    print(f"🌐 Fetching city IDs from OSM (fast query)...")
    city_ids = await fetch_nearby_city_ids(lat, lon, radius)
    
    if not city_ids:
        print("⚠️ Fast query failed, falling back to full fetch...")
        # Fallback to old method that gets everything at once
        return await _fetch_cities_fallback(db, lat, lon, radius)
    
    # STEP 3: Process city IDs - fetch boundaries only for cities we don't have
    return await _process_city_ids(db, city_ids)


async def _fetch_cities_fallback(
    db: Session,
    lat: float,
    lon: float,
    radius: float
) -> List[CityBoundaryResponse]:
    """Fallback method - fetch all cities at once from OSM"""
    osm_cities = await fetch_cities_from_osm(lat, lon, radius, admin_levels="8")
    
    if not osm_cities:
        return []
    
    # Process cities
    result_cities = []
    for city_data in osm_cities:
        osm_id = city_data["osm_id"]
        existing = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
        
        if existing:
            existing.access_count += 1
            existing.last_accessed = datetime.utcnow()
            result_cities.append(existing)
        else:
            new_city = CityBoundary(
                osm_id=osm_id,
                name=city_data["name"],
                admin_level=city_data["admin_level"],
                center_lat=city_data["center_lat"],
                center_lon=city_data["center_lon"],
                boundary_geojson={"type": "Polygon", "coordinates": city_data["boundary"]},
                radius_meters=city_data["radius_meters"],
                boundary_points_count=len(city_data["boundary"]),
                access_count=1,
                osm_metadata=city_data.get("osm_tags", {})
            )
            db.add(new_city)
            result_cities.append(new_city)
    
    db.commit()
    
    return [
        CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=city.boundary_geojson["coordinates"],
            radius_meters=city.radius_meters,
            cached=(city.access_count > 1)
        )
        for city in result_cities
    ]


async def _process_city_ids(
    db: Session,
    city_ids: List[dict]
) -> List[CityBoundaryResponse]:
    """Process city IDs - fetch boundaries only for cities we don't have"""
    print(f"📦 Processing {len(city_ids)} cities...")
    
    # Get OSM IDs for top 35 closest cities
    target_city_ids = [c["osm_id"] for c in city_ids[:35]]
    
    # Fetch ALL cached cities in ONE query (fixes N+1 problem!)
    cached_cities = db.query(CityBoundary).filter(CityBoundary.osm_id.in_(target_city_ids)).all()
    cached_by_id = {city.osm_id: city for city in cached_cities}
    
    print(f"   💾 Found {len(cached_by_id)} cached / {len(target_city_ids)} total")
    
    result_cities = []
    cached_count = 0
    new_count = 0
    
    for city_info in city_ids[:35]:  # Limit to 35 closest
        osm_id = city_info["osm_id"]
        
        # Check if we already have this city (from our bulk query)
        existing = cached_by_id.get(osm_id)
        
        if existing:
            # Use cached boundary (FAST!)
            existing.access_count += 1
            existing.last_accessed = datetime.utcnow()
            result_cities.append(existing)
            cached_count += 1
            print(f"    ✅ Cached: {existing.name}")
        else:
            # Fetch ACCURATE boundary for this specific city
            print(f"    🌐 Fetching: {city_info['name']}")
            boundary_data = await fetch_city_boundary_by_id(osm_id, city_info['name'])
            
            if boundary_data:
                new_city = CityBoundary(
                    osm_id=osm_id,
                    name=boundary_data["name"],
                    admin_level=boundary_data["admin_level"],
                    center_lat=boundary_data["center_lat"],
                    center_lon=boundary_data["center_lon"],
                    boundary_geojson={
                        "type": "Polygon",
                        "coordinates": boundary_data["boundary"]
                    },
                    radius_meters=boundary_data["radius_meters"],
                    boundary_points_count=len(boundary_data["boundary"]),
                    access_count=1,
                    osm_metadata=boundary_data.get("osm_tags", {})
                )
                db.add(new_city)
                result_cities.append(new_city)
                new_count += 1
                print(f"        ✅ Saved with accurate boundary")
                
                # Rate limit between boundary fetches (OSM courtesy)
                if new_count < len(city_ids) - cached_count:
                    await asyncio.sleep(0.5)
            else:
                print(f"        ⚠️ Could not fetch boundary, skipping")
    
    db.commit()
    
    print(f"✅ Returning {len(result_cities)} cities ({cached_count} cached, {new_count} newly fetched)")
    
    return [
        CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=city.boundary_geojson["coordinates"],
            radius_meters=city.radius_meters,
            cached=(city.access_count > 1)
        )
        for city in result_cities
    ]


def get_city_by_id(db: Session, osm_id: str) -> CityBoundaryResponse:
    """Get a specific city boundary by its OSM ID"""
    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if not city:
        return None
    
    # Update access stats
    city.access_count += 1
    city.last_accessed = datetime.utcnow()
    db.commit()
    
    return CityBoundaryResponse(
        osm_id=city.osm_id,
        name=city.name,
        admin_level=city.admin_level,
        center_lat=city.center_lat,
        center_lon=city.center_lon,
        boundary=city.boundary_geojson["coordinates"],
        radius_meters=city.radius_meters,
        cached=True
    )


def get_city_stats(db: Session) -> dict:
    """Get statistics about cached cities"""
    total_cities = db.query(CityBoundary).count()
    top_cities = db.query(CityBoundary).order_by(CityBoundary.access_count.desc()).limit(10).all()
    
    return {
        "total_cached": total_cities,
        "top_accessed": [
            {
                "osm_id": city.osm_id,
                "name": city.name,
                "access_count": city.access_count,
                "last_accessed": city.last_accessed.isoformat() if city.last_accessed else None
            }
            for city in top_cities
        ]
    }

