"""
City service - Business logic for city boundary lookups
"""
from sqlalchemy.orm import Session
from typing import List, Tuple, Optional
from datetime import datetime, timedelta
import math
import asyncio

from db import CityBoundary, Kingdom, User
from schemas import CityBoundaryResponse, KingdomData
from osm_service import (
    fetch_nearby_city_ids,
    fetch_city_boundary_by_id,
    fetch_cities_from_osm
)

# In-memory cache for OSM city ID lookups
# This prevents redundant Overpass API calls when scrolling the map
_city_ids_cache: dict = {}
_CACHE_DURATION_SECONDS = 300  # 5 minutes


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


def _get_cache_key(lat: float, lon: float, radius: float) -> str:
    """
    Generate cache key for city ID lookups.
    Rounds coordinates to reduce cache fragmentation while maintaining accuracy.
    ~111m precision is fine for city-scale caching.
    """
    # Round to 3 decimal places (~111m precision)
    # This means slightly different coordinates use the same cache
    lat_rounded = round(lat, 3)
    lon_rounded = round(lon, 3)
    radius_rounded = round(radius, 1)
    return f"{lat_rounded},{lon_rounded},{radius_rounded}"


def _get_cached_city_ids(lat: float, lon: float, radius: float) -> Optional[List[dict]]:
    """Get cached city IDs if available and not expired"""
    cache_key = _get_cache_key(lat, lon, radius)
    
    if cache_key in _city_ids_cache:
        cached_data = _city_ids_cache[cache_key]
        cache_time = cached_data["timestamp"]
        
        # Check if cache is still valid
        if datetime.utcnow() - cache_time < timedelta(seconds=_CACHE_DURATION_SECONDS):
            print(f"   ⚡ Using cached city IDs (age: {int((datetime.utcnow() - cache_time).total_seconds())}s)")
            return cached_data["city_ids"]
        else:
            # Cache expired, remove it
            del _city_ids_cache[cache_key]
            print(f"   🕐 Cache expired, will fetch fresh data")
    
    return None


def _cache_city_ids(lat: float, lon: float, radius: float, city_ids: List[dict]):
    """Cache city IDs for future lookups"""
    cache_key = _get_cache_key(lat, lon, radius)
    _city_ids_cache[cache_key] = {
        "city_ids": city_ids,
        "timestamp": datetime.utcnow()
    }
    print(f"   💾 Cached {len(city_ids)} city IDs for future lookups")


def _get_or_create_kingdoms_for_cities(db: Session, cities: List[CityBoundary]) -> dict:
    """
    Get or create kingdoms for cities.
    Creates unclaimed kingdoms for any cities that don't have one yet.
    Returns dict of osm_id -> KingdomData
    """
    osm_ids = [city.osm_id for city in cities]
    kingdoms = db.query(Kingdom).filter(Kingdom.id.in_(osm_ids)).all()
    existing_kingdom_ids = {k.id for k in kingdoms}
    
    # Create kingdoms for cities that don't have one
    for city in cities:
        if city.osm_id not in existing_kingdom_ids:
            new_kingdom = Kingdom(
                id=city.osm_id,  # Kingdom ID = OSM ID
                name=city.name,
                city_boundary_osm_id=city.osm_id,
                ruler_id=None,  # Unclaimed
                population=0,
                level=1,
                treasury_gold=0
            )
            db.add(new_kingdom)
            kingdoms.append(new_kingdom)
    
    db.commit()
    
    # Build result map
    result = {}
    for kingdom in kingdoms:
        # Get ruler name if there's a ruler
        ruler_name = None
        if kingdom.ruler_id:
            ruler = db.query(User).filter(User.id == kingdom.ruler_id).first()
            if ruler:
                ruler_name = ruler.display_name
        
        result[kingdom.id] = KingdomData(
            id=kingdom.id,
            ruler_id=kingdom.ruler_id,
            ruler_name=ruler_name,
            level=kingdom.level,
            population=kingdom.population,
            treasury_gold=kingdom.treasury_gold
        )
    
    return result


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
    SMART city boundary lookup with accurate boundaries + in-memory caching.
    
    Strategy:
    1. Check in-memory cache for city IDs (INSTANT!)
    2. If not cached, query OSM for city IDs (9-11 seconds but now cached)
    3. For each city ID, check database for cached boundaries
    4. Only fetch boundaries for cities we DON'T have
    
    This makes map scrolling INSTANT after the first load!
    """
    print(f"🔍 City lookup request: lat={lat}, lon={lon}, radius={radius}km")
    
    # STEP 1: Check in-memory cache for city IDs (INSTANT!)
    city_ids = _get_cached_city_ids(lat, lon, radius)
    
    if not city_ids:
        # STEP 2: Cache miss - fetch from OSM (9-11 seconds but only once per 5 minutes)
        print(f"🌐 Fetching city IDs from OSM (fast query)...")
        city_ids = await fetch_nearby_city_ids(lat, lon, radius)
        
        if not city_ids:
            print("⚠️ OSM query returned no cities")
            return []
        
        # Cache the result for future requests
        _cache_city_ids(lat, lon, radius, city_ids)
    
    # STEP 3: For each city ID, check if we have it cached in DB
    # Only fetch boundaries for cities we DON'T have
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
    
    # Get or create kingdoms for all cities
    kingdoms_map = _get_or_create_kingdoms_for_cities(db, result_cities)
    
    return [
        CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=city.boundary_geojson["coordinates"],
            radius_meters=city.radius_meters,
            cached=(city.access_count > 1),
            kingdom=kingdoms_map.get(city.osm_id)
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
    
    # Get or create kingdoms for all cities
    kingdoms_map = _get_or_create_kingdoms_for_cities(db, result_cities)
    
    return [
        CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=city.boundary_geojson["coordinates"],
            radius_meters=city.radius_meters,
            cached=(city.access_count > 1),
            kingdom=kingdoms_map.get(city.osm_id)
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
    
    # Get or create kingdom data
    kingdoms_map = _get_or_create_kingdoms_for_cities(db, [city])
    
    return CityBoundaryResponse(
        osm_id=city.osm_id,
        name=city.name,
        admin_level=city.admin_level,
        center_lat=city.center_lat,
        center_lon=city.center_lon,
        boundary=city.boundary_geojson["coordinates"],
        radius_meters=city.radius_meters,
        cached=True,
        kingdom=kingdoms_map.get(osm_id)
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

