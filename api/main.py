"""
Kingdom Game API - Main application setup
"""
import logging
from fastapi import FastAPI, Request, WebSocket, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from services.auth_service import decode_access_token

from db import init_db, SessionLocal
from routers import cities, game, auth, player, contracts, notifications, actions, intelligence, coups, invasions, alliances, players, friends, activity, tiers, app_config, weather, market, resources, hunts
from routers import property as property_router
import config  # Import to trigger dev mode message

# Local WebSocket support
from websocket.local_manager import local_manager

# Setup logging
logger = logging.getLogger("kingdom_api")
logging.basicConfig(level=logging.ERROR)

# Create FastAPI app
app = FastAPI(
    title="Kingdom Game API",
    description="Backend API for Kingdom iOS app",
    version="1.0.0"
)

# Before request - extract username from JWT
@app.middleware("http")
async def extract_user_from_token(request: Request, call_next):
    """Extract username from JWT token before each request (like Flask's @app.before_request)"""
    request.state.username = "anonymous"
    
    try:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split()[1]
            payload = decode_access_token(token)
            apple_user_id = payload.get("sub")
            if apple_user_id:
                request.state.username = apple_user_id
    except:
        pass
    
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
        print("⚔️  Coups: /coups")
        print("🏴 Invasions: /invasions")
        print("🤝 Alliances: /alliances")
        print("👥 Players: /players")
        print("👫 Friends: /friends")
        print("📊 Activity: /activity")
        print("🎯 Tiers: /tiers (SINGLE SOURCE OF TRUTH)")
        print("💰 Market: /market (Grand Exchange - dynamic items)")
        print("📦 Resources: /resources (item definitions)")
        print("🏹 Hunts: /hunts (Group hunting)")
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
app.include_router(coups.router)
app.include_router(invasions.router)
app.include_router(alliances.router)
app.include_router(players.router)
app.include_router(friends.router)
app.include_router(activity.router)
app.include_router(tiers.router)
app.include_router(resources.router)
app.include_router(weather.router)
app.include_router(market.router)
app.include_router(hunts.router)


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
