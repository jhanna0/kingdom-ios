"""
App Configuration Router

Provides version checking and maintenance mode functionality.
Clients should call this endpoint on startup to check:
- If their app version meets minimum requirements
- If the app is in maintenance mode
- TestFlight or App Store update URLs
"""

from fastapi import APIRouter, Query
from typing import Optional
import psycopg2
import os

router = APIRouter()


def get_db_connection():
    """Get raw psycopg2 connection for simple queries"""
    database_url = os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")
    return psycopg2.connect(database_url)


@router.get("/app-config")
async def get_app_config(
    platform: str = Query("ios", description="Platform: ios, android, or all"),
    app_version: Optional[str] = Query(None, description="Current app version"),
    build: Optional[str] = Query(None, description="Current build number"),
    schema_version: Optional[str] = Query(None, description="API schema version")
):
    """
    Get app configuration for version checking and maintenance mode.
    
    Returns:
        - maintenance: Whether the app is in maintenance mode
        - maintenance_message: Message to show during maintenance
        - min_version: Minimum required app version
        - testflight_url: URL to TestFlight or App Store for updates
    
    Example:
        GET /app-config?platform=ios&app_version=1.0.0&build=1
    """
    platform = platform.strip().lower()
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        query = """
            SELECT platform, min_version, maintenance, maintenance_message, link_url
            FROM app_config 
            WHERE LOWER(platform) = %s
        """
        cur.execute(query, (platform,))
        row = cur.fetchone()
        
        cur.close()
        conn.close()
        
        if row is None:
            # Return safe defaults if no config found
            return {
                "status": 200,
                "maintenance": False,
                "maintenance_message": "Kingdom: Territory is currently undergoing maintenance. Please check back later.",
                "min_version": "1.0.0",
                "link_url": "https://testflight.apple.com/join/4jxSyUmW",
                "testflight_url": "https://testflight.apple.com/join/4jxSyUmW",
                "platform": platform
            }
        
        platform_value, min_version, maintenance, maintenance_message, link_url = row
        
        return {
            "status": 200,
            "maintenance": bool(maintenance),
            "maintenance_message": maintenance_message,
            "min_version": min_version,
            "min_ios_version": min_version,  # Alias for compatibility
            "link_url": link_url,
            "testflight_url": link_url,  # Alias for compatibility
            "update_url": link_url,  # Alias for compatibility
            "platform": platform_value
        }
        
    except Exception as e:
        return {
            "status": 500,
            "error": f"Failed to fetch app config: {str(e)}",
            "maintenance": False,
            "min_version": "1.0.0",
            "link_url": "https://testflight.apple.com/join/4jxSyUmW"
        }

