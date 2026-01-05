"""
Player discovery and social endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, PlayerState, Kingdom, UnifiedContract, ContractContribution
from db.models import KingdomIntelligence, UserKingdom
from routers.auth import get_current_user
from sqlalchemy import func
from schemas.player import (
    PlayerPublicProfile, 
    PlayerInKingdom, 
    PlayersInKingdomResponse, 
    ActivePlayersResponse,
    PlayerActivity,
    PlayerEquipment
)


router = APIRouter(prefix="/players", tags=["players"])


def _get_player_activity(db: Session, state: PlayerState) -> PlayerActivity:
    """Determine what a player is currently doing"""
    now = datetime.utcnow()
    
    # Check patrol first (it's a duration-based activity)
    from db.models.action_cooldown import ActionCooldown
    patrol_cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == state.user_id,
        ActionCooldown.action_type == "patrol"
    ).first()
    
    if patrol_cooldown and patrol_cooldown.expires_at and patrol_cooldown.expires_at > now:
        return PlayerActivity(
            type="patrolling",
            details="On patrol",
            expires_at=patrol_cooldown.expires_at
        )
    
    # Import centralized skill types
    from routers.tiers import SKILL_TYPES
    training_types = SKILL_TYPES
    
    # Check training contracts from unified_contracts table (active = not completed)
    active_training = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == state.user_id,
        UnifiedContract.type.in_(training_types),
        UnifiedContract.completed_at.is_(None)
    ).first()
    
    if active_training:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == active_training.id
        ).scalar()
        return PlayerActivity(
            type="training",
            details=f"Training {active_training.type.capitalize()} ({actions_completed}/{active_training.actions_required})",
            training_type=active_training.type,  # "attack", "defense", etc.
            tier=active_training.tier
        )
    
    # Check crafting contracts from unified_contracts table (active = not completed)
    crafting_types = ["weapon", "armor"]
    active_crafting = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == state.user_id,
        UnifiedContract.type.in_(crafting_types),
        UnifiedContract.completed_at.is_(None)
    ).first()
    
    if active_crafting:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == active_crafting.id
        ).scalar()
        return PlayerActivity(
            type="crafting",
            details=f"Crafting T{active_crafting.tier} {active_crafting.type.capitalize()} ({actions_completed}/{active_crafting.actions_required})",
            equipment_type=active_crafting.type,  # "weapon", "armor"
            tier=active_crafting.tier
        )
    
    # Check recent actions (within last 2 minutes)
    from db.models.action_cooldown import ActionCooldown
    recent_threshold = now - timedelta(minutes=2)
    
    recent_cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == state.user_id,
        ActionCooldown.last_performed >= recent_threshold
    ).all()
    
    for cooldown in recent_cooldowns:
        if cooldown.action_type == "work":
            return PlayerActivity(
                type="working",
                details="Working on construction"
            )
        elif cooldown.action_type == "scout":
            return PlayerActivity(
                type="scouting",
                details="Gathering intelligence"
            )
        elif cooldown.action_type == "sabotage":
            return PlayerActivity(
                type="sabotage",
                details="Sabotaging enemy"
            )
    
    # Default to idle
    return PlayerActivity(type="idle")


def _get_player_equipment(db: Session, user_id: int) -> PlayerEquipment:
    """Get equipped items from player_items table"""
    from db import PlayerItem
    
    equipped = db.query(PlayerItem).filter(
        PlayerItem.user_id == user_id,
        PlayerItem.is_equipped == True
    ).all()
    
    weapon = None
    armor = None
    for item in equipped:
        if item.type == "weapon":
            weapon = item
        elif item.type == "armor":
            armor = item
    
    return PlayerEquipment(
        weapon_tier=weapon.tier if weapon else None,
        weapon_attack_bonus=weapon.attack_bonus if weapon else None,
        armor_tier=armor.tier if armor else None,
        armor_defense_bonus=armor.defense_bonus if armor else None
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
        
        activity = _get_player_activity(db, state)
        is_ruler = kingdom.ruler_id == user.id
        
        # Get per-kingdom reputation from user_kingdoms table
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom_id
        ).first()
        reputation = user_kingdom.local_reputation if user_kingdom else 0
        
        players.append(PlayerInKingdom(
            id=user.id,
            display_name=user.display_name,
            avatar_url=user.avatar_url,
            level=state.level,
            reputation=reputation,
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
        
        activity = _get_player_activity(db, state)
        is_online = _is_player_online(user)
        is_ruler = False
        
        # Check if ruler of current kingdom
        if state.current_kingdom_id:
            kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
            if kingdom:
                is_ruler = kingdom.ruler_id == user.id
        
        # Get per-kingdom reputation from user_kingdoms table (for current kingdom)
        reputation = 0
        if state.current_kingdom_id:
            user_kingdom = db.query(UserKingdom).filter(
                UserKingdom.user_id == user.id,
                UserKingdom.kingdom_id == state.current_kingdom_id
            ).first()
            reputation = user_kingdom.local_reputation if user_kingdom else 0
        
        players.append(PlayerInKingdom(
            id=user.id,
            display_name=user.display_name,
            avatar_url=user.avatar_url,
            level=state.level,
            reputation=reputation,
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
    
    activity = _get_player_activity(db, state)
    equipment = _get_player_equipment(db, user.id)
    
    # Get per-kingdom reputation (for current kingdom)
    reputation = 0
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        reputation = user_kingdom.local_reputation if user_kingdom else 0
    
    # Compute stats from other tables
    
    # Count kingdoms ruled
    kingdoms_ruled = db.query(func.count(Kingdom.id)).filter(
        Kingdom.ruler_id == user.id
    ).scalar() or 0
    
    # Count coups won
    from db.models import CoupEvent
    coups_won = db.query(func.count(CoupEvent.id)).filter(
        CoupEvent.initiator_id == user.id,
        CoupEvent.attacker_victory == True
    ).scalar() or 0
    
    # Count contracts completed (distinct contract_ids from contributions)
    contracts_completed = db.query(func.count(func.distinct(ContractContribution.contract_id))).filter(
        ContractContribution.user_id == user.id
    ).scalar() or 0
    
    # Sum total check-ins across all kingdoms
    total_checkins = db.query(func.sum(UserKingdom.checkins_count)).filter(
        UserKingdom.user_id == user.id
    ).scalar() or 0
    
    # Count total conquests (times this player became ruler via coup/invasion)
    from db.models import KingdomHistory
    total_conquests = db.query(func.count(KingdomHistory.id)).filter(
        KingdomHistory.ruler_id == user.id,
        KingdomHistory.event_type.in_(['coup', 'invasion', 'reconquest'])
    ).scalar() or 0
    
    return PlayerPublicProfile(
        id=user.id,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        current_kingdom_id=state.current_kingdom_id,
        current_kingdom_name=current_kingdom_name,
        hometown_kingdom_id=state.hometown_kingdom_id,
        level=state.level,
        reputation=reputation,
        honor=100,  # Default honor value
        attack_power=state.attack_power,
        defense_power=state.defense_power,
        leadership=state.leadership,
        building_skill=state.building_skill,
        intelligence=state.intelligence,
        science=state.science,
        faith=state.faith,
        equipment=equipment,
        total_checkins=total_checkins,
        total_conquests=total_conquests,
        kingdoms_ruled=kingdoms_ruled,
        coups_won=coups_won,
        contracts_completed=contracts_completed,
        activity=activity,
        last_login=user.last_login,
        created_at=user.created_at
    )

