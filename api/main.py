"""
Kingdom Game API - Main application setup
"""
import logging
import json
from datetime import datetime, date
from fastapi import FastAPI, Request, WebSocket, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from services.auth_service import decode_access_token


class ISO8601JSONEncoder(json.JSONEncoder):
    """Custom JSON encoder that formats datetimes with 'Z' suffix for iOS compatibility"""
    def default(self, obj):
        if isinstance(obj, datetime):
            # Strip microseconds - Swift's .iso8601 decoder can't parse them
            obj_no_micro = obj.replace(microsecond=0)
            iso_str = obj_no_micro.isoformat()
            if iso_str.endswith('+00:00'):
                return iso_str.replace('+00:00', 'Z')
            elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
                # Naive datetime - assume UTC and add Z
                return iso_str + 'Z'
            return iso_str
        elif isinstance(obj, date):
            return obj.isoformat()
        return super().default(obj)


class ISO8601JSONResponse(JSONResponse):
    """JSONResponse that uses our custom encoder for proper datetime formatting"""
    def render(self, content) -> bytes:
        return json.dumps(
            content,
            cls=ISO8601JSONEncoder,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
        ).encode("utf-8")

from db import init_db, SessionLocal
from routers import cities, game, auth, player, contracts, notifications, actions, intelligence, alliances, players, friends, activity, tiers, app_config, weather, market, resources, hunts, incidents, battles, tutorial, duels, trades, fishing, workshop, equipment, foraging, science, garden, feedback, achievements, empire, permits
from routers import property as property_router
import config  # Import to trigger dev mode message

# Local WebSocket support
from websocket.local_manager import local_manager

# Setup logging
logger = logging.getLogger("kingdom_api")
logging.basicConfig(level=logging.ERROR)

# Create FastAPI app with custom JSON encoder for iOS-compatible datetime formatting
app = FastAPI(
    title="Kingdom Game API",
    description="Backend API for Kingdom iOS app",
    version="1.0.0",
    default_response_class=ISO8601JSONResponse
)

# Routes that don't require authentication
PUBLIC_ROUTES = {
    "/auth/apple-signin",  # Sign in
    "/auth/health",        # Health check
    "/auth/client-log",    # Client debug logging (for sign-up debugging)
    "/auth/demo-login",    # Demo login for App Store review
    "/app-config",         # App config (version check)
    "/docs",               # Swagger docs (dev only)
    "/openapi.json",       # OpenAPI schema
    "/",                   # Root
}

# Prefixes that don't require auth (for path params)
PUBLIC_PREFIXES = [
    "/docs",
    "/redoc",
]

@app.middleware("http")
async def require_auth_middleware(request: Request, call_next):
    """
    SECURITY: Require authentication for ALL routes except explicit whitelist.
    This ensures no route is accidentally left unprotected.
    """
    path = request.url.path
    
    # Allow public routes
    if path in PUBLIC_ROUTES:
        return await call_next(request)
    
    # Allow public prefixes
    for prefix in PUBLIC_PREFIXES:
        if path.startswith(prefix):
            return await call_next(request)
    
    # All other routes require valid JWT
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return JSONResponse(
            status_code=401,
            content={"detail": "Authentication required"}
        )
    
    try:
        token = auth_header.split()[1]
        payload = decode_access_token(token)
        apple_user_id = payload.get("sub")
        if not apple_user_id:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid token"}
            )
        request.state.username = apple_user_id
    except:
        return JSONResponse(
            status_code=401,
            content={"detail": "Invalid or expired token"}
        )
    
    try:
        response = await call_next(request)
        return response
    except Exception as e:
        # Get the traceback to find the actual function where error occurred
        import traceback
        tb = traceback.extract_tb(e.__traceback__)
        
        # Find the last frame in /app/ (our code, not libraries)
        error_location = "unknown"
        for frame in reversed(tb):
            if "/app/" in frame.filename:
                filename = frame.filename.split("/app/")[-1]
                error_location = f"{filename}:{frame.name}() line {frame.lineno}"
                break
        
        # Clean, readable error log
        logger.error(
            f"❌ {request.method} {request.url.path}\n"
            f"   User: {request.state.username}\n"
            f"   Location: {error_location}\n"
            f"   Error: {type(e).__name__}: {str(e)}"
        )
        
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})


# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    try:
        init_db()
        
        # Sync items from RESOURCES to database (code is authoritative)
        from routers.resources import sync_items_to_db
        db = SessionLocal()
        try:
            sync_items_to_db(db)
        finally:
            db.close()
        
        print("🚀 Kingdom API started")
        print("📱 App Config: /app-config (version checking)")
        print("🔐 Authentication: /auth/apple-signin")
        print("📍 City boundaries: /cities")
        print("🎮 Game endpoints: /my-kingdoms, /kingdoms, /checkin")
        print("👤 Player state: /player/state, /player/sync")
        print("📜 Contracts: /contracts")
        print("🏠 Properties: /properties")
        print("⚔️  Coups: /coups (legacy)")
        print("🏴 Invasions: /invasions (legacy)")
        print("🗡️  Battles: /battles (unified coups + invasions)")
        print("🤝 Alliances: /alliances")
        print("👥 Players: /players")
        print("👫 Friends: /friends")
        print("📊 Activity: /activity")
        print("🎯 Tiers: /tiers (SINGLE SOURCE OF TRUTH)")
        print("💰 Market: /market (Grand Exchange - dynamic items)")
        print("📦 Resources: /resources (item definitions)")
        print("🏹 Hunts: /hunts (Group hunting)")
        print("🕵️ Incidents: /incidents (Covert operations)")
        print("📖 Tutorial: /tutorial (Help content)")
        print("🤝 Trades: /trades (Player-to-player trading)")
        print("🎣 Fishing: /fishing (Chill fishing minigame)")
        print("🌿 Foraging: /foraging (Scratch-ticket minigame)")
        print("🏰 Empire: /empire (Empire management & treasury)")
        print("🔌 WebSocket: /ws (Real-time updates)")
    except Exception as e:
        print(f"❌ Database initialization error: {e}")
        # Don't fail startup, tables might already exist

# Don't initialize DB during import - let it happen on first request
# This prevents cold start timeouts in Lambda VPC
# Tables should already exist in production anyway


# Enable CORS so iOS app can connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routers
app.include_router(app_config.router)  # No auth required - called on startup
app.include_router(auth.router)
app.include_router(cities.router)
app.include_router(game.router)
app.include_router(player.router)
app.include_router(contracts.router)
app.include_router(notifications.router)
app.include_router(actions.router)
app.include_router(property_router.router)
app.include_router(intelligence.router)
app.include_router(alliances.router)
app.include_router(players.router)
app.include_router(friends.router)
app.include_router(activity.router)
app.include_router(tiers.router)
app.include_router(resources.router)
app.include_router(weather.router)
app.include_router(market.router)
app.include_router(hunts.router)
app.include_router(incidents.router)
app.include_router(battles.router)  # Unified battle system (coups + invasions)
app.include_router(tutorial.router)  # Help/tutorial content
app.include_router(duels.router)  # PvP Arena duels in Town Hall
app.include_router(trades.router)  # Player-to-player trading (Merchant skill)
app.include_router(fishing.router)  # Chill fishing minigame
app.include_router(workshop.router)  # Blueprint-based crafting at Workshop (Property T3+)
app.include_router(equipment.router)  # View and equip weapons/armor
app.include_router(foraging.router)  # Foraging minigame - scratch ticket style
app.include_router(science.router)  # Science minigame - high/low guessing
app.include_router(garden.router)  # Personal garden - plant, water, harvest
app.include_router(feedback.router)  # In-app feedback submission
app.include_router(achievements.router)  # Achievement diary with tiered rewards
app.include_router(empire.router)  # Empire management (treasury, fund transfers)
app.include_router(permits.router)  # Building permits for visitors


# ===== WebSocket Endpoint (Local Development) =====
@app.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(default=None),
    kingdom_id: str = Query(default="none"),
):
    """
    WebSocket endpoint for real-time features (local dev only).
    
    Connect with:
        ws://192.168.1.13:8000/ws?token=<jwt>&kingdom_id=<id>
    
    Actions:
        - {"action": "subscribe", "kingdom_id": "123"}
        - {"action": "unsubscribe"}
        - {"action": "ping"}
        - {"action": "sendMessage", "message": "Hello!"}
    """
    await local_manager.handle_connection(websocket, token, kingdom_id)


@app.get("/ws/stats")
def websocket_stats():
    """Get WebSocket connection statistics (local dev debugging)."""
    return {
        "mode": "local",
        **local_manager.stats,
    }


# Health check
@app.get("/")
def root():
    """API health check"""
    return {
        "status": "online",
        "service": "Kingdom Game API",
        "version": "1.0.0"
    }


@app.get("/test/db")
def test_database():
    """Test database connectivity"""
    try:
        from db import get_db, CityBoundary
        db = next(get_db())
        # Try a simple query
        count = db.query(CityBoundary).count()
        return {
            "status": "connected",
            "database": "PostgreSQL",
            "cached_cities": count
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


# Lambda handler (for AWS Lambda deployment)
from mangum import Mangum
handler = Mangum(app, lifespan="off")
