"""
Game endpoints - Kingdoms, check-ins, conquests

FAST STARTUP:
- GET /startup - Combined endpoint for app init (replaces /cities/current + /player/state + /auth/me)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
from typing import List, Optional
import uuid

from db import get_db, User, PlayerState, Kingdom, UserKingdom, CityBoundary
from db.models.kingdom_event import KingdomEvent
from schemas import CheckInRequest, CheckInResponse, CheckInRewards, CityBoundaryResponse
from schemas.user import PlayerState as PlayerStateSchema, TravelEvent
from routers.auth import get_current_user, get_current_user_optional
from routers.actions.utils import format_datetime_iso
from routers.player import player_state_to_response, handle_kingdom_checkin, get_or_create_player_state
from services import city_service
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


# ===== FAST STARTUP ENDPOINT =====
# GET /startup - Combines: /cities/current + /player/state + /auth/me last_login update
# One round-trip instead of three!

@router.get("/startup")
async def get_startup_data(
    lat: float,
    lon: float,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    FAST STARTUP - Single endpoint for app initialization.
    
    Replaces the sequential calls to:
    1. GET /cities/current (get current city)
    2. GET /player/state?kingdom_id=X (check-in + player data)
    3. GET /auth/me (updates last_login)
    
    Takes lat/lon, returns everything needed to start the app:
    - Current city with full boundary and kingdom data
    - Player state with check-in handled
    - Updates last_login for online status
    
    This is THE call to make on app launch after authentication.
    """
    from services import city_service
    
    # 1. Update last_login (what /auth/me does)
    current_user.last_login = datetime.utcnow()
    
    # 2. Get current city (what /cities/current does)
    city = await city_service.get_current_city(db, lat, lon, current_user)
    
    if not city:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No city found at this location"
        )
    
    # 3. Get or create player state
    state = get_or_create_player_state(db, current_user)
    
    # 4. Handle check-in if entering a kingdom (what /player/state does)
    travel_event = None
    kingdom_id = city.osm_id  # The city's OSM ID is the kingdom ID
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if kingdom:
        # Use existing check-in logic
        travel_event = handle_kingdom_checkin(db, current_user, state, kingdom)
    
    # 5. Commit all changes (last_login + check-in)
    db.commit()
    
    # 6. Build player state response (what /player/state returns)
    player_state = player_state_to_response(current_user, state, db, travel_event)
    
    # 7. Return combined response
    return {
        "city": city,
        "player": player_state,
        "server_time": format_datetime_iso(datetime.utcnow())
    }


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
def get_kingdom(
    kingdom_id: str, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_optional)
):
    """Get kingdom details with building upgrade costs and catchup info"""
    from services.kingdom_service import get_active_citizens_count, check_ruler_abandonment, calculate_actions_required
    from services.city_service import get_buildings_for_kingdom
    from db.models import PlayerState, UnifiedContract, ContractContribution
    from sqlalchemy import func
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check for ruler abandonment (rulers who haven't logged in for 60+ days)
    check_ruler_abandonment(db, kingdom)
    
    # Get ruler name from User if kingdom has a ruler
    ruler_name = None
    if kingdom.ruler_id:
        ruler = db.query(User).filter(User.id == kingdom.ruler_id).first()
        if ruler:
            ruler_name = ruler.display_name
    
    # CALCULATE LIVE: Count players in kingdom RIGHT NOW
    cutoff = datetime.utcnow() - timedelta(hours=1)
    checked_in_count = db.query(PlayerState).join(
        User, PlayerState.user_id == User.id
    ).filter(
        PlayerState.current_kingdom_id == kingdom.id,
        User.last_login >= cutoff
    ).count()
    
    # CALCULATE LIVE: Count active citizens (alive citizens whose hometown is this kingdom)
    active_citizens_count = get_active_citizens_count(db, kingdom.id)
    
    # Dynamic contract scaling for hometown kingdom
    # Adjust actions_required based on current active citizens (can only go down)
    if current_user:
        player_state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
        if player_state and player_state.hometown_kingdom_id == kingdom_id:
            farm_level = kingdom.farm_level if hasattr(kingdom, 'farm_level') else 0
            contracts = db.query(UnifiedContract).filter(
                UnifiedContract.kingdom_id == kingdom_id,
                UnifiedContract.category == 'kingdom_building',
                UnifiedContract.completed_at.is_(None)
            ).with_for_update().all()
            for contract in contracts:
                new_actions = calculate_actions_required(contract.type, contract.tier, active_citizens_count, farm_level)
                if new_actions < contract.actions_required:
                    actions_completed = db.query(func.count(ContractContribution.id)).filter(
                        ContractContribution.contract_id == contract.id
                    ).scalar()
                    new_actions = max(new_actions, actions_completed + 1)
                    if new_actions < contract.actions_required:
                        contract.actions_required = new_actions
                        contract.action_reward = int(contract.reward_pool / new_actions)
            db.commit()
    
    # SINGLE SOURCE OF TRUTH: Get buildings with all metadata, costs, and catchup info
    buildings = get_buildings_for_kingdom(db, kingdom, current_user)
    
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
        "treasury_gold": int(kingdom.treasury_gold),
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
            existing.ruler_started_at = datetime.utcnow()
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
        ruler_started_at=datetime.utcnow(),
        empire_id=city_boundary_osm_id,  # New independent empire
        original_kingdom_id=city_boundary_osm_id,  # Original city identity
        population=1,
        level=1,
        treasury_gold=starting_treasury,
        townhall_level=1  # All kingdoms start with Town Hall level 1
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
            
            # Lose reputation in this kingdom (philosophy reduces loss)
            from routers.actions.utils import deduct_reputation
            deduct_reputation(
                db=db,
                user_id=old_ruler_id,
                kingdom_id=kingdom.id,
                base_amount=10,
                philosophy_level=old_ruler_state.philosophy or 0
            )
        
        # Note: No need to update old ruler's user_kingdom record
        # Kingdom.ruler_id being updated is sufficient
    
    # Set new ruler
    kingdom.ruler_id = current_user.id
    kingdom.ruler_started_at = datetime.utcnow()
    kingdom.last_activity = datetime.utcnow()
    
    # Update new ruler state
    state.gold -= conquest_cost
    state.kingdoms_ruled += 1
    state.total_conquests += 1
    state.experience += 100 * kingdom.level
    
    # Gain reputation in conquered kingdom (philosophy bonus)
    from routers.actions.utils import award_reputation
    award_reputation(
        db=db,
        user_id=current_user.id,
        kingdom_id=kingdom.id,
        base_amount=20,
        philosophy_level=state.philosophy or 0
    )
    
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
            "treasury_gold": int(kingdom.treasury_gold),
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
