"""
Kingdom Game API - Local Development Server
This is a minimal FastAPI server for testing with your iOS app.
Safe to delete this entire /api folder if not needed.
"""
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session
import os

# Import our modules
from database import get_db, init_db, CityBoundary
from osm_service import (
    fetch_cities_from_osm, 
    find_user_city_fast, 
    fetch_nearby_city_ids,
    fetch_city_boundary_by_id
)
import asyncio

app = FastAPI(
    title="Kingdom Game API",
    description="Local development API for Kingdom iOS app",
    version="1.0.0"
)

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    init_db()
    print("🚀 Kingdom API started")

# Enable CORS so your iOS app can connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple in-memory storage (will reset when server restarts)
# In production, this would use the PostgreSQL database
players_db = {}
kingdoms_db = {}

# Pydantic models for request/response validation
class Player(BaseModel):
    id: str
    name: str
    gold: int = 0
    level: int = 1
    created_at: Optional[datetime] = None

class Kingdom(BaseModel):
    id: str
    name: str
    ruler_id: str
    location: dict  # {latitude, longitude}
    population: int = 0
    level: int = 1

class CheckIn(BaseModel):
    player_id: str
    kingdom_id: str
    location: dict

class CityBoundaryResponse(BaseModel):
    osm_id: str
    name: str
    admin_level: int
    center_lat: float
    center_lon: float
    boundary: List[List[float]]  # List of [lat, lon] pairs
    radius_meters: float
    cached: bool = False  # True if from database, False if freshly fetched

# Health check endpoint
@app.get("/")
def root():
    return {
        "status": "online",
        "message": "Kingdom Game API is running",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "health": "/health",
            "docs": "/docs",
            "players": "/players",
            "kingdoms": "/kingdoms"
        }
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

# Player endpoints
@app.post("/players", response_model=Player)
def create_player(player: Player):
    if player.id in players_db:
        raise HTTPException(status_code=400, detail="Player already exists")
    
    player.created_at = datetime.now()
    players_db[player.id] = player
    return player

@app.get("/players/{player_id}", response_model=Player)
def get_player(player_id: str):
    if player_id not in players_db:
        raise HTTPException(status_code=404, detail="Player not found")
    return players_db[player_id]

@app.get("/players", response_model=List[Player])
def list_players():
    return list(players_db.values())

@app.put("/players/{player_id}", response_model=Player)
def update_player(player_id: str, player: Player):
    if player_id not in players_db:
        raise HTTPException(status_code=404, detail="Player not found")
    players_db[player_id] = player
    return player

# Kingdom endpoints
@app.post("/kingdoms", response_model=Kingdom)
def create_kingdom(kingdom: Kingdom):
    if kingdom.id in kingdoms_db:
        raise HTTPException(status_code=400, detail="Kingdom already exists")
    kingdoms_db[kingdom.id] = kingdom
    return kingdom

@app.get("/kingdoms/{kingdom_id}", response_model=Kingdom)
def get_kingdom(kingdom_id: str):
    if kingdom_id not in kingdoms_db:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    return kingdoms_db[kingdom_id]

@app.get("/kingdoms", response_model=List[Kingdom])
def list_kingdoms():
    return list(kingdoms_db.values())

# Check-in endpoint (for location-based gameplay)
@app.post("/checkin")
def check_in(checkin: CheckIn):
    player = players_db.get(checkin.player_id)
    kingdom = kingdoms_db.get(checkin.kingdom_id)
    
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    return {
        "success": True,
        "message": f"{player.name} checked in to {kingdom.name}",
        "rewards": {
            "gold": 10,
            "experience": 5
        }
    }

# Test endpoint to see database connection
@app.get("/test/db")
def test_database(db: Session = Depends(get_db)):
    """Test if PostgreSQL is accessible"""
    db_url = os.getenv("DATABASE_URL", "Not configured")
    
    # Try to query database
    try:
        city_count = db.query(CityBoundary).count()
        return {
            "database_configured": "DATABASE_URL" in os.environ,
            "database_url": db_url.replace(":admin@", ":****@") if "@" in db_url else db_url,
            "connection_success": True,
            "cities_in_database": city_count
        }
    except Exception as e:
        return {
            "database_configured": "DATABASE_URL" in os.environ,
            "database_url": db_url.replace(":admin@", ":****@") if "@" in db_url else db_url,
            "connection_success": False,
            "error": str(e)
        }

# MARK: - City Boundary Endpoints

@app.get("/cities", response_model=List[CityBoundaryResponse])
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
    print(f"🔍 City lookup request: lat={lat}, lon={lon}, radius={radius}km")
    
    # STEP 1: Check database for cities we already have nearby
    print(f"💾 Checking database for cached cities...")
    all_cached = db.query(CityBoundary).all()
    
    nearby_cached = []
    for city in all_cached:
        distance = _calculate_distance(lat, lon, city.center_lat, city.center_lon)
        if distance <= radius * 1000:
            nearby_cached.append((city, distance))
    
    nearby_cached.sort(key=lambda x: x[1])
    
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
        osm_cities = await fetch_cities_from_osm(lat, lon, radius, admin_levels="8")
        
        if not osm_cities:
            raise HTTPException(status_code=404, detail="No cities found in this area")
        
        # Process as before
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
    
    # STEP 3: Process city IDs - fetch boundaries only for cities we don't have
    print(f"📦 Processing {len(city_ids)} cities...")
    result_cities = []
    cached_count = 0
    new_count = 0
    
    for city_info in city_ids[:35]:  # Limit to 35 closest
        osm_id = city_info["osm_id"]
        
        # Check if we already have this city
        existing = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
        
        if existing:
            # Use cached boundary (FAST!)
            existing.access_count += 1
            existing.last_accessed = datetime.utcnow()
            result_cities.append(existing)
            cached_count += 1
            print(f"    ✅ Cached: {existing.name}")
        else:
            # Fetch ACCURATE boundary for this specific city
            print(f"    🌐 New city: {city_info['name']}")
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
    
    print(f"✅ Returning {len(result_cities)} cities ({cached_count} cached, {new_count} newly fetched with accurate boundaries)")
    
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


@app.get("/cities/{osm_id}", response_model=CityBoundaryResponse)
async def get_city_by_id(osm_id: str, db: Session = Depends(get_db)):
    """
    Get a specific city boundary by its OSM ID
    
    Parameters:
    - osm_id: OpenStreetMap relation ID
    
    Returns:
    - City boundary with coordinates
    """
    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if not city:
        raise HTTPException(status_code=404, detail=f"City with OSM ID {osm_id} not found")
    
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


@app.get("/cities/stats")
async def get_city_stats(db: Session = Depends(get_db)):
    """Get statistics about cached cities"""
    total_cities = db.query(CityBoundary).count()
    
    if total_cities == 0:
        return {
            "total_cities": 0,
            "message": "No cities cached yet"
        }
    
    # Get most accessed cities
    top_cities = db.query(CityBoundary).order_by(
        CityBoundary.access_count.desc()
    ).limit(10).all()
    
    return {
        "total_cities": total_cities,
        "top_cities": [
            {
                "name": city.name,
                "access_count": city.access_count,
                "last_accessed": city.last_accessed.isoformat()
            }
            for city in top_cities
        ]
    }


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in meters (Haversine formula)"""
    import math
    
    R = 6371000  # Earth's radius in meters
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

