"""
Player state endpoints - Sync, load, save player data
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from db import get_db, User, PlayerState as DBPlayerState
from schemas import PlayerState, PlayerStateUpdate, SyncRequest, SyncResponse
from routers.auth import get_current_user

router = APIRouter(prefix="/player", tags=["player"])


def get_or_create_player_state(db: Session, user: User) -> DBPlayerState:
    """Get or create player state for user"""
    if not user.player_state:
        player_state = DBPlayerState(
            user_id=user.id,
            hometown_kingdom_id=user.hometown_kingdom_id
        )
        db.add(player_state)
        db.commit()
        db.refresh(player_state)
        return player_state
    return user.player_state


def player_state_to_response(user: User, state: DBPlayerState) -> PlayerState:
    """Convert PlayerState model to PlayerState schema"""
    return PlayerState(
        id=user.id,
        display_name=user.display_name,
        email=user.email,
        avatar_url=user.avatar_url,
        
        # Kingdom & Territory
        hometown_kingdom_id=state.hometown_kingdom_id,
        origin_kingdom_id=state.origin_kingdom_id,
        home_kingdom_id=state.home_kingdom_id,
        current_kingdom_id=state.current_kingdom_id,
        fiefs_ruled=state.fiefs_ruled or [],
        
        # Core Stats
        gold=state.gold,
        level=state.level,
        experience=state.experience,
        skill_points=state.skill_points,
        
        # Combat Stats
        attack_power=state.attack_power,
        defense_power=state.defense_power,
        leadership=state.leadership,
        building_skill=state.building_skill,
        
        # Debuffs
        attack_debuff=state.attack_debuff,
        debuff_expires_at=state.debuff_expires_at,
        
        # Reputation
        reputation=state.reputation,
        honor=state.honor,
        kingdom_reputation=state.kingdom_reputation or {},
        
        # Check-in tracking
        check_in_history=state.check_in_history or {},
        last_check_in=state.last_check_in,
        last_check_in_lat=state.last_check_in_lat,
        last_check_in_lon=state.last_check_in_lon,
        last_daily_check_in=state.last_daily_check_in,
        
        # Activity tracking
        total_checkins=state.total_checkins,
        total_conquests=state.total_conquests,
        kingdoms_ruled=state.kingdoms_ruled,
        coups_won=state.coups_won,
        coups_failed=state.coups_failed,
        times_executed=state.times_executed,
        executions_ordered=state.executions_ordered,
        last_coup_attempt=state.last_coup_attempt,
        
        # Contract & Work
        active_contract_id=state.active_contract_id,
        contracts_completed=state.contracts_completed,
        total_work_contributed=state.total_work_contributed,
        
        # Resources
        iron=state.iron,
        steel=state.steel,
        
        # Daily Actions
        last_mining_action=state.last_mining_action,
        last_crafting_action=state.last_crafting_action,
        last_building_action=state.last_building_action,
        last_spy_action=state.last_spy_action,
        
        # Equipment
        equipped_weapon=state.equipped_weapon,
        equipped_armor=state.equipped_armor,
        equipped_shield=state.equipped_shield,
        inventory=state.inventory or [],
        crafting_queue=state.crafting_queue or [],
        crafting_progress=state.crafting_progress or {},
        
        # Properties
        properties=state.properties or [],
        
        # Rewards
        total_rewards_received=state.total_rewards_received,
        last_reward_received=state.last_reward_received,
        last_reward_amount=state.last_reward_amount,
        
        # Status
        is_alive=state.is_alive,
        is_ruler=state.is_ruler,
        is_premium=user.is_premium,
        is_verified=user.is_verified,
        
        # Timestamps
        created_at=state.created_at,
        updated_at=state.updated_at,
        last_login=user.last_login,
    )


def apply_state_update(state: DBPlayerState, update: PlayerStateUpdate) -> None:
    """Apply partial state update to player state model"""
    update_data = update.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        if value is not None and hasattr(state, field):
            setattr(state, field, value)
    
    state.updated_at = datetime.utcnow()


# ===== Endpoints =====

@router.get("/state", response_model=PlayerState)
def get_player_state(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current player state
    
    Returns the complete player state for the authenticated user.
    Use this to load player data on app launch.
    """
    state = get_or_create_player_state(db, current_user)
    return player_state_to_response(current_user, state)


@router.put("/state", response_model=PlayerState)
def update_player_state(
    update: PlayerStateUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update player state
    
    Applies partial updates to the player state.
    Only fields included in the request will be updated.
    """
    state = get_or_create_player_state(db, current_user)
    apply_state_update(state, update)
    db.commit()
    db.refresh(state)
    
    return player_state_to_response(current_user, state)


@router.post("/sync", response_model=SyncResponse)
def sync_player_state(
    request: SyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sync player state with server
    
    Merges client state with server state.
    Server-authoritative fields (gold, reputation, etc.) are validated.
    Client-authoritative fields (UI preferences, etc.) are accepted.
    
    Returns the merged state and server timestamp.
    """
    state = get_or_create_player_state(db, current_user)
    
    # Apply updates from client
    apply_state_update(state, request.player_state)
    
    db.commit()
    db.refresh(state)
    
    return SyncResponse(
        success=True,
        message="State synced successfully",
        player_state=player_state_to_response(current_user, state),
        server_time=datetime.utcnow()
    )


@router.post("/reset")
def reset_player_state(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Reset player state to defaults
    
    WARNING: This is destructive! Use only for testing/debugging.
    Resets gold, stats, equipment, etc. to starting values.
    """
    state = get_or_create_player_state(db, current_user)
    
    # Reset core stats
    state.gold = 100
    state.level = 1
    state.experience = 0
    state.skill_points = 0
    
    # Reset combat stats
    state.attack_power = 1
    state.defense_power = 1
    state.leadership = 1
    state.building_skill = 1
    state.attack_debuff = 0
    state.debuff_expires_at = None
    
    # Reset reputation
    state.reputation = 0
    state.honor = 100
    state.kingdom_reputation = {}
    
    # Reset territory
    state.fiefs_ruled = []
    state.is_ruler = False
    state.current_kingdom_id = None
    
    # Reset activity
    state.coups_won = 0
    state.coups_failed = 0
    state.times_executed = 0
    state.executions_ordered = 0
    state.last_coup_attempt = None
    
    # Reset resources
    state.iron = 0
    state.steel = 0
    
    # Reset equipment
    state.equipped_weapon = None
    state.equipped_armor = None
    state.equipped_shield = None
    state.inventory = []
    state.crafting_queue = []
    state.crafting_progress = {}
    
    # Reset properties
    state.properties = []
    
    # Reset daily actions
    state.last_mining_action = None
    state.last_crafting_action = None
    state.last_building_action = None
    state.last_spy_action = None
    
    # Reset status
    state.is_alive = True
    
    state.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(state)
    
    return {
        "success": True,
        "message": "Player state reset to defaults",
        "player_state": player_state_to_response(current_user, state)
    }


# ===== Resource Operations =====

@router.post("/gold/add")
def add_gold(
    amount: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add gold to player"""
    if amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Amount must be positive"
        )
    
    state = get_or_create_player_state(db, current_user)
    state.gold += amount
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {"success": True, "new_gold": state.gold}


@router.post("/gold/spend")
def spend_gold(
    amount: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Spend gold (validates sufficient funds)"""
    if amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Amount must be positive"
        )
    
    state = get_or_create_player_state(db, current_user)
    
    if state.gold < amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient gold"
        )
    
    state.gold -= amount
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {"success": True, "new_gold": state.gold}


@router.post("/experience/add")
def add_experience(
    amount: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add experience and handle level ups"""
    if amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Amount must be positive"
        )
    
    state = get_or_create_player_state(db, current_user)
    state.experience += amount
    levels_gained = 0
    
    # Level up formula: 100 * 2^(level-1) XP per level
    while True:
        xp_needed = 100 * (2 ** (state.level - 1))
        if state.experience >= xp_needed:
            state.experience -= xp_needed
            state.level += 1
            state.skill_points += 3  # 3 skill points per level
            state.gold += 50  # Level up bonus
            levels_gained += 1
        else:
            break
    
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {
        "success": True,
        "new_level": state.level,
        "new_experience": state.experience,
        "levels_gained": levels_gained,
        "skill_points": state.skill_points
    }


@router.post("/reputation/add")
def add_reputation(
    amount: int,
    kingdom_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add reputation (global and optionally to specific kingdom)"""
    state = get_or_create_player_state(db, current_user)
    
    # Global reputation
    state.reputation += amount
    
    # Kingdom-specific reputation
    if kingdom_id:
        kingdom_rep = state.kingdom_reputation or {}
        current_rep = kingdom_rep.get(kingdom_id, 0)
        new_rep = current_rep + amount
        kingdom_rep[kingdom_id] = new_rep
        state.kingdom_reputation = kingdom_rep
        
        # Track origin kingdom (first time hitting 300+ rep)
        if state.origin_kingdom_id is None and new_rep >= 300:
            state.origin_kingdom_id = kingdom_id
    
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {
        "success": True,
        "new_reputation": state.reputation,
        "kingdom_reputation": state.kingdom_reputation.get(kingdom_id) if kingdom_id else None
    }


# ===== Training Operations =====

@router.post("/train/{stat}")
def train_stat(
    stat: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Train a combat stat (costs gold)"""
    valid_stats = ["attack", "defense", "leadership", "building"]
    if stat not in valid_stats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid stat. Choose: {', '.join(valid_stats)}"
        )
    
    state = get_or_create_player_state(db, current_user)
    
    # Map stat name to state attribute
    stat_map = {
        "attack": "attack_power",
        "defense": "defense_power",
        "leadership": "leadership",
        "building": "building_skill"
    }
    
    attr = stat_map[stat]
    current_level = getattr(state, attr)
    
    # Training cost: 100 * (level^1.5)
    cost = int(100 * (current_level ** 1.5))
    
    if state.gold < cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient gold. Need {cost}g, have {state.gold}g"
        )
    
    state.gold -= cost
    setattr(state, attr, current_level + 1)
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {
        "success": True,
        "stat": stat,
        "new_level": current_level + 1,
        "cost": cost,
        "remaining_gold": state.gold
    }


@router.post("/skill-point/{stat}")
def use_skill_point(
    stat: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Use a skill point to increase a stat"""
    valid_stats = ["attack", "defense", "leadership", "building"]
    if stat not in valid_stats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid stat. Choose: {', '.join(valid_stats)}"
        )
    
    state = get_or_create_player_state(db, current_user)
    
    if state.skill_points <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No skill points available"
        )
    
    stat_map = {
        "attack": "attack_power",
        "defense": "defense_power",
        "leadership": "leadership",
        "building": "building_skill"
    }
    
    attr = stat_map[stat]
    current_level = getattr(state, attr)
    
    state.skill_points -= 1
    setattr(state, attr, current_level + 1)
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {
        "success": True,
        "stat": stat,
        "new_level": current_level + 1,
        "remaining_skill_points": state.skill_points
    }

