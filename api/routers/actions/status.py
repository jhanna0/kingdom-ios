"""
Action status endpoint - Get cooldown status for all actions
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
import json

from db import get_db, User, PlayerState, Contract, UnifiedContract, ContractContribution
from routers.auth import get_current_user
from routers.property import get_tier_name  # Import tier name helper
from .utils import check_cooldown_from_table, calculate_cooldown, check_global_action_cooldown_from_table, is_patrolling
from .training import calculate_training_cost, TRAINING_TYPES
from .crafting import get_craft_cost, get_iron_required, get_steel_required, get_actions_required, get_stat_bonus, CRAFTING_TYPES
from .constants import (
    WORK_BASE_COOLDOWN,
    PATROL_COOLDOWN,
    FARM_COOLDOWN,
    FARM_GOLD_REWARD,
    SABOTAGE_COOLDOWN,
    SCOUT_COOLDOWN,
    SCOUT_GOLD_REWARD,
    TRAINING_COOLDOWN,
    PATROL_REPUTATION_REWARD,
    MIN_INTELLIGENCE_REQUIRED,
    VAULT_HEIST_COOLDOWN_HOURS
)


router = APIRouter()


def get_training_contracts_for_status(db: Session, user_id: int) -> list:
    """Get training contracts from unified_contracts table for status endpoint"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type.in_(TRAINING_TYPES),
        UnifiedContract.status == 'in_progress'
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
            "created_at": contract.created_at.isoformat() if contract.created_at else None,
            "status": contract.status
        })
    
    return result


def get_crafting_contracts_for_status(db: Session, user_id: int) -> list:
    """Get crafting contracts from unified_contracts table for status endpoint"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type.in_(CRAFTING_TYPES),
        UnifiedContract.status == 'in_progress'
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
            "created_at": contract.created_at.isoformat() if contract.created_at else None,
            "status": contract.status
        })
    
    return result


def get_property_contracts_for_status(db: Session, user_id: int) -> list:
    """Get property contracts from unified_contracts table for status endpoint"""
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.type == 'property',
        UnifiedContract.status == 'in_progress'
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
            "status": contract.status,
            "started_at": contract.created_at.isoformat() if contract.created_at else None
        })
    
    return result


@router.get("/status")
def get_action_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get cooldown status for all actions AND available contracts in current kingdom"""
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
    scout_cooldown = SCOUT_COOLDOWN
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
    
    # Get contracts for current kingdom
    contracts = []
    if state.current_kingdom_id:
        from routers.contracts import contract_to_response
        contracts_query = db.query(Contract).filter(
            Contract.kingdom_id == state.current_kingdom_id,
            Contract.status.in_(["open", "in_progress"])
        ).all()
        contracts = [contract_to_response(c) for c in contracts_query]
    
    # Check global action cooldown (ONE ACTION AT A TIME!)
    global_cooldown = check_global_action_cooldown_from_table(
        db,
        current_user.id,
        work_cooldown, 
        patrol_cooldown,
        farm_cooldown,
        sabotage_cooldown, 
        scout_cooldown, 
        training_cooldown
    )
    
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
    
    # Scout reward (no tax or bonus for scouts in enemy territory)
    scout_reward = SCOUT_GOLD_REWARD
    
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
    
    # Scout - Requires Tier 1 Intelligence
    if state.intelligence >= 1:
        actions["scout"] = {
            **check_cooldown_from_table(db, current_user.id, "scout", scout_cooldown),
            "cooldown_minutes": scout_cooldown,
            "expected_reward": {
                "gold": scout_reward
            },
            "unlocked": True,
            "action_type": "scout",
            "title": "Scout Kingdom",
            "icon": "magnifyingglass",
            "description": "Gather intelligence on enemy kingdom",
            "category": "hostile",
            "theme_color": "buttonWarning",
            "display_order": 10,
            "endpoint": f"/actions/scout/{state.current_kingdom_id}" if state.current_kingdom_id else None
        }
    else:
        actions["scout"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "scout",
            "requirements_met": False,
            "requirement_description": f"Requires T1 Intelligence (you: T{state.intelligence})",
            "title": "Scout Kingdom",
            "icon": "magnifyingglass",
            "description": "Gather intelligence on enemy kingdom",
            "category": "hostile",
            "theme_color": "buttonWarning",
            "endpoint": None
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
    
    # INTELLIGENCE-GATED ACTIONS - dynamically add based on requirements
    # For sabotage, get the active contract in current kingdom (if any)
    sabotage_endpoint = None
    if state.current_kingdom_id:
        from db.models.unified_contract import UnifiedContract
        active_contract = db.query(UnifiedContract).filter(
            UnifiedContract.kingdom_id == state.current_kingdom_id,
            UnifiedContract.type.in_(["wall", "vault", "mine", "market", "farm", "education"]),
            UnifiedContract.status.in_(["open", "in_progress"])
        ).first()
        if active_contract:
            sabotage_endpoint = f"/actions/sabotage/{active_contract.id}"
    
    if state.intelligence >= 4:
        actions["sabotage"] = {
            **check_cooldown_from_table(db, current_user.id, "sabotage", sabotage_cooldown),
            "cooldown_minutes": sabotage_cooldown,
            "unlocked": True,
            "action_type": "sabotage",
            "requirements_met": True,
            "title": "Sabotage Contract",
            "icon": "flame.fill",
            "description": "Delay enemy construction projects (300g cost)",
            "category": "hostile",
            "theme_color": "buttonDanger",
            "endpoint": sabotage_endpoint
        }
    else:
        actions["sabotage"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "sabotage",
            "requirements_met": False,
            "requirement_description": f"Requires T4 Intelligence (you: T{state.intelligence})",
            "title": "Sabotage Contract",
            "icon": "flame.fill",
            "description": "Delay enemy construction projects",
            "category": "hostile",
            "theme_color": "buttonDanger",
            "endpoint": None
        }
    
    if state.intelligence >= MIN_INTELLIGENCE_REQUIRED:
        actions["vault_heist"] = {
            **check_cooldown_from_table(db, current_user.id, "vault_heist", VAULT_HEIST_COOLDOWN_HOURS * 60),
            "cooldown_minutes": VAULT_HEIST_COOLDOWN_HOURS * 60,
            "unlocked": True,
            "action_type": "vault_heist",
            "requirements_met": True,
            "title": "Vault Heist",
            "icon": "banknote.fill",
            "description": "Steal 10% of kingdom vault (1000g cost, 7 day cooldown)",
            "category": "hostile",
            "theme_color": "buttonSpecial",
            "endpoint": f"/actions/vault-heist/{state.current_kingdom_id}" if state.current_kingdom_id else None
        }
    else:
        actions["vault_heist"] = {
            "ready": False,
            "seconds_remaining": 0,
            "unlocked": False,
            "action_type": "vault_heist",
            "requirements_met": False,
            "requirement_description": f"Requires Intelligence Tier {MIN_INTELLIGENCE_REQUIRED} (current: Tier {state.intelligence})",
            "title": "Vault Heist",
            "icon": "banknote.fill",
            "description": "Steal from enemy kingdom vault",
            "category": "hostile",
            "theme_color": "buttonSpecial",
            "endpoint": None
        }
    
    return {
        "global_cooldown": global_cooldown,
        "actions": actions,  # DYNAMIC ACTION LIST
        # Legacy structure for backward compatibility
        "work": actions["work"],
        "patrol": actions["patrol"],
        "farm": actions["farm"],
        "sabotage": actions["sabotage"],
        "scout": actions["scout"],
        "training": actions["training"],
        "crafting": actions["crafting"],
        "vault_heist": actions.get("vault_heist"),
        "training_contracts": get_training_contracts_for_status(db, current_user.id),
        "training_costs": {
            "attack": calculate_training_cost(state.attack_power),
            "defense": calculate_training_cost(state.defense_power),
            "leadership": calculate_training_cost(state.leadership),
            "building": calculate_training_cost(state.building_skill)
        },
        "crafting_queue": get_crafting_contracts_for_status(db, current_user.id),
        "crafting_costs": crafting_costs,
        "property_upgrade_contracts": property_contracts,
        "contracts": contracts
    }
