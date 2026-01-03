"""
Player state endpoints - Sync, load, save player data
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, PlayerState as DBPlayerState, Kingdom, Property
from schemas import PlayerState, PlayerStateUpdate, SyncRequest, SyncResponse
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from config import DEV_MODE
from routers.actions.training import calculate_training_cost
from routers.actions.utils import get_equipped_items, get_inventory

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


def player_state_to_response(user: User, state: DBPlayerState, db: Session, travel_event=None) -> PlayerState:
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
    
    # Calculate ruler status dynamically from Kingdom table (SOURCE OF TRUTH)
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()
    fiefs_ruled = [kingdom.id for kingdom in ruled_kingdoms]
    is_ruler = len(fiefs_ruled) > 0
    kingdoms_ruled_count = len(fiefs_ruled)
    
    # Get equipped items and inventory from player_items table
    equipped = get_equipped_items(db, user.id)
    inventory = get_inventory(db, user.id)
    
    return PlayerState(
        id=user.id,
        display_name=user.display_name,
        email=user.email,
        avatar_url=user.avatar_url,
        
        # Kingdom & Territory
        hometown_kingdom_id=state.hometown_kingdom_id,
        origin_kingdom_id=None,  # Removed from schema (was for first 300+ rep kingdom)
        home_kingdom_id=None,  # Removed from schema (was for most check-ins)
        current_kingdom_id=state.current_kingdom_id,
        
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
        
        # Reputation (NOTE: Now per-kingdom in user_kingdoms table - defaulting here)
        reputation=0,  # TODO: fetch from user_kingdoms for current kingdom
        honor=100,  # Removed from schema
        kingdom_reputation={},  # Removed from schema
        
        # Check-in tracking (NOTE: moved to user_kingdoms table)
        check_in_history={},  # Removed from schema
        last_check_in=None,  # TODO: fetch from user_kingdoms
        last_daily_check_in=None,  # TODO: implement if needed
        
        # Activity tracking (NOTE: computed from other tables)
        total_checkins=0,  # TODO: compute from user_kingdoms
        total_conquests=0,  # TODO: compute from kingdom_history
        kingdoms_ruled=kingdoms_ruled_count,
        coups_won=0,  # TODO: compute from coup_events
        coups_failed=0,  # TODO: compute from coup_events
        times_executed=0,  # TODO: compute from coup_events
        executions_ordered=0,  # TODO: compute from coup_events
        last_coup_attempt=None,  # TODO: fetch from coup_events
        
        # Contract & Work
        contracts_completed=0,  # TODO: compute from contract_contributions
        total_work_contributed=0,  # TODO: compute from contract_contributions
        total_training_purchases=total_trainings,
        
        # Resources
        iron=state.iron,
        steel=state.steel,
        
        # Daily Actions (NOTE: moved to action_cooldowns table)
        last_mining_action=None,  # Removed from schema
        last_crafting_action=None,  # Removed from schema
        last_building_action=None,  # Removed from schema
        last_spy_action=None,  # Removed from schema
        
        # Equipment (from player_items table)
        equipped_weapon=equipped["equipped_weapon"],
        equipped_armor=equipped["equipped_armor"],
        equipped_shield=equipped["equipped_shield"],
        inventory=inventory,
        crafting_queue=[],  # TODO: fetch from unified_contracts
        crafting_progress={},  # Removed (tracked in unified_contracts)
        
        # Properties (from properties table - TODO: query from properties table)
        properties=[],
        
        # Rewards (removed - dead code)
        total_rewards_received=0,
        last_reward_received=None,
        last_reward_amount=0,
        
        # Status
        is_alive=state.is_alive,
        is_ruler=is_ruler,
        is_verified=user.is_verified,
        
        # Timestamps
        created_at=state.created_at,
        updated_at=state.updated_at,
        last_login=user.last_login,
        
        # Training costs (dynamically calculated)
        training_costs=training_costs,
        
        # Travel event (if provided)
        travel_event=travel_event,
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
    travel_event = None
    
    # Auto check-in if kingdom_id provided
    if kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
        if kingdom:
            # Check if entering a NEW kingdom (for travel fee)
            is_entering_new_kingdom = state.current_kingdom_id != kingdom.id
            
            travel_fee_paid = 0
            free_travel_reason = None
            
            # Charge travel fee if entering new kingdom (not ruler or property owner)
            if is_entering_new_kingdom and kingdom.travel_fee > 0:
                # Check if player is ruler (rulers don't pay)
                is_ruler = kingdom.ruler_id == current_user.id
                
                # Check if player owns property in this kingdom (property owners don't pay)
                owns_property = db.query(Property).filter(
                    Property.kingdom_id == kingdom.id,
                    Property.owner_id == current_user.id
                ).first() is not None
                
                # Check if player's empire is allied with target kingdom's empire
                home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first() if state.hometown_kingdom_id else None
                is_allied = home_kingdom and are_empires_allied(
                    db,
                    home_kingdom.empire_id or home_kingdom.id,
                    kingdom.empire_id or kingdom.id
                )
                
                if is_ruler:
                    free_travel_reason = "ruler"
                    print(f"👑 {current_user.display_name} rules {kingdom.name} - no travel fee")
                elif owns_property:
                    free_travel_reason = "property_owner"
                    print(f"🏠 {current_user.display_name} owns property in {kingdom.name} - no travel fee")
                elif is_allied:
                    free_travel_reason = "allied"
                    print(f"🤝 {current_user.display_name} is from allied empire - no travel fee in {kingdom.name}")
                else:
                    # Check if player has enough gold
                    if state.gold < kingdom.travel_fee:
                        raise HTTPException(
                            status_code=status.HTTP_402_PAYMENT_REQUIRED,
                            detail=f"Insufficient gold. Need {kingdom.travel_fee}g to enter {kingdom.name}"
                        )
                    
                    # Charge travel fee
                    travel_fee_paid = kingdom.travel_fee
                    state.gold -= kingdom.travel_fee
                    kingdom.treasury_gold += kingdom.travel_fee
                    print(f"💰 {current_user.display_name} paid {kingdom.travel_fee}g travel fee to enter {kingdom.name}")
            
            # Update current kingdom IMMEDIATELY (even if on cooldown)
            # This prevents charging travel fee multiple times
            if is_entering_new_kingdom:
                state.current_kingdom_id = kingdom.id
                state.last_check_in = datetime.utcnow()
                
                # Update check-in history for tracking purposes
                check_in_history = state.check_in_history or {}
                check_in_history[kingdom.id] = check_in_history.get(kingdom.id, 0) + 1
                state.check_in_history = check_in_history
                state.total_checkins += 1
                
                # Update kingdom activity
                kingdom.last_activity = datetime.utcnow()
                
                print(f"📍 {current_user.display_name} entered {kingdom.name}")
                
                # Create travel event for response
                from schemas.user import TravelEvent
                travel_event = TravelEvent(
                    entered_kingdom=True,
                    kingdom_name=kingdom.name,
                    travel_fee_paid=travel_fee_paid,
                    free_travel_reason=free_travel_reason
                )
            
            # Commit changes (travel fee and/or current_kingdom_id update)
            db.commit()
            db.refresh(state)
    
    return player_state_to_response(current_user, state, db, travel_event)


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
    
    return player_state_to_response(current_user, state, db)


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
        player_state=player_state_to_response(current_user, state, db),
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
    state.current_kingdom_id = None
    state.kingdoms_ruled = 0
    
    # Reset resources
    state.iron = 0
    state.steel = 0
    
    # NOTE: The following have been moved to other tables and can't be reset here:
    # - coup stats: now in coup_events table
    # - equipment/inventory: now in player_items table
    # - properties: now in properties table
    # - cooldowns: now in action_cooldowns table
    # - contracts: now in unified_contracts table
    
    # Reset status
    state.is_alive = True
    
    state.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(state)
    
    return {
        "success": True,
        "message": "Player state reset to defaults",
        "player_state": player_state_to_response(current_user, state, db)
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

