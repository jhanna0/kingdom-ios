"""
Kingdom Game API - Main application setup
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db
from routers import cities, game, auth


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
        from database import get_db
        db = next(get_db())
        # Try a simple query
        from database import CityBoundary
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
