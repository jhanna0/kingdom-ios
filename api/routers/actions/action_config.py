"""
ACTION CONFIGURATION - Single Source of Truth for ALL actions
Defines cooldowns, metadata, requirements, and display info for every action in the game
"""

# ===== ACTION TYPES - SINGLE SOURCE OF TRUTH =====
# Add new actions HERE and they'll appear everywhere with proper cooldowns!

ACTION_TYPES = {
    "work": {
        "display_name": "Work on Contract",
        "icon": "hammer.fill",
        "description": "Build kingdom infrastructure",
        "category": "beneficial",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "inkMedium",
        "display_order": 10,
        "endpoint": "/actions/contracts/{contract_id}/work",
        "always_unlocked": True,
        "requirements": None
    },
    "patrol": {
        "display_name": "Patrol",
        "icon": "eye.fill",
        "description": "Guard against saboteurs for 10 minutes",
        "category": "beneficial",
        "cooldown_minutes": 10,
        "duration_minutes": 10,  # Active patrol duration
        "theme_color": "buttonPrimary",
        "display_order": 20,
        "endpoint": "/actions/patrol",
        "always_unlocked": True,
        "requirements": None,
        "rewards": {
            "reputation": 5
        }
    },
    "farm": {
        "display_name": "Farm",
        "icon": "leaf.fill",
        "description": "Work the fields to earn gold",
        "category": "beneficial",
        "cooldown_minutes": 10,
        "theme_color": "buttonSuccess",
        "display_order": 30,
        "endpoint": "/actions/farm",
        "always_unlocked": True,
        "requirements": None,
        "rewards": {
            "gold": 10  # Base reward
        }
    },
    "scout": {
        "display_name": "Infiltrate",
        "icon": "eye.fill",
        "description": "Hostile operation in enemy territory. Higher tiers unlock better outcomes!",
        "category": "hostile",
        "cooldown_minutes": 30,
        "theme_color": "royalEmerald",
        "display_order": 5,
        "endpoint": "/incidents/trigger",
        "always_unlocked": False,
        "requirements": {
            "skill": "intelligence",
            "skill_level": 1,
            "location": "enemy_kingdom",
            "cost": 100,
            "requirement_text": "Intelligence T1+ (100g). T3: disruption, T5: sabotage/heist"
        }
    },
    # NOTE: sabotage and vault_heist are now OUTCOMES of the incident probability bar
    # T1: intel only, T3: +disruption, T5: +contract_sabotage, +vault_heist
    "training": {
        "display_name": "Training",
        "icon": "figure.run",
        "description": "Train your skills",
        "category": "training",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "buttonPrimary",
        "display_order": 1,
        "endpoint": "/actions/training/{contract_id}/work",
        "always_unlocked": True,
        "requirements": {
            "property": "house",
            "property_tier": 2,
            "requirement_text": "House (Tier 2 property) required in some kingdom"
        },
        "rewards": {
            "experience": "varies_by_skill_level"
        }
    },
    "crafting": {
        "display_name": "Crafting",
        "icon": "wrench.and.screwdriver.fill",
        "description": "Craft weapons and armor",
        "category": "crafting",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "inkMedium",
        "display_order": 1,
        "endpoint": "/actions/crafting",
        "always_unlocked": False,
        "requirements": {
            "property": "workshop",
            "property_tier": 3,
            "requirement_text": "Workshop (Tier 3 property) required"
        }
    },
    "property_upgrade": {
        "display_name": "Property Upgrade",
        "icon": "house.fill",
        "description": "Work on upgrading your property",
        "category": "property",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "buttonPrimary",
        "display_order": 1,
        "endpoint": "/actions/work-property/{contract_id}",
        "always_unlocked": False,
        "requirements": {
            "property": "owned",
            "requirement_text": "Must own a property with active upgrade"
        }
    },
    "stage_coup": {
        "display_name": "Stage Coup",
        "icon": "bolt.fill",
        "description": "Overthrow the current ruler and seize power",
        "category": "political",
        "cooldown_minutes": 0,  # No cooldown - but has other restrictions
        "theme_color": "buttonSpecial",
        "display_order": 1,
        "endpoint": "/coups/initiate",
        "always_unlocked": False,
        "requirements": {
            "skill": "leadership",
            "skill_level": 3,
            "kingdom_reputation": 500,
            "location": "not_ruler",
            "requirement_text": "Leadership T3+, 500 kingdom rep, not the ruler"
        }
    },
    "declare_invasion": {
        "display_name": "Declare Invasion",
        "icon": "flag.2.crossed.fill",
        "description": "Declare war on this kingdom and conquer it",
        "category": "warfare",
        "cooldown_minutes": 0,  # No cooldown - but has other restrictions
        "theme_color": "buttonDanger",
        "display_order": 1,
        "endpoint": "/battles/invasion/declare",
        "always_unlocked": False,
        "requirements": {
            "location": "enemy_kingdom",
            "must_be_ruler": True,
            "requirement_text": "Must rule a kingdom to invade. Must be at target kingdom."
        }
    }
}


# ===== ACTION SLOT SYSTEM (Parallel Actions) =====
# Maps action_type to slot category - actions in different slots can run in parallel!
# Actions in the SAME slot block each other (only 1 at a time per slot)

ACTION_SLOTS = {
    # BUILDING SLOT - Kingdom/property construction work
    "work": "building",
    "property_upgrade": "building",
    
    # ECONOMY SLOT - Resource gathering
    "farm": "economy",
    
    # SECURITY SLOT - Defense and reconnaissance
    "patrol": "security",
    
    # INTELLIGENCE SLOT - Hostile operations (ONE action, outcomes scale with tier)
    "scout": "intelligence",          # Triggers incidents - outcomes: intel, disruption, sabotage, heist
    
    # PERSONAL SLOT - Self-improvement
    "training": "personal",
    "crafting": "personal",
    
    # POLITICAL SLOT - Power struggles (initiate coups)
    "stage_coup": "political",
    
    # WARFARE SLOT - External conquest (declare invasions)
    "declare_invasion": "warfare",
    
    # ACTIVE BATTLES SLOT - View/participate in battles you've joined (shows ANYWHERE)
    "view_coup": "active_battles",
    "view_invasion": "active_battles",
    "view_battle": "active_battles",
}


# ===== SLOT DEFINITIONS - Frontend Rendering Metadata =====
# Defines display name, icon, color, and order for each slot
# Frontend renders these dynamically - NO hardcoding allowed!

SLOT_DEFINITIONS = {
    "personal": {
        "id": "personal",
        "display_name": "Training",
        "icon": "figure.strengthtraining.traditional",
        "color_theme": "buttonPrimary",
        "display_order": 1,
        "description": "Train your skills - complete actions to level up",
        "location": "any",  # Can be done anywhere
        "content_type": "training_contracts",  # Frontend uses this to pick renderer
    },
    "building": {
        "id": "building",
        "display_name": "Building",
        "icon": "hammer.fill",
        "color_theme": "inkMedium",
        "display_order": 2,
        "description": "Construct and upgrade infrastructure",
        "location": "home",  # Home kingdom only
        "content_type": "building_contracts",  # Kingdom + property contracts
    },
    "economy": {
        "id": "economy",
        "display_name": "Economy",
        "icon": "leaf.fill",
        "color_theme": "buttonSuccess",
        "display_order": 3,
        "description": "Gather resources and earn gold",
        "location": "home",  # Home kingdom only
        "content_type": "actions",  # Generic action cards
    },
    "security": {
        "id": "security",
        "display_name": "Security",
        "icon": "eye.fill",
        "color_theme": "buttonPrimary",
        "display_order": 4,
        "description": "Protect your kingdom from threats",
        "location": "home",  # Home kingdom only
        "content_type": "actions",
    },
    "intelligence": {
        "id": "intelligence",
        "display_name": "Intelligence",
        "icon": "eye.fill",
        "color_theme": "royalEmerald",
        "display_order": 5,
        "description": "Infiltrate enemy territory",
        "location": "enemy",  # Enemy kingdom only
        "content_type": "actions",
    },
    "political": {
        "id": "political",
        "display_name": "⚔️ Political",
        "icon": "shield.lefthalf.filled.badge.checkmark",
        "color_theme": "buttonDanger",
        "display_order": 0,  # Show at top - coups are important!
        "description": "Seize power through political action",
        "location": "home",  # Shows in "home" but action only added when not ruler
        "content_type": "actions",
    },
    "warfare": {
        "id": "warfare",
        "display_name": "⚔️ Warfare",
        "icon": "flag.2.crossed.fill",
        "color_theme": "buttonDanger",
        "display_order": 0,  # Show at top - invasions are important!
        "description": "Declare war and conquer enemy kingdoms",
        "location": "enemy",  # Only shows in enemy territory
        "content_type": "actions",
    },
    "active_battles": {
        "id": "active_battles",
        "display_name": "⚔️ Active Battle",
        "icon": "flame.fill",
        "color_theme": "buttonDanger",
        "display_order": -1,  # Show FIRST - battles are urgent!
        "description": "You have an active battle - fight from anywhere!",
        "location": "any",  # Shows EVERYWHERE - once joined, fight from anywhere
        "content_type": "actions",
    },
}


def get_slot_definition(slot_id: str) -> dict:
    """Get the full definition for a slot"""
    return SLOT_DEFINITIONS.get(slot_id, {
        "id": slot_id,
        "display_name": slot_id.replace("_", " ").title(),
        "icon": "circle.fill",
        "color_theme": "inkMedium",
        "display_order": 99,
        "description": "",
        "location": "any",
    })


def get_all_slot_definitions() -> list:
    """Get all slot definitions sorted by display order"""
    return sorted(
        SLOT_DEFINITIONS.values(),
        key=lambda s: s.get("display_order", 99)
    )


def get_slots_for_location(location: str) -> list:
    """Get slots available for a specific location (home, enemy, any)"""
    result = []
    for slot in get_all_slot_definitions():
        slot_location = slot.get("location", "any")
        if slot_location == "any" or slot_location == location:
            result.append(slot)
    return result


def get_action_slot(action_type: str) -> str:
    """Get the slot category for an action type"""
    return ACTION_SLOTS.get(action_type, "default")


def actions_conflict(action1: str, action2: str) -> bool:
    """Check if two actions would conflict (same slot)"""
    return get_action_slot(action1) == get_action_slot(action2)


# ===== HELPER FUNCTIONS =====

def get_action_config(action_type: str) -> dict:
    """Get configuration for a specific action type"""
    return ACTION_TYPES.get(action_type, {})


def get_action_cooldown(action_type: str) -> float:
    """Get BASE cooldown in minutes for an action (before skill adjustment)"""
    config = get_action_config(action_type)
    return config.get("cooldown_minutes", 120)  # Default 2 hours


def get_action_food_cost(action_type: str, cooldown_minutes: float = None) -> int:
    """Get food cost for an action based on its cooldown.
    
    If cooldown_minutes is provided, uses that (for skill-adjusted cooldowns).
    Otherwise uses base cooldown from config.
    
    Food cost = cooldown_minutes * 0.5 (from tiers.FOOD_COST_PER_COOLDOWN_MINUTE)
    """
    from routers.tiers import calculate_food_cost
    
    if cooldown_minutes is None:
        cooldown_minutes = get_action_cooldown(action_type)
    
    return calculate_food_cost(cooldown_minutes)


def get_actions_by_category(category: str) -> dict:
    """Get all actions of a specific category"""
    return {
        key: value for key, value in ACTION_TYPES.items()
        if value.get("category") == category
    }


def get_all_action_types() -> list:
    """Get list of all action type keys"""
    return list(ACTION_TYPES.keys())


# ===== LEGACY CONSTANTS (for backwards compatibility) =====
# TODO: Migrate all code to use ACTION_TYPES directly via get_action_config()
# These module-level constants are fragile - they're evaluated at import time
# and break if the ACTION_TYPES structure changes.
# Better approach: Use get_action_config("patrol")["rewards"].get("gold", 0) directly in code

WORK_BASE_COOLDOWN = ACTION_TYPES["work"]["cooldown_minutes"]
PATROL_COOLDOWN = ACTION_TYPES["patrol"]["cooldown_minutes"]
FARM_COOLDOWN = ACTION_TYPES["farm"]["cooldown_minutes"]
SABOTAGE_COOLDOWN = 120  # Legacy - sabotage is now an incident outcome
TRAINING_COOLDOWN = ACTION_TYPES["training"]["cooldown_minutes"]
CRAFTING_BASE_COOLDOWN = ACTION_TYPES["crafting"]["cooldown_minutes"]

# Covert operation (scout) - ONE action, outcomes scale with intelligence tier
# T1: intel, T3: +disruption, T5: +contract_sabotage, +vault_heist
SCOUT_COOLDOWN = ACTION_TYPES["scout"]["cooldown_minutes"]
SCOUT_COST = 100  # Gold cost to trigger

# Vault heist outcome config (when rolled on probability bar at T5)
HEIST_PERCENT = 0.10
MIN_HEIST_AMOUNT = 500

# Action rewards (use .get() for safety - rewards structure may vary)
FARM_GOLD_REWARD = ACTION_TYPES["farm"]["rewards"].get("gold", 0)
PATROL_GOLD_REWARD = ACTION_TYPES["patrol"]["rewards"].get("gold", 0)
PATROL_REPUTATION_REWARD = ACTION_TYPES["patrol"]["rewards"].get("reputation", 0)

# Patrol duration
PATROL_DURATION_MINUTES = ACTION_TYPES["patrol"]["duration_minutes"]

