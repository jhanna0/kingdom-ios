"""
Game endpoints - Kingdoms, check-ins, conquests
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List
import uuid

from db import get_db, User, PlayerState, Kingdom, UserKingdom, CheckInHistory, CityBoundary
from schemas import CheckInRequest, CheckInResponse, CheckInRewards
from routers.auth import get_current_user
from config import DEV_MODE


router = APIRouter(tags=["game"])


# ===== Helper Functions =====

def _get_or_create_player_state(db: Session, user: User) -> PlayerState:
    """Get or create player state for user"""
    if not user.player_state:
        player_state = PlayerState(
            user_id=user.id,
            hometown_kingdom_id=user.hometown_kingdom_id
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
            is_ruler=False,
            is_subject=False,
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
    from routers.contracts import calculate_actions_required, calculate_suggested_reward, calculate_construction_cost
    
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
    
    # Convert to dict and add calculated upgrade costs
    kingdom_dict = {
        "id": kingdom.id,
        "name": kingdom.name,
        "ruler_id": kingdom.ruler_id,
        "ruler_name": ruler_name,
        "city_boundary_osm_id": kingdom.city_boundary_osm_id,
        "population": kingdom.population,
        "level": kingdom.level,
        "treasury_gold": kingdom.treasury_gold,
        "checked_in_players": kingdom.checked_in_players,
        "wall_level": kingdom.wall_level,
        "vault_level": kingdom.vault_level,
        "mine_level": kingdom.mine_level,
        "market_level": kingdom.market_level,
        "farm_level": kingdom.farm_level,
        "education_level": kingdom.education_level,
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
    
    # Calculate upgrade costs for each building
    building_types = [
        ("wall", kingdom.wall_level),
        ("vault", kingdom.vault_level),
        ("mine", kingdom.mine_level),
        ("market", kingdom.market_level),
        ("farm", kingdom.farm_level),
        ("education", kingdom.education_level)
    ]
    
    for building_name, current_level in building_types:
        if current_level < 5:  # Max level is 5
            next_level = current_level + 1
            actions = calculate_actions_required(building_name.capitalize(), next_level, kingdom.checked_in_players)
            construction_cost = calculate_construction_cost(next_level, kingdom.checked_in_players)
            reward = calculate_suggested_reward(actions, next_level)
            total_cost = construction_cost + reward
            kingdom_dict[f"{building_name}_upgrade_cost"] = {
                "actions_required": actions,
                "construction_cost": construction_cost,
                "suggested_reward": reward,
                "can_afford": kingdom.treasury_gold >= total_cost
            }
        else:
            kingdom_dict[f"{building_name}_upgrade_cost"] = None
    
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
    
    RESTRICTION: Users can only claim a city for free if they don't currently rule any kingdoms.
    This prevents empire spam. Military conquest is required to expand once you rule a kingdom.
    """
    # Get player state
    state = _get_or_create_player_state(db, current_user)
    
    # Check if user currently rules any kingdoms
    # Can only claim a free kingdom if you don't currently rule any
    current_kingdoms = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.is_ruler == True
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
            
            # Create user-kingdom relationship
            user_kingdom = UserKingdom(
                user_id=current_user.id,
                kingdom_id=existing.id,
                is_ruler=True,
                is_subject=False,
                became_ruler_at=datetime.utcnow(),
                times_conquered=1
            )
            db.add(user_kingdom)
            
            # Update user stats
            state.kingdoms_ruled += 1
            state.total_conquests += 1
            
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
    
    # Create user-kingdom relationship
    user_kingdom = UserKingdom(
        user_id=current_user.id,
        kingdom_id=kingdom.id,
        is_ruler=True,
        is_subject=False,
        became_ruler_at=datetime.utcnow(),
        times_conquered=1
    )
    
    db.add(user_kingdom)
    
    # Update user stats
    state.kingdoms_ruled += 1
    state.total_conquests += 1
    
    db.commit()
    
    return kingdom


# ===== Check-in System =====

@router.post("/checkin", response_model=CheckInResponse)
def check_in(
    request: CheckInRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Check in to a kingdom
    
    Validates location and rewards player with gold and XP
    Enforces cooldown to prevent spam
    """
    
    # Get kingdom - should already exist from /cities call
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.city_boundary_osm_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Verify user is actually inside kingdom boundaries
    if not _is_user_in_kingdom(db, request.latitude, request.longitude, kingdom):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are not within the kingdom boundaries"
        )
    
    # Get or create user-kingdom relationship
    user_kingdom = _get_or_create_user_kingdom(db, current_user.id, kingdom.id)
    
    # Check cooldown (1 hour in production, 5 minutes in dev mode)
    if user_kingdom.last_checkin:
        time_since_last = datetime.utcnow() - user_kingdom.last_checkin
        cooldown = timedelta(minutes=5) if DEV_MODE else timedelta(hours=1)
        
        if time_since_last < cooldown:
            remaining = cooldown - time_since_last
            minutes = int(remaining.total_seconds() / 60)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Check-in cooldown active. Try again in {minutes} minutes."
            )
    
    # Calculate rewards
    base_gold = 10
    base_xp = 5
    
    # DEV MODE: 10x rewards
    if DEV_MODE:
        base_gold *= 10
        base_xp *= 10
    
    # Bonus if you're the ruler
    if user_kingdom.is_ruler:
        base_gold *= 2
        base_xp *= 2
    
    # Bonus based on kingdom level
    gold_reward = base_gold * kingdom.level
    xp_reward = base_xp * kingdom.level
    
    # Update user state
    state = _get_or_create_player_state(db, current_user)
    state.gold += gold_reward
    state.experience += xp_reward
    state.total_checkins += 1
    
    # Level up check
    required_exp = state.level * 100
    if state.experience >= required_exp:
        state.level += 1
        state.experience -= required_exp
        state.gold += 50 * state.level
    
    # Update user-kingdom
    user_kingdom.checkins_count += 1
    user_kingdom.last_checkin = datetime.utcnow()
    user_kingdom.gold_earned += gold_reward
    user_kingdom.local_reputation += 1
    
    # Update kingdom
    kingdom.treasury_gold += gold_reward // 10  # 10% tax
    kingdom.last_activity = datetime.utcnow()
    
    # Record check-in history
    checkin_record = CheckInHistory(
        user_id=current_user.id,
        kingdom_id=kingdom.id,
        latitude=request.latitude,
        longitude=request.longitude,
        gold_earned=gold_reward,
        experience_earned=xp_reward,
        checked_in_at=datetime.utcnow()
    )
    db.add(checkin_record)
    
    db.commit()
    
    return CheckInResponse(
        success=True,
        message=f"Checked in to {kingdom.name}!",
        rewards=CheckInRewards(
            gold=gold_reward,
            experience=xp_reward
        )
    )


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
    user_kingdom = _get_or_create_user_kingdom(db, current_user.id, kingdom_id)
    
    if user_kingdom.is_ruler:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already rule this kingdom"
        )
    
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
            old_ruler_state.reputation -= 10  # Lose reputation for losing kingdom
        
        # Update old ruler's user_kingdom record
        old_user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == old_ruler_id,
            UserKingdom.kingdom_id == kingdom_id
        ).first()
        
        if old_user_kingdom:
            old_user_kingdom.is_ruler = False
            old_user_kingdom.is_subject = True  # Becomes a subject
            old_user_kingdom.lost_rulership_at = datetime.utcnow()
            old_user_kingdom.times_lost += 1
    
    # Set new ruler
    kingdom.ruler_id = current_user.id
    kingdom.last_activity = datetime.utcnow()
    
    # Update new ruler state
    state.gold -= conquest_cost
    state.kingdoms_ruled += 1
    state.total_conquests += 1
    state.reputation += 20
    state.experience += 100 * kingdom.level
    
    # Update user-kingdom relationship
    user_kingdom.is_ruler = True
    user_kingdom.is_subject = False
    user_kingdom.became_ruler_at = datetime.utcnow()
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
    
    user_kingdoms = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.is_ruler == True
    ).all()
    
    kingdoms = []
    for uk in user_kingdoms:
        kingdom = db.query(Kingdom).filter(Kingdom.id == uk.kingdom_id).first()
        if kingdom:
            kingdoms.append({
                "id": kingdom.id,
                "name": kingdom.name,
                "level": kingdom.level,
                "population": kingdom.population,
                "treasury_gold": kingdom.treasury_gold,
                "checkins_count": uk.checkins_count,
                "became_ruler_at": uk.became_ruler_at,
                "local_reputation": uk.local_reputation
            })
    
    return kingdoms


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
