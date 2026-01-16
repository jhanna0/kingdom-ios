"""
Action status endpoint - Get cooldown status for all actions
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
import json

from db import get_db, User, PlayerState, Contract, UnifiedContract, ContractContribution, Kingdom
from routers.auth import get_current_user
from routers.property import get_tier_name  # Import tier name helper
from routers.notifications.alliances import get_pending_alliance_requests
from .utils import check_cooldown_from_table, calculate_cooldown, check_global_action_cooldown_from_table, is_patrolling, format_datetime_iso, get_player_food_total
from .training import calculate_training_cost, TRAINING_TYPES
from routers.tiers import get_total_skill_points, SKILL_TYPES, calculate_food_cost


def _get_training_costs_dict(state) -> dict:
    """Helper to generate training costs dict for all skills"""
    total = get_total_skill_points(state)
    cost = calculate_training_cost(total)
    return {skill_type: cost for skill_type in SKILL_TYPES}
from .crafting import get_craft_cost, get_iron_required, get_steel_required, get_actions_required, get_stat_bonus, CRAFTING_TYPES
from .constants import (
    WORK_BASE_COOLDOWN,
    PATROL_COOLDOWN,
    FARM_COOLDOWN,
    FARM_GOLD_REWARD,
    SABOTAGE_COOLDOWN,
    TRAINING_COOLDOWN,
    PATROL_REPUTATION_REWARD,
    SCOUT_COOLDOWN,
)


router = APIRouter()


def get_training_contracts_for_status(db: Session, user_id: int) -> list:
    """Get training contracts from unified_contracts table for status endpoint"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type.in_(TRAINING_TYPES),
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).all()
    
    result = []
    for contract in contracts:
        # Count contributions = actions completed
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        result.append({
            "id": str(contract.id),  # String for backwards compatibility
            "type": contract.type,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost_paid": contract.gold_paid,
            "created_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "status": "completed" if contract.completed_at else "in_progress"
        })
    
    return result


def get_crafting_contracts_for_status(db: Session, user_id: int) -> list:
    """Get crafting contracts from unified_contracts table for status endpoint"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type.in_(CRAFTING_TYPES),
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        result.append({
            "id": str(contract.id),
            "equipment_type": contract.type,
            "tier": contract.tier,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "gold_paid": contract.gold_paid,
            "iron_paid": contract.iron_paid,
            "steel_paid": contract.steel_paid,
            "created_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "status": "completed" if contract.completed_at else "in_progress"
        })
    
    return result


def get_property_contracts_for_status(db: Session, user_id: int, player_state) -> list:
    """Get property contracts from unified_contracts table for status endpoint"""
    from routers.tiers import PROPERTY_TIERS
    from routers.resources import RESOURCES
    
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type == 'property',
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        # Parse target_id to get property_id
        target_parts = contract.target_id.split("|") if contract.target_id else []
        property_id = target_parts[0] if target_parts else contract.target_id
        
        # Get per-action costs from tier config
        tier_data = PROPERTY_TIERS.get(contract.tier or 1, {})
        raw_per_action = tier_data.get("per_action_costs", [])
        
        # Enrich with display info and check affordability
        per_action_costs = []
        can_afford = True
        for cost in raw_per_action:
            resource_info = RESOURCES.get(cost["resource"], {})
            player_has = getattr(player_state, cost["resource"], 0) or 0
            has_enough = player_has >= cost["amount"]
            if not has_enough:
                can_afford = False
            per_action_costs.append({
                "resource": cost["resource"],
                "amount": cost["amount"],
                "display_name": resource_info.get("display_name", cost["resource"].capitalize()),
                "icon": resource_info.get("icon", "questionmark.circle")
            })
        
        result.append({
            "contract_id": str(contract.id),
            "property_id": property_id,
            "kingdom_id": contract.kingdom_id,
            "kingdom_name": contract.kingdom_name,
            "from_tier": (contract.tier or 1) - 1,
            "to_tier": contract.tier or 1,
            "target_tier_name": get_tier_name(contract.tier or 1),
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost": contract.gold_paid,
            "status": "completed" if contract.completed_at else "in_progress",
            "started_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "endpoint": f"/actions/work-property/{contract.id}",
            "per_action_costs": per_action_costs,
            "can_afford": can_afford  # Can player afford the per-action costs?
        })
    
    return result


@router.get("/status")
def get_action_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get cooldown status for all actions AND available contracts in current kingdom"""
    # Import here to avoid circular imports
    from routers.contracts import contract_to_response
    from routers.tiers import BUILDING_TYPES
    
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Calculate cooldowns based on skills
    work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    patrol_cooldown = PATROL_COOLDOWN
    farm_cooldown = FARM_COOLDOWN
    sabotage_cooldown = SABOTAGE_COOLDOWN
    training_cooldown = TRAINING_COOLDOWN
    
    # Count active patrollers in current kingdom
    active_patrollers = 0
    if state.current_kingdom_id:
        from db.models.action_cooldown import ActionCooldown
        # Get all users in this kingdom
        user_ids_in_kingdom = db.query(PlayerState.user_id).filter(
            PlayerState.current_kingdom_id == state.current_kingdom_id
        ).all()
        user_ids = [uid[0] for uid in user_ids_in_kingdom]
        
        # Count how many have active patrol cooldowns
        active_patrollers = db.query(ActionCooldown).filter(
            ActionCooldown.user_id.in_(user_ids),
            ActionCooldown.action_type == 'patrol',
            ActionCooldown.expires_at > datetime.utcnow()
        ).count()
    
    # Get contracts for current kingdom (from UnifiedContract table)
    contracts = []
    if state.current_kingdom_id:
        # Query UnifiedContract table (not old Contract table!)
        contracts_query = db.query(UnifiedContract).filter(
            UnifiedContract.kingdom_id == state.current_kingdom_id,
            UnifiedContract.category == 'kingdom_building',  # Only building contracts
            UnifiedContract.completed_at.is_(None)  # Active contracts only
        ).all()
        contracts = [contract_to_response(c, db) for c in contracts_query]
    
    # Check slot-based cooldowns (PARALLEL ACTIONS!)
    # Each slot can have one action running - different slots can run in parallel
    from .action_config import get_action_slot, get_all_slot_definitions, get_slots_for_location, SLOT_DEFINITIONS, ACTION_SLOTS
    
    # Map action types to their calculated cooldowns (skill-adjusted where applicable)
    action_cooldown_map = {
        "work": work_cooldown,
        "farm": farm_cooldown,
        "patrol": patrol_cooldown,
        "training": training_cooldown,
        "crafting": work_cooldown,  # Uses building skill
        "scout": sabotage_cooldown,
    }
    
    slot_cooldowns = {}
    action_types_to_check = ["work", "farm", "patrol", "training", "crafting", "scout"]
    
    for action_type in action_types_to_check:
        slot = get_action_slot(action_type)
        if slot not in slot_cooldowns:
            # Pass the SAME skill-adjusted cooldown that the action endpoint uses
            cooldown_info = check_global_action_cooldown_from_table(
                db,
                current_user.id,
                current_action_type=action_type,
                cooldown_minutes=action_cooldown_map[action_type]
            )
            slot_cooldowns[slot] = cooldown_info
    
    # Check for ACTIVE BATTLE cooldowns (separate from action slots)
    # Battle cooldowns are stored as 'battle_{battle_id}' in action_cooldowns table
    from db.models.action_cooldown import ActionCooldown
    from systems.battle.config import BATTLE_ACTION_COOLDOWN_MINUTES
    
    active_battle_cooldown = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type.like('battle_%'),
        ActionCooldown.expires_at > datetime.utcnow()
    ).order_by(ActionCooldown.expires_at.desc()).first()
    
    if active_battle_cooldown:
        remaining = (active_battle_cooldown.expires_at - datetime.utcnow()).total_seconds()
        slot_cooldowns["active_battles"] = {
            "ready": False,
            "seconds_remaining": int(max(0, remaining)),
            "blocking_action": "battle",
            "blocking_slot": "active_battles"
        }
    else:
        slot_cooldowns["active_battles"] = {
            "ready": True,
            "seconds_remaining": 0,
            "blocking_action": None,
            "blocking_slot": None
        }
    
    # Get crafting costs for all tiers
    crafting_costs = {}
    for tier in range(1, 6):
        crafting_costs[f"tier_{tier}"] = {
            "gold": get_craft_cost(tier),
            "iron": get_iron_required(tier),
            "steel": get_steel_required(tier),
            "actions_required": get_actions_required(tier),
            "stat_bonus": get_stat_bonus(tier)
        }
    
    # Load property upgrade contracts from unified_contracts table
    property_contracts = get_property_contracts_for_status(db, current_user.id, state)
    
    # Calculate expected rewards (accounting for bonuses and taxes)
    # Farm reward
    farm_base = FARM_GOLD_REWARD
    farm_bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    farm_gross = int(farm_base * farm_bonus_multiplier)
    
    # Patrol reward (reputation only)
    patrol_rep_reward = PATROL_REPUTATION_REWARD
    
    # Work reward (need to calculate per contract, so we'll add it to each contract object)
    
    # Get player's current food total (from inventory items with is_food=True)
    player_food_total = get_player_food_total(db, current_user.id)
    
    # Build list of ALL possible actions dynamically
    actions = {}
    
    # ALWAYS AVAILABLE ACTIONS - API defines ALL metadata
    # Food costs are calculated from cooldown: 0.5 food per minute
    work_food_cost = calculate_food_cost(work_cooldown)
    actions["work"] = {
        **check_cooldown_from_table(db, current_user.id, "work", work_cooldown),
        "cooldown_minutes": work_cooldown,
        "food_cost": work_food_cost,
        "can_afford_food": player_food_total >= work_food_cost,
        "unlocked": True,
        "action_type": "work",
        "title": "Work on Contract",
        "icon": "hammer.fill",
        "description": "Build kingdom infrastructure",
        "category": "beneficial",
        "theme_color": "inkMedium",
        "display_order": 10
    }
    
    # Patrol uses duration (10 min) for food cost, not cooldown
    from .constants import PATROL_DURATION_MINUTES
    patrol_food_cost = calculate_food_cost(PATROL_DURATION_MINUTES)
    actions["patrol"] = {
        **check_cooldown_from_table(db, current_user.id, "patrol", patrol_cooldown),
        "cooldown_minutes": patrol_cooldown,
        "food_cost": patrol_food_cost,
        "can_afford_food": player_food_total >= patrol_food_cost,
        "is_patrolling": is_patrolling(db, current_user.id),
        "active_patrollers": active_patrollers,
        "expected_reward": {
            "reputation": patrol_rep_reward
        },
        "unlocked": True,
        "action_type": "patrol",
        "title": "Patrol",
        "icon": "eye.fill",
        "description": "Guard against saboteurs for 10 minutes",
        "category": "beneficial",
        "theme_color": "buttonPrimary",
        "display_order": 20,
        "endpoint": "/actions/patrol"
    }
    
    farm_food_cost = calculate_food_cost(farm_cooldown)
    actions["farm"] = {
        **check_cooldown_from_table(db, current_user.id, "farm", farm_cooldown),
        "cooldown_minutes": farm_cooldown,
        "food_cost": farm_food_cost,
        "can_afford_food": player_food_total >= farm_food_cost,
        "expected_reward": {
            "gold_gross": farm_gross,
            "gold_bonus_multiplier": farm_bonus_multiplier,
            "building_skill": state.building_skill
        },
        "unlocked": True,
        "action_type": "farm",
        "title": "Farm",
        "icon": "leaf.fill",
        "description": "Work the fields to earn gold",
        "category": "beneficial",
        "theme_color": "buttonSuccess",
        "display_order": 30,
        "endpoint": "/actions/farm"
    }
    
    # Get kingdom for coup eligibility checks
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first() if state.current_kingdom_id else None
    
    training_food_cost = calculate_food_cost(training_cooldown)
    actions["training"] = {
        **check_cooldown_from_table(db, current_user.id, "training", training_cooldown),
        "cooldown_minutes": training_cooldown,
        "food_cost": training_food_cost,
        "can_afford_food": player_food_total >= training_food_cost,
        "unlocked": True,
        "action_type": "training",
        "title": "Training",
        "icon": "figure.strengthtraining.traditional",
        "description": "Train your stats",
        "category": "personal",
        "theme_color": "buttonPrimary",
        "display_order": 10
    }
    
    crafting_food_cost = calculate_food_cost(work_cooldown)  # Uses building skill cooldown
    actions["crafting"] = {
        **check_cooldown_from_table(db, current_user.id, "crafting", work_cooldown),
        "cooldown_minutes": work_cooldown,
        "food_cost": crafting_food_cost,
        "can_afford_food": player_food_total >= crafting_food_cost,
        "unlocked": True,
        "action_type": "crafting",
        "title": "Crafting",
        "icon": "hammer.fill",
        "description": "Craft equipment",
        "category": "personal",
        "theme_color": "buttonWarning",
        "display_order": 20
    }
    
    # COVERT OPERATION - ONE action, outcomes scale with tier!
    # T1: intel only
    # T3: + disruption
    # T5: + contract_sabotage, vault_heist
    # Patrol count determines if the incident triggers
    intel_tier = state.intelligence
    
    # Build outcome list with tier requirements shown
    current_outcomes = []
    locked_outcomes = []
    
    if intel_tier >= 1:
        current_outcomes.append("Intel")
    else:
        locked_outcomes.append("Intel (T1)")
    
    if intel_tier >= 3:
        current_outcomes.append("Disruption")
    else:
        locked_outcomes.append("Disruption (T3)")
    
    if intel_tier >= 5:
        current_outcomes.append("Sabotage")
        current_outcomes.append("Vault Heist")
    else:
        locked_outcomes.append("Sabotage (T5)")
        locked_outcomes.append("Vault Heist (T5)")
    
    scout_food_cost = calculate_food_cost(SCOUT_COOLDOWN)
    if state.intelligence >= 1:
        # ONLY show what they CAN do - no locked outcomes
        description = f"Outcomes: {', '.join(current_outcomes)}"
        
        actions["scout"] = {
            **check_cooldown_from_table(db, current_user.id, "scout", SCOUT_COOLDOWN),
            "cooldown_minutes": SCOUT_COOLDOWN,
            "food_cost": scout_food_cost,
            "can_afford_food": player_food_total >= scout_food_cost,
            "unlocked": True,
            "action_type": "scout",
            "requirements_met": True,
            "title": "Infiltrate",
            "icon": "eye.fill",
            "description": description,
            "category": "hostile",
            "theme_color": "royalEmerald",
            "display_order": 5,
            "endpoint": "/incidents/trigger",
            "cost": 100,
            "intelligence_tier": intel_tier,
            "current_outcomes": current_outcomes,
            "locked_outcomes": locked_outcomes,
        }
    else:
        actions["scout"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "scout",
            "requirements_met": False,
            "requirement_description": f"Requires Intelligence T1+ (you: T{state.intelligence})",
            "title": "Infiltrate",
            "icon": "eye.fill",
            "description": "Hostile operations in enemy territory",
            "category": "hostile",
            "theme_color": "royalEmerald",
            "display_order": 5,
            "endpoint": None,
        }
    
    # STAGE COUP - Available when in a kingdom with a ruler who isn't you
    # Check eligibility using the coup router's logic
    from routers.coups import (
        COUP_LEADERSHIP_REQUIREMENT,
        COUP_REPUTATION_REQUIREMENT,
        _check_player_cooldown,
        _check_kingdom_cooldown,
        _get_kingdom_reputation
    )
    
    can_stage_coup = False
    coup_ineligibility_reason = None
    active_coup_id = None
    
    if state.current_kingdom_id and kingdom:
        if kingdom.ruler_id is None:
            coup_ineligibility_reason = "Kingdom has no ruler"
        elif kingdom.ruler_id == current_user.id:
            coup_ineligibility_reason = "You are the ruler"
        else:
            # Check for active battle (coup or invasion) first
            from db.models import Battle
            active_battle = db.query(Battle).filter(
                Battle.kingdom_id == kingdom.id,
                Battle.resolved_at.is_(None)
            ).first()
            
            if active_battle:
                battle_type = "Coup" if active_battle.is_coup else "Invasion"
                coup_ineligibility_reason = f"{battle_type} already in progress"
                active_coup_id = active_battle.id
            else:
                # Check player stats
                kingdom_rep = _get_kingdom_reputation(db, current_user.id, kingdom.id)
                
                if state.leadership < COUP_LEADERSHIP_REQUIREMENT:
                    coup_ineligibility_reason = f"Need T{COUP_LEADERSHIP_REQUIREMENT} leadership (you have T{state.leadership})"
                elif kingdom_rep < COUP_REPUTATION_REQUIREMENT:
                    coup_ineligibility_reason = f"Need {COUP_REPUTATION_REQUIREMENT} kingdom rep (you have {kingdom_rep})"
                else:
                    # Check cooldowns
                    can_player, player_msg = _check_player_cooldown(db, current_user.id)
                    can_kingdom, kingdom_msg = _check_kingdom_cooldown(db, kingdom.id)
                    
                    if not can_player:
                        coup_ineligibility_reason = player_msg
                    elif not can_kingdom:
                        coup_ineligibility_reason = kingdom_msg
                    else:
                        can_stage_coup = True
    
    # Only add coup action if user is in a kingdom with a ruler (not themselves)
    if state.current_kingdom_id and kingdom and kingdom.ruler_id and kingdom.ruler_id != current_user.id:
        if can_stage_coup:
            actions["stage_coup"] = {
                "ready": True,
                "seconds_remaining": 0,
                "unlocked": True,
                "action_type": "stage_coup",
                "requirements_met": True,
                "title": "Stage Coup",
                "icon": "bolt.fill",
                "description": "Overthrow the current ruler",
                "category": "political",
                "theme_color": "buttonSpecial",
                "display_order": 1,
                "endpoint": "/battles/coup/initiate",
                "handler": "initiate_battle",  # Frontend knows to POST and open BattleView
                "kingdom_id": kingdom.id,
            }
        else:
            actions["stage_coup"] = {
                "ready": False,
                "seconds_remaining": 0,
                "unlocked": False,
                "action_type": "stage_coup",
                "requirements_met": False,
                "requirement_description": coup_ineligibility_reason,
                "title": "Stage Coup",
                "icon": "bolt.fill",
                "description": "Overthrow the current ruler",
                "category": "political",
                "theme_color": "buttonSpecial",
                "display_order": 1,
                "endpoint": None,
                "handler": None,
                "active_coup_id": active_coup_id,  # If there's an active coup, frontend can show it
            }
    
    # DECLARE INVASION - Available when in an enemy kingdom you can invade
    # Uses same eligibility logic as /battles/eligibility/{kingdom_id}
    can_declare_invasion = False
    invasion_ineligibility_reason = None
    
    # Get kingdoms this player rules
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).all()
    fiefs_ruled = [k.id for k in ruled_kingdoms]
    
    if state.current_kingdom_id and kingdom:
        # Check if this is an enemy kingdom (not our own)
        is_enemy_kingdom = kingdom.ruler_id and kingdom.ruler_id != current_user.id
        
        if is_enemy_kingdom:
            # Check invasion eligibility
            if not fiefs_ruled:
                invasion_ineligibility_reason = "Must rule a kingdom to invade"
            elif not kingdom.ruler_id:
                invasion_ineligibility_reason = "Cannot invade unruled kingdom"
            else:
                # Check empire - can't invade own empire
                my_kingdom_id = fiefs_ruled[0] if fiefs_ruled else None
                if my_kingdom_id:
                    my_kingdom = db.query(Kingdom).filter(Kingdom.id == my_kingdom_id).first()
                    if my_kingdom:
                        my_empire = my_kingdom.empire_id or my_kingdom.id
                        target_empire = kingdom.empire_id or kingdom.id
                        if my_empire == target_empire:
                            invasion_ineligibility_reason = "Cannot invade your own empire"
                
                # Check for active battle
                if not invasion_ineligibility_reason:
                    from db.models import Battle
                    active_battle = db.query(Battle).filter(
                        Battle.kingdom_id == kingdom.id,
                        Battle.resolved_at.is_(None)
                    ).first()
                    
                    if active_battle:
                        battle_type = "Coup" if active_battle.is_coup else "Invasion"
                        invasion_ineligibility_reason = f"{battle_type} already in progress"
                
                # Check invasion cooldown
                if not invasion_ineligibility_reason:
                    from routers.battles import _check_kingdom_invasion_cooldown
                    ok, msg = _check_kingdom_invasion_cooldown(db, kingdom.id)
                    if not ok:
                        invasion_ineligibility_reason = msg
                
                # If no reason to block, can invade!
                if not invasion_ineligibility_reason:
                    can_declare_invasion = True
            
            # Add declare_invasion action
            if can_declare_invasion:
                actions["declare_invasion"] = {
                    "ready": True,
                    "seconds_remaining": 0,
                    "unlocked": True,
                    "action_type": "declare_invasion",
                    "requirements_met": True,
                    "title": "Declare Invasion",
                    "icon": "flag.2.crossed.fill",
                    "description": f"Declare war on {kingdom.name}",
                    "category": "warfare",
                    "theme_color": "buttonDanger",
                    "display_order": 1,
                    "endpoint": "/battles/invasion/declare",
                    "handler": "initiate_battle",  # Frontend knows to POST and open BattleView
                    "kingdom_id": kingdom.id,
                    "kingdom_name": kingdom.name,
                }
            else:
                actions["declare_invasion"] = {
                    "ready": False,
                    "seconds_remaining": 0,
                    "unlocked": False,
                    "action_type": "declare_invasion",
                    "requirements_met": False,
                    "requirement_description": invasion_ineligibility_reason,
                    "title": "Declare Invasion",
                    "icon": "flag.2.crossed.fill",
                    "description": "Declare war on this kingdom",
                    "category": "warfare",
                    "theme_color": "buttonDanger",
                    "display_order": 1,
                    "endpoint": None,
                    "handler": None,
                }
    
    # VIEW BATTLE - Show when there's an active battle involving the user's hometown kingdom
    # This includes:
    # 1. Battles targeting the hometown (coups or invasions where we're defending)
    # 2. Battles where hometown is attacking (invasions we declared)
    if state.hometown_kingdom_id:
        from db.models import Battle
        from sqlalchemy import or_
        
        active_home_battle = db.query(Battle).filter(
            or_(
                Battle.kingdom_id == state.hometown_kingdom_id,  # We're being attacked
                Battle.attacking_from_kingdom_id == state.hometown_kingdom_id  # We're attacking
            ),
            Battle.resolved_at.is_(None)
        ).first()
        
        if active_home_battle:
            # Check if user already pledged
            attacker_ids = active_home_battle.get_attacker_ids()
            defender_ids = active_home_battle.get_defender_ids()
            user_pledged = current_user.id in attacker_ids or current_user.id in defender_ids
            user_side = None
            if current_user.id in attacker_ids:
                user_side = "attackers"
            elif current_user.id in defender_ids:
                user_side = "defenders"
            
            # Location check for JOINING (not for fighting once joined)
            # - Coups: must be in the kingdom
            # - Invasions as attacker: must be at target kingdom to declare, but can fight from home after
            # - Invasions as defender: must be in home kingdom
            is_in_home_kingdom = state.current_kingdom_id == state.hometown_kingdom_id
            is_in_target_kingdom = state.current_kingdom_id == active_home_battle.kingdom_id
            
            # For joining: need to be at correct location
            # For invasions where we're attacking, we join from home (attacking_from)
            is_our_attack = active_home_battle.attacking_from_kingdom_id == state.hometown_kingdom_id
            
            if is_our_attack:
                # We're the attackers - can join from home kingdom
                is_in_correct_kingdom_to_join = is_in_home_kingdom
            else:
                # We're being attacked (coup or invasion) - join from home kingdom
                is_in_correct_kingdom_to_join = is_in_home_kingdom
            
            # Can pledge if: in correct kingdom, pledge phase, not already pledged
            can_pledge = is_in_correct_kingdom_to_join and active_home_battle.is_pledge_phase and not user_pledged
            
            # Battle-type aware text
            battle_type_name = "Coup" if active_home_battle.is_coup else "Invasion"
            battle_type_lower = battle_type_name.lower()
            
            # Determine display text based on phase, user status, and location
            # KEY: Once pledged, user can fight from ANYWHERE
            # Button color based on user's side
            if user_side == "attackers":
                button_color = "buttonDanger"  # Red for attackers
            elif user_side == "defenders":
                button_color = "royalBlue"  # Blue for defenders
            else:
                button_color = "buttonPrimary"  # Default
            
            if user_pledged:
                # Already joined - can participate from anywhere!
                if active_home_battle.is_pledge_phase:
                    title = f"View {battle_type_name}"
                    description = f"You've pledged as {user_side} - waiting for battle"
                    button_text = "View"
                else:
                    title = f"⚔️ {battle_type_name} Battle"
                    description = f"Fight for the {user_side}! Join from anywhere."
                    button_text = "Fight!"
            elif not is_in_correct_kingdom_to_join:
                # Not joined and not in correct location
                title = "Travel Home to Vote"
                description = f"Return to your home kingdom to pledge in the {battle_type_lower}"
                button_text = "View"
                button_color = "inkMedium"
            elif active_home_battle.is_pledge_phase:
                # In correct location, can pledge
                minutes_left = active_home_battle.time_remaining_seconds // 60
                title = f"Vote in {battle_type_name}"
                description = f"A {battle_type_lower} is underway! {minutes_left}m to pledge"
                button_text = "Join"
                button_color = "buttonPrimary"
            else:
                # Battle phase but didn't pledge
                title = "View Battle"
                description = "Battle phase - you didn't pledge"
                button_text = "View"
                button_color = "inkMedium"
            
            # Rename key to view_battle for unified system, but keep view_coup for backwards compat
            actions["view_coup"] = {
                "ready": True,
                "seconds_remaining": 0,
                "unlocked": True,
                "action_type": "view_coup",  # Keep for backwards compat in iOS
                "requirements_met": True,
                "title": title,
                "icon": "bolt.fill" if active_home_battle.is_coup else "flag.2.crossed.fill",
                "description": description,
                "category": "political",
                "theme_color": button_color,  # Dynamic based on user side
                "display_order": 0,  # Show first in political slot
                "endpoint": None,  # No endpoint - frontend uses handler
                "handler": "view_battle",  # Frontend opens BattleView with battle_id
                "button_text": button_text,  # NEW: "Fight!", "View", "Join"
                "button_color": button_color,  # NEW: buttonDanger/royalBlue based on side
                "coup_id": active_home_battle.id,  # Keep coup_id for backwards compat
                "battle_id": active_home_battle.id,  # Used by handler
                "battle_type": active_home_battle.type,  # "coup" or "invasion"
                "can_pledge": can_pledge,
                "user_side": user_side,
                "user_pledged": user_pledged,  # NEW: true if user can fight from anywhere
                "coup_status": active_home_battle.current_phase,  # Keep for backwards compat
                "battle_status": active_home_battle.current_phase,  # New field
                "attacker_count": len(attacker_ids),
                "defender_count": len(defender_ids),
                "is_in_correct_kingdom": is_in_correct_kingdom_to_join or user_pledged,  # Once pledged, always "correct"
            }
    
    # Add slot information to each action
    for action_key, action_data in actions.items():
        action_data["slot"] = get_action_slot(action_key)
    
    # Build slots array with actions for each slot
    # Frontend renders this dynamically - no hardcoding!
    slots = []
    for slot_def in get_all_slot_definitions():
        slot_id = slot_def["id"]
        # Get actions that belong to this slot
        slot_actions = [
            action_key for action_key, action_data in actions.items()
            if action_data.get("slot") == slot_id
        ]
        slots.append({
            "id": slot_id,
            "display_name": slot_def["display_name"],
            "icon": slot_def["icon"],
            "color_theme": slot_def["color_theme"],
            "display_order": slot_def["display_order"],
            "description": slot_def["description"],
            "location": slot_def["location"],
            "content_type": slot_def["content_type"],  # Tells frontend which renderer to use
            "actions": slot_actions,
        })
    
    # Add food cost to property contracts
    for contract in property_contracts:
        contract["food_cost"] = work_food_cost  # Property work uses building slot cooldown
        contract["can_afford_food"] = player_food_total >= work_food_cost
    
    return {
        "parallel_actions_enabled": True,  # NEW: Signals to frontend that parallel actions are supported
        "slot_cooldowns": slot_cooldowns,  # NEW: Per-slot cooldown status
        "slots": slots,  # NEW: Full slot metadata for frontend rendering (no hardcoding!)
        "global_cooldown": slot_cooldowns.get("building", {"ready": True, "seconds_remaining": 0}),  # For old clients
        "actions": actions,  # DYNAMIC ACTION LIST
        # Food system - actions cost food based on cooldown (0.5 food per minute)
        "player_food_total": player_food_total,
        "food_cost_per_minute": 0.5,  # For frontend to calculate costs dynamically
        # Legacy structure for backward compatibility
        "work": actions["work"],
        "patrol": actions["patrol"],
        "farm": actions["farm"],
        "sabotage": actions["scout"],  # Legacy - now "Covert Operation" with tier-based outcomes
        "training": actions["training"],
        "crafting": actions["crafting"],
        "vault_heist": actions["scout"],  # Legacy - now "Covert Operation" (T5 unlocks heist outcome)
        "scout": actions["scout"],
        "training_contracts": get_training_contracts_for_status(db, current_user.id),
        "training_costs": _get_training_costs_dict(state),
        "crafting_queue": get_crafting_contracts_for_status(db, current_user.id),
        "crafting_costs": crafting_costs,
        "property_upgrade_contracts": property_contracts,
        "contracts": contracts,
        # Alliance requests for rulers - shows in ActionsView with accept/decline buttons
        "pending_alliance_requests": get_pending_alliance_requests(db, current_user, state)
    }
