"""
Kingdom Game API - Main application setup
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from db import init_db
from routers import cities, game, auth, player, contracts, notifications, actions, intelligence, coups, invasions
from routers import property as property_router
import config  # Import to trigger dev mode message


# Create FastAPI app
app = FastAPI(
    title="Kingdom Game API",
    description="Backend API for Kingdom iOS app",
    version="1.0.0"
)


# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    init_db()
    print("🚀 Kingdom API started")
    print("🔐 Authentication: /auth/apple-signin")
    print("📍 City boundaries: /cities")
    print("🎮 Game endpoints: /my-kingdoms, /kingdoms, /checkin")
    print("👤 Player state: /player/state, /player/sync")
    print("📜 Contracts: /contracts")
    print("🏠 Properties: /properties")
    print("⚔️  Coups: /coups")
    print("🏴 Invasions: /invasions")


# Enable CORS so iOS app can connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routers
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
