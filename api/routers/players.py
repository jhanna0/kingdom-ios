"""
Player discovery and social endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, PlayerState, Kingdom
from db.models import KingdomIntelligence
from routers.auth import get_current_user
from schemas.player import (
    PlayerPublicProfile, 
    PlayerInKingdom, 
    PlayersInKingdomResponse, 
    ActivePlayersResponse,
    PlayerActivity,
    PlayerEquipment
)


router = APIRouter(prefix="/players", tags=["players"])


def _get_player_activity(state: PlayerState) -> PlayerActivity:
    """Determine what a player is currently doing"""
    now = datetime.utcnow()
    
    # Check patrol first (it's a duration-based activity)
    if state.patrol_expires_at and state.patrol_expires_at > now:
        return PlayerActivity(
            type="patrolling",
            details="On patrol",
            expires_at=state.patrol_expires_at
        )
    
    # Check training contracts
    if state.training_contracts:
        for contract in state.training_contracts:
            if contract.get("status") != "completed":
                training_type = contract.get("type", "").capitalize()
                completed = contract.get("actionsCompleted", 0)
                required = contract.get("actionsRequired", 0)
                return PlayerActivity(
                    type="training",
                    details=f"Training {training_type} ({completed}/{required})"
                )
    
    # Check crafting queue
    if state.crafting_queue:
        for craft in state.crafting_queue:
            if craft.get("status") != "completed":
                equipment_type = craft.get("equipmentType", "").capitalize()
                tier = craft.get("tier", 0)
                completed = craft.get("actionsCompleted", 0)
                required = craft.get("actionsRequired", 0)
                return PlayerActivity(
                    type="crafting",
                    details=f"Crafting T{tier} {equipment_type} ({completed}/{required})"
                )
    
    # Check recent actions (within last 2 minutes)
    recent_threshold = now - timedelta(minutes=2)
    
    if state.last_work_action and state.last_work_action > recent_threshold:
        return PlayerActivity(
            type="working",
            details="Working on construction"
        )
    
    if state.last_scout_action and state.last_scout_action > recent_threshold:
        return PlayerActivity(
            type="scouting",
            details="Gathering intelligence"
        )
    
    if state.last_sabotage_action and state.last_sabotage_action > recent_threshold:
        return PlayerActivity(
            type="sabotage",
            details="Sabotaging enemy"
        )
    
    # Default to idle
    return PlayerActivity(type="idle")


def _get_player_equipment(state: PlayerState) -> PlayerEquipment:
    """Extract equipment data from player state"""
    equipped_weapon = None
    equipped_armor = None
    
    if state.equipped_weapon:
        equipped_weapon = state.equipped_weapon
    if state.equipped_armor:
        equipped_armor = state.equipped_armor
    
    return PlayerEquipment(
        weapon_tier=equipped_weapon.get("tier") if equipped_weapon else None,
        weapon_attack_bonus=equipped_weapon.get("attackBonus") if equipped_weapon else None,
        armor_tier=equipped_armor.get("tier") if equipped_armor else None,
        armor_defense_bonus=equipped_armor.get("defenseBonus") if equipped_armor else None
    )


def _is_player_online(user: User) -> bool:
    """Check if player was active in last 5 minutes"""
    if not user.last_login:
        return False
    return user.last_login > datetime.utcnow() - timedelta(minutes=5)


@router.get("/in-kingdom/{kingdom_id}", response_model=PlayersInKingdomResponse)
def get_players_in_kingdom(
    kingdom_id: str,
    limit: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all players currently in a kingdom with their activity status
    
    **ACCESS CONTROL**: You can only see player activity if:
    - You rule this kingdom, OR
    - This is your hometown kingdom, OR
    - You have gathered intelligence on this kingdom (Level 4+)
    
    Parameters:
    - limit: Optional - max number of players to return (for efficient polling)
    
    Shows:
    - All players who have checked into this kingdom
    - Their current activity (working, patrolling, training, etc.)
    - Who's online (active in last 5 minutes)
    - Who's the ruler
    """
    # Verify kingdom exists
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if player can see this intel
    is_ruler = kingdom.ruler_id == current_user.id
    is_hometown = state.hometown_kingdom_id == kingdom_id
    has_intel = False
    
    if not is_ruler and not is_hometown:
        # Check if we have Level 4+ intelligence on this kingdom
        intel = db.query(KingdomIntelligence).filter(
            KingdomIntelligence.kingdom_id == kingdom_id,
            KingdomIntelligence.gatherer_kingdom_id == state.hometown_kingdom_id,
            KingdomIntelligence.intelligence_level >= 4,  # Need Level 4+ to see player activity
            KingdomIntelligence.expires_at > datetime.utcnow()
        ).first()
        
        has_intel = intel is not None
    
    # If not ruler, not hometown, and no intel, deny access
    if not is_ruler and not is_hometown and not has_intel:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Intelligence required. Gather Level 4+ intelligence on this kingdom to see player activity."
        )
    
    # Get all players in this kingdom
    player_states = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == kingdom_id
    ).all()
    
    players = []
    online_count = 0
    
    for state in player_states:
        user = state.user
        if not user or not user.is_active:
            continue
        
        is_online = _is_player_online(user)
        if is_online:
            online_count += 1
        
        activity = _get_player_activity(state)
        is_ruler = kingdom.ruler_id == user.id
        
        players.append(PlayerInKingdom(
            id=user.id,
            display_name=user.display_name,
            avatar_url=user.avatar_url,
            level=state.level,
            reputation=state.reputation,
            attack_power=state.attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            activity=activity,
            is_ruler=is_ruler,
            is_online=is_online
        ))
    
    # Sort: ruler first, then online players, then by reputation
    players.sort(key=lambda p: (-p.is_ruler, -p.is_online, -p.reputation))
    
    # 🚨 TESTING: Simulated live feed - players trickle in/out (REMOVE BEFORE PRODUCTION)
    import random
    import time
    
    # Use time-based seed so players rotate in/out gradually
    seed = int(time.time() / 3)  # Changes every 3 seconds
    random.seed(seed)
    
    fake_pool = [
        ("Sir Reginald", "working", "Building city walls"),
        ("Lady Beatrice", "training", "Training defense"),
        ("Baron Testing", "patrolling", "Patrolling walls"),
        ("Duke Lorem", "crafting", "Forging steel sword"),
        ("Count Debug", "working", "Upgrading vault"),
        ("Princess Sample", "training", "Training attack"),
        ("Knight Ipsum", "scouting", "Gathering intelligence"),
        ("Duchess Mock", "working", "Building market"),
        ("Earl Testwell", "idle", "Resting in tavern"),
        ("Sir Devmode", "patrolling", "Watching the gates"),
    ]
    
    # Randomly select 3-6 players to be "in kingdom" right now
    num_present = random.randint(3, 6)
    present_fakes = random.sample(fake_pool, num_present)
    
    for i, (name, activity_type, activity_text) in enumerate(present_fakes):
        players.append(PlayerInKingdom(
            id=9000 + hash(name) % 1000,  # Consistent ID per fake
            display_name=f"{name}",
            avatar_url=None,
            level=random.randint(2, 8),
            reputation=random.randint(100, 400),
            attack_power=random.randint(1, 8),
            defense_power=random.randint(1, 8),
            leadership=random.randint(1, 8),
            activity=PlayerActivity(
                type=activity_type,
                details=activity_text,
                expires_at=None
            ),
            is_ruler=False,
            is_online=True  # All visible fakes are "online"
        ))
        online_count += 1
    
    # Re-sort after adding fakes
    players.sort(key=lambda p: (-p.is_ruler, -p.is_online, -p.reputation))
    # 🚨 END TESTING CODE
    
    # Apply limit if specified
    total_players = len(players)
    if limit and limit > 0:
        players = players[:limit]
    
    return PlayersInKingdomResponse(
        kingdom_id=kingdom_id,
        kingdom_name=kingdom.name,
        total_players=total_players,
        online_count=online_count,
        players=players
    )


@router.get("/active", response_model=ActivePlayersResponse)
def get_active_players(
    kingdom_id: Optional[str] = None,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get recently active players (logged in within last hour)
    
    Parameters:
    - kingdom_id: Optional - filter to specific kingdom
    - limit: Max players to return (default 50)
    """
    # Get players active in last hour
    recent_threshold = datetime.utcnow() - timedelta(hours=1)
    
    query = db.query(User).filter(
        User.is_active == True,
        User.last_login >= recent_threshold
    )
    
    # Filter by kingdom if specified
    if kingdom_id:
        query = query.join(PlayerState).filter(
            PlayerState.current_kingdom_id == kingdom_id
        )
    else:
        query = query.join(PlayerState)
    
    users = query.order_by(desc(User.last_login)).limit(limit).all()
    
    players = []
    for user in users:
        state = user.player_state
        if not state:
            continue
        
        activity = _get_player_activity(state)
        is_online = _is_player_online(user)
        is_ruler = False
        
        # Check if ruler of current kingdom
        if state.current_kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
            if kingdom:
                is_ruler = kingdom.ruler_id == user.id
        
        players.append(PlayerInKingdom(
            id=user.id,
            display_name=user.display_name,
            avatar_url=user.avatar_url,
            level=state.level,
            reputation=state.reputation,
            attack_power=state.attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            activity=activity,
            is_ruler=is_ruler,
            is_online=is_online
        ))
    
    return ActivePlayersResponse(
        total=len(players),
        players=players
    )


@router.get("/{user_id}/profile", response_model=PlayerPublicProfile)
def get_player_profile(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get public profile for any player
    
    Shows:
    - Stats and equipment
    - Achievements and history
    - Current activity and location
    """
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player not found"
        )
    
    state = user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Get current kingdom name
    current_kingdom_name = None
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            current_kingdom_name = kingdom.name
    
    activity = _get_player_activity(state)
    equipment = _get_player_equipment(state)
    
    return PlayerPublicProfile(
        id=user.id,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        current_kingdom_id=state.current_kingdom_id,
        current_kingdom_name=current_kingdom_name,
        hometown_kingdom_id=state.hometown_kingdom_id,
        level=state.level,
        reputation=state.reputation,
        honor=state.honor,
        attack_power=state.attack_power,
        defense_power=state.defense_power,
        leadership=state.leadership,
        building_skill=state.building_skill,
        intelligence=state.intelligence,
        equipment=equipment,
        total_checkins=state.total_checkins,
        total_conquests=state.total_conquests,
        kingdoms_ruled=state.kingdoms_ruled,
        coups_won=state.coups_won,
        contracts_completed=state.contracts_completed,
        activity=activity,
        last_login=user.last_login,
        created_at=user.created_at
    )

