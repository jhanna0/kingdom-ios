"""
OpenStreetMap Service - Fetches and processes city boundaries
Ported from iOS OSMLoader.swift
"""
import httpx
import asyncio
from typing import List, Dict, Optional, Tuple
from datetime import datetime
import math

# Multiple Overpass API endpoints for redundancy
OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
]


async def find_user_city_fast(lat: float, lon: float) -> Optional[Dict]:
    """
    FAST query to find what city the user is currently in.
    Uses 'is_in' which is much faster than radius search.
    Returns just ONE city with center point (no geometry yet).
    """
    query = f"""
    [out:json][timeout:10];
    is_in({lat},{lon})->.a;
    relation(pivot.a)["boundary"="administrative"]["admin_level"="8"]["name"];
    out center;
    """
    
    print(f"🎯 Fast lookup: What city is user in?")
    
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    endpoint,
                    data={"data": query},
                    headers={"User-Agent": "KingdomApp/1.0"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    elements = data.get("elements", [])
                    
                    if elements:
                        city = elements[0]
                        tags = city.get("tags", {})
                        center = city.get("center", {})
                        
                        result = {
                            "osm_id": str(city.get("id")),
                            "name": tags.get("name"),
                            "center_lat": center.get("lat", lat),
                            "center_lon": center.get("lon", lon),
                            "admin_level": int(tags.get("admin_level", 8))
                        }
                        print(f"    ✅ Found: {result['name']} (OSM ID: {result['osm_id']})")
                        return result
        except Exception as e:
            print(f"    ⚠️ Failed on {endpoint}: {e}")
            await asyncio.sleep(0.3)
    
    print("    ❌ Could not determine user's city")
    return None


async def fetch_nearby_city_ids(lat: float, lon: float) -> List[Dict]:
    """
    Find cities that DIRECTLY BORDER the user's current city.
    
    NOT a radius search - finds cities that share boundary ways.
    ONLY admin_level=8 (actual cities, not counties/states).
    """
    
    # Query finds neighbors by shared boundary ways
    query = f"""
    [out:json][timeout:10];
    
    // Step 1: What city is the user in?
    is_in({lat},{lon})->.a;
    relation(pivot.a)["boundary"="administrative"]["admin_level"="8"]->.current;
    
    // Step 2: Get the ways that form this city's boundary
    way(r.current)->.boundary_ways;
    
    // Step 3: Find ALL cities that share these boundary ways (= neighbors)
    relation(bw.boundary_ways)["boundary"="administrative"]["admin_level"="8"]["name"];
    
    // Output with center points
    out center;
    """
    
    print(f"🌐 Finding neighboring cities for ({lat:.4f}, {lon:.4f})")
    
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    endpoint,
                    data={"data": query},
                    headers={"User-Agent": "KingdomApp/1.0"}
                )
                
                if response.status_code != 200:
                    continue
                
                data = response.json()
                elements = data.get("elements", [])
                
                cities = []
                for element in elements:
                    tags = element.get("tags", {})
                    center = element.get("center", {})
                    
                    if not tags.get("name") or not center:
                        continue
                    
                    distance = _distance_between(
                        lat, lon,
                        center.get("lat"), center.get("lon")
                    )
                    
                    cities.append({
                        "osm_id": str(element.get("id")),
                        "name": tags.get("name"),
                        "center_lat": center.get("lat"),
                        "center_lon": center.get("lon"),
                        "admin_level": int(tags.get("admin_level", 8)),
                        "distance": distance,
                        "osm_tags": tags
                    })
                
                cities.sort(key=lambda c: c["distance"])
                print(f"    ✅ Found {len(cities)} neighboring cities from {endpoint}")
                return cities[:50]
                
        except Exception as e:
            print(f"    ⚠️ {endpoint}: {e}")
    
    print("    ❌ Could not fetch neighboring cities")
    return []


async def fetch_city_boundary_by_id(osm_id: str, name: str = "Unknown") -> Optional[Dict]:
    """
    Fetch ACCURATE boundary geometry for ONE specific city by OSM ID.
    Only call this for cities we don't have cached.
    Returns full city data with accurate boundaries.
    """
    query = f"""
    [out:json][timeout:25];
    relation({osm_id});
    out geom;
    """
    
    print(f"    🌐 Fetching accurate boundary for: {name} (OSM {osm_id})")
    
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    endpoint,
                    data={"data": query},
                    headers={"User-Agent": "KingdomApp/1.0"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    elements = data.get("elements", [])
                    
                    if not elements:
                        continue
                    
                    element = elements[0]
                    tags = element.get("tags", {})
                    members = element.get("members", [])
                    
                    # Extract and process boundary with full accuracy
                    boundary = _extract_boundary_from_members(members)
                    
                    if len(boundary) < 10:
                        print(f"        ⚠️ Insufficient boundary points ({len(boundary)})")
                        continue
                    
                    # Simplify polygon but maintain accuracy
                    simplified = _simplify_polygon(boundary, target_points=100, min_points=25)
                    
                    # Calculate center and radius
                    center = _calculate_centroid(simplified)
                    radius = _calculate_radius(center, simplified)
                    
                    city_data = {
                        "osm_id": osm_id,
                        "name": tags.get("name", name),
                        "admin_level": int(tags.get("admin_level", 8)),
                        "center_lat": center[0],
                        "center_lon": center[1],
                        "boundary": simplified,
                        "radius_meters": radius,
                        "osm_tags": tags
                    }
                    
                    print(f"        ✅ Got accurate boundary: {len(simplified)} points, radius: {int(radius)}m")
                    return city_data
                    
        except Exception as e:
            print(f"        ⚠️ Failed on {endpoint}: {e}")
            await asyncio.sleep(0.3)
    
    print(f"        ❌ Could not fetch boundary for {name}")
    return None


async def fetch_cities_from_osm(
    lat: float, 
    lon: float, 
    radius_km: float = 30,
    admin_levels: str = "8"  # Default to just cities (level 8)
) -> List[Dict]:
    """
    Fetch city boundaries from OpenStreetMap Overpass API
    Returns list of city dictionaries with name, boundaries, etc.
    Uses bbox instead of around: for much faster queries.
    
    Admin levels:
    - 8: Cities (most accurate, fewest results - FAST)
    - 7,8: Counties + Cities (more results - SLOWER)
    - 8,9: Cities + Districts (more granular - SLOWER)
    """
    print(f"🌍 Fetching cities from OSM: lat={lat}, lon={lon}, radius={radius_km}km, admin_levels={admin_levels}")
    
    # Calculate bounding box (MUCH faster than around:)
    lat_delta = radius_km / 111.0
    lon_delta = radius_km / (111.0 * max(0.1, math.cos(math.radians(lat))))
    
    south = lat - lat_delta
    north = lat + lat_delta
    west = lon - lon_delta
    east = lon + lon_delta
    
    # Build Overpass query with bbox - KEEP out geom for accuracy!
    query = f"""
    [out:json][timeout:15][bbox:{south},{west},{north},{east}];
    relation["boundary"="administrative"]["admin_level"~"^({admin_levels})$"]["name"];
    out geom;
    """
    
    # Try multiple endpoints
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            cities = await _execute_overpass_query(query, endpoint, lat, lon)
            if cities:
                print(f"✅ Found {len(cities)} cities from {endpoint}")
                return cities
        except Exception as e:
            print(f"⚠️ Failed to fetch from {endpoint}: {e}")
            await asyncio.sleep(0.3)  # Rate limiting
    
    print("❌ All Overpass endpoints failed")
    return []


async def _execute_overpass_query(
    query: str, 
    endpoint: str, 
    user_lat: float, 
    user_lon: float
) -> List[Dict]:
    """Execute Overpass API query and parse results"""
    
    async with httpx.AsyncClient(timeout=35.0) as client:
        response = await client.post(
            endpoint,
            data={"data": query},
            headers={"User-Agent": "KingdomApp/1.0"}
        )
        
        if response.status_code != 200:
            raise Exception(f"HTTP {response.status_code}")
        
        data = response.json()
        return _parse_overpass_response(data, user_lat, user_lon)


def _parse_overpass_response(data: Dict, user_lat: float, user_lon: float) -> List[Dict]:
    """Parse Overpass API response and extract city boundaries"""
    cities = []
    
    elements = data.get("elements", [])
    print(f"📦 Processing {len(elements)} OSM elements")
    
    for element in elements:
        if element.get("type") != "relation":
            continue
        
        tags = element.get("tags", {})
        name = tags.get("name")
        if not name:
            continue
        
        osm_id = str(element.get("id"))
        admin_level = int(tags.get("admin_level", 8))
        
        # Extract boundary coordinates from members
        members = element.get("members", [])
        boundary = _extract_boundary_from_members(members)
        
        if len(boundary) < 10:
            print(f"    ⚠️ {name}: only {len(boundary)} points, skipping")
            continue
        
        # Calculate distance from user
        center = _calculate_centroid(boundary)
        distance = _distance_between(user_lat, user_lon, center[0], center[1])
        
        # Skip if too far
        if distance > 40_000:
            print(f"    ⏭️ {name}: too far ({int(distance/1000)}km)")
            continue
        
        # Simplify polygon to 25-150 points
        simplified = _simplify_polygon(boundary, target_points=100, min_points=25)
        
        # Calculate final center and radius
        final_center = _calculate_centroid(simplified)
        radius = _calculate_radius(final_center, simplified)
        
        city = {
            "osm_id": osm_id,
            "name": name,
            "admin_level": admin_level,
            "center_lat": final_center[0],
            "center_lon": final_center[1],
            "boundary": simplified,  # List of [lat, lon] pairs
            "radius_meters": radius,
            "distance_from_user": distance,
            "osm_tags": tags
        }
        
        cities.append(city)
        print(f"    🏰 {name} - {len(simplified)} points, {int(distance/1000)}km away")
    
    # Sort by distance and return closest 35
    cities.sort(key=lambda c: c["distance_from_user"])
    return cities[:35]


def _extract_boundary_from_members(members: List[Dict]) -> List[Tuple[float, float]]:
    """Extract boundary coordinates from OSM relation members"""
    segments = []
    
    for member in members:
        if member.get("role") != "outer":
            continue
        if member.get("type") != "way":
            continue
        
        geometry = member.get("geometry", [])
        segment = [(point["lat"], point["lon"]) for point in geometry if "lat" in point and "lon" in point]
        
        if len(segment) >= 2:
            segments.append(segment)
    
    # Join segments into complete boundary
    if not segments:
        return []
    
    if len(segments) == 1:
        return segments[0]
    
    # Try to join multiple segments
    return _join_segments(segments)


def _join_segments(segments: List[List[Tuple[float, float]]]) -> List[Tuple[float, float]]:
    """
    Join disconnected way segments into a complete boundary
    This handles OSM boundaries made of multiple ways
    """
    if len(segments) == 1:
        return segments[0]
    
    # Start with longest segment
    result = max(segments, key=len)
    used = {segments.index(result)}
    remaining = [s for i, s in enumerate(segments) if i not in used]
    
    # Try to connect segments with increasing tolerance
    tolerances = [0.0001, 0.0005, 0.001, 0.005, 0.01]
    
    for tolerance in tolerances:
        progress = True
        while progress and len(used) < len(segments):
            progress = False
            
            for i, segment in enumerate(remaining):
                if i in used or not segment:
                    continue
                
                # Try to connect to start or end
                if _coord_distance(result[-1], segment[0]) < tolerance:
                    result.extend(segment[1:])
                    used.add(i)
                    progress = True
                elif _coord_distance(result[-1], segment[-1]) < tolerance:
                    result.extend(reversed(segment[:-1]))
                    used.add(i)
                    progress = True
                elif _coord_distance(result[0], segment[-1]) < tolerance:
                    result = segment[:-1] + result
                    used.add(i)
                    progress = True
                elif _coord_distance(result[0], segment[0]) < tolerance:
                    result = list(reversed(segment[1:])) + result
                    used.add(i)
                    progress = True
    
    return result


def _simplify_polygon(points: List[Tuple[float, float]], target_points: int = 100, min_points: int = 25) -> List[Tuple[float, float]]:
    """
    Douglas-Peucker simplification - preserves shape better than uniform sampling
    NEVER goes below minimumPoints to prevent degenerate polygons
    Exact port from iOS OSMLoader.swift
    """
    if len(points) <= target_points:
        return points
    
    # Start with a small tolerance and increase until we hit target
    # BUT stop if we go below minimum
    tolerance = 0.00001
    result = points
    previous_result = points
    
    while len(result) > target_points and tolerance < 0.01:
        previous_result = result
        result = _douglas_peucker(points, tolerance)
        
        # CRITICAL: If we went below minimum, use the previous result
        if len(result) < min_points:
            result = previous_result
            break
        
        tolerance *= 1.5  # Slower increase for better control
    
    # Final safety check - if still too few points, use uniform sampling
    if len(result) < min_points and len(points) >= min_points:
        result = _uniform_sample(points, min_points)
    
    return _ensure_closed(result)


def _uniform_sample(points: List[Tuple[float, float]], target_count: int) -> List[Tuple[float, float]]:
    """Uniform sampling fallback - guaranteed to return targetCount points"""
    if len(points) <= target_count:
        return points
    
    step = len(points) / target_count
    result = []
    
    for i in range(target_count):
        index = int(i * step)
        if index < len(points):
            result.append(points[index])
    
    return result


def _douglas_peucker(points: List[Tuple[float, float]], tolerance: float) -> List[Tuple[float, float]]:
    """Douglas-Peucker algorithm - exact port from iOS"""
    if len(points) < 3:
        return points
    
    dmax = 0.0
    index = 0
    end = len(points) - 1
    
    for i in range(1, end):
        d = _perpendicular_distance(points[i], points[0], points[end])
        if d > dmax:
            index = i
            dmax = d
    
    if dmax > tolerance:
        left = _douglas_peucker(points[0:index+1], tolerance)
        right = _douglas_peucker(points[index:end+1], tolerance)
        return left[:-1] + right
    else:
        return [points[0], points[end]]


def _perpendicular_distance(point: Tuple[float, float], line_start: Tuple[float, float], line_end: Tuple[float, float]) -> float:
    """Calculate perpendicular distance from point to line - exact port from iOS"""
    lat, lon = point
    lat1, lon1 = line_start
    lat2, lon2 = line_end
    
    dx = lon2 - lon1
    dy = lat2 - lat1
    
    mag = math.sqrt(dx * dx + dy * dy)
    if mag <= 0:
        return 0.0
    
    u = ((lon - lon1) * dx + (lat - lat1) * dy) / (mag * mag)
    
    if u < 0:
        closest_lon = lon1
        closest_lat = lat1
    elif u > 1:
        closest_lon = lon2
        closest_lat = lat2
    else:
        closest_lon = lon1 + u * dx
        closest_lat = lat1 + u * dy
    
    ddx = lon - closest_lon
    ddy = lat - closest_lat
    
    return math.sqrt(ddx * ddx + ddy * ddy)


def _ensure_closed(coords: List[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """Ensure the polygon is closed (first point == last point)"""
    if len(coords) < 3:
        return coords
    
    first = coords[0]
    last = coords[-1]
    
    if _coord_distance(first, last) > 0.00001:
        return coords + [first]
    
    return coords


def _calculate_centroid(coords: List[Tuple[float, float]]) -> Tuple[float, float]:
    """Calculate polygon centroid (weighted by area)"""
    if len(coords) < 3:
        # Just average
        lat_sum = sum(c[0] for c in coords)
        lon_sum = sum(c[1] for c in coords)
        return (lat_sum / len(coords), lon_sum / len(coords))
    
    # Polygon centroid formula
    signed_area = 0
    centroid_lat = 0
    centroid_lon = 0
    
    n = len(coords)
    for i in range(n):
        lat0, lon0 = coords[i]
        lat1, lon1 = coords[(i + 1) % n]
        
        a = lon0 * lat1 - lon1 * lat0
        signed_area += a
        centroid_lat += (lat0 + lat1) * a
        centroid_lon += (lon0 + lon1) * a
    
    signed_area *= 0.5
    
    if abs(signed_area) < 0.0000001:
        # Fall back to simple average
        lat_sum = sum(c[0] for c in coords)
        lon_sum = sum(c[1] for c in coords)
        return (lat_sum / len(coords), lon_sum / len(coords))
    
    centroid_lat /= (6.0 * signed_area)
    centroid_lon /= (6.0 * signed_area)
    
    return (centroid_lat, centroid_lon)


def _calculate_radius(center: Tuple[float, float], boundary: List[Tuple[float, float]]) -> float:
    """Calculate average distance from center to boundary points"""
    distances = [_distance_between(center[0], center[1], point[0], point[1]) for point in boundary]
    return sum(distances) / len(distances) if distances else 5000.0


def _distance_between(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two coordinates in meters (Haversine formula)"""
    R = 6371000  # Earth's radius in meters
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c


def _coord_distance(c1: Tuple[float, float], c2: Tuple[float, float]) -> float:
    """Calculate Euclidean distance between two coordinates (for segment joining)"""
    lat_diff = c1[0] - c2[0]
    lon_diff = c1[1] - c2[1]
    return math.sqrt(lat_diff**2 + lon_diff**2)

