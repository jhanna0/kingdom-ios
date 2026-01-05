"""
Weather endpoints - Real-time weather for kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import Optional

from db import get_db, User
from routers.auth import get_current_user
from services.weather_service import get_weather_for_kingdom


router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/kingdom/{kingdom_id}")
async def get_kingdom_weather(
    kingdom_id: str,
    force_refresh: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get current weather for a kingdom
    
    Query params:
        force_refresh: Force API call (skip cache)
    
    Returns:
        {
            "success": true,
            "weather": {
                "condition": "rain",
                "temperature": 15.5,
                "temperature_f": 59.9,
                "description": "light rain",
                "icon": "10d",
                "effects": {
                    "farming_gold": 0.8,
                    "wood_chopping": 1.2,
                    ...
                },
                "display_description": "🌧️ Rain showers",
                "flavor_text": "The rain makes outdoor work difficult.",
                "cached_at": "2024-01-04T10:30:00Z"
            }
        }
    """
    
    weather_data = await get_weather_for_kingdom(db, kingdom_id, force_refresh=force_refresh)
    
    if not weather_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found or no location data available"
        )
    
    return {
        "success": True,
        "weather": weather_data
    }


@router.get("/current")
async def get_current_weather(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get weather for player's current kingdom
    
    Returns weather data for the kingdom the player is currently checked into
    """
    state = current_user.player_state
    
    if not state or not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not currently in a kingdom. Check in to see weather."
        )
    
    weather_data = await get_weather_for_kingdom(db, state.current_kingdom_id)
    
    if not weather_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Weather data not available for current kingdom"
        )
    
    return {
        "success": True,
        "kingdom_id": state.current_kingdom_id,
        "weather": weather_data
    }



