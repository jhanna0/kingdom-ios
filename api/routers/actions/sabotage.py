"""
Sabotage action - Disrupt enemy kingdom contracts
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
import random
import math

from db import get_db, User, Kingdom, Contract, PlayerState, ActionCooldown
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from config import DEV_MODE
from .utils import check_cooldown, check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown, get_cooldown
from .constants import WORK_BASE_COOLDOWN, SABOTAGE_COOLDOWN
from .tax_utils import apply_kingdom_tax


router = APIRouter()


# ==========================================
# SABOTAGE CONFIGURATION - TUNE THESE VALUES
# ==========================================

# Economic balance
SABOTAGE_COST = 300           # Gold cost to attempt sabotage (always paid upfront)
SABOTAGE_GOLD_REWARD = 100    # Gold reward for successful sabotage
SABOTAGE_REP_REWARD = 50      # Reputation gained in hometown for success
PATROL_BOUNTY = 150           # Gold bounty paid to patrol who catches saboteur
PATROL_REP_REWARD = 50        # Reputation gained by patrol for catching saboteur

# Consequences
BAN_ON_CAUGHT = True          # Whether to ban saboteur from kingdom when caught
REPUTATION_LOSS = 200         # Reputation lost in target kingdom when caught

# Effects
SABOTAGE_DELAY_PERCENT = 0.1  # Percentage of actions added to contract (10% = 0.1)

# Cooldown
SABOTAGE_COOLDOWN_HOURS = 24  # Hours between sabotage attempts

# Detection mechanics (see calculate_detection_chance function for details)
BASE_DETECTION_PER_PATROL = 0.005  # 0.5% base detection chance per patrol
SKILL_REDUCTION_PER_LEVEL = 0.0005  # 0.05% detection reduction per building skill above 3
INTELLIGENCE_REDUCTION_PER_LEVEL = 0.02  # 2% detection reduction per intelligence level
MIN_DETECTION_CHANCE = 0.00001      # Minimum detection chance (0.001%)

# ==========================================


def calculate_detection_chance(
    active_patrols: int,
    city_population: int,
    saboteur_building_skill: int,
    saboteur_intelligence: int = 1,
    avg_patrol_intelligence: float = 1.0
) -> float:
    """
    Calculate chance of being caught by patrols
    
    Formula:
    - Base detection: 0.5% per patrol
    - City size scaling: baseDetection / sqrt(totalActivePlayersInCity)
    - Saboteur skill reduction: -0.05% per building skill level above 3
    - Saboteur intelligence: -2% per intelligence level (reduces detection)
    - Patrol intelligence: +2% per avg intelligence level (increases detection)
    
    Intelligence tiers (both sides):
    - T1: 2% effect
    - T2: 4% effect
    - T3: 6% effect
    - T4: 8% effect
    - T5: 10% effect
    
    Returns: probability of being caught (0.0 to 1.0)
    
    TUNE THIS METHOD to adjust sabotage success rates
    """
    if active_patrols == 0:
        return 0.0
    
    # Scale by city population (higher pop = harder to detect individual)
    # Minimum population of 1 to avoid division by zero
    population_scaling = 1.0 / math.sqrt(max(1, city_population))
    
    # Saboteur skill reduction (per level above 3)
    skill_levels_above_3 = max(0, saboteur_building_skill - 3)
    skill_reduction = skill_levels_above_3 * SKILL_REDUCTION_PER_LEVEL
    
    # Calculate per-patrol detection chance
    detection_per_patrol = max(
        MIN_DETECTION_CHANCE,
        (BASE_DETECTION_PER_PATROL * population_scaling) - skill_reduction
    )
    
    # Each patrol rolls independently
    # Total chance = 1 - (chance of avoiding all patrols)
    avoid_all_chance = (1.0 - detection_per_patrol) ** active_patrols
    total_detection_chance = 1.0 - avoid_all_chance
    
    # Apply intelligence modifiers (multiplicative)
    # Saboteur intelligence reduces detection
    saboteur_intelligence_multiplier = 1.0 - (saboteur_intelligence * INTELLIGENCE_REDUCTION_PER_LEVEL)
    saboteur_intelligence_multiplier = max(0.0, saboteur_intelligence_multiplier)
    
    # Patrol intelligence increases detection
    patrol_intelligence_multiplier = 1.0 + (avg_patrol_intelligence * INTELLIGENCE_REDUCTION_PER_LEVEL)
    
    final_detection_chance = total_detection_chance * saboteur_intelligence_multiplier * patrol_intelligence_multiplier
    
    # Clamp between min and 100%
    return max(MIN_DETECTION_CHANCE, min(1.0, final_detection_chance))


def process_sabotage_attempt(
    db: Session,
    saboteur: User,
    saboteur_state: PlayerState,
    contract: Contract,
    kingdom: Kingdom,
    sabotage_cost: int
) -> dict:
    """
    Process a sabotage attempt with detection mechanics
    
    Returns dict with:
    - success: bool (True if sabotage succeeded, False if caught)
    - caught: bool (True if caught by patrol)
    - response: dict (full API response)
    
    TUNE THIS METHOD to adjust sabotage mechanics and consequences
    """
    # Get active patrols and their intelligence
    now = datetime.utcnow()
    
    # Get all players in this kingdom
    players_in_kingdom = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == contract.kingdom_id
    ).all()
    
    # Filter for those with active patrol cooldowns
    active_patrol_states = []
    for ps in players_in_kingdom:
        cooldown = get_cooldown(db, ps.user_id, "patrol")
        if cooldown and cooldown.expires_at and cooldown.expires_at > now:
            active_patrol_states.append(ps)
    
    active_patrols = len(active_patrol_states)
    
    # Calculate average patrol intelligence for detection bonus
    avg_patrol_intelligence = 1.0
    if active_patrols > 0:
        total_intel = sum(ps.intelligence for ps in active_patrol_states)
        avg_patrol_intelligence = total_intel / active_patrols
    
    # Get active player count for scaling
    active_player_count = max(1, kingdom.checked_in_players)
    
    # Calculate detection chance (with intelligence bonuses)
    detection_chance = calculate_detection_chance(
        active_patrols=active_patrols,
        city_population=active_player_count,
        saboteur_building_skill=saboteur_state.building_skill,
        saboteur_intelligence=saboteur_state.intelligence,
        avg_patrol_intelligence=avg_patrol_intelligence
    )
    
    # Roll for detection
    caught = random.random() < detection_chance
    
    if caught:
        return _handle_caught_saboteur(
            db=db,
            saboteur=saboteur,
            saboteur_state=saboteur_state,
            contract=contract,
            kingdom=kingdom,
            sabotage_cost=sabotage_cost,
            active_patrols=active_patrols,
            detection_chance=detection_chance
        )
    else:
        return _handle_successful_sabotage(
            db=db,
            saboteur=saboteur,
            saboteur_state=saboteur_state,
            contract=contract,
            kingdom=kingdom,
            sabotage_cost=sabotage_cost,
            detection_chance=detection_chance,
            active_patrols=active_patrols
        )


def _handle_caught_saboteur(
    db: Session,
    saboteur: User,
    saboteur_state: PlayerState,
    contract: Contract,
    kingdom: Kingdom,
    sabotage_cost: int,
    active_patrols: int,
    detection_chance: float
) -> dict:
    """Handle consequences when saboteur is caught"""
    # Find a random active patrol who caught them
    now = datetime.utcnow()
    
    # Get all players in this kingdom with active patrol cooldowns
    players_in_kingdom = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == contract.kingdom_id
    ).all()
    
    active_patrol_states = []
    for ps in players_in_kingdom:
        cooldown = get_cooldown(db, ps.user_id, "patrol")
        if cooldown and cooldown.expires_at and cooldown.expires_at > now:
            active_patrol_states.append(ps)
    
    catcher = random.choice(active_patrol_states) if active_patrol_states else None
    catcher_user = db.query(User).filter(User.id == catcher.user_id).first() if catcher else None
    
    # Ban the saboteur from this kingdom (if enabled)
    if BAN_ON_CAUGHT:
        banned_players = kingdom.banned_players or []
        if str(saboteur.id) not in banned_players:
            banned_players.append(str(saboteur.id))
            kingdom.banned_players = banned_players
    
    # TODO: Saboteur loses reputation in target kingdom (use user_kingdoms table)
    # Note: kingdom_reputation removed from player_state
    
    # Reward the patrol who caught them (with tax applied to bounty)
    if catcher:
        catcher.reputation += PATROL_REP_REWARD
        # Apply tax to patrol bounty
        net_bounty, bounty_tax, bounty_tax_rate = apply_kingdom_tax(
            db=db,
            kingdom_id=kingdom.id,
            player_state=catcher,
            gross_income=PATROL_BOUNTY
        )
        catcher.gold += net_bounty
    
    # Record failed sabotage
    game_data = saboteur_state.game_data or {}
    if 'sabotage_history' not in game_data:
        game_data['sabotage_history'] = []
    
    game_data['sabotage_history'].append({
        'kingdom_id': contract.kingdom_id,
        'kingdom_name': kingdom.name,
        'contract_id': contract.id,
        'timestamp': datetime.utcnow().isoformat(),
        'caught': True,
        'caught_by': catcher_user.username if catcher_user else 'patrol',
        'cost': sabotage_cost,
        'reputation_lost': REPUTATION_LOSS
    })
    
    if 'total_sabotages_caught' not in game_data:
        game_data['total_sabotages_caught'] = 0
    game_data['total_sabotages_caught'] += 1
    
    saboteur_state.game_data = game_data
    
    return {
        "success": False,
        "caught": True,
        "response": {
            "success": False,
            "caught": True,
            "message": f"Caught by {catcher_user.username if catcher_user else 'a patrol'}! You've been banned from this kingdom.",
            "detection": {
                "active_patrols": active_patrols,
                "detection_chance": f"{detection_chance * 100:.2f}%",
                "caught_by": catcher_user.username if catcher_user else "patrol"
            },
            "consequences": {
                "banned": BAN_ON_CAUGHT,
                "reputation_lost": REPUTATION_LOSS,
                "gold_lost": sabotage_cost,
                "patrol_reward": {
                    "gold": PATROL_BOUNTY,
                    "reputation": PATROL_REP_REWARD
                }
            },
            "next_sabotage_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=SABOTAGE_COOLDOWN_HOURS))
        }
    }


def _handle_successful_sabotage(
    db: Session,
    saboteur: User,
    saboteur_state: PlayerState,
    contract: Contract,
    kingdom: Kingdom,
    sabotage_cost: int,
    detection_chance: float,
    active_patrols: int
) -> dict:
    """Handle successful sabotage (not caught)"""
    # Calculate sabotage effect: Add X% more actions required
    delay_actions = int(contract.total_actions_required * SABOTAGE_DELAY_PERCENT)
    contract.total_actions_required += delay_actions
    
    # Record the sabotage in contract
    contributions = contract.action_contributions or {}
    if '_sabotage_log' not in contributions:
        contributions['_sabotage_log'] = []
    
    contributions['_sabotage_log'].append({
        'user_id': saboteur.id,
        'username': saboteur.username,
        'timestamp': datetime.utcnow().isoformat(),
        'actions_added': delay_actions,
        'cost_paid': sabotage_cost
    })
    contract.action_contributions = contributions
    
    # Record sabotage in player's game_data
    game_data = saboteur_state.game_data or {}
    if 'sabotage_history' not in game_data:
        game_data['sabotage_history'] = []
    
    game_data['sabotage_history'].append({
        'kingdom_id': contract.kingdom_id,
        'kingdom_name': kingdom.name,
        'contract_id': contract.id,
        'timestamp': datetime.utcnow().isoformat(),
        'actions_added': delay_actions,
        'cost': sabotage_cost,
        'caught': False
    })
    
    if 'total_sabotages' not in game_data:
        game_data['total_sabotages'] = 0
    game_data['total_sabotages'] += 1
    
    saboteur_state.game_data = game_data
    
    # Award rewards (tax applied if sabotaging in a kingdom where they're a subject)
    # Sabotage rewards are taxed by the saboteur's hometown kingdom if they have one
    if saboteur_state.hometown_kingdom_id:
        net_reward, reward_tax, reward_tax_rate = apply_kingdom_tax(
            db=db,
            kingdom_id=saboteur_state.hometown_kingdom_id,
            player_state=saboteur_state,
            gross_income=SABOTAGE_GOLD_REWARD
        )
    else:
        # No hometown, no tax
        net_reward = SABOTAGE_GOLD_REWARD
        reward_tax = 0
        reward_tax_rate = 0
    
    saboteur_state.gold += net_reward
    
    # TODO: Add reputation in hometown (use user_kingdoms table)
    # Note: kingdom_reputation removed from player_state
    
    progress_percent = int((contract.actions_completed / contract.total_actions_required) * 100)
    
    return {
        "success": True,
        "caught": False,
        "response": {
            "success": True,
            "message": f"You sabotaged {kingdom.name}'s {contract.building_type} project",
            "sabotage": {
                "target_kingdom": kingdom.name,
                "target_contract": {
                    "id": contract.id,
                    "building_type": contract.building_type,
                    "building_level": contract.building_level
                },
                "delay_applied": f"+{delay_actions} actions required",
                "new_total_actions": contract.total_actions_required,
                "current_progress": f"{contract.actions_completed}/{contract.total_actions_required} ({progress_percent}%)"
            },
            "detection": {
                "active_patrols": active_patrols,
                "detection_chance": f"{detection_chance * 100:.2f}%",
                "avoided_detection": True
            },
            "costs": {
                "gold_paid": sabotage_cost
            },
            "rewards": {
                "gold": net_reward,
                "gold_before_tax": SABOTAGE_GOLD_REWARD,
                "tax_amount": reward_tax,
                "tax_rate": reward_tax_rate,
                "reputation": SABOTAGE_REP_REWARD if saboteur_state.hometown_kingdom_id else 0,
                "net_gold": net_reward - sabotage_cost
            },
            "next_sabotage_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=SABOTAGE_COOLDOWN_HOURS)),
            "statistics": {
                "total_sabotages": game_data.get('total_sabotages', 0)
            }
        }
    }


@router.post("/sabotage/{contract_id}")
def sabotage_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sabotage an active contract in an opposing kingdom
    - Must be checked into target kingdom (physically present)
    - Costs 300 gold (always paid upfront)
    - Once per day cooldown
    - Delays contract by adding 10% more actions required
    - Records action for future badge/reputation system
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=work_cooldown)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Set cooldown IMMEDIATELY to prevent double-click exploits
    cooldown_expires = datetime.utcnow() + timedelta(hours=SABOTAGE_COOLDOWN_HOURS)
    set_cooldown(db, current_user.id, "sabotage", cooldown_expires)
    
    # Check if user has enough gold
    if state.gold < SABOTAGE_COST:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient gold. Need {SABOTAGE_COST}g, have {state.gold}g"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to sabotage"
        )
    
    # Get the contract
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    # Verify contract belongs to the kingdom user is checked into
    if contract.kingdom_id != state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract must be in the kingdom you're checked into"
        )
    
    # Verify this is an active contract (not completed)
    if contract.completed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Contract is already completed"
        )
    
    # Check if this is an opposing kingdom (not their hometown)
    if state.hometown_kingdom_id == contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot sabotage your hometown kingdom (for now)"
        )
    
    # Get the target kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Cannot sabotage allies
    home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if home_kingdom and are_empires_allied(
        db,
        home_kingdom.empire_id or home_kingdom.id,
        kingdom.empire_id or kingdom.id
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot sabotage allies! This would violate your alliance."
        )
    
    # Deduct gold cost (always paid upfront)
    state.gold -= SABOTAGE_COST
    
    # Process sabotage attempt with detection mechanics
    result = process_sabotage_attempt(
        db=db,
        saboteur=current_user,
        saboteur_state=state,
        contract=contract,
        kingdom=kingdom,
        sabotage_cost=SABOTAGE_COST
    )
    
    # Commit all changes
    db.commit()
    
    # Return the API response
    return result["response"]


# Legacy endpoint removed - kingdoms only have ONE contract, no need for target selection
