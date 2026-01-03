"""
City service - Business logic for city boundary lookups

FAST LOADING - TWO ENDPOINTS:
1. /cities/current - Returns ONLY the city user is in (< 2s) - UNBLOCKS FRONTEND
2. /cities/neighbors - Returns neighbor cities IMMEDIATELY, fetches boundaries in background
"""
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from datetime import datetime
import math
import asyncio

from db import CityBoundary, Kingdom, User, get_db
from schemas import CityBoundaryResponse, BoundaryResponse, KingdomData
from osm_service import (
    find_user_city_fast,
    fetch_nearby_city_ids,
    fetch_city_boundary_by_id,
)


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in meters (Haversine formula)"""
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def _is_point_in_polygon(lat: float, lon: float, polygon: List[List[float]]) -> bool:
    """Check if a point is inside a polygon using ray-casting algorithm"""
    if not polygon or len(polygon) < 3:
        return False
    x, y = lat, lon
    n = len(polygon)
    inside = False
    p1x, p1y = polygon[0]
    for i in range(1, n + 1):
        p2x, p2y = polygon[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside


def _get_kingdom_data(db: Session, osm_ids: List[str], current_user=None) -> Dict[str, KingdomData]:
    """Get or create kingdom data for cities. Returns dict of osm_id -> KingdomData"""
    from db.models import UserKingdom
    from db.models import PlayerState
    
    if not osm_ids:
        return {}
    
    # Fetch existing kingdoms
    kingdoms = db.query(Kingdom).filter(Kingdom.id.in_(osm_ids)).all()
    existing_ids = {k.id for k in kingdoms}
    
    # Get user's current location (which kingdom they're in)
    user_current_kingdom_id = None
    if current_user:
        player_state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
        if player_state:
            user_current_kingdom_id = player_state.current_kingdom_id
    
    # Get user's kingdoms for relationship checking
    user_kingdom_ids = set()
    if current_user:
        user_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).all()
        user_kingdom_ids = {k.id for k in user_kingdoms}
    
    # Batch fetch ruler names
    ruler_ids = [k.ruler_id for k in kingdoms if k.ruler_id]
    rulers = {}
    if ruler_ids:
        ruler_users = db.query(User).filter(User.id.in_(ruler_ids)).all()
        rulers = {u.id: u.display_name for u in ruler_users}
    
    # Build result
    result = {}
    for kingdom in kingdoms:
        ruler_name = rulers.get(kingdom.ruler_id) if kingdom.ruler_id else None
        # Can claim ONLY if: kingdom is unclaimed, user doesn't rule any kingdoms, AND user is INSIDE this kingdom
        can_claim = (
            kingdom.ruler_id is None and 
            len(user_kingdom_ids) == 0 and 
            user_current_kingdom_id == kingdom.id
        )
        
        # Can declare war / form alliance ONLY if:
        # - User is a ruler of a different kingdom
        # - User is INSIDE this kingdom (traveling into it)
        # - This kingdom has a ruler
        # - This kingdom's ruler is not the current user
        can_interact = (
            len(user_kingdom_ids) > 0 and
            user_current_kingdom_id == kingdom.id and
            kingdom.ruler_id is not None and
            kingdom.ruler_id != current_user.id if current_user else False
        )
        
        # Determine relationship to player
        is_allied = False
        is_enemy = False
        
        if user_kingdom_ids:
            # Check if this kingdom is allied or at war with any of player's kingdoms
            kingdom_allies = set(kingdom.allies) if kingdom.allies else set()
            kingdom_enemies = set(kingdom.enemies) if kingdom.enemies else set()
            
            is_allied = bool(user_kingdom_ids & kingdom_allies)
            is_enemy = bool(user_kingdom_ids & kingdom_enemies)
        
        result[kingdom.id] = KingdomData(
            id=kingdom.id,
            ruler_id=kingdom.ruler_id,
            ruler_name=ruler_name,
            level=kingdom.level,
            population=kingdom.population,
            treasury_gold=kingdom.treasury_gold,
            wall_level=kingdom.wall_level,
            vault_level=kingdom.vault_level,
            mine_level=kingdom.mine_level,
            market_level=kingdom.market_level,
            farm_level=kingdom.farm_level,
            education_level=kingdom.education_level,
            travel_fee=kingdom.travel_fee,
            can_claim=can_claim,
            can_declare_war=can_interact,
            can_form_alliance=can_interact,
            is_allied=is_allied,
            is_enemy=is_enemy
        )
    
    return result


def _ensure_kingdom_exists(db: Session, osm_id: str, name: str):
    """Create kingdom if it doesn't exist"""
    existing = db.query(Kingdom).filter(Kingdom.id == osm_id).first()
    if not existing:
        new_kingdom = Kingdom(
            id=osm_id,
            name=name,
            city_boundary_osm_id=osm_id,
            ruler_id=None,
            population=0,
            level=1,
            treasury_gold=0
        )
        db.add(new_kingdom)
        db.commit()


async def get_current_city(
    db: Session,
    lat: float,
    lon: float,
    current_user = None
) -> Optional[CityBoundaryResponse]:
    """
    FAST - Get ONLY the city the user is currently in.
    This should return in < 2 seconds to unblock the frontend.
    
    Strategy:
    1. Check cache first (instant)
    2. If not cached, call fast OSM query
    3. Fetch boundary for just this ONE city
    """
    print(f"🎯 Getting current city for ({lat:.4f}, {lon:.4f})")
    
    # Step 1: Check cache - find city user is inside
    lat_delta = 0.5  # ~55km
    lon_delta = 0.5 / max(0.1, math.cos(math.radians(lat)))
    
    cached_cities = db.query(CityBoundary).filter(
        CityBoundary.center_lat.between(lat - lat_delta, lat + lat_delta),
        CityBoundary.center_lon.between(lon - lon_delta, lon + lon_delta)
    ).all()
    
    # Check which cached city user is inside
    for city in cached_cities:
        boundary = city.boundary_geojson.get("coordinates", [])
        if boundary and _is_point_in_polygon(lat, lon, boundary):
            print(f"   💾 Found in cache: {city.name}")
            city.access_count += 1
            city.last_accessed = datetime.utcnow()
            db.commit()
            
            # Get kingdom data
            _ensure_kingdom_exists(db, city.osm_id, city.name)
            kingdoms = _get_kingdom_data(db, [city.osm_id], current_user)
            
            return CityBoundaryResponse(
                osm_id=city.osm_id,
                name=city.name,
                admin_level=city.admin_level,
                center_lat=city.center_lat,
                center_lon=city.center_lon,
                boundary=boundary,
                radius_meters=city.radius_meters,
                cached=True,
                is_current=True,
                kingdom=kingdoms.get(city.osm_id)
            )
    
    # Step 2: Not in cache - call OSM
    print(f"   🌐 Not in cache, calling OSM...")
    city_info = await find_user_city_fast(lat, lon)
    
    if not city_info:
        print(f"   ⚠️ No city found at this location")
        return None
    
    osm_id = city_info["osm_id"]
    
    # Check if we have this city cached (just not with user inside)
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if cached:
        print(f"   💾 Found boundary in cache: {cached.name}")
        cached.access_count += 1
        cached.last_accessed = datetime.utcnow()
        db.commit()
        
        _ensure_kingdom_exists(db, cached.osm_id, cached.name)
        kingdoms = _get_kingdom_data(db, [cached.osm_id], current_user)
        
        return CityBoundaryResponse(
            osm_id=cached.osm_id,
            name=cached.name,
            admin_level=cached.admin_level,
            center_lat=cached.center_lat,
            center_lon=cached.center_lon,
            boundary=cached.boundary_geojson.get("coordinates", []),
            radius_meters=cached.radius_meters,
            cached=True,
            is_current=True,
            kingdom=kingdoms.get(cached.osm_id)
        )
    
    # Step 3: Fetch boundary from OSM
    print(f"   🌐 Fetching boundary for {city_info['name']}...")
    boundary_data = await fetch_city_boundary_by_id(osm_id, city_info.get("name", "Unknown"))
    
    if not boundary_data:
        # Return city with center only, no boundary
        print(f"   ⚠️ Could not fetch boundary, returning center only")
        _ensure_kingdom_exists(db, osm_id, city_info.get("name", "Unknown"))
        kingdoms = _get_kingdom_data(db, [osm_id], current_user)
        
        return CityBoundaryResponse(
            osm_id=osm_id,
            name=city_info.get("name", "Unknown"),
            admin_level=city_info.get("admin_level", 8),
            center_lat=city_info.get("center_lat", lat),
            center_lon=city_info.get("center_lon", lon),
            boundary=[],
            radius_meters=5000.0,
            cached=False,
            is_current=True,
            kingdom=kingdoms.get(osm_id)
        )
    
    # Cache it (with race condition protection)
    try:
        new_city = CityBoundary(
            osm_id=osm_id,
            name=boundary_data["name"],
            admin_level=boundary_data["admin_level"],
            center_lat=boundary_data["center_lat"],
            center_lon=boundary_data["center_lon"],
            boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
            radius_meters=boundary_data["radius_meters"],
            boundary_points_count=len(boundary_data["boundary"]),
            access_count=1,
            osm_metadata=boundary_data.get("osm_tags", {})
        )
        db.add(new_city)
        db.commit()
    except Exception as e:
        # Race condition - another request already cached it
        db.rollback()
        if "duplicate key" in str(e).lower():
            print(f"   ⏭️  {osm_id} already cached by another request")
            # Fetch from DB to get the existing record
            cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
            if cached:
                cached.access_count += 1
                cached.last_accessed = datetime.utcnow()
                db.commit()
        else:
            # Some other error - re-raise
            raise
    
    _ensure_kingdom_exists(db, osm_id, boundary_data["name"])
    kingdoms = _get_kingdom_data(db, [osm_id], current_user)
    
    print(f"   ✅ Got current city: {boundary_data['name']}")
    
    return CityBoundaryResponse(
        osm_id=osm_id,
        name=boundary_data["name"],
        admin_level=boundary_data["admin_level"],
        center_lat=boundary_data["center_lat"],
        center_lon=boundary_data["center_lon"],
        boundary=boundary_data["boundary"],
        radius_meters=boundary_data["radius_meters"],
        cached=False,
        is_current=True,
        kingdom=kingdoms.get(osm_id)
    )


async def get_neighbor_cities(
    db: Session,
    lat: float,
    lon: float,
    current_user = None
) -> List[CityBoundaryResponse]:
    """
    Get cities that DIRECTLY TOUCH the current city (shared borders only).
    admin_level=8 ONLY (cities, not counties).
    """
    print(f"🏘️ Loading neighbors for ({lat:.4f}, {lon:.4f})")
    
    # Step 1: Find the current city
    current_city = None
    lat_delta = 0.5
    lon_delta = 0.5 / max(0.1, math.cos(math.radians(lat)))
    
    cached_cities = db.query(CityBoundary).filter(
        CityBoundary.center_lat.between(lat - lat_delta, lat + lat_delta),
        CityBoundary.center_lon.between(lon - lon_delta, lon + lon_delta)
    ).all()
    
    for city in cached_cities:
        boundary = city.boundary_geojson.get("coordinates", [])
        if boundary and _is_point_in_polygon(lat, lon, boundary):
            current_city = city
            break
    
    # Step 2: Check cached neighbors
    neighbor_ids = []
    if current_city and current_city.neighbor_ids is not None:
        print(f"   💾 Cached neighbors for {current_city.name}")
        osm_ids = current_city.neighbor_ids
        neighbor_ids = [{"osm_id": osm_id, "name": f"City-{osm_id}"} for osm_id in osm_ids]
    
    # Step 3: Fetch from OSM if not cached
    if not neighbor_ids:
        print(f"   🌐 Fetching neighbors from OSM...")
        neighbor_ids = await fetch_nearby_city_ids(lat, lon)
        
        if not neighbor_ids:
            print(f"   ⚠️ No neighbors found")
            return []
        
        print(f"   🌐 OSM returned {len(neighbor_ids)} neighbors")
        
        # Cache the neighbor list if we found the current city
        if current_city:
            current_city.neighbor_ids = [n["osm_id"] for n in neighbor_ids]
            current_city.neighbors_updated_at = datetime.utcnow()
            db.commit()
            print(f"   💾 Cached neighbor list for {current_city.name}")
    else:
        print(f"   🌐 Using {len(neighbor_ids)} cached neighbors")
    
    # Check which ones we have cached
    osm_ids = [n["osm_id"] for n in neighbor_ids]
    cached_by_id = {c.osm_id: c for c in db.query(CityBoundary).filter(CityBoundary.osm_id.in_(osm_ids)).all()}
    
    print(f"   💾 {len(cached_by_id)}/{len(osm_ids)} boundaries cached")
    
    # Build result - return immediately with what we have
    result_cities = []
    
    for city_info in neighbor_ids:
        osm_id = city_info["osm_id"]
        name = city_info.get("name", "Unknown")
        
        _ensure_kingdom_exists(db, osm_id, name)
        
        if osm_id in cached_by_id:
            # Have boundary cached - return full data
            city = cached_by_id[osm_id]
            city.access_count += 1
            city.last_accessed = datetime.utcnow()
            result_cities.append(city)
        else:
            # NOT cached - return center point only
            temp_city = type('TempCity', (), {
                'osm_id': osm_id,
                'name': name,
                'admin_level': city_info.get("admin_level", 8),
                'center_lat': city_info.get("center_lat", 0.0),
                'center_lon': city_info.get("center_lon", 0.0),
                'boundary_geojson': {"coordinates": []},  # Empty - frontend should fetch via batch endpoint
                'radius_meters': 5000.0,  # Estimated
                'cached': False
            })()
            result_cities.append(temp_city)
    
    db.commit()
    
    # Get kingdom data
    kingdoms = _get_kingdom_data(db, [c.osm_id for c in result_cities], current_user)
    
    cached_count = len(cached_by_id)
    uncached_count = len(result_cities) - cached_count
    print(f"   ✅ Returning {len(result_cities)} neighbors ({cached_count} with boundaries, {uncached_count} center-only)")
    
    return [
        CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=city.boundary_geojson.get("coordinates", []),
            radius_meters=city.radius_meters,
            cached=True,
            is_current=False,
            kingdom=kingdoms.get(city.osm_id)
        )
        for city in result_cities
    ]


# Legacy endpoint - combines current + neighbors (for backward compat)
async def get_cities_near_location(
    db: Session,
    lat: float,
    lon: float,
    radius: float = 30.0,  # Ignored - kept for backward compat with legacy endpoint
    current_user = None
) -> List[CityBoundaryResponse]:
    """Legacy endpoint - returns current city + neighbors together"""
    current = await get_current_city(db, lat, lon, current_user)
    neighbors = await get_neighbor_cities(db, lat, lon, current_user)
    
    result = []
    if current:
        result.append(current)
    result.extend(neighbors)
    return result


async def get_city_boundary(db: Session, osm_id: str) -> Optional[BoundaryResponse]:
    """Lazy-load boundary for a single city."""
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if cached:
        cached.access_count += 1
        cached.last_accessed = datetime.utcnow()
        db.commit()
        return BoundaryResponse(
            osm_id=cached.osm_id,
            name=cached.name,
            boundary=cached.boundary_geojson.get("coordinates", []),
            radius_meters=cached.radius_meters,
            from_cache=True
        )
    
    print(f"🌐 Lazy-loading boundary for {osm_id}")
    boundary_data = await fetch_city_boundary_by_id(osm_id)
    
    if not boundary_data:
        return None
    
    # Cache it (with race condition protection)
    try:
        new_city = CityBoundary(
            osm_id=osm_id,
            name=boundary_data["name"],
            admin_level=boundary_data["admin_level"],
            center_lat=boundary_data["center_lat"],
            center_lon=boundary_data["center_lon"],
            boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
            radius_meters=boundary_data["radius_meters"],
            boundary_points_count=len(boundary_data["boundary"]),
            access_count=1,
            osm_metadata=boundary_data.get("osm_tags", {})
        )
        db.add(new_city)
        db.commit()
    except Exception as e:
        # Race condition - another request already cached it
        db.rollback()
        if "duplicate key" in str(e).lower():
            print(f"   ⏭️  {osm_id} already cached by another request")
            # Fetch from DB to get the existing record
            cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
            if cached:
                cached.access_count += 1
                cached.last_accessed = datetime.utcnow()
                db.commit()
        else:
            # Some other error - re-raise
            raise
    
    return BoundaryResponse(
        osm_id=osm_id,
        name=boundary_data["name"],
        boundary=boundary_data["boundary"],
        radius_meters=boundary_data["radius_meters"],
        from_cache=False
    )


async def get_city_boundaries_batch(db: Session, osm_ids: List[str]) -> List[BoundaryResponse]:
    """
    Fetch multiple city boundaries in parallel.
    
    Much faster than calling get_city_boundary() sequentially.
    Returns boundaries in same order as requested osm_ids.
    """
    print(f"📦 Batch loading {len(osm_ids)} boundaries...")
    
    # Check cache first
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id.in_(osm_ids)).all()
    cached_by_id = {c.osm_id: c for c in cached}
    
    print(f"   💾 {len(cached)}/{len(osm_ids)} already cached")
    
    # Update access counts for cached items
    for city in cached:
        city.access_count += 1
        city.last_accessed = datetime.utcnow()
    db.commit()
    
    # Fetch missing ones in parallel
    missing_ids = [osm_id for osm_id in osm_ids if osm_id not in cached_by_id]
    
    if missing_ids:
        print(f"   🌐 Fetching {len(missing_ids)} from OSM in parallel...")
        
        # Fetch all in parallel using asyncio.gather
        fetch_tasks = [fetch_city_boundary_by_id(osm_id) for osm_id in missing_ids]
        boundary_results = await asyncio.gather(*fetch_tasks, return_exceptions=True)
        
        # Cache successful fetches
        newly_cached = {}
        for osm_id, boundary_data in zip(missing_ids, boundary_results):
            # Skip exceptions and None results
            if isinstance(boundary_data, Exception):
                print(f"   ❌ Error fetching {osm_id}: {boundary_data}")
                continue
            if not boundary_data:
                print(f"   ⚠️  No data for {osm_id}")
                continue
            
            try:
                new_city = CityBoundary(
                    osm_id=osm_id,
                    name=boundary_data["name"],
                    admin_level=boundary_data["admin_level"],
                    center_lat=boundary_data["center_lat"],
                    center_lon=boundary_data["center_lon"],
                    boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
                    radius_meters=boundary_data["radius_meters"],
                    boundary_points_count=len(boundary_data["boundary"]),
                    access_count=1,
                    osm_metadata=boundary_data.get("osm_tags", {})
                )
                db.add(new_city)
                db.flush()  # Get it into session without committing
                newly_cached[osm_id] = new_city
                print(f"   ✅ Cached {boundary_data['name']}")
            except Exception as e:
                # Race condition - another request cached it
                db.rollback()
                if "duplicate key" in str(e).lower():
                    print(f"   ⏭️  {osm_id} already cached by another request")
                    # Fetch from DB
                    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
                    if city:
                        newly_cached[osm_id] = city
                else:
                    print(f"   ❌ Error caching {osm_id}: {e}")
        
        try:
            db.commit()
        except Exception as e:
            db.rollback()
            print(f"   ⚠️  Commit error (likely race condition): {e}")
            # Re-fetch to get latest state
            for osm_id in missing_ids:
                if osm_id not in newly_cached:
                    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
                    if city:
                        newly_cached[osm_id] = city
        
        # Update cached_by_id with newly cached items
        cached_by_id.update(newly_cached)
    
    # Build response in same order as input
    result = []
    for osm_id in osm_ids:
        if osm_id in cached_by_id:
            city = cached_by_id[osm_id]
            result.append(BoundaryResponse(
                osm_id=city.osm_id,
                name=city.name,
                boundary=city.boundary_geojson.get("coordinates", []),
                radius_meters=city.radius_meters,
                from_cache=(osm_id in cached_by_id and osm_id not in missing_ids)
            ))
        else:
            # Failed to fetch - return empty boundary
            result.append(BoundaryResponse(
                osm_id=osm_id,
                name=f"City-{osm_id}",
                boundary=[],
                radius_meters=5000.0,
                from_cache=False
            ))
    
    print(f"   ✅ Batch complete: {len([r for r in result if r.boundary])} with boundaries")
    return result


def get_city_by_id(db: Session, osm_id: str) -> Optional[CityBoundaryResponse]:
    """Get a specific city from cache"""
    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    if not city:
        return None
    
    city.access_count += 1
    city.last_accessed = datetime.utcnow()
    db.commit()
    
    kingdoms = _get_kingdom_data(db, [osm_id], None)
    
    return CityBoundaryResponse(
        osm_id=city.osm_id,
        name=city.name,
        admin_level=city.admin_level,
        center_lat=city.center_lat,
        center_lon=city.center_lon,
        boundary=city.boundary_geojson.get("coordinates", []),
        radius_meters=city.radius_meters,
        cached=True,
        kingdom=kingdoms.get(osm_id)
    )


def get_city_stats(db: Session) -> dict:
    """Get cache statistics"""
    total = db.query(CityBoundary).count()
    top = db.query(CityBoundary).order_by(CityBoundary.access_count.desc()).limit(10).all()
    return {
        "total_cached": total,
        "top_accessed": [
            {"osm_id": c.osm_id, "name": c.name, "access_count": c.access_count}
            for c in top
        ]
    }
