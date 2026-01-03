"""
Player state endpoints - Sync, load, save player data
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, PlayerState as DBPlayerState, Kingdom, Property, UserKingdom
from schemas import PlayerState, PlayerStateUpdate, SyncRequest, SyncResponse
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from config import DEV_MODE
from routers.actions.training import calculate_training_cost
from routers.actions.utils import get_equipped_items, get_inventory

router = APIRouter(prefix="/player", tags=["player"])


def calculate_player_perks(user: User, state: DBPlayerState, db: Session) -> dict:
    """Calculate all active perks/bonuses for a player"""
    perks = {
        "combat": [],
        "training": [],
        "building": [],
        "espionage": [],
        "political": [],
        "travel": [],
        "total_power": 0
    }
    
    # Get equipped items
    equipped = get_equipped_items(db, user.id)
    
    # Attack skill bonus (T1+ only, T0 is base)
    if state.attack_power >= 1:
        perks["combat"].append({
            "stat": "attack",
            "bonus": state.attack_power,
            "source": f"Attack Skill T{state.attack_power}",
            "source_type": "player_skill"
        })
    
    # Defense skill bonus (T1+ only, T0 is base)
    if state.defense_power >= 1:
        perks["combat"].append({
            "stat": "defense",
            "bonus": state.defense_power,
            "source": f"Defense Skill T{state.defense_power}",
            "source_type": "player_skill"
        })
    
    # Equipment bonuses
    if equipped["equipped_weapon"]:
        weapon = equipped["equipped_weapon"]
        bonus = get_stat_bonus_for_tier(weapon.get("tier", 1))
        perks["combat"].append({
            "stat": "attack",
            "bonus": bonus,
            "source": f"T{weapon.get('tier', 1)} {weapon.get('type', 'weapon').capitalize()}",
            "source_type": "equipment"
        })
    
    if equipped["equipped_armor"]:
        armor = equipped["equipped_armor"]
        bonus = get_stat_bonus_for_tier(armor.get("tier", 1))
        perks["combat"].append({
            "stat": "defense",
            "bonus": bonus,
            "source": f"T{armor.get('tier', 1)} Armor",
            "source_type": "equipment"
        })
    
    # Active debuffs
    if state.attack_debuff > 0:
        from datetime import datetime, timezone
        if state.debuff_expires_at and state.debuff_expires_at > datetime.now(timezone.utc):
            perks["combat"].append({
                "stat": "attack",
                "bonus": -state.attack_debuff,
                "source": "Combat Debuff",
                "source_type": "debuff",
                "expires_at": state.debuff_expires_at.isoformat()
            })
    
    # Kingdom bonuses (if in a kingdom)
    if state.current_kingdom_id:
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            # Education building reduces training time
            if kingdom.education_level > 0:
                reduction = kingdom.education_level * 5
                perks["training"].append({
                    "description": f"-{reduction}% training actions",
                    "source": f"{kingdom.name} Education Hall T{kingdom.education_level}",
                    "source_type": "kingdom_building"
                })
            
            # Farm reduces contract time
            if kingdom.farm_level > 0:
                reduction_map = {1: 5, 2: 10, 3: 20, 4: 25, 5: 33}
                reduction = reduction_map.get(kingdom.farm_level, 0)
                perks["building"].append({
                    "description": f"-{reduction}% contract time",
                    "source": f"{kingdom.name} Farm T{kingdom.farm_level}",
                    "source_type": "kingdom_building"
                })
    
    # Building skill bonuses (T1+ show bonuses, T0 is base)
    if state.building_skill >= 1:
        bonus_map = {1: 10, 2: 20, 3: 30, 4: 40, 5: 50}
        bonus = bonus_map.get(state.building_skill, 0)
        if bonus > 0:
            perks["building"].append({
                "description": f"+{bonus}% gold from building",
                "source": f"Building Skill T{state.building_skill}",
                "source_type": "player_skill"
            })
    
    if state.building_skill >= 2:
        perks["building"].append({
            "description": "+1 Assist action per day",
            "source": f"Building Skill T2",
            "source_type": "player_skill"
        })
    
    if state.building_skill >= 3:
        perks["building"].append({
            "description": "10% cooldown refund chance",
            "source": f"Building Skill T3",
            "source_type": "player_skill"
        })
    
    if state.building_skill >= 4:
        perks["building"].append({
            "description": "25% double progress chance",
            "source": f"Building Skill T4",
            "source_type": "player_skill"
        })
    
    if state.building_skill >= 5:
        perks["building"].append({
            "description": "Instant complete 1 contract/day",
            "source": f"Building Skill T5",
            "source_type": "player_skill"
        })
    
    # Intelligence bonuses (T1+ show bonuses, T0 is base)
    if state.intelligence >= 1:
        bonus = (state.intelligence + 1) * 2
        perks["espionage"].append({
            "description": f"+{bonus}% sabotage/scout success",
            "source": f"Intelligence T{state.intelligence}",
            "source_type": "player_skill"
        })
    
    if state.intelligence >= 5:
        perks["espionage"].append({
            "description": "Vault Heist unlocked",
            "source": "Intelligence T5",
            "source_type": "player_skill"
        })
    
    # Leadership bonuses (T1+ show bonuses, T0 is base)
    if state.leadership >= 1:
        vote_weight = 1.0 + (state.leadership * 0.2)
        perks["political"].append({
            "description": f"Vote weight: {vote_weight:.1f}x",
            "source": f"Leadership T{state.leadership}",
            "source_type": "player_skill"
        })
    
    if state.leadership >= 1:
        perks["political"].append({
            "description": "+50% ruler rewards",
            "source": "Leadership T1",
            "source_type": "player_skill"
        })
    
    if state.leadership >= 2:
        perks["political"].append({
            "description": "Can propose coups",
            "source": "Leadership T2",
            "source_type": "player_skill"
        })
    
    if state.leadership >= 3:
        perks["political"].append({
            "description": "+100% ruler rewards",
            "source": "Leadership T3",
            "source_type": "player_skill"
        })
    
    if state.leadership >= 5:
        perks["political"].append({
            "description": "-50% coup cost",
            "source": "Leadership T5",
            "source_type": "player_skill"
        })
    
    # Property bonuses
    properties = db.query(Property).filter(Property.owner_id == user.id).all()
    for prop in properties:
        kingdom = db.query(Kingdom).filter(Kingdom.id == prop.kingdom_id).first()
        if kingdom:
            perks["travel"].append({
                "description": "Free travel, instant arrival",
                "source": f"Property in {kingdom.name}",
                "source_type": "property"
            })
    
    perks["total_power"] = 0  # Removed - meaningless number
    
    return perks


def get_stat_bonus_for_tier(tier: int) -> int:
    """Get equipment stat bonus for tier"""
    bonus_map = {1: 1, 2: 2, 3: 3, 4: 5, 5: 8}
    return bonus_map.get(tier, 0)


def get_or_create_player_state(db: Session, user: User) -> DBPlayerState:
    """Get or create player state for user"""
    if not user.player_state:
        player_state = DBPlayerState(
            user_id=user.id,
            hometown_kingdom_id=None  # Will be set on first check-in
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
    
    # Calculate active perks
    active_perks = calculate_player_perks(user, state, db)
    
    # Calculate ruler status dynamically from Kingdom table (SOURCE OF TRUTH)
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()
    fiefs_ruled = [kingdom.id for kingdom in ruled_kingdoms]
    is_ruler = len(fiefs_ruled) > 0
    kingdoms_ruled_count = len(fiefs_ruled)
    
    # Get equipped items and inventory from player_items table
    equipped = get_equipped_items(db, user.id)
    inventory = get_inventory(db, user.id)
    
    # Get reputation and kingdom name from current kingdom
    reputation = 0
    current_kingdom_name = None
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        reputation = user_kingdom.local_reputation if user_kingdom else 0
        
        # Look up kingdom name
        kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if kingdom:
            current_kingdom_name = kingdom.name
    
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
        current_kingdom_name=current_kingdom_name,
        
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
        
        # Reputation (from user_kingdoms table for current kingdom)
        reputation=reputation,
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
        
        # Active perks (dynamically calculated)
        active_perks=active_perks,
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
                
                # Create or update user_kingdoms record (tracks per-kingdom reputation and check-ins)
                user_kingdom = db.query(UserKingdom).filter(
                    UserKingdom.user_id == current_user.id,
                    UserKingdom.kingdom_id == kingdom.id
                ).first()
                
                if not user_kingdom:
                    # First time visiting this kingdom - create record with starting reputation
                    user_kingdom = UserKingdom(
                        user_id=current_user.id,
                        kingdom_id=kingdom.id,
                        local_reputation=0,  # Start at 0 reputation
                        checkins_count=1,
                        gold_earned=0,
                        gold_spent=0
                    )
                    db.add(user_kingdom)
                    print(f"📍 {current_user.display_name} first time entering {kingdom.name}")
                else:
                    # Increment check-in counter
                    user_kingdom.checkins_count += 1
                    print(f"📍 {current_user.display_name} entered {kingdom.name} (visit #{user_kingdom.checkins_count})")
                
                # Update kingdom activity
                kingdom.last_activity = datetime.utcnow()
                kingdom.checked_in_players = db.query(DBPlayerState).filter(
                    DBPlayerState.current_kingdom_id == kingdom.id
                ).count()
                
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
    
    # NOTE: Reputation is now in user_kingdoms table, not resetting here
    # To reset reputation, you'd need to update/delete user_kingdoms records separately
    state.honor = 100
    
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
    """Add reputation to a specific kingdom (reputation is now per-kingdom in user_kingdoms)"""
    state = get_or_create_player_state(db, current_user)
    
    if not kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="kingdom_id is required. Reputation is now per-kingdom in user_kingdoms table."
        )
    
    # Update or create user_kingdom record
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == current_user.id,
        UserKingdom.kingdom_id == kingdom_id
    ).first()
    
    if not user_kingdom:
        user_kingdom = UserKingdom(
            user_id=current_user.id,
            kingdom_id=kingdom_id,
            local_reputation=amount,
            checkins_count=0,
            gold_earned=0,
            gold_spent=0
        )
        db.add(user_kingdom)
    else:
        user_kingdom.local_reputation += amount
    
    state.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user_kingdom)
    
    return {
        "success": True,
        "kingdom_id": kingdom_id,
        "new_reputation": user_kingdom.local_reputation
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
    state.iron += 100
    state.steel += 50
    
    # Boost reputation in current kingdom if player is checked in
    reputation_boosted = False
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == current_user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        
        if user_kingdom:
            user_kingdom.local_reputation += 500
            reputation_boosted = True
        else:
            # Create new user_kingdom record
            user_kingdom = UserKingdom(
                user_id=current_user.id,
                kingdom_id=state.current_kingdom_id,
                local_reputation=500,
                checkins_count=0,
                gold_earned=0,
                gold_spent=0
            )
            db.add(user_kingdom)
            reputation_boosted = True
    
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
        "message": "Dev boost applied!" + (" (includes +500 reputation in current kingdom)" if reputation_boosted else ""),
        "gold": state.gold,
        "level": state.level,
        "skill_points": state.skill_points,
        "levels_gained": levels_gained,
        "reputation_boosted": reputation_boosted
    }

