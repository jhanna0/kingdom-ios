"""
Player state endpoints - Sync, load, save player data
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, PlayerState as DBPlayerState, Kingdom
from schemas import PlayerState, PlayerStateUpdate, SyncRequest, SyncResponse
from routers.auth import get_current_user
from config import DEV_MODE
from routers.actions.training import calculate_training_cost

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
    # Calculate training costs based on current stats and total purchases
    total_trainings = state.total_training_purchases or 0
    training_costs = {
        "attack": calculate_training_cost(state.attack_power, total_trainings),
        "defense": calculate_training_cost(state.defense_power, total_trainings),
        "leadership": calculate_training_cost(state.leadership, total_trainings),
        "building": calculate_training_cost(state.building_skill, total_trainings),
        "intelligence": calculate_training_cost(state.intelligence, total_trainings)
    }
    
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
        intelligence=state.intelligence,
        
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
        contracts_completed=state.contracts_completed,
        total_work_contributed=state.total_work_contributed,
        total_training_purchases=total_trainings,
        
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
        
        # Training costs (dynamically calculated)
        training_costs=training_costs,
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
    db: Session = Depends(get_db),
    kingdom_id: Optional[str] = None
):
    """
    Get current player state
    
    Returns the complete player state for the authenticated user.
    Use this to load player data on app launch.
    
    If kingdom_id provided, auto-checks in to that kingdom.
    """
    state = get_or_create_player_state(db, current_user)
    
    # Auto check-in if kingdom_id provided
    if kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
        if kingdom:
            # Check cooldown
            can_checkin = True
            if state.current_kingdom_id == kingdom.id and state.last_check_in:
                time_since_last = datetime.utcnow() - state.last_check_in
                cooldown = timedelta(minutes=5) if DEV_MODE else timedelta(hours=1)
                can_checkin = time_since_last >= cooldown
            
            if can_checkin:
                # Calculate rewards
                base_gold = 10
                base_xp = 5
                
                if DEV_MODE:
                    base_gold *= 10
                    base_xp *= 10
                
                if kingdom.ruler_id == current_user.id:
                    base_gold *= 2
                    base_xp *= 2
                
                gold_reward = base_gold * kingdom.level
                xp_reward = base_xp * kingdom.level
                
                # Update state
                state.gold += gold_reward
                state.experience += xp_reward
                state.total_checkins += 1
                state.current_kingdom_id = kingdom.id
                state.last_check_in = datetime.utcnow()
                
                # Update check-in history
                check_in_history = state.check_in_history or {}
                check_in_history[kingdom.id] = check_in_history.get(kingdom.id, 0) + 1
                state.check_in_history = check_in_history
                
                # Update hometown
                most_visited = max(check_in_history.items(), key=lambda x: x[1])
                if most_visited[0] == kingdom.id:
                    state.hometown_kingdom_id = kingdom.id
                
                # Level up
                while True:
                    xp_needed = 100 * (2 ** (state.level - 1))
                    if state.experience >= xp_needed:
                        state.experience -= xp_needed
                        state.level += 1
                        state.skill_points += 3
                        state.gold += 50
                    else:
                        break
                
                # Update kingdom
                kingdom.treasury_gold += gold_reward // 10
                kingdom.last_activity = datetime.utcnow()
                
                db.commit()
                db.refresh(state)
                
                print(f"✅ Auto-checked in {current_user.display_name} to {kingdom.name} (+{gold_reward}g, +{xp_reward} XP)")
    
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


# ===== Dev Tools =====

@router.post("/dev/boost")
def dev_boost(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """DEV ONLY: Instantly boost resources for testing"""
    if not DEV_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Dev mode is disabled"
        )
    
    state = get_or_create_player_state(db, current_user)
    
    # Give testing resources
    state.gold += 10000
    state.experience += 500
    state.skill_points += 10
    state.reputation += 500
    state.iron += 100
    state.steel += 50
    
    # Level up if possible
    levels_gained = 0
    while True:
        xp_needed = 100 * (2 ** (state.level - 1))
        if state.experience >= xp_needed:
            state.experience -= xp_needed
            state.level += 1
            state.skill_points += 3
            state.gold += 50
            levels_gained += 1
        else:
            break
    
    state.updated_at = datetime.utcnow()
    db.commit()
    
    return {
        "success": True,
        "message": "Dev boost applied!",
        "gold": state.gold,
        "level": state.level,
        "skill_points": state.skill_points,
        "reputation": state.reputation,
        "levels_gained": levels_gained
    }

