"""
Game endpoints - Kingdoms, check-ins, conquests
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
from typing import List
import uuid

from db import get_db, User, PlayerState, Kingdom, UserKingdom, CityBoundary
from db.models.kingdom_event import KingdomEvent
from schemas import CheckInRequest, CheckInResponse, CheckInRewards
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso
from config import DEV_MODE


router = APIRouter(tags=["game"])


# ===== Helper Functions =====

def _get_or_create_player_state(db: Session, user: User) -> PlayerState:
    """Get or create player state for user"""
    if not user.player_state:
        player_state = PlayerState(
            user_id=user.id,
            hometown_kingdom_id=None  # Will be set on first check-in
        )
        db.add(player_state)
        db.commit()
        db.refresh(player_state)
        return player_state
    return user.player_state


def _is_user_in_kingdom(db: Session, lat: float, lon: float, kingdom: Kingdom) -> bool:
    """
    Check if user's location is within kingdom boundaries
    TODO: Implement actual boundary checking using city_boundary_osm_id
    For now, just check if they're within 5km of kingdom center
    """
    if not kingdom.city_boundary_osm_id:
        return True  # Allow check-in if kingdom has no boundary set
    
    # Fetch city boundary to get center coordinates
    city_boundary = db.query(CityBoundary).filter(
        CityBoundary.osm_id == kingdom.city_boundary_osm_id
    ).first()
    
    if not city_boundary:
        return True  # Allow check-in if boundary data not found
    
    # Simple distance check using Haversine formula
    import math
    R = 6371  # Earth's radius in km
    
    lat1, lon1 = math.radians(lat), math.radians(lon)
    lat2, lon2 = math.radians(city_boundary.center_lat), math.radians(city_boundary.center_lon)
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    distance = R * c
    
    return distance <= 5.0  # Within 5km


def _get_or_create_user_kingdom(db: Session, user_id: int, kingdom_id: str) -> UserKingdom:
    """
    Get or create UserKingdom relationship
    
    SECURITY: user_id MUST come from authenticated current_user.id, NEVER from request data
    """
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == user_id,
        UserKingdom.kingdom_id == kingdom_id
    ).first()
    
    if not user_kingdom:
        user_kingdom = UserKingdom(
            user_id=user_id,
            kingdom_id=kingdom_id,
            first_visited=datetime.utcnow()
        )
        db.add(user_kingdom)
        db.commit()
        db.refresh(user_kingdom)
    
    return user_kingdom


# ===== Kingdom Endpoints =====

@router.get("/kingdoms")
def list_kingdoms(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """List all kingdoms"""
    kingdoms = db.query(Kingdom).offset(skip).limit(limit).all()
    return kingdoms


@router.get("/kingdoms/{kingdom_id}")
def get_kingdom(kingdom_id: str, db: Session = Depends(get_db)):
    """Get kingdom details with building upgrade costs"""
    from routers.contracts import calculate_actions_required, calculate_construction_cost
    from routers.tiers import BUILDING_TYPES
    from schemas.common import BUILDING_COLORS
    from db.models import PlayerState, UserKingdom
    from datetime import datetime, timedelta
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Get ruler name from User if kingdom has a ruler
    ruler_name = None
    if kingdom.ruler_id:
        ruler = db.query(User).filter(User.id == kingdom.ruler_id).first()
        if ruler:
            ruler_name = ruler.display_name
    
    # CALCULATE LIVE: Count players in kingdom RIGHT NOW
    checked_in_count = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == kingdom.id
    ).count()
    
    # CALCULATE LIVE: Count active citizens (alive citizens whose hometown is this kingdom)
    active_citizens_count = db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom.id,
        PlayerState.is_alive == True
    ).count()
    
    # DYNAMIC BUILDINGS - Build array from BUILDING_TYPES metadata with upgrade costs
    # Read from kingdom_buildings table (NEW WAY) with fallback to columns (OLD WAY)
    from db.models import KingdomBuilding
    
    # Load all buildings for this kingdom from the table
    kingdom_buildings_rows = db.query(KingdomBuilding).filter(
        KingdomBuilding.kingdom_id == kingdom.id
    ).all()
    building_levels_map = {b.building_type: b.level for b in kingdom_buildings_rows}
    
    buildings = []
    for building_type, building_meta in BUILDING_TYPES.items():
        # Try new table first, fallback to old column
        level = building_levels_map.get(building_type)
        if level is None:
            # Fallback to old column for backward compatibility
            level_attr = f"{building_type}_level"
            level = getattr(kingdom, level_attr, 0)
        
        # Calculate upgrade cost for next level (None if at max)
        max_level = building_meta["max_tier"]
        upgrade_cost = None
        if level < max_level:
            next_level = level + 1
            actions = calculate_actions_required(building_meta["display_name"], next_level, kingdom.population)
            construction_cost = calculate_construction_cost(next_level, kingdom.population)
            upgrade_cost = {
                "actions_required": actions,
                "construction_cost": construction_cost,
                "can_afford": kingdom.treasury_gold >= construction_cost
            }
        
        # Get current tier info
        tiers_data = building_meta.get("tiers", {})
        current_tier_data = tiers_data.get(level, tiers_data.get(1, {}))
        tier_name = current_tier_data.get("name", f"Level {level}")
        tier_benefit = current_tier_data.get("benefit", "")
        
        # Build all tiers info for detail view
        all_tiers = []
        for tier_num in range(1, max_level + 1):
            tier_data = tiers_data.get(tier_num, {})
            all_tiers.append({
                "tier": tier_num,
                "name": tier_data.get("name", f"Level {tier_num}"),
                "benefit": tier_data.get("benefit", ""),
                "description": tier_data.get("description", "")
            })
        
        # Get click action if defined (only clickable if level > 0)
        click_action = None
        click_action_meta = building_meta.get("click_action")
        if click_action_meta and level > 0:
            click_action = {
                "type": click_action_meta.get("type", ""),
                "resource": click_action_meta.get("resource")
            }
        
        buildings.append({
            "type": building_type,
            "display_name": building_meta["display_name"],
            "icon": building_meta["icon"],
            "color": BUILDING_COLORS.get(building_type, "#666666"),
            "category": building_meta["category"],
            "description": building_meta["description"],
            "level": level,
            "max_level": max_level,
            "upgrade_cost": upgrade_cost,
            "click_action": click_action,
            "tier_name": tier_name,
            "tier_benefit": tier_benefit,
            "all_tiers": all_tiers
        })
    
    # Return kingdom data - buildings array is the SINGLE SOURCE OF TRUTH
    # Frontend should iterate buildings array - no hardcoded building references!
    kingdom_dict = {
        "id": kingdom.id,
        "name": kingdom.name,
        "ruler_id": kingdom.ruler_id,
        "ruler_name": ruler_name,
        "city_boundary_osm_id": kingdom.city_boundary_osm_id,
        "population": kingdom.population,
        "level": kingdom.level,
        "treasury_gold": kingdom.treasury_gold,
        "checked_in_players": checked_in_count,  # LIVE COUNT
        "active_citizens": active_citizens_count,  # LIVE COUNT of citizens
        "buildings": buildings,  # DYNAMIC BUILDINGS with metadata + upgrade costs
        "tax_rate": kingdom.tax_rate,
        "travel_fee": kingdom.travel_fee,
        "subject_reward_rate": kingdom.subject_reward_rate,
        "total_income_collected": kingdom.total_income_collected,
        "total_rewards_distributed": kingdom.total_rewards_distributed,
        "allies": kingdom.allies or [],
        "enemies": kingdom.enemies or [],
        "created_at": kingdom.created_at,
        "updated_at": kingdom.updated_at
    }
    
    return kingdom_dict


@router.post("/kingdoms", status_code=status.HTTP_201_CREATED)
def create_kingdom(
    name: str,
    city_boundary_osm_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    DEPRECATED: Use /checkin instead - it auto-creates kingdoms
    
    Create a new kingdom / Claim an unclaimed city
    
    User automatically becomes the ruler of the new kingdom
    Coordinates are stored in the CityBoundary, not duplicated here
    
    RESTRICTIONS: 
    - Users can only claim a city for free if they don't currently rule any kingdoms.
    - Users must be INSIDE the kingdom to claim it.
    This prevents empire spam. Military conquest is required to expand once you rule a kingdom.
    """
    # Get player state
    state = _get_or_create_player_state(db, current_user)
    
    # Check if user is currently inside this kingdom
    if state.current_kingdom_id != city_boundary_osm_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be inside the kingdom to claim it. Travel there first."
        )
    
    # Check if this is the user's hometown - you can only claim your hometown
    if state.hometown_kingdom_id != city_boundary_osm_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can only claim your hometown as your kingdom. This is not your hometown."
        )
    
    # Check if user currently rules any kingdoms
    # Can only claim a free kingdom if you don't currently rule any
    current_kingdoms = db.query(Kingdom).filter(
        Kingdom.ruler_id == current_user.id
    ).count()
    
    if current_kingdoms > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already rule a kingdom. Use military conquest to expand your territory."
        )
    
    # Check if kingdom with this OSM ID already exists
    existing = db.query(Kingdom).filter(
        Kingdom.city_boundary_osm_id == city_boundary_osm_id
    ).first()
    
    if existing:
        # If kingdom exists but is unclaimed, claim it
        if existing.ruler_id is None:
            existing.ruler_id = current_user.id
            existing.last_activity = datetime.utcnow()
            
            # Reset empire status - this becomes a NEW independent empire
            # (Not tied to any previous empire the player ruled)
            existing.empire_id = existing.id
            existing.original_kingdom_id = existing.id
            
            # Get or create user-kingdom relationship (prevents duplicates)
            user_kingdom = _get_or_create_user_kingdom(db, current_user.id, existing.id)
            user_kingdom.times_conquered = (user_kingdom.times_conquered or 0) + 1
            
            # Update user stats - mark as claimed starting city
            state.has_claimed_starting_city = True
            
            db.commit()
            db.refresh(existing)
            
            return existing
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Kingdom already claimed by another player"
            )
    
    # Create kingdom - USE OSM ID as the kingdom ID for consistency with map
    # DEV MODE: Give starting treasury so you can actually create contracts
    starting_treasury = 10000 if DEV_MODE else 0
    
    kingdom = Kingdom(
        id=city_boundary_osm_id,  # Use OSM ID so map cities match kingdoms!
        name=name,
        city_boundary_osm_id=city_boundary_osm_id,
        ruler_id=current_user.id,
        empire_id=city_boundary_osm_id,  # New independent empire
        original_kingdom_id=city_boundary_osm_id,  # Original city identity
        population=1,
        level=1,
        treasury_gold=starting_treasury
    )
    
    db.add(kingdom)
    db.commit()
    db.refresh(kingdom)
    
    # Get or create user-kingdom relationship (prevents duplicates)
    user_kingdom = _get_or_create_user_kingdom(db, current_user.id, kingdom.id)
    user_kingdom.times_conquered = 1
    
    # Update user stats - mark as claimed starting city
    state.has_claimed_starting_city = True
    
    db.commit()
    
    return kingdom


# REMOVED: Manual check-in endpoint - Kingdom entry is automatic via /state endpoint


# ===== Conquest System =====

@router.post("/kingdoms/{kingdom_id}/conquer")
def conquer_kingdom(
    kingdom_id: str,
    latitude: float,
    longitude: float,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Attempt to conquer a kingdom
    
    Requirements:
    - Must be within kingdom boundaries
    - Must have sufficient level
    - Must have sufficient gold for conquest attempt
    """
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if user already rules this kingdom
    if kingdom.ruler_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already rule this kingdom"
        )
    
    # Get or create user-kingdom relationship for stats tracking
    user_kingdom = _get_or_create_user_kingdom(db, current_user.id, kingdom_id)
    
    # Verify location
    if not _is_user_in_kingdom(db, latitude, longitude, kingdom):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be within the kingdom boundaries to conquer it"
        )
    
    # Get player state
    state = _get_or_create_player_state(db, current_user)
    
    # Check level requirement
    min_level = kingdom.level
    if state.level < min_level:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You need to be at least level {min_level} to conquer this kingdom"
        )
    
    # Check gold cost
    conquest_cost = kingdom.level * 100
    if state.gold < conquest_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Conquest requires {conquest_cost} gold"
        )
    
    # Perform conquest
    old_ruler_id = kingdom.ruler_id
    
    # Remove old ruler
    if old_ruler_id:
        old_ruler = db.query(User).filter(User.id == old_ruler_id).first()
        if old_ruler:
            old_ruler_state = _get_or_create_player_state(db, old_ruler)
            old_ruler_state.kingdoms_ruled -= 1
            
            # Lose reputation in this kingdom
            old_ruler_user_kingdom = db.query(UserKingdom).filter(
                UserKingdom.user_id == old_ruler_id,
                UserKingdom.kingdom_id == kingdom.id
            ).first()
            if old_ruler_user_kingdom:
                old_ruler_user_kingdom.local_reputation -= 10
        
        # Note: No need to update old ruler's user_kingdom record
        # Kingdom.ruler_id being updated is sufficient
    
    # Set new ruler
    kingdom.ruler_id = current_user.id
    kingdom.last_activity = datetime.utcnow()
    
    # Update new ruler state
    state.gold -= conquest_cost
    state.kingdoms_ruled += 1
    state.total_conquests += 1
    state.experience += 100 * kingdom.level
    
    # Gain reputation in conquered kingdom
    new_ruler_user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.kingdom_id == kingdom.id
    ).first()
    if new_ruler_user_kingdom:
        new_ruler_user_kingdom.local_reputation += 20
    else:
        # Create new user_kingdom record
        new_ruler_user_kingdom = UserKingdom(
            user_id=current_user.id,
            kingdom_id=kingdom.id,
            local_reputation=20,
            checkins_count=0,
            gold_earned=0,
            gold_spent=0
        )
        db.add(new_ruler_user_kingdom)
    
    # Update user-kingdom stats
    user_kingdom.times_conquered += 1
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Successfully conquered {kingdom.name}!",
        "kingdom": {
            "id": kingdom.id,
            "name": kingdom.name,
            "level": kingdom.level,
            "population": kingdom.population
        },
        "rewards": {
            "experience": 100 * kingdom.level,
            "reputation": 20
        },
        "cost": conquest_cost
    }


# ===== User Kingdoms =====

@router.get("/my-kingdoms")
def get_my_kingdoms(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all kingdoms where current user is the ruler"""
    from db.models import KingdomHistory, PlayerState, UserKingdom
    from datetime import datetime, timedelta
    
    # Query kingdoms directly by ruler_id (source of truth)
    ruled_kingdoms = db.query(Kingdom).filter(
        Kingdom.ruler_id == current_user.id
    ).all()
    
    kingdoms = []
    for kingdom in ruled_kingdoms:
        # Get user-kingdom stats if they exist
        uk = db.query(UserKingdom).filter(
            UserKingdom.user_id == current_user.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        
        # Get current reign start time from kingdom_history
        history = db.query(KingdomHistory).filter(
            KingdomHistory.kingdom_id == kingdom.id,
            KingdomHistory.ruler_id == current_user.id,
            KingdomHistory.ended_at == None  # Current reign
        ).first()
        
        # CALCULATE LIVE: Count players in kingdom RIGHT NOW
        checked_in_count = db.query(PlayerState).filter(
            PlayerState.current_kingdom_id == kingdom.id
        ).count()
        
        kingdoms.append({
            "id": kingdom.id,
            "name": kingdom.name,
            "treasury_gold": kingdom.treasury_gold,
            "checked_in_players": checked_in_count  # LIVE COUNT
        })
    
    return kingdoms


# ===== Kingdom Management (Ruler Only) =====

@router.put("/kingdoms/{kingdom_id}/tax-rate")
def set_kingdom_tax_rate(
    kingdom_id: str,
    tax_rate: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Set tax rate for a kingdom (ruler only)"""
    # Validate tax rate
    if tax_rate < 0 or tax_rate > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tax rate must be between 0 and 100"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if user is the ruler
    if kingdom.ruler_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the ruler can change the tax rate"
        )
    
    # Store old rate for event logging
    old_rate = kingdom.tax_rate
    
    # Update tax rate
    kingdom.tax_rate = tax_rate
    kingdom.updated_at = datetime.utcnow()
    
    # Log tax change event for kingdom activity feed
    if old_rate != tax_rate:
        action = "raised" if tax_rate > old_rate else "lowered"
        tax_event = KingdomEvent(
            kingdom_id=kingdom.id,
            title=f"{current_user.display_name} {action} taxes",
            description=f"Tax rate changed to {tax_rate}%"
        )
        db.add(tax_event)
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Tax rate updated to {tax_rate}%",
        "kingdom_id": kingdom.id,
        "kingdom_name": kingdom.name,
        "tax_rate": tax_rate
    }


from pydantic import BaseModel

class DecreeRequest(BaseModel):
    text: str

@router.post("/kingdoms/{kingdom_id}/decree")
def make_decree(
    kingdom_id: str,
    request: DecreeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Make a royal decree (ruler only) - appears in kingdom activity feed"""
    decree_text = request.text.strip()
    
    # Validate decree text
    if not decree_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Decree text cannot be empty"
        )
    
    if len(decree_text) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Decree text cannot exceed 500 characters"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if user is the ruler
    if kingdom.ruler_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the ruler can make decrees"
        )
    
    # Create decree event
    decree = KingdomEvent(
        kingdom_id=kingdom.id,
        title=f"Decree from {current_user.display_name}",
        description=decree_text
    )
    db.add(decree)
    
    # Update kingdom activity timestamp
    kingdom.last_activity = datetime.utcnow()
    db.commit()
    db.refresh(decree)
    
    return {
        "success": True,
        "message": "Decree proclaimed successfully",
        "decree_id": decree.id,
        "kingdom_id": kingdom.id,
        "kingdom_name": kingdom.name,
        "decree_text": decree.description,
        "ruler_name": current_user.display_name,
        "created_at": format_datetime_iso(decree.created_at)
    }


# ===== Stats & Leaderboard =====

@router.get("/leaderboard")
def get_leaderboard(
    category: str = "reputation",  # reputation, kingdoms, gold, conquests
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """
    Get leaderboard rankings
    
    Categories: reputation, kingdoms, gold, conquests
    """
    
    if category == "reputation":
        users = db.query(User).filter(User.is_active == True).order_by(User.reputation.desc()).limit(limit).all()
    elif category == "kingdoms":
        users = db.query(User).filter(User.is_active == True).order_by(User.kingdoms_ruled.desc()).limit(limit).all()
    elif category == "gold":
        users = db.query(User).filter(User.is_active == True).order_by(User.gold.desc()).limit(limit).all()
    elif category == "conquests":
        users = db.query(User).filter(User.is_active == True).order_by(User.total_conquests.desc()).limit(limit).all()
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid category. Choose: reputation, kingdoms, gold, or conquests"
        )
    
    leaderboard = []
    for rank, user in enumerate(users, start=1):
        # Get player state for score and level
        user_state = user.player_state
        if category == "kingdoms":
            score = user_state.kingdoms_ruled if user_state else 0
        else:
            score = getattr(user_state, category, 0) if user_state else 0
        
        leaderboard.append({
            "rank": rank,
            "user_id": user.id,
            "username": getattr(user, 'username', user.display_name),
            "display_name": user.display_name,
            "avatar_url": user.avatar_url,
            "score": score,
            "level": user_state.level if user_state else 1
        })
    
    return {
        "category": category,
        "leaderboard": leaderboard
    }
