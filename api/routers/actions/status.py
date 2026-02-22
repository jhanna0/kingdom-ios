"""
Action status endpoint - Get cooldown status for all actions
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
import json

from db import get_db, User, PlayerState, Contract, UnifiedContract, ContractContribution, Kingdom, Property
from routers.auth import get_current_user
from routers.property import get_tier_name  # Import tier name helper
from routers.notifications.alliances import get_pending_alliance_requests
from routers.alliances import are_empires_allied
from .utils import check_cooldown_from_table, calculate_cooldown, calculate_training_cooldown, check_global_action_cooldown_from_table, is_patrolling, format_datetime_iso, get_player_food_total
from .training import TRAINING_TYPES
from routers.tiers import get_total_skill_points, SKILL_TYPES, calculate_food_cost, calculate_training_gold_per_action, calculate_training_actions, get_all_skill_values


def _get_training_costs_dict(state) -> dict:
    """Helper to generate training costs dict for all skills.
    Uses centralized function from tiers.py.
    """
    from routers.tiers import get_training_costs_for_player
    return get_training_costs_for_player(state)
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
from .scout import OUTCOMES_BY_TIER, OUTCOME_DESCRIPTIONS


router = APIRouter()


def get_training_contracts_for_status(db: Session, user_id: int, current_tax_rate: int = 0, is_ruler: bool = False) -> list:
    """Get training contracts from unified_contracts table for status endpoint"""
    # Rulers don't pay tax
    effective_tax_rate = 0 if is_ruler else current_tax_rate
    
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
        
        # Get gold per action for pay-per-action system
        gold_per_action = contract.gold_per_action or 0
        
        result.append({
            "id": str(contract.id),  # String for backwards compatibility
            "type": contract.type,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost_paid": contract.gold_paid,  # OLD: upfront payment (backwards compat)
            "gold_per_action": round(gold_per_action, 1) if gold_per_action > 0 else None,  # NEW: per-action cost
            "current_tax_rate": effective_tax_rate if gold_per_action > 0 else None,  # For display (0 for rulers)
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


def get_catchup_contracts_for_status(db: Session, user_id: int, state: PlayerState) -> list:
    """
    Get active building catchup work for status endpoint.
    
    Only returns catchup records that have been STARTED (player tried to use the building).
    This prevents spamming the Actions view with every building that needs catchup.
    
    Catchup is only for HOMETOWN - you can only contribute to your hometown's buildings!
    """
    from db import BuildingCatchup
    from routers.tiers import BUILDING_TYPES
    
    # Only get incomplete catchup records for the player's HOMETOWN kingdom
    if not state.hometown_kingdom_id:
        return []
    
    catchups = db.query(BuildingCatchup).filter(
        BuildingCatchup.user_id == user_id,
        BuildingCatchup.kingdom_id == state.hometown_kingdom_id,
        BuildingCatchup.completed_at.is_(None)  # Only incomplete
    ).all()
    
    result = []
    for catchup in catchups:
        # Get building metadata
        building_meta = BUILDING_TYPES.get(catchup.building_type, {})
        
        result.append({
            "id": str(catchup.id),
            "building_type": catchup.building_type,
            "building_display_name": building_meta.get("display_name", catchup.building_type.capitalize()),
            "building_icon": building_meta.get("icon", "building.2.fill"),
            "kingdom_id": catchup.kingdom_id,
            "actions_required": catchup.actions_required,
            "actions_completed": catchup.actions_completed,
            "actions_remaining": catchup.actions_remaining,
            "progress_percent": catchup.progress_percent,
            "created_at": format_datetime_iso(catchup.created_at) if catchup.created_at else None,
            "status": "in_progress",
            "endpoint": None  # Work is done through normal building contracts
        })
    
    return result


def get_workshop_contracts_for_status(db: Session, user_id: int) -> list:
    """Get workshop crafting contracts from unified_contracts table for status endpoint"""
    from routers.workshop import CRAFTABLE_ITEMS
    
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.category == "workshop_craft",
        UnifiedContract.completed_at.is_(None)  # Active contracts only
    ).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        item_config = CRAFTABLE_ITEMS.get(contract.type, {})
        
        result.append({
            "id": str(contract.id),
            "item_id": contract.type,
            "display_name": item_config.get("display_name", contract.type),
            "icon": item_config.get("icon", "hammer"),
            "color": item_config.get("color", "buttonWarning"),
            "type": item_config.get("type", "equipment"),
            "tier": contract.tier,
            "attack_bonus": item_config.get("attack_bonus", 0),
            "defense_bonus": item_config.get("defense_bonus", 0),
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "progress_percent": int((actions_completed / contract.actions_required) * 100) if contract.actions_required > 0 else 0,
            "created_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "status": "completed" if contract.completed_at else "in_progress",
            "endpoint": "/workshop/craft/work"  # For action button
        })
    
    return result


def get_property_contracts_for_status(db: Session, user_id: int, player_state, current_tax_rate: int = 0, is_ruler: bool = False, current_kingdom_id: str = None) -> list:
    """Get property contracts from unified_contracts table for status endpoint.
    
    Only returns contracts for properties in the player's current kingdom.
    """
    from routers.tiers import get_property_per_action_costs
    from routers.resources import RESOURCES
    from db.models.inventory import PlayerInventory
    from .action_config import ACTION_TYPES
    from .utils import calculate_cooldown
    
    # Rulers don't pay tax
    effective_tax_rate = 0 if is_ruler else current_tax_rate
    
    # Get contracts for properties in current kingdom only
    if not current_kingdom_id:
        return []
    
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type == 'property',
        UnifiedContract.kingdom_id == current_kingdom_id,
        UnifiedContract.completed_at.is_(None)
    ).all()
    
    # Pre-fetch inventory items for resource checking (wood, etc.)
    inventory_items = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id
    ).all()
    inventory_map = {item.item_id: item.quantity for item in inventory_items}
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        # Parse target_id to get property_id
        target_parts = contract.target_id.split("|") if contract.target_id else []
        property_id = target_parts[0] if target_parts else contract.target_id
        
        # Get per-action costs for this specific option
        from routers.tiers import get_property_option_per_action_costs
        raw_per_action = get_property_option_per_action_costs(contract.tier, contract.option_id) if contract.tier else []
        
        # Enrich with display info and check affordability
        per_action_costs = []
        can_afford = True
        for cost in raw_per_action:
            resource_info = RESOURCES.get(cost["resource"], {})
            # Check inventory for resources like wood (not player_state)
            player_has = inventory_map.get(cost["resource"], 0)
            has_enough = player_has >= cost["amount"]
            if not has_enough:
                can_afford = False
            per_action_costs.append({
                "resource": cost["resource"],
                "amount": cost["amount"],
                "display_name": resource_info.get("display_name", cost["resource"].capitalize()),
                "icon": resource_info.get("icon", "questionmark.circle"),
                "color": resource_info.get("color", "inkMedium"),
                "can_afford": has_enough  # Per-resource affordability
            })
        
        # Get gold per action for pay-per-action system
        gold_per_action = contract.gold_per_action or 0
        
        # Check if player can afford gold cost (with tax - rulers pay 0 tax)
        gold_cost_with_tax = gold_per_action * (1 + effective_tax_rate / 100.0) if gold_per_action > 0 else 0
        can_afford_gold = player_state.gold >= gold_cost_with_tax
        
        # Calculate cooldown (skill-adjusted) - uses building skill
        base_cooldown = ACTION_TYPES["property_upgrade"]["cooldown_minutes"]
        cooldown_minutes = calculate_cooldown(base_cooldown, player_state.building_skill)
        
        # Look up option name for display
        from routers.property import get_option_name
        option_name = get_option_name(contract.tier, contract.option_id) if contract.tier and contract.option_id else None
        
        result.append({
            "contract_id": str(contract.id),
            "property_id": property_id,
            "kingdom_id": contract.kingdom_id,
            "kingdom_name": contract.kingdom_name,
            "from_tier": (contract.tier or 1) - 1,
            "to_tier": contract.tier or 1,
            "target_tier_name": option_name or get_tier_name(contract.tier or 1),
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "cost": contract.gold_paid or 0,  # OLD: upfront payment (backwards compat)
            "gold_per_action": round(gold_per_action, 1) if gold_per_action > 0 else None,  # NEW: per-action cost
            "current_tax_rate": effective_tax_rate if gold_per_action > 0 else None,  # For display (0 for rulers)
            "can_afford_gold": can_afford_gold if gold_per_action > 0 else None,  # NEW: gold affordability
            "status": "completed" if contract.completed_at else "in_progress",
            "started_at": format_datetime_iso(contract.created_at) if contract.created_at else None,
            "endpoint": f"/actions/work-property/{contract.id}",
            "per_action_costs": per_action_costs,
            "can_afford": can_afford,  # Can player afford the per-action costs?
            "cooldown_minutes": cooldown_minutes  # Skill-adjusted cooldown for display
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
    
    # Get kingdom early - needed for tax rate in contracts and later for coup eligibility
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first() if state.current_kingdom_id else None
    
    # Calculate cooldowns based on skills
    # Building skill reduces building/work cooldowns
    work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    patrol_cooldown = PATROL_COOLDOWN
    farm_cooldown = FARM_COOLDOWN
    # Science skill reduces training cooldowns
    training_cooldown = calculate_training_cooldown(TRAINING_COOLDOWN, state.science or 1)
    
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
    
    # Get contracts for HOMETOWN kingdom (from UnifiedContract table)
    # Players can ONLY work on building contracts when physically IN their hometown
    contracts = []
    if state.hometown_kingdom_id and state.current_kingdom_id == state.hometown_kingdom_id:
        # Query UnifiedContract table (not old Contract table!)
        contracts_query = db.query(UnifiedContract).filter(
            UnifiedContract.kingdom_id == state.hometown_kingdom_id,
            UnifiedContract.category == 'kingdom_building',  # Only building contracts
            UnifiedContract.completed_at.is_(None)  # Active contracts only
        ).all()
        contracts = [contract_to_response(c, db) for c in contracts_query]
        
        # Add catchup contracts as building contracts (unique name: "Expand {building}")
        catchup_list = get_catchup_contracts_for_status(db, current_user.id, state)
        for c in catchup_list:
            contracts.append({
                "id": c['id'],  # Numeric ID for the dedicated endpoint
                "kingdom_id": c["kingdom_id"],
                "kingdom_name": "",
                "building_type": c["building_type"],
                "building_level": 0,
                "building_benefit": "Expand capacity",
                "building_icon": c["building_icon"],
                "building_display_name": f"Expand {c['building_display_name']}",
                "base_population": 0,
                "base_hours_required": 0,
                "work_started_at": c.get("created_at") or datetime.utcnow().isoformat(),
                "total_actions_required": c["actions_required"],
                "actions_completed": c["actions_completed"],
                "action_contributions": {},
                "construction_cost": 0,
                "reward_pool": 0,
                "action_reward": 0,
                "created_by": current_user.id,
                "created_at": c.get("created_at") or datetime.utcnow().isoformat(),
                "completed_at": None,
                "status": "open",
                "per_action_costs": [],
                "endpoint": f"/actions/work/catchup/{c['id']}",
            })
    
    # Check slot-based cooldowns (PARALLEL ACTIONS!)
    # Each slot can have one action running - different slots can run in parallel
    from .action_config import get_action_slot, get_all_slot_definitions, SLOT_DEFINITIONS, ACTION_SLOTS
    
    # Map action types to their calculated cooldowns (skill-adjusted where applicable)
    action_cooldown_map = {
        "work": work_cooldown,
        "farm": farm_cooldown,
        "patrol": patrol_cooldown,
        "training": training_cooldown,
        "crafting": work_cooldown,  # Uses building skill
        "scout": SCOUT_COOLDOWN,  # 30 minutes from scout.py
    }
    
    slot_cooldowns = {}
    action_types_to_check = ["work", "farm", "patrol", "training", "crafting", "scout"]
    
    # Import book eligibility - server-driven so we can change without app updates
    from routers.store import BOOK_ELIGIBLE_SLOTS
    
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
            # Add book eligibility to slot cooldown (frontend uses this to show book button)
            cooldown_info["can_use_book"] = slot in BOOK_ELIGIBLE_SLOTS
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
    # Rulers don't pay tax, so pass is_ruler flag
    # Only show contracts for properties in current kingdom
    is_ruler = kingdom and kingdom.ruler_id == current_user.id
    property_contracts = get_property_contracts_for_status(db, current_user.id, state, kingdom.tax_rate if kingdom else 0, is_ruler, state.current_kingdom_id)
    
    # Calculate expected rewards (accounting for bonuses and taxes)
    # Farm reward - no gold bonus from building skill (it provides cooldown reduction instead)
    farm_base = FARM_GOLD_REWARD
    farm_gross = farm_base  # No bonus multiplier
    
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
            "gold_gross": farm_gross
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
    
    # kingdom already loaded earlier for tax rate in contracts
    
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
    
    # Check if we're in friendly territory (same empire or allied - can farm/patrol, but can't scout)
    # "Friendly" = home kingdom, same empire, or allied empire
    is_home_kingdom = state.current_kingdom_id == state.hometown_kingdom_id
    is_in_allied_territory = False  # Same empire or allied
    if state.current_kingdom_id and state.hometown_kingdom_id and not is_home_kingdom:
        home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
        current_kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
        if home_kingdom and current_kingdom:
            is_in_allied_territory = are_empires_allied(
                db,
                home_kingdom.empire_id or home_kingdom.id,
                current_kingdom.empire_id or current_kingdom.id
            )
    # Friendly = home OR same empire/allied
    is_friendly_territory = is_home_kingdom or is_in_allied_territory
    
    # Build outcome list dynamically from OUTCOMES_BY_TIER
    available_outcomes = OUTCOMES_BY_TIER.get(intel_tier, []) if intel_tier >= 1 else []
    current_outcomes = [OUTCOME_DESCRIPTIONS.get(o, o) for o in available_outcomes]
    
    # Show what's locked at higher tiers
    locked_outcomes = []
    for tier in range(intel_tier + 1, 6):
        tier_outcomes = OUTCOMES_BY_TIER.get(tier, [])
        for o in tier_outcomes:
            if o not in available_outcomes:
                locked_outcomes.append(f"{OUTCOME_DESCRIPTIONS.get(o, o)} (T{tier})")
    
    scout_food_cost = calculate_food_cost(SCOUT_COOLDOWN)
    if is_in_allied_territory:
        # In allied territory - can't scout
        actions["scout"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "scout",
            "requirements_met": False,
            "requirement_description": "Cannot scout allied kingdoms",
            "title": "Intelligence Operation",
            "icon": "eye.fill",
            "description": "Cannot scout allies",
            "category": "hostile",
            "theme_color": "royalEmerald",
            "display_order": 5,
            "endpoint": None,
        }
    elif state.intelligence >= 1:
        # ONLY show what they CAN do - no locked outcomes
        description = f"{', '.join(current_outcomes)}" if current_outcomes else "Gather intel"
        
        actions["scout"] = {
            **check_cooldown_from_table(db, current_user.id, "scout", SCOUT_COOLDOWN),
            "cooldown_minutes": SCOUT_COOLDOWN,
            "food_cost": scout_food_cost,
            "can_afford_food": player_food_total >= scout_food_cost,
            "unlocked": True,
            "action_type": "scout",
            "requirements_met": True,
            "title": "Intelligence Operation",
            "icon": "eye.fill",
            "description": description,
            "category": "hostile",
            "theme_color": "royalEmerald",
            "display_order": 5,
            "endpoint": "/actions/scout",
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
            "title": "Intelligence Operation",
            "icon": "eye.fill",
            "description": "Gather intel in enemy territory",
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
        elif state.hometown_kingdom_id != state.current_kingdom_id:
            coup_ineligibility_reason = "Can only coup in your hometown"
        elif kingdom.ruler_started_at:
            # Check 7-day new ruler protection
            ruler_tenure = datetime.utcnow() - kingdom.ruler_started_at
            if ruler_tenure.days < 7:
                days_remaining = 7 - ruler_tenure.days
                coup_ineligibility_reason = f"Ruler protected for {days_remaining} more days"
        
        if not coup_ineligibility_reason:
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
            elif kingdom.ruler_started_at:
                # Check 30-day new ruler protection
                from datetime import datetime
                ruler_tenure = datetime.utcnow() - kingdom.ruler_started_at
                if ruler_tenure.days < 30:
                    days_remaining = 30 - ruler_tenure.days
                    invasion_ineligibility_reason = f"Ruler protected for {days_remaining} more days"
            
            if not invasion_ineligibility_reason:
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
                
                # Check if user is already in an active battle
                if not invasion_ineligibility_reason:
                    from routers.battles import _check_user_in_active_battle
                    in_battle, battle_msg = _check_user_in_active_battle(db, current_user.id)
                    if in_battle:
                        invasion_ineligibility_reason = battle_msg
                
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
            
            # PROPOSE ALLIANCE - Available when in enemy kingdom, user is ruler, not already allied
            can_propose_alliance = False
            alliance_ineligibility_reason = None
            
            if not fiefs_ruled:
                alliance_ineligibility_reason = "Must rule a kingdom to propose alliances"
            elif not kingdom.ruler_id:
                alliance_ineligibility_reason = "Cannot ally with unruled kingdom"
            else:
                # Check if already allied
                my_empire_id = ruled_kingdoms[0].empire_id or ruled_kingdoms[0].id
                target_empire_id = kingdom.empire_id or kingdom.id
                
                if are_empires_allied(db, my_empire_id, target_empire_id):
                    alliance_ineligibility_reason = "Already allied with this empire"
                else:
                    # Check for existing pending proposal
                    from db import Alliance
                    existing_proposal = db.query(Alliance).filter(
                        Alliance.status == 'pending',
                        ((Alliance.initiator_empire_id == my_empire_id) & (Alliance.target_empire_id == target_empire_id)) |
                        ((Alliance.initiator_empire_id == target_empire_id) & (Alliance.target_empire_id == my_empire_id))
                    ).first()
                    
                    if existing_proposal:
                        alliance_ineligibility_reason = "Alliance proposal already pending"
                    else:
                        can_propose_alliance = True
            
            if can_propose_alliance:
                actions["propose_alliance"] = {
                    "ready": True,
                    "seconds_remaining": 0,
                    "unlocked": True,
                    "action_type": "propose_alliance",
                    "requirements_met": True,
                    "title": "Propose Alliance",
                    "icon": "person.2.fill",
                    "description": f"Form alliance with {kingdom.name}",
                    "category": "political",
                    "theme_color": "buttonSuccess",
                    "display_order": 2,
                    "slot": "political",
                    "endpoint": "/alliances/propose",
                    "handler": "propose_alliance",
                    "kingdom_id": kingdom.id,
                    "kingdom_name": kingdom.name,
                }
            else:
                actions["propose_alliance"] = {
                    "ready": False,
                    "seconds_remaining": 0,
                    "unlocked": False,
                    "action_type": "propose_alliance",
                    "requirements_met": False,
                    "requirement_description": alliance_ineligibility_reason,
                    "title": "Propose Alliance",
                    "icon": "person.2.fill",
                    "description": "Form strategic alliance",
                    "category": "political",
                    "theme_color": "buttonSuccess",
                    "display_order": 2,
                    "slot": "political",
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
    
    # SPECTATE BATTLE - Show when visiting a kingdom with an active battle you're not part of
    # This lets visitors watch battles in progress (read-only - can't fight)
    if state.current_kingdom_id and "view_coup" not in actions:
        from db.models import Battle
        
        # Check for active battle in the kingdom we're currently visiting
        local_battle = db.query(Battle).filter(
            Battle.kingdom_id == state.current_kingdom_id,
            Battle.resolved_at.is_(None)
        ).first()
        
        if local_battle:
            attacker_ids = local_battle.get_attacker_ids()
            defender_ids = local_battle.get_defender_ids()
            user_involved = current_user.id in attacker_ids or current_user.id in defender_ids
            
            # Only show spectate if user is NOT involved
            if not user_involved:
                battle_type_name = "Coup" if local_battle.is_coup else "Invasion"
                is_battle_phase = local_battle.is_battle_phase
                
                if is_battle_phase:
                    title = f"⚔️ {battle_type_name} in Progress"
                    description = f"Watch the battle unfold"
                else:
                    title = f"View {battle_type_name}"
                    description = f"Pledge phase - {local_battle.time_remaining_seconds // 60}m remaining"
                
                actions["spectate_battle"] = {
                    "ready": True,
                    "seconds_remaining": 0,
                    "unlocked": True,
                    "action_type": "spectate_battle",
                    "requirements_met": True,
                    "title": title,
                    "icon": "bolt.fill" if local_battle.is_coup else "flag.2.crossed.fill",
                    "description": description,
                    "category": "political",
                    "theme_color": "inkMedium",  # Gray for spectator
                    "display_order": 0,
                    "endpoint": None,
                    "handler": "view_battle",  # Same handler - frontend opens BattleView
                    "button_text": "Watch",
                    "button_color": "inkMedium",
                    "battle_id": local_battle.id,
                    "battle_type": local_battle.type,
                    "can_pledge": False,  # Spectators can't pledge
                    "user_side": None,
                    "user_pledged": False,
                    "battle_status": local_battle.current_phase,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "is_spectator": True,  # NEW: Frontend knows this is spectate-only
                }
    
    # Add slot information and book eligibility to each action
    # Book eligibility is server-driven so we can change it without app updates
    from routers.store import BOOK_ELIGIBLE_SLOTS, BOOK_INELIGIBLE_ACTIONS
    
    for action_key, action_data in actions.items():
        slot = get_action_slot(action_key)
        action_data["slot"] = slot
        
        # Can this action use books to skip cooldown?
        # Must be in eligible slot AND not in the ineligible actions list
        can_use_book = slot in BOOK_ELIGIBLE_SLOTS and action_key not in BOOK_INELIGIBLE_ACTIONS
        action_data["can_use_book"] = can_use_book
    
    # Build slots array - FILTERED by current location
    # Backend is the single source of truth - frontend just renders what we return
    slots = []
    for slot_def in get_all_slot_definitions():
        slot_id = slot_def["id"]
        slot_location = slot_def["location"]
        allow_in_friendly = slot_def.get("allow_in_friendly", False)
        
        # FILTER: Only include slots valid for current location
        # - "any" slots: always show
        # - "home" slots: show in home kingdom, OR in friendly territory if allow_in_friendly=True
        # - "enemy" slots: show in non-home, non-friendly territory
        should_include = False
        if slot_location == "any":
            should_include = True
        elif slot_location == "home":
            # Show in home kingdom, or in friendly territory if allowed
            should_include = is_home_kingdom or (allow_in_friendly and is_friendly_territory)
        elif slot_location == "enemy":
            # Show in enemy territory (not home, not friendly)
            should_include = not is_home_kingdom and not is_friendly_territory
        
        if not should_include:
            continue
        
        # Get actions that belong to this slot
        # Include actions with endpoint OR handler (view_battle uses handler, not endpoint)
        slot_actions = [
            action_key for action_key, action_data in actions.items()
            if action_data.get("slot") == slot_id and (action_data.get("endpoint") or action_data.get("handler"))
        ]
        
        slots.append({
            "id": slot_id,
            "display_name": slot_def["display_name"],
            "icon": slot_def["icon"],
            "color_theme": slot_def["color_theme"],
            "display_order": slot_def["display_order"],
            "description": slot_def["description"],
            "content_type": slot_def["content_type"],  # Tells frontend which renderer to use
            "actions": slot_actions,
            # Backwards compat: old apps filter by location client-side
            # Since we pre-filter, just return "any" so old filtering logic includes everything
            "location": "any",
        })
    
    # Add food cost to property contracts
    for contract in property_contracts:
        contract["food_cost"] = work_food_cost  # Property work uses building slot cooldown
        contract["can_afford_food"] = player_food_total >= work_food_cost
    
    return {
        "parallel_actions_enabled": True,  # NEW: Signals to frontend that parallel actions are supported
        "slot_cooldowns": slot_cooldowns,  # NEW: Per-slot cooldown status
        "slots": slots,  # Pre-filtered by backend based on current location - frontend just renders
        "global_cooldown": slot_cooldowns.get("building", {"ready": True, "seconds_remaining": 0}),  # For old clients
        "actions": actions,  # DYNAMIC ACTION LIST
        # Food system - actions cost food based on cooldown (0.5 food per minute)
        "player_food_total": player_food_total,
        "food_cost_per_minute": 0.4,  # For frontend to calculate costs dynamically (minutes / 2.5)
        # Legacy structure for backward compatibility
        "work": actions["work"],
        "patrol": actions["patrol"],
        "farm": actions["farm"],
        "sabotage": actions["scout"],  # Legacy - now "Covert Operation" with tier-based outcomes
        "training": actions["training"],
        "crafting": actions["crafting"],
        "vault_heist": actions["scout"],  # Legacy - now "Covert Operation" (T5 unlocks heist outcome)
        "scout": actions["scout"],
        "training_contracts": get_training_contracts_for_status(db, current_user.id, kingdom.tax_rate if kingdom else 0, is_ruler),
        "training_costs": _get_training_costs_dict(state),
        "crafting_queue": get_crafting_contracts_for_status(db, current_user.id),
        "crafting_costs": crafting_costs,
        "workshop_contracts": get_workshop_contracts_for_status(db, current_user.id),  # Workshop crafting
        "property_upgrade_contracts": property_contracts,
        "contracts": contracts,
        # Alliance requests for rulers - shows in ActionsView with accept/decline buttons
        "pending_alliance_requests": get_pending_alliance_requests(db, current_user, state)
    }
