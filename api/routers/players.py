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
    PlayerEquipment,
    PlayerAchievement,
    AchievementGroup,
    TitleData,
    StylePreset,
    SubscriberCustomization,
    SubscriberSettings,
    SubscriberSettingsUpdate
)
from db.models.subscription import STYLE_PRESETS, get_style_colors
from sqlalchemy import text


router = APIRouter(prefix="/players", tags=["players"])


# Import centralized activity icons
from routers.actions.action_config import ACTIVITY_ICONS


def _get_player_activity(db: Session, state: PlayerState) -> PlayerActivity:
    """Determine what a player is currently doing"""
    now = datetime.utcnow()
    
    # Check active minigame sessions first (these are real-time activities)
    # These show as status WITHOUT spamming activity log
    
    # Check hunting session (highest priority - group activity)
    # Check as creator first, then as participant
    from db.models import HuntSession
    active_hunt = db.query(HuntSession).filter(
        HuntSession.created_by == state.user_id,
        HuntSession.status.in_(['lobby', 'in_progress']),
        HuntSession.expires_at > now
    ).first()
    
    # Also check if they're a participant in someone else's hunt
    if not active_hunt:
        active_hunts = db.query(HuntSession).filter(
            HuntSession.status.in_(['lobby', 'in_progress']),
            HuntSession.expires_at > now
        ).all()
        for hunt in active_hunts:
            participants = hunt.session_data.get("participants", {})
            if str(state.user_id) in participants:
                active_hunt = hunt
                break
    
    if active_hunt:
        hunt_status = "Waiting for hunters" if active_hunt.status == 'lobby' else "Tracking prey"
        return PlayerActivity(
            type="hunting",
            details=hunt_status,
            icon=ACTIVITY_ICONS["hunting"],
            expires_at=active_hunt.expires_at
        )
    
    # Check fishing session
    from db.models import FishingSession
    active_fishing = db.query(FishingSession).filter(
        FishingSession.created_by == state.user_id,
        FishingSession.status == 'active',
        FishingSession.expires_at > now
    ).first()
    if active_fishing:
        return PlayerActivity(
            type="fishing",
            details="Fishing",
            icon=ACTIVITY_ICONS["fishing"],
            expires_at=active_fishing.expires_at
        )
    
    # Check foraging session
    from db.models import ForagingSession
    active_foraging = db.query(ForagingSession).filter(
        ForagingSession.user_id == state.user_id,
        ForagingSession.status == 'active',
        ForagingSession.expires_at > now
    ).first()
    if active_foraging:
        return PlayerActivity(
            type="foraging",
            details="Foraging for resources",
            icon=ACTIVITY_ICONS["foraging"],
            expires_at=active_foraging.expires_at
        )
    
    # Check science/research session
    from db.models import ScienceSession
    active_science = db.query(ScienceSession).filter(
        ScienceSession.user_id == state.user_id,
        ScienceSession.status == 'active',
        ScienceSession.expires_at > now
    ).first()
    if active_science:
        return PlayerActivity(
            type="researching",
            details="Conducting research",
            icon=ACTIVITY_ICONS["researching"],
            expires_at=active_science.expires_at
        )
    
    # Check patrol (it's a duration-based activity)
    from db.models.action_cooldown import ActionCooldown
    patrol_cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == state.user_id,
        ActionCooldown.action_type == "patrol"
    ).first()
    
    if patrol_cooldown and patrol_cooldown.expires_at and patrol_cooldown.expires_at > now:
        return PlayerActivity(
            type="patrolling",
            details="On patrol",
            icon=ACTIVITY_ICONS["patrolling"],
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
            icon=ACTIVITY_ICONS["training"],
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
            icon=ACTIVITY_ICONS["crafting"],
            equipment_type=active_crafting.type,  # "weapon", "armor"
            tier=active_crafting.tier
        )
    
    # Check recent actions that are still on cooldown
    # If someone did an action recently and it's still on cooldown, show that activity
    from db.models.action_cooldown import ActionCooldown
    from routers.actions.action_config import ACTION_TYPES
    
    # Get all cooldowns for this user
    cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == state.user_id
    ).all()
    
    # Find the most recent action that's still on cooldown
    most_recent_active = None
    most_recent_time = None
    
    for cooldown in cooldowns:
        if not cooldown.last_performed:
            continue
        
        # Get the cooldown duration for this action type
        action_config = ACTION_TYPES.get(cooldown.action_type)
        if not action_config:
            continue
        
        cooldown_minutes = action_config.get("cooldown_minutes", 120)
        time_since_action = now - cooldown.last_performed
        
        # If the action is still on cooldown, it's a candidate
        if time_since_action < timedelta(minutes=cooldown_minutes):
            if most_recent_time is None or cooldown.last_performed > most_recent_time:
                most_recent_time = cooldown.last_performed
                most_recent_active = cooldown.action_type
    
    # Show the most recent action that's still on cooldown
    if most_recent_active:
        if most_recent_active == "work":
            return PlayerActivity(
                type="working",
                details="Working on construction",
                icon=ACTIVITY_ICONS["working"]
            )
        elif most_recent_active == "scout":
            return PlayerActivity(
                type="scouting",
                details="Gathering intelligence",
                icon=ACTIVITY_ICONS["scouting"]
            )
        elif most_recent_active == "sabotage":
            return PlayerActivity(
                type="sabotage",
                details="Sabotaging enemy",
                icon=ACTIVITY_ICONS["sabotage"]
            )
        elif most_recent_active == "farm":
            return PlayerActivity(
                type="working",
                details="Farming for gold",
                icon=ACTIVITY_ICONS["working"]
            )
    
    # Default to idle only if no actions are on cooldown
    return PlayerActivity(type="idle", icon=ACTIVITY_ICONS["idle"])


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
    """Check if player was active in last 10 minutes"""
    if not user.last_login:
        return False
    return user.last_login > datetime.utcnow() - timedelta(minutes=10)


def _has_membership(db: Session, user_id: int) -> bool:
    """
    Check if user has active subscription.
    Membership controls visibility of achievements and pets on public profile.
    """
    from routers.store import is_user_subscriber
    return is_user_subscriber(db, user_id)


def _get_user_preferences(db: Session, user_id: int):
    """Get user preferences from user_preferences table."""
    from db.models import UserPreferences
    return db.query(UserPreferences).filter(UserPreferences.user_id == user_id).first()


def _get_style_preset(style_id: str) -> Optional[StylePreset]:
    """Convert style ID to StylePreset object."""
    if not style_id:
        return None
    colors = get_style_colors(style_id)
    if not colors.get("background"):
        return None
    return StylePreset(id=style_id, name=colors["name"], background_color=colors["background"], text_color=colors["text"])


def _get_user_subscriber_customization(db: Session, user_id: int) -> Optional[SubscriberCustomization]:
    """Get user's full subscriber customization."""
    prefs = _get_user_preferences(db, user_id)
    selected_title = _get_user_selected_title(db, user_id)
    
    if not prefs and not selected_title:
        return None
    
    icon_style = _get_style_preset(prefs.icon_style) if prefs else None
    card_style = _get_style_preset(prefs.card_style) if prefs else None
    
    if not icon_style and not card_style and not selected_title:
        return None
    
    return SubscriberCustomization(icon_style=icon_style, card_style=card_style, selected_title=selected_title)


def _get_user_selected_title(db: Session, user_id: int) -> Optional[TitleData]:
    """Get user's selected achievement title."""
    prefs = _get_user_preferences(db, user_id)
    if not prefs or not prefs.selected_title_achievement_id:
        return None
    
    # Query the achievement definition
    result = db.execute(text("""
        SELECT id, display_name, icon
        FROM achievement_definitions
        WHERE id = :achievement_id
    """), {"achievement_id": prefs.selected_title_achievement_id}).fetchone()
    
    if not result:
        return None
    
    return TitleData(
        achievement_id=result.id,
        display_name=result.display_name,
        icon=result.icon or "star.fill"
    )


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
        
        # Get per-kingdom reputation from user_kingdoms table (convert float to int for frontend)
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom_id
        ).first()
        reputation = int(user_kingdom.local_reputation) if user_kingdom else 0
        
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
        
        # Get per-kingdom reputation from user_kingdoms table (for current kingdom, convert float to int)
        reputation = 0
        if state.current_kingdom_id:
            user_kingdom = db.query(UserKingdom).filter(
                UserKingdom.user_id == user.id,
                UserKingdom.kingdom_id == state.current_kingdom_id
            ).first()
            reputation = int(user_kingdom.local_reputation) if user_kingdom else 0
        
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
    
    # Get per-kingdom reputation (for current kingdom, convert float to int)
    reputation = 0
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        reputation = int(user_kingdom.local_reputation) if user_kingdom else 0
    
    # Compute stats from other tables
    
    # Get kingdoms ruled (fetch first one for display, count for stats)
    ruled_kingdoms = db.query(Kingdom).filter(
        Kingdom.ruler_id == user.id
    ).all()
    kingdoms_ruled = len(ruled_kingdoms)
    
    # Get first ruled kingdom for display
    ruled_kingdom_id = ruled_kingdoms[0].id if ruled_kingdoms else None
    ruled_kingdom_name = ruled_kingdoms[0].name if ruled_kingdoms else None
    
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
    
    # Generate dynamic skills data - frontend renders without hardcoding!
    from routers.tiers import get_skills_data_for_player
    skills_data = get_skills_data_for_player(state)
    
    # Check if this is own profile or if target user has membership
    # Pets and achievements are only shown publicly for members
    is_own_profile = user.id == current_user.id
    show_premium_content = is_own_profile or _has_membership(db, user.id)
    
    # Get pets (only if own profile or has membership)
    pets = []
    if show_premium_content:
        from routers.resources import get_player_pets
        pets = get_player_pets(db, user.id)
    
    # Get claimed achievements for profile display (only if own profile or has membership)
    achievement_groups = []
    if show_premium_content:
        from routers.achievements import CATEGORY_CONFIG
        
        achievements_query = text("""
            SELECT DISTINCT ON (ad.achievement_type)
                ad.id,
                ad.achievement_type,
                ad.tier,
                ad.display_name,
                ad.icon,
                ad.category,
                pac.claimed_at
            FROM player_achievement_claims pac
            JOIN achievement_definitions ad ON ad.id = pac.achievement_tier_id
            WHERE pac.user_id = :user_id
            ORDER BY ad.achievement_type, ad.tier DESC
        """)
        achievements_result = db.execute(achievements_query, {"user_id": user.id}).fetchall()
        
        # Group achievements by category
        from collections import defaultdict
        achievements_by_category = defaultdict(list)
        for row in achievements_result:
            achievements_by_category[row.category].append(
                PlayerAchievement(
                    id=row.id,
                    achievement_type=row.achievement_type,
                    tier=row.tier,
                    display_name=row.display_name,
                    icon=row.icon,
                    category=row.category,
                    color=CATEGORY_CONFIG.get(row.category, {}).get("color", "inkMedium"),
                    claimed_at=row.claimed_at
                )
            )
        
        # Build sorted category groups
        sorted_categories = sorted(
            achievements_by_category.keys(),
            key=lambda c: CATEGORY_CONFIG.get(c, {}).get("order", 999)
        )
        for cat in sorted_categories:
            cat_config = CATEGORY_CONFIG.get(cat, {"display_name": cat.title(), "icon": "star.fill"})
            achievement_groups.append(
                AchievementGroup(
                    category=cat,
                    display_name=cat_config["display_name"],
                    icon=cat_config["icon"],
                    achievements=achievements_by_category[cat]
                )
            )
    
    # Get subscriber customization data (server-driven)
    is_subscriber = _has_membership(db, user.id)
    subscriber_customization = _get_user_subscriber_customization(db, user.id) if is_subscriber else None
    
    return PlayerPublicProfile(
        id=user.id,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        current_kingdom_id=state.current_kingdom_id,
        current_kingdom_name=current_kingdom_name,
        hometown_kingdom_id=state.hometown_kingdom_id,
        ruled_kingdom_id=ruled_kingdom_id,
        ruled_kingdom_name=ruled_kingdom_name,
        level=state.level,
        reputation=reputation,
        skills_data=skills_data,
        equipment=equipment,
        pets=pets,
        achievement_groups=achievement_groups,
        is_subscriber=is_subscriber,
        subscriber_customization=subscriber_customization,
        total_checkins=total_checkins,
        total_conquests=total_conquests,
        kingdoms_ruled=kingdoms_ruled,
        coups_won=coups_won,
        contracts_completed=contracts_completed,
        activity=activity,
        last_login=user.last_login,
        created_at=user.created_at
    )


# ============================================================
# SUBSCRIBER SETTINGS ENDPOINTS
# ============================================================

@router.get("/me/subscriber-settings", response_model=SubscriberSettings)
def get_subscriber_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's subscriber settings."""
    is_subscriber = _has_membership(db, current_user.id)
    prefs = _get_user_preferences(db, current_user.id)
    selected_title = _get_user_selected_title(db, current_user.id)
    
    # Build available styles list
    available_styles = [
        StylePreset(id=sid, name=s["name"], background_color=s["background"], text_color=s["text"])
        for sid, s in STYLE_PRESETS.items()
    ]
    
    # Get available titles (claimed achievements)
    available_titles = []
    achievements_query = text("""
        SELECT DISTINCT ON (ad.achievement_type)
            ad.id, ad.display_name, ad.icon
        FROM player_achievement_claims pac
        JOIN achievement_definitions ad ON ad.id = pac.achievement_tier_id
        WHERE pac.user_id = :user_id
        ORDER BY ad.achievement_type, ad.tier DESC
    """)
    for row in db.execute(achievements_query, {"user_id": current_user.id}).fetchall():
        available_titles.append(TitleData(achievement_id=row.id, display_name=row.display_name, icon=row.icon or "star.fill"))
    
    return SubscriberSettings(
        is_subscriber=is_subscriber,
        icon_style=_get_style_preset(prefs.icon_style) if prefs else None,
        card_style=_get_style_preset(prefs.card_style) if prefs else None,
        selected_title=selected_title,
        available_styles=available_styles,
        available_titles=available_titles
    )


@router.put("/me/subscriber-settings", response_model=SubscriberSettings)
def update_subscriber_settings(
    settings: SubscriberSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update subscriber settings. Requires active subscription."""
    from db.models import UserPreferences
    
    if not _has_membership(db, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Active subscription required")
    
    prefs = db.query(UserPreferences).filter(UserPreferences.user_id == current_user.id).first()
    if not prefs:
        prefs = UserPreferences(user_id=current_user.id)
        db.add(prefs)
    
    # Update styles (validate they exist, empty string or None clears the style)
    icon_style = settings.icon_style_id if settings.icon_style_id else None
    if icon_style and icon_style not in STYLE_PRESETS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid icon style: {icon_style}")
    prefs.icon_style = icon_style
    
    card_style = settings.card_style_id if settings.card_style_id else None
    if card_style and card_style not in STYLE_PRESETS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid card style: {card_style}")
    prefs.card_style = card_style
    
    # Update title
    if settings.selected_title_achievement_id is not None:
        if settings.selected_title_achievement_id == 0:
            prefs.selected_title_achievement_id = None
        else:
            claim_check = db.execute(text("""
                SELECT 1 FROM player_achievement_claims pac
                JOIN achievement_definitions ad ON ad.id = pac.achievement_tier_id
                WHERE pac.user_id = :user_id AND ad.id = :achievement_id
            """), {"user_id": current_user.id, "achievement_id": settings.selected_title_achievement_id}).fetchone()
            
            if not claim_check:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Achievement not claimed")
            prefs.selected_title_achievement_id = settings.selected_title_achievement_id
    
    db.commit()
    return get_subscriber_settings(current_user, db)

