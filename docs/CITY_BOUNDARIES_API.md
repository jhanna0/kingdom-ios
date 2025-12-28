# City Boundaries API - Optimized & Accurate

## Overview

The city boundaries API provides **accurate city boundaries** from OpenStreetMap while being **smart about performance**.

## The Problem We Solved

Original implementation was slow because:
- Fetching `out geom;` for 30+ cities at once = HUGE data transfer
- Every request hit OSM, even for previously-seen cities
- Querying multiple admin levels (7,8,9,10) = more results = slower

## The Smart Solution

**Two-stage lookup that keeps accuracy but optimizes performance:**

### Stage 1: Fast Query (City IDs Only)
```
relation["boundary"="administrative"]["admin_level"="8"]["name"](around:30000,lat,lon);
out center;
```
- Returns just city IDs and center points (no geometry)
- Admin level 8 only = cities (not counties or neighborhoods)
- VERY fast (~1-2 seconds)

### Stage 2: Fetch Boundaries On-Demand
For each city we don't have cached:
```
relation(OSM_ID);
out geom;
```
- Fetches **accurate boundary** for ONE specific city
- Takes ~2-3 seconds per city
- But only needed once - then cached forever!

### Stage 3: Database Cache
- All boundaries stored in PostgreSQL
- Next time someone visits same area = **instant response** (no OSM call!)
- After a few days of use, most cities will be cached

## Performance Comparison

| Scenario | Old Method | New Method |
|----------|-----------|------------|
| First visit to NYC | ~25s (all cities) | ~8s (IDs + missing boundaries) |
| Second visit to NYC | ~25s (still fetches all) | ~0.1s (all cached!) |
| Visit nearby area | ~25s (fetches duplicates) | ~2s (only new cities) |

## API Endpoint

### GET `/cities`

**Parameters:**
- `lat`: Latitude of search center
- `lon`: Longitude of search center  
- `radius`: Search radius in kilometers (default: 30)

**Response:**
```json
[
  {
    "osm_id": "175905",
    "name": "New York City",
    "admin_level": 8,
    "center_lat": 40.7128,
    "center_lon": -74.0060,
    "boundary": [[lat, lon], [lat, lon], ...],
    "radius_meters": 15000.0,
    "cached": true
  }
]
```

**Response includes:**
- `cached`: `true` if from database, `false` if freshly fetched
- `boundary`: Array of `[lat, lon]` coordinate pairs (accurate boundaries!)
- Simplified to 25-150 points (maintains shape, reduces data size)

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Requests Cities                    │
│                    GET /cities?lat=X&lon=Y                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Step 1: Check Database Cache                    │
│                                                               │
│  Found 15+ cities nearby in DB?                              │
│    ✅ YES → Return immediately (0.1s) ────────────────────┐  │
│    ❌ NO → Continue to Step 2                            │  │
└────────────────────────┬────────────────────────────────┘  │
                         │                                   │
                         ▼                                   │
┌─────────────────────────────────────────────────────────┐  │
│         Step 2: Fast OSM Query (City IDs)                │  │
│                                                           │  │
│  Query: relation[admin_level=8](around:30km)             │  │
│  Returns: City IDs + center points (NO geometry)         │  │
│  Speed: ~1-2 seconds                                      │  │
└────────────────────────┬─────────────────────────────────┘  │
                         │                                   │
                         ▼                                   │
┌─────────────────────────────────────────────────────────┐  │
│    Step 3: Fetch Missing Boundaries (One at a Time)      │  │
│                                                           │  │
│  For each city ID:                                        │  │
│    • Already in DB? → Use cached (instant)                │  │
│    • Not in DB? → Fetch accurate boundary from OSM       │  │
│                   (2-3s per city, then cache forever)     │  │
│                                                           │  │
│  Rate limited: 0.5s delay between fetches                │  │
└────────────────────────┬─────────────────────────────────┘  │
                         │                                   │
                         ▼                                   │
                    ┌────────────────────────────────────┐   │
                    │    Return All Cities with          │   │
                    │    Accurate Boundaries             │◄──┘
                    └────────────────────────────────────┘
```

## Key Benefits

✅ **Accurate Boundaries** - Never compromised, always from OSM  
✅ **Fast Repeat Visits** - Cached cities return instantly  
✅ **Smart Caching** - Shares boundaries across all users  
✅ **Graceful Degradation** - Falls back to full fetch if fast query fails  
✅ **OSM-Friendly** - Rate limited, doesn't hammer their servers  

## Additional Endpoints

### GET `/cities/{osm_id}`
Get a specific city by OpenStreetMap ID.

### GET `/cities/stats`
View caching statistics (total cities cached, most accessed, etc.)

### GET `/test/db`
Test database connection and see how many cities are cached.

## Database Schema

```sql
CREATE TABLE city_boundaries (
    id SERIAL PRIMARY KEY,
    osm_id VARCHAR UNIQUE,
    name VARCHAR,
    admin_level INTEGER,
    center_lat DOUBLE PRECISION,
    center_lon DOUBLE PRECISION,
    boundary_geojson JSONB,          -- Accurate polygon coordinates
    radius_meters DOUBLE PRECISION,
    boundary_points_count INTEGER,
    access_count INTEGER,            -- How many times accessed
    last_accessed TIMESTAMP,
    created_at TIMESTAMP,
    osm_metadata JSONB
);
```

## Usage Example

### iOS/Swift
```swift
// First time in NYC - might take 8s (fetching missing boundaries)
let cities = try await api.getCities(lat: 40.7128, lon: -74.0060)

// Second time in NYC - takes 0.1s (all cached!)
let cities = try await api.getCities(lat: 40.7128, lon: -74.0060)

// Nearby location - takes 2s (only new cities fetched)
let cities = try await api.getCities(lat: 40.7500, lon: -73.9900)
```

### Python
```python
import httpx

async with httpx.AsyncClient() as client:
    response = await client.get(
        "http://localhost:8000/cities",
        params={"lat": 40.7128, "lon": -74.0060, "radius": 30}
    )
    cities = response.json()
    
    for city in cities:
        print(f"{city['name']}: {len(city['boundary'])} boundary points")
        print(f"  Cached: {city['cached']}")
```

## Monitoring

Watch the console output to see the optimization in action:

```
🔍 City lookup request: lat=40.7128, lon=-74.0060, radius=30.0km
💾 Checking database for cached cities...
✅ Found 23 cached cities - NO OSM CALL NEEDED!
✅ Returning 23 cities (23 cached, 0 newly fetched with accurate boundaries)
```

Or when fetching new cities:

```
🔍 City lookup request: lat=37.7749, lon=-122.4194, radius=30.0km
💾 Checking database for cached cities...
🌐 Fetching city IDs from OSM (fast query)...
    ✅ Found 28 cities from https://overpass-api.de/api/interpreter
📦 Processing 28 cities...
    ✅ Cached: San Francisco
    ✅ Cached: Oakland
    🌐 New city: Berkeley
        🌐 Fetching accurate boundary for: Berkeley (OSM 112259)
        ✅ Got accurate boundary: 87 points, radius: 8234m
        ✅ Saved with accurate boundary
    ✅ Cached: San Mateo
    ...
✅ Returning 28 cities (25 cached, 3 newly fetched with accurate boundaries)
```

## Future Optimizations

Possible improvements for even better performance:

1. **Spatial Indexing** - Add PostGIS for geographic queries
2. **Predictive Caching** - Pre-fetch boundaries for major cities
3. **Progressive Loading** - Return cached cities immediately, fetch new ones in background
4. **City Hierarchy** - Cache relationships between cities to avoid duplicate queries

## Notes

- Admin level 8 = cities (most relevant for gameplay)
- Boundaries simplified to 25-150 points (maintains accuracy, reduces size)
- OSM IDs are stable - perfect for caching
- Database is source of truth after first fetch
- All timestamps in UTC
