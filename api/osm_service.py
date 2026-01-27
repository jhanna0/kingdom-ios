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
    Cascading: try level 8 first, then 7, then 6.
    """
    print(f"🎯 Fast lookup: What city is user in?")
    
    # Cascading: 8 first, then 7, then 6
    for level in [8, 7, 6]:
        query = f"""
        [out:json][timeout:10];
        is_in({lat},{lon})->.a;
        relation(pivot.a)["boundary"="administrative"]["admin_level"="{level}"]["name"];
        out center;
        """
        
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
                                "admin_level": level
                            }
                            print(f"    ✅ Found: {result['name']} (OSM ID: {result['osm_id']}, level {level})")
                            return result
                        else:
                            # No results at this level, try next
                            break
            except Exception as e:
                print(f"    ⚠️ Failed on {endpoint}: {e}")
                await asyncio.sleep(0.3)
    
    print("    ❌ Could not determine user's city")
    return None


async def fetch_nearby_city_candidates(lat: float, lon: float) -> Tuple[List[Dict], bool]:
    """
    Fetch candidate neighboring cities from OSM. Returns UNFILTERED candidates.
    Filtering happens in city_service based on cached boundaries.
    
    Returns:
        Tuple of (candidates, is_boundary_sharing)
        - is_boundary_sharing: True if results came from boundary sharing (already precise)
                              False if from radius search (needs filtering)
    """
    print(f"🌐 Finding neighboring cities for ({lat:.4f}, {lon:.4f})")
    
    all_candidates = []
    seen_ids = set()
    found_level_8_boundary = False
    found_level_7_boundary = False
    
    # Try level 8 boundary sharing first - these are TRUE neighbors
    cities = await _fetch_neighbors_at_level(lat, lon, 8)
    if cities:
        found_level_8_boundary = True
        for c in cities:
            if c["osm_id"] not in seen_ids:
                c["source"] = "boundary"
                all_candidates.append(c)
                seen_ids.add(c["osm_id"])
        # Level 8 boundary sharing = DONE, we have precise neighbors
        all_candidates.sort(key=lambda c: c.get("distance", 0))
        print(f"    ✅ Found {len(all_candidates)} level 8 boundary neighbors (precise)")
        return all_candidates, True
    
    # Try level 7 boundary sharing (boroughs like Manhattan)
    cities = await _fetch_neighbors_at_level(lat, lon, 7)
    if cities:
        found_level_7_boundary = True
        for c in cities:
            if c["osm_id"] not in seen_ids:
                c["source"] = "boundary"
                all_candidates.append(c)
                seen_ids.add(c["osm_id"])
        
        # Level 7 found - also do radius search for cross-state level 8 cities (like NJ for Manhattan)
        print(f"    🔍 Level 7 area, checking radius for cross-boundary level 8 cities...")
        radius_cities = await _fetch_cities_in_radius(lat, lon, level=8, radius_km=15)
        for c in radius_cities:
            if c["osm_id"] not in seen_ids:
                c["source"] = "radius"
                all_candidates.append(c)
                seen_ids.add(c["osm_id"])
        
        all_candidates.sort(key=lambda c: c.get("distance", 0))
        boundary_count = sum(1 for c in all_candidates if c.get('source')=='boundary')
        radius_count = sum(1 for c in all_candidates if c.get('source')=='radius')
        print(f"    ✅ Found {len(all_candidates)} total candidates ({boundary_count} boundary, {radius_count} radius)")
        return all_candidates, True
    
    # No boundary sharing results (level 6 area like SF) - use radius search only
    print(f"    🔍 No boundary neighbors, using radius search...")
    
    # Level 8 radius search
    radius_cities = await _fetch_cities_in_radius(lat, lon, level=8, radius_km=20)
    for c in radius_cities:
        if c["osm_id"] not in seen_ids:
            c["source"] = "radius"
            all_candidates.append(c)
            seen_ids.add(c["osm_id"])
    
    # Level 7 radius search as fallback
    if not all_candidates:
        radius_cities = await _fetch_cities_in_radius(lat, lon, level=7, radius_km=20)
        for c in radius_cities:
            if c["osm_id"] not in seen_ids:
                c["source"] = "radius"
                all_candidates.append(c)
                seen_ids.add(c["osm_id"])
    
    if all_candidates:
        all_candidates.sort(key=lambda c: c.get("distance", 0))
        print(f"    ✅ Found {len(all_candidates)} radius candidates")
        return all_candidates, False
    
    print("    ❌ Could not fetch neighboring cities")
    return [], False


# Keep old name for backwards compatibility
async def fetch_nearby_city_ids(lat: float, lon: float, current_city_boundary: Optional[List[Tuple[float, float]]] = None) -> List[Dict]:
    """Deprecated: use fetch_nearby_city_candidates instead."""
    candidates, _ = await fetch_nearby_city_candidates(lat, lon)
    return candidates


async def _fetch_neighbors_at_level(lat: float, lon: float, level: int) -> List[Dict]:
    """Fetch neighbors at a specific admin level using boundary sharing."""
    query = f"""
    [out:json][timeout:10];
    
    // Step 1: What city is the user in?
    is_in({lat},{lon})->.a;
    relation(pivot.a)["boundary"="administrative"]["admin_level"="{level}"]->.current;
    
    // Step 2: Get the ways that form this city's boundary
    way(r.current)->.boundary_ways;
    
    // Step 3: Find ALL cities that share these boundary ways (= neighbors)
    relation(bw.boundary_ways)["boundary"="administrative"]["admin_level"="{level}"]["name"];
    
    // Output with center points
    out center;
    """
    
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
                
                if not elements:
                    return []
                
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
                        "admin_level": level,
                        "distance": distance,
                        "osm_tags": tags
                    })
                
                if cities:
                    print(f"    ✅ Found {len(cities)} neighbors (level {level}) from {endpoint}")
                    return cities
                
        except Exception as e:
            print(f"    ⚠️ {endpoint}: {e}")
    
    return []


async def _fetch_cities_in_radius(lat: float, lon: float, level: int, radius_km: float) -> List[Dict]:
    """Fetch cities of a specific level within a radius (for supplementing level 6 results)."""
    # Calculate bounding box
    lat_delta = radius_km / 111.0
    lon_delta = radius_km / (111.0 * max(0.1, math.cos(math.radians(lat))))
    
    south = lat - lat_delta
    north = lat + lat_delta
    west = lon - lon_delta
    east = lon + lon_delta
    
    print(f"    📍 Radius search: level {level}, {radius_km}km, bbox=({south:.3f},{west:.3f}) to ({north:.3f},{east:.3f})")
    
    query = f"""
    [out:json][timeout:15][bbox:{south},{west},{north},{east}];
    relation["boundary"="administrative"]["admin_level"="{level}"]["name"];
    out center;
    """
    
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(
                    endpoint,
                    data={"data": query},
                    headers={"User-Agent": "KingdomApp/1.0"}
                )
                
                if response.status_code != 200:
                    print(f"    ⚠️ {endpoint}: HTTP {response.status_code}")
                    continue
                
                data = response.json()
                elements = data.get("elements", [])
                print(f"    📦 Got {len(elements)} elements from {endpoint}")
                
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
                    
                    # Only include cities within the radius
                    if distance <= radius_km * 1000:
                        cities.append({
                            "osm_id": str(element.get("id")),
                            "name": tags.get("name"),
                            "center_lat": center.get("lat"),
                            "center_lon": center.get("lon"),
                            "admin_level": level,
                            "distance": distance,
                            "osm_tags": tags
                        })
                
                if cities:
                    print(f"    ✅ Found {len(cities)} cities (level {level}) within {radius_km}km")
                    return cities
                else:
                    print(f"    ⚠️ {len(elements)} elements but 0 passed filters")
                    return []  # Got response, just no results
                    
        except Exception as e:
            print(f"    ⚠️ {endpoint}: {e}")
    
    print(f"    ❌ All endpoints failed for radius search")
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


def _find_connected_components(segments: List[List[Tuple[float, float]]], max_gap: float = 0.0001) -> List[List[int]]:
    """
    Find connected components among segments using Union-Find.
    Two segments are connected if any of their endpoints are within max_gap of each other.
    Returns list of components, each component is a list of segment indices.
    """
    n = len(segments)
    if n == 0:
        return []
    
    # Union-Find data structure
    parent = list(range(n))
    rank = [0] * n
    
    def find(x):
        if parent[x] != x:
            parent[x] = find(parent[x])  # Path compression
        return parent[x]
    
    def union(x, y):
        px, py = find(x), find(y)
        if px == py:
            return
        # Union by rank
        if rank[px] < rank[py]:
            px, py = py, px
        parent[py] = px
        if rank[px] == rank[py]:
            rank[px] += 1
    
    # Check all pairs of segments for connectivity
    for i in range(n):
        if not segments[i]:
            continue
        seg_i_start = segments[i][0]
        seg_i_end = segments[i][-1]
        
        for j in range(i + 1, n):
            if not segments[j]:
                continue
            seg_j_start = segments[j][0]
            seg_j_end = segments[j][-1]
            
            # Check all 4 endpoint combinations
            if (_coord_distance(seg_i_end, seg_j_start) <= max_gap or
                _coord_distance(seg_i_end, seg_j_end) <= max_gap or
                _coord_distance(seg_i_start, seg_j_start) <= max_gap or
                _coord_distance(seg_i_start, seg_j_end) <= max_gap):
                union(i, j)
    
    # Group segments by their root
    components: dict[int, List[int]] = {}
    for i in range(n):
        root = find(i)
        if root not in components:
            components[root] = []
        components[root].append(i)
    
    return list(components.values())


def _join_segments(segments: List[List[Tuple[float, float]]]) -> List[Tuple[float, float]]:
    """
    Join disconnected way segments into a complete boundary.
    Uses nearest-neighbor chaining: always pick the BEST connection, not just any.
    IMPROVED: Starts with the largest connected component to avoid orphaning the main boundary.
    """
    if not segments:
        return []
    if len(segments) == 1:
        return segments[0]
    
    n = len(segments)
    print(f"    🔗 Joining {n} segments using nearest-neighbor chain...")
    
    # Debug: show endpoint connectivity
    _debug_segment_connectivity(segments)
    
    # Find connected components and start with the largest one
    components = _find_connected_components(segments)
    
    if len(components) > 1:
        # Sort by total point count (largest first)
        components.sort(key=lambda comp: sum(len(segments[i]) for i in comp), reverse=True)
        largest_component = components[0]
        total_points_in_largest = sum(len(segments[i]) for i in largest_component)
        print(f"       📊 Found {len(components)} disconnected components, using largest with {len(largest_component)} segments ({total_points_in_largest} points)")
        
        # Start with the first segment of the largest component
        start_idx = largest_component[0]
    else:
        start_idx = 0
    
    # Build chain using nearest-neighbor algorithm
    # Each entry: (segment_index, is_reversed)
    chain: List[Tuple[int, bool]] = [(start_idx, False)]  # Start with chosen segment
    used = {start_idx}
    
    # Grow chain from both ends until all segments connected
    max_gap = 0.001  # ~100m max gap (tight tolerance)
    
    while len(used) < n:
        # Find best connection to either end of current chain
        best = _find_best_connection(segments, chain, used, max_gap)
        
        if best is None:
            # Increase tolerance and try again
            max_gap *= 2
            if max_gap > 0.02:  # ~2km absolute max
                print(f"       ⚠️ Stopping: remaining segments too far (gap > {max_gap:.4f})")
                break
            continue
        
        seg_idx, is_reversed, attach_to_end, dist = best
        used.add(seg_idx)
        
        if attach_to_end:
            chain.append((seg_idx, is_reversed))
        else:
            chain.insert(0, (seg_idx, is_reversed))
    
    # Build final result from chain
    result = _build_result_from_chain(segments, chain)
    
    connected_pct = len(used) / n * 100
    print(f"    🔗 Joined {len(used)}/{n} segments ({connected_pct:.0f}%) -> {len(result)} total points")
    
    if len(used) < n:
        print(f"    ⚠️ WARNING: {n - len(used)} segments could not be connected!")
        _debug_orphan_segments(segments, used, chain)
    
    return result


def _find_best_connection(
    segments: List[List[Tuple[float, float]]],
    chain: List[Tuple[int, bool]],
    used: set,
    max_gap: float
) -> Optional[Tuple[int, bool, bool, float]]:
    """
    Find the best segment to connect to the current chain.
    Returns: (segment_index, is_reversed, attach_to_end, distance) or None
    """
    # Get current chain endpoints
    first_seg_idx, first_reversed = chain[0]
    last_seg_idx, last_reversed = chain[-1]
    
    first_seg = segments[first_seg_idx]
    last_seg = segments[last_seg_idx]
    
    # Chain start point (where we'd prepend)
    chain_start = first_seg[-1] if first_reversed else first_seg[0]
    # Chain end point (where we'd append)
    chain_end = last_seg[0] if last_reversed else last_seg[-1]
    
    best_result = None
    best_dist = float('inf')
    
    for i, seg in enumerate(segments):
        if i in used or not seg:
            continue
        
        seg_start = seg[0]
        seg_end = seg[-1]
        
        # 4 possible connections:
        # 1. chain_end -> seg_start (append, normal)
        d1 = _coord_distance(chain_end, seg_start)
        if d1 < best_dist and d1 <= max_gap:
            best_dist = d1
            best_result = (i, False, True, d1)
        
        # 2. chain_end -> seg_end (append, reversed)
        d2 = _coord_distance(chain_end, seg_end)
        if d2 < best_dist and d2 <= max_gap:
            best_dist = d2
            best_result = (i, True, True, d2)
        
        # 3. seg_end -> chain_start (prepend, normal)
        d3 = _coord_distance(seg_end, chain_start)
        if d3 < best_dist and d3 <= max_gap:
            best_dist = d3
            best_result = (i, False, False, d3)
        
        # 4. seg_start -> chain_start (prepend, reversed)
        d4 = _coord_distance(seg_start, chain_start)
        if d4 < best_dist and d4 <= max_gap:
            best_dist = d4
            best_result = (i, True, False, d4)
    
    return best_result


def _build_result_from_chain(
    segments: List[List[Tuple[float, float]]],
    chain: List[Tuple[int, bool]]
) -> List[Tuple[float, float]]:
    """Build the final coordinate list from the ordered chain."""
    result = []
    
    for i, (seg_idx, is_reversed) in enumerate(chain):
        seg = segments[seg_idx]
        points = list(reversed(seg)) if is_reversed else seg
        
        if i == 0:
            result.extend(points)
        else:
            # Skip first point if it's very close to last result point (avoid duplicates)
            if result and _coord_distance(result[-1], points[0]) < 0.0001:
                result.extend(points[1:])
            else:
                result.extend(points)
    
    return result


def _debug_segment_connectivity(segments: List[List[Tuple[float, float]]]):
    """Print debug info about how segments connect."""
    n = len(segments)
    perfect_matches = 0
    
    for i, seg in enumerate(segments):
        if not seg:
            continue
        
        # Find what connects to this segment's end
        end = seg[-1]
        best_match = None
        best_dist = float('inf')
        
        for j, other in enumerate(segments):
            if i == j or not other:
                continue
            
            d_start = _coord_distance(end, other[0])
            d_end = _coord_distance(end, other[-1])
            
            if d_start < best_dist:
                best_dist = d_start
                best_match = (j, 'start', d_start)
            if d_end < best_dist:
                best_dist = d_end
                best_match = (j, 'end', d_end)
        
        if best_match and best_match[2] < 0.0001:
            perfect_matches += 1
    
    print(f"       📊 {perfect_matches}/{n} segments have perfect endpoint matches")


def _debug_orphan_segments(
    segments: List[List[Tuple[float, float]]],
    used: set,
    chain: List[Tuple[int, bool]]
):
    """Debug info about segments that couldn't be connected."""
    # Get chain endpoints
    first_seg_idx, first_reversed = chain[0]
    last_seg_idx, last_reversed = chain[-1]
    
    first_seg = segments[first_seg_idx]
    last_seg = segments[last_seg_idx]
    
    chain_start = first_seg[-1] if first_reversed else first_seg[0]
    chain_end = last_seg[0] if last_reversed else last_seg[-1]
    
    print(f"       Chain endpoints: start={chain_start}, end={chain_end}")
    
    for i, seg in enumerate(segments):
        if i in used or not seg:
            continue
        
        d_to_end = min(_coord_distance(chain_end, seg[0]), _coord_distance(chain_end, seg[-1]))
        d_to_start = min(_coord_distance(chain_start, seg[0]), _coord_distance(chain_start, seg[-1]))
        
        print(f"       Orphan {i}: {len(seg)} pts, dist to chain end={d_to_end:.6f}, start={d_to_start:.6f}")


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


def _distance_to_polygon_edge(lat: float, lon: float, polygon: List[Tuple[float, float]]) -> float:
    """
    Calculate minimum distance from a point to the nearest edge of a polygon (in meters).
    Uses point-to-segment distance for accuracy.
    """
    if not polygon or len(polygon) < 3:
        return float('inf')
    
    min_dist = float('inf')
    n = len(polygon)
    
    for i in range(n):
        # Get segment endpoints
        p1 = polygon[i]
        p2 = polygon[(i + 1) % n]
        
        # Calculate distance from point to this segment
        dist = _point_to_segment_distance(lat, lon, p1[0], p1[1], p2[0], p2[1])
        min_dist = min(min_dist, dist)
    
    return min_dist


def _point_to_segment_distance(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
    """
    Calculate distance from point (px, py) to line segment (x1,y1)-(x2,y2).
    Returns distance in meters.
    """
    # Vector from p1 to p2
    dx = x2 - x1
    dy = y2 - y1
    
    # If segment is a point
    if dx == 0 and dy == 0:
        return _distance_between(px, py, x1, y1)
    
    # Parameter t for closest point on line
    t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
    
    # Closest point on segment
    closest_x = x1 + t * dx
    closest_y = y1 + t * dy
    
    return _distance_between(px, py, closest_x, closest_y)


def _min_distance_between_polygons(poly_a: List[Tuple[float, float]], poly_b: List[Tuple[float, float]]) -> float:
    """
    Calculate minimum distance between two polygon boundaries (in meters).
    Checks distance from each vertex of poly_a to edges of poly_b.
    For true neighbors that share a border, this returns ~0.
    """
    if not poly_a or not poly_b:
        return float('inf')
    
    min_dist = float('inf')
    
    # Sample every Nth point for performance (polygons can have 500+ points)
    step = max(1, len(poly_a) // 50)  # Check ~50 points max
    
    for i in range(0, len(poly_a), step):
        point = poly_a[i]
        dist = _distance_to_polygon_edge(point[0], point[1], poly_b)
        min_dist = min(min_dist, dist)
        
        # Early exit if we find they touch
        if min_dist < 100:  # Within 100m = basically touching
            return min_dist
    
    return min_dist


def _coord_distance(c1: Tuple[float, float], c2: Tuple[float, float]) -> float:
    """Calculate Euclidean distance between two coordinates (for segment joining)"""
    lat_diff = c1[0] - c2[0]
    lon_diff = c1[1] - c2[1]
    return math.sqrt(lat_diff**2 + lon_diff**2)

