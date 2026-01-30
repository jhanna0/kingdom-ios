"""
Weather Service - Real-time weather data integration
Fetches weather from OpenWeather API and applies game modifiers
"""
import httpx
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple
from sqlalchemy.orm import Session
import os

from db.models import Kingdom
from db.models.city_boundary import CityBoundary


# Weather API Configuration
# Using Open-Meteo - 100% FREE, no API key needed!
WEATHER_CACHE_MINUTES = 60  # Cache weather data for 1 hour per city


class WeatherCondition:
    """Weather condition types and their game effects"""
    CLEAR = "clear"
    RAIN = "rain"
    SNOW = "snow"
    THUNDERSTORM = "thunderstorm"
    FOG = "fog"
    CLOUDS = "clouds"
    EXTREME = "extreme"  # Tornado, hurricane, etc.


# ===== WEATHER EFFECTS ON GAME ACTIONS =====
# Each weather type provides buffs/debuffs as multipliers
# 1.0 = no change, 1.2 = +20%, 0.8 = -20%

WEATHER_EFFECTS = {
    WeatherCondition.CLEAR: {
        "farming_gold": 1.15,  # +15% farming gold (sunny crops)
        "patrol_effectiveness": 1.10,  # +10% patrol
        "scouting_success": 1.05,  # +5% scouting (good visibility)
        "description": "Clear skies and sunshine",
        "flavor_text": "Perfect weather for outdoor work!"
    },
    
    WeatherCondition.RAIN: {
        "farming_gold": 0.80,  # -20% farming (muddy fields)
        "vault_heist_success": 1.10,  # +10% heist (guards distracted)
        "scouting_success": 0.90,  # -10% scouting (poor visibility)
        "contract_work_speed": 0.90,  # -10% work speed (wet conditions)
        "description": "Rain showers",
        "flavor_text": "The rain makes outdoor work difficult."
    },
    
    WeatherCondition.SNOW: {
        "farming_gold": 0.60,  # -40% farming (frozen ground)
        "training_effectiveness": 1.25,  # +25% indoor training (everyone inside)
        "vault_defense": 1.30,  # +30% vault defense (tracks in snow)
        "contract_work_speed": 0.85,  # -15% work speed (cold)
        "travel_fee": 1.50,  # +50% travel fee (dangerous roads)
        "description": "Snow falling",
        "flavor_text": "Crops grow slower in the cold. All natural resource yields are reduced."
    },
    
    WeatherCondition.THUNDERSTORM: {
        "farming_gold": 0.70,  # -30% farming (dangerous)
        "scouting_success": 0.60,  # -40% scouting (too dangerous)
        "sabotage_success": 1.50,  # +50% sabotage (chaos & confusion)
        "contract_work_speed": 0.80,  # -20% work (unsafe)
        "patrol_effectiveness": 0.70,  # -30% patrol (guards take cover)
        "coup_success": 1.15,  # +15% coup (chaos helps attackers)
        "description": "Thunderstorm raging",
        "flavor_text": "Lightning crashes! Chaos reigns!"
    },
    
    WeatherCondition.FOG: {
        "scouting_success": 1.40,  # +40% scouting (stealth bonus)
        "vault_heist_success": 1.40,  # +40% heist (can't be seen)
        "patrol_effectiveness": 0.70,  # -30% patrol (can't see)
        "coup_success": 1.20,  # +20% coup (surprise attack)
        "sabotage_success": 1.30,  # +30% sabotage (stealth)
        "description": "Thick fog",
        "flavor_text": "You can barely see your hand in front of you."
    },
    
    WeatherCondition.CLOUDS: {
        "farming_gold": 1.05,  # +5% farming (good for crops, not too hot)
        "description": "Overcast skies",
        "flavor_text": "Cloudy but comfortable weather."
    },
    
    WeatherCondition.EXTREME: {
        "farming_gold": 0.0,  # Cannot farm
        "patrol_effectiveness": 0.50,  # -50% patrol (emergency mode)
        "contract_work_speed": 0.50,  # -50% work (emergency)
        "kingdom_damage": 100,  # Kingdom takes damage (gold cost to repair)
        "description": "EXTREME WEATHER WARNING",
        "flavor_text": "Seek shelter immediately! All outdoor activities halted!"
    }
}


async def get_weather_for_kingdom(
    db: Session,
    kingdom_id: str,
    force_refresh: bool = False
) -> Optional[dict]:
    """
    Get current weather for a kingdom
    
    Weather is cached in the database (city_boundaries table) for 1 hour per city.
    
    Returns:
        {
            "condition": "rain",
            "temperature": 15.5,
            "description": "light rain",
            "icon": "10d",
            "effects": {
                "farming_gold": 0.8,
                ...
            },
            "flavor_text": "The rain makes outdoor work difficult.",
            "cached_at": "2024-01-04T10:30:00Z"
        }
    """
    
    # Get kingdom to find coordinates
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom or not kingdom.city_boundary_osm_id:
        return None
    
    # Get city boundary for coordinates AND cached weather
    city = db.query(CityBoundary).filter(
        CityBoundary.osm_id == kingdom.city_boundary_osm_id
    ).first()
    
    if not city:
        return None
    
    # Check DB cache first (unless force refresh)
    if not force_refresh and city.weather_data and city.weather_cached_at:
        age = datetime.utcnow() - city.weather_cached_at
        
        if age < timedelta(minutes=WEATHER_CACHE_MINUTES):
            # Return cached weather from DB
            return city.weather_data
    
    # Cache expired or missing - fetch fresh weather from API
    weather_data = await fetch_weather_from_api(city.center_lat, city.center_lon)
    
    if weather_data:
        # Only cache REAL weather data (not fallback)
        if not weather_data.get("is_fallback"):
            city.weather_data = weather_data
            city.weather_cached_at = datetime.utcnow()
            db.commit()
    
    return weather_data


async def fetch_weather_from_api(lat: float, lon: float) -> Optional[dict]:
    """
    Fetch weather from Open-Meteo API
    
    Open-Meteo is COMPLETELY FREE, no API key needed!
    API docs: https://open-meteo.com/en/docs
    """
    
    try:
        # Open-Meteo - FREE FOREVER, no limits, no API key!
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": "temperature_2m,weather_code",
            "temperature_unit": "celsius"
        }
        
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url, params=params)
            
            if response.status_code != 200:
                print(f"❌ Open-Meteo API error: {response.status_code}")
                return _get_default_weather()
            
            data = response.json()
            
            # Parse Open-Meteo response
            return _parse_open_meteo_response(data)
            
    except Exception as e:
        print(f"❌ Error fetching weather: {e}")
        return _get_default_weather()


def _parse_open_meteo_response(data: dict) -> dict:
    """
    Parse Open-Meteo API response into game weather data
    
    Open-Meteo weather codes: https://open-meteo.com/en/docs
    WMO Weather interpretation codes (WW):
    0: Clear sky
    1-3: Mainly clear, partly cloudy, overcast
    45, 48: Fog
    51-67: Rain (various intensities)
    71-77: Snow
    80-82: Rain showers
    85-86: Snow showers
    95-99: Thunderstorm
    """
    
    # Get weather code and temperature
    weather_code = data["current"]["weather_code"]
    temp = data["current"]["temperature_2m"]
    
    # Map Open-Meteo code to game condition
    condition = _map_open_meteo_condition(weather_code)
    
    # OVERRIDE: If it's freezing cold, treat as snow weather regardless of code!
    if temp <= 0:  # 0°C = 32°F
        condition = WeatherCondition.SNOW
    
    # Get human-readable description
    weather_desc = _get_weather_description(weather_code)
    
    # Get effects for this condition
    effects = WEATHER_EFFECTS.get(condition, {})
    
    return {
        "condition": condition,
        "temperature": temp,
        "temperature_f": temp * 9/5 + 32,  # Also provide Fahrenheit
        "description": weather_desc,
        "icon": _get_weather_icon(condition),
        "effects": {k: v for k, v in effects.items() if k not in ["description", "flavor_text"]},
        "display_description": effects.get("description", ""),
        "flavor_text": effects.get("flavor_text", ""),
        "cached_at": datetime.utcnow().isoformat() + "Z"
    }


def _map_open_meteo_condition(code: int) -> str:
    """Map Open-Meteo WMO codes to game conditions"""
    
    if code == 0:
        return WeatherCondition.CLEAR
    elif 1 <= code <= 3:
        return WeatherCondition.CLOUDS
    elif code in [45, 48]:
        return WeatherCondition.FOG
    elif 51 <= code <= 67 or 80 <= code <= 82:
        return WeatherCondition.RAIN
    elif 71 <= code <= 77 or 85 <= code <= 86:
        return WeatherCondition.SNOW
    elif 95 <= code <= 99:
        return WeatherCondition.THUNDERSTORM
    else:
        return WeatherCondition.CLEAR


def _get_weather_description(code: int) -> str:
    """Get human-readable weather description"""
    descriptions = {
        0: "clear sky",
        1: "mainly clear",
        2: "partly cloudy",
        3: "overcast",
        45: "foggy",
        48: "depositing rime fog",
        51: "light drizzle",
        53: "moderate drizzle",
        55: "dense drizzle",
        61: "slight rain",
        63: "moderate rain",
        65: "heavy rain",
        71: "slight snow",
        73: "moderate snow",
        75: "heavy snow",
        80: "slight rain showers",
        81: "moderate rain showers",
        82: "violent rain showers",
        85: "slight snow showers",
        86: "heavy snow showers",
        95: "thunderstorm",
        96: "thunderstorm with slight hail",
        99: "thunderstorm with heavy hail"
    }
    return descriptions.get(code, "unknown")


def _get_weather_icon(condition: str) -> str:
    """Get weather icon code"""
    icons = {
        WeatherCondition.CLEAR: "01d",
        WeatherCondition.CLOUDS: "02d",
        WeatherCondition.FOG: "50d",
        WeatherCondition.RAIN: "10d",
        WeatherCondition.SNOW: "13d",
        WeatherCondition.THUNDERSTORM: "11d",
        WeatherCondition.EXTREME: "11d"
    }
    return icons.get(condition, "01d")


def _get_default_weather() -> dict:
    """Default clear weather for development/fallback - NOT CACHED"""
    effects = WEATHER_EFFECTS[WeatherCondition.CLEAR]
    
    return {
        "condition": WeatherCondition.CLEAR,
        "temperature": 20.0,
        "temperature_f": 68.0,
        "description": "clear sky",
        "icon": "01d",
        "effects": {k: v for k, v in effects.items() if k not in ["description", "flavor_text"]},
        "display_description": effects.get("description", ""),
        "flavor_text": effects.get("flavor_text", ""),
        "cached_at": datetime.utcnow().isoformat() + "Z",
        "is_fallback": True  # Mark as fallback - DO NOT CACHE
    }


def get_weather_modifier(weather_data: Optional[dict], modifier_key: str) -> float:
    """
    Get a specific weather modifier value
    
    Args:
        weather_data: Weather data dict from get_weather_for_kingdom
        modifier_key: Key like "farming_gold", "patrol_effectiveness", etc.
    
    Returns:
        Multiplier value (1.0 = no change)
    """
    if not weather_data or "effects" not in weather_data:
        return 1.0
    
    return weather_data["effects"].get(modifier_key, 1.0)


def apply_weather_to_gold_reward(base_gold: int, weather_data: Optional[dict], action_type: str) -> Tuple[int, float]:
    """
    Apply weather modifier to a gold reward
    
    Args:
        base_gold: Base gold amount
        weather_data: Weather data from get_weather_for_kingdom
        action_type: "farming", "patrol", etc.
    
    Returns:
        (modified_gold, multiplier_used)
    """
    modifier_key = f"{action_type}_gold"
    multiplier = get_weather_modifier(weather_data, modifier_key)
    
    modified_gold = int(base_gold * multiplier)
    
    return modified_gold, multiplier


def get_weather_flavor_message(weather_data: Optional[dict], action_success: bool) -> str:
    """
    Get a flavor message about weather effects on an action
    
    Returns:
        String like "The sunshine boosts your farming!" or "The rain hinders your work."
    """
    if not weather_data:
        return ""
    
    condition = weather_data.get("condition", "clear")
    
    # Different messages based on condition and success
    messages = {
        WeatherCondition.CLEAR: [
            "The sunshine energizes your work!",
            "Perfect weather for getting things done!",
            "The clear skies make everything easier."
        ],
        WeatherCondition.RAIN: [
            "You work through the rain.",
            "The wet conditions slow you down.",
            "Rain patters on your shoulders as you work."
        ],
        WeatherCondition.SNOW: [
            "The cold numbs your fingers.",
            "You shiver as you work in the snow.",
            "Snowflakes fall around you."
        ],
        WeatherCondition.THUNDERSTORM: [
            "Thunder crashes overhead!",
            "The storm makes this difficult and dangerous!",
            "Lightning illuminates your work."
        ],
        WeatherCondition.FOG: [
            "The fog conceals your movements.",
            "You can barely see in this thick mist.",
            "The fog provides cover."
        ],
        WeatherCondition.CLOUDS: [
            "The clouds keep the sun at bay.",
            "Comfortable weather for working."
        ]
    }
    
    condition_messages = messages.get(condition, [""])
    
    # Return first message (can randomize later)
    return condition_messages[0] if condition_messages else ""

