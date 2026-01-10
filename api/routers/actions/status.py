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
from .utils import check_cooldown_from_table, calculate_cooldown, check_global_action_cooldown_from_table, is_patrolling, format_datetime_iso
from .training import calculate_training_cost, TRAINING_TYPES
from routers.tiers import get_total_skill_points, SKILL_TYPES


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


def get_property_contracts_for_status(db: Session, user_id: int) -> list:
    """Get property contracts from unified_contracts table for status endpoint"""
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
            "started_at": format_datetime_iso(contract.created_at) if contract.created_at else None
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
    
    slot_cooldowns = {}
    action_types_to_check = ["work", "farm", "patrol", "training", "crafting", "scout", "chop_wood"]
    
    for action_type in action_types_to_check:
        slot = get_action_slot(action_type)
        if slot not in slot_cooldowns:
            cooldown_info = check_global_action_cooldown_from_table(
                db,
                current_user.id,
                current_action_type=action_type,
                work_cooldown=work_cooldown, 
                patrol_cooldown=patrol_cooldown,
                farm_cooldown=farm_cooldown,
                sabotage_cooldown=sabotage_cooldown,
                training_cooldown=training_cooldown
            )
            slot_cooldowns[slot] = cooldown_info
    
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
    property_contracts = get_property_contracts_for_status(db, current_user.id)
    
    # Calculate expected rewards (accounting for bonuses and taxes)
    # Farm reward
    farm_base = FARM_GOLD_REWARD
    farm_bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
    farm_gross = int(farm_base * farm_bonus_multiplier)
    
    # Patrol reward (reputation only)
    patrol_rep_reward = PATROL_REPUTATION_REWARD
    
    # Work reward (need to calculate per contract, so we'll add it to each contract object)
    
    # Build list of ALL possible actions dynamically
    actions = {}
    
    # ALWAYS AVAILABLE ACTIONS - API defines ALL metadata
    actions["work"] = {
        **check_cooldown_from_table(db, current_user.id, "work", work_cooldown),
        "cooldown_minutes": work_cooldown,
        "unlocked": True,
        "action_type": "work",
        "title": "Work on Contract",
        "icon": "hammer.fill",
        "description": "Build kingdom infrastructure",
        "category": "beneficial",
        "theme_color": "inkMedium",
        "display_order": 10
    }
    
    actions["patrol"] = {
        **check_cooldown_from_table(db, current_user.id, "patrol", patrol_cooldown),
        "cooldown_minutes": patrol_cooldown,
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
    
    actions["farm"] = {
        **check_cooldown_from_table(db, current_user.id, "farm", farm_cooldown),
        "cooldown_minutes": farm_cooldown,
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
    
    # Chop Wood - Available if kingdom has lumbermill
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first() if state.current_kingdom_id else None
    lumbermill_level = kingdom.lumbermill_level if kingdom and hasattr(kingdom, 'lumbermill_level') else 0
    
    if lumbermill_level > 0:
        wood_per_action = {0: 0, 1: 10, 2: 20, 3: 35, 4: 50, 5: 75}.get(lumbermill_level, 0)
        wood_bonus_multiplier = 1.0 + (max(0, state.building_skill - 1) * 0.02)
        wood_gross = int(wood_per_action * wood_bonus_multiplier)
        
        actions["chop_wood"] = {
            **check_cooldown_from_table(db, current_user.id, "chop_wood", 60),
            "cooldown_minutes": 60,
            "expected_reward": {
                "wood": wood_gross,
                "lumbermill_level": lumbermill_level,
                "building_skill": state.building_skill
            },
            "unlocked": True,
            "action_type": "chop_wood",
            "title": "Chop Wood",
            "icon": "tree.fill",
            "description": f"Gather wood at the lumbermill (Level {lumbermill_level})",
            "category": "beneficial",
            "theme_color": "buttonSuccess",
            "display_order": 35,
            "endpoint": "/actions/chop-wood"
        }
    else:
        actions["chop_wood"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "chop_wood",
            "requirements_met": False,
            "requirement_description": "Kingdom needs a lumbermill",
            "title": "Chop Wood",
            "icon": "tree.fill",
            "description": "Gather wood for construction",
            "category": "beneficial",
            "theme_color": "buttonSuccess",
            "display_order": 35
        }
    
    actions["training"] = {
        **check_cooldown_from_table(db, current_user.id, "training", training_cooldown),
        "cooldown_minutes": training_cooldown,
        "unlocked": True,
        "action_type": "training",
        "title": "Training",
        "icon": "figure.strengthtraining.traditional",
        "description": "Train your stats",
        "category": "personal",
        "theme_color": "buttonPrimary",
        "display_order": 10
    }
    
    actions["crafting"] = {
        **check_cooldown_from_table(db, current_user.id, "crafting", work_cooldown),
        "cooldown_minutes": work_cooldown,
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
    
    if state.intelligence >= 1:
        # ONLY show what they CAN do - no locked outcomes
        description = f"Outcomes: {', '.join(current_outcomes)}"
        
        actions["scout"] = {
            **check_cooldown_from_table(db, current_user.id, "scout", SCOUT_COOLDOWN),
            "cooldown_minutes": SCOUT_COOLDOWN,
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
            # Check for active coup first
            from db.models import CoupEvent
            active_coup = db.query(CoupEvent).filter(
                CoupEvent.kingdom_id == kingdom.id,
                CoupEvent.status.in_(['pledge', 'battle'])
            ).first()
            
            if active_coup:
                coup_ineligibility_reason = "Coup already in progress"
                active_coup_id = active_coup.id
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
                "endpoint": "/coups/initiate",
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
                "active_coup_id": active_coup_id,  # If there's an active coup, frontend can show it
            }
    
    # VIEW COUP - Show when there's an active coup in the user's current kingdom
    if state.current_kingdom_id:
        from db.models import CoupEvent
        active_coup = db.query(CoupEvent).filter(
            CoupEvent.kingdom_id == state.current_kingdom_id,
            CoupEvent.status.in_(['pledge', 'battle'])
        ).first()
        
        if active_coup:
            # Check if user already pledged
            attacker_ids = active_coup.get_attacker_ids()
            defender_ids = active_coup.get_defender_ids()
            user_pledged = current_user.id in attacker_ids or current_user.id in defender_ids
            user_side = None
            if current_user.id in attacker_ids:
                user_side = "attackers"
            elif current_user.id in defender_ids:
                user_side = "defenders"
            
            # Can pledge if: pledge phase, not already pledged
            can_pledge = (
                active_coup.status == 'pledge' and
                not user_pledged
            )
            
            # Determine display text based on phase and user status
            if active_coup.status == 'pledge':
                if user_pledged:
                    title = "View Coup"
                    description = f"You've pledged as {user_side} - waiting for battle"
                else:
                    minutes_left = active_coup.time_remaining_seconds // 60
                    title = "Join Coup"
                    description = f"A coup is underway! {minutes_left}m to pledge"
            else:  # battle phase
                title = "View Battle"
                description = "The battle for the throne is underway"
            
            actions["view_coup"] = {
                "ready": True,
                "seconds_remaining": 0,
                "unlocked": True,
                "action_type": "view_coup",
                "requirements_met": True,
                "title": title,
                "icon": "bolt.fill",
                "description": description,
                "category": "political",
                "theme_color": "buttonDanger",
                "display_order": 0,  # Show first in political slot
                "endpoint": None,  # No endpoint - frontend handles opening CoupView
                "coup_id": active_coup.id,
                "can_pledge": can_pledge,
                "user_side": user_side,
                "coup_status": active_coup.status,
                "attacker_count": len(attacker_ids),
                "defender_count": len(defender_ids),
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
    
    return {
        "parallel_actions_enabled": True,  # NEW: Signals to frontend that parallel actions are supported
        "slot_cooldowns": slot_cooldowns,  # NEW: Per-slot cooldown status
        "slots": slots,  # NEW: Full slot metadata for frontend rendering (no hardcoding!)
        "global_cooldown": slot_cooldowns.get("building", {"ready": True, "seconds_remaining": 0}),  # For old clients
        "actions": actions,  # DYNAMIC ACTION LIST
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
