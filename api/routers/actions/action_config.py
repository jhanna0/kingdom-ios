"""
ACTION CONFIGURATION - Single Source of Truth for ALL actions
Defines cooldowns, metadata, requirements, and display info for every action in the game
"""

# ===== ACTIVITY ICONS - For player status display =====
# Maps activity type -> SF Symbol name
# Used by players.py to show what players are currently doing
ACTIVITY_ICONS = {
    # Idle
    "idle": "person.fill",
    # Actions
    "working": "hammer.fill",
    "patrolling": "eye.fill",
    "training": "figure.run",  # From ACTION_TYPES["training"]["icon"]
    "crafting": "wrench.and.screwdriver.fill",
    "scouting": "binoculars.fill",
    "sabotage": "bolt.slash.fill",
    # Minigames
    "fishing": "fish.fill",  # From fishing/config.py
    "foraging": "leaf.fill",
    "hunting": "scope",  # From hunting/config.py
    "researching": "flask.fill",  # From science/config.py
}


# ===== ACTION TYPES - SINGLE SOURCE OF TRUTH =====
# Add new actions HERE and they'll appear everywhere with proper cooldowns!

# ===== COST MODELS =====
# Defines how costs are structured for different action types
# Frontend uses this to render cost displays dynamically

COST_MODELS = {
    "none": {
        "description": "No cost to perform this action",
    },
    "fixed_gold": {
        "description": "Fixed gold cost per action",
        "fields": ["gold"],
    },
    "per_action_gold": {
        "description": "Gold cost per action (Pay-As-You-Go). Base burned, tax to kingdom.",
        "fields": ["gold_per_action"],
        "tax_model": "on_top",  # Tax added on top of base
    },
    "per_action_resources": {
        "description": "Resources consumed per action (from tier config)",
        "fields": ["per_action_costs"],  # List of {resource, amount}
    },
    "upfront_gold_per_action_resources": {
        "description": "Gold paid upfront, resources per action",
        "fields": ["gold_upfront", "per_action_costs"],
    },
    "upfront_all": {
        "description": "All costs paid upfront (gold + resources)",
        "fields": ["gold", "iron", "steel", "wood"],
    },
    "dynamic_formula": {
        "description": "Cost calculated from formula (see config_ref)",
        "fields": ["config_ref"],  # Reference to TRAINING_CONFIG, etc.
    },
}


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
        "requirements": None,
        # COSTS: Resources per action (from building tier config) + gold reward from treasury
        "costs": {
            "model": "per_action_resources",
            "config_ref": "BUILDING_TYPES[type].tiers[tier].per_action_costs",
            "description": "Resources from tier config. Gold earned from treasury (ruler-set)."
        },
        "rewards": {
            "gold": "from_contract",  # action_reward set by ruler
            "experience": 10
        }
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
        "costs": {
            "model": "none",
            "description": "Free to patrol"
        },
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
        "costs": {
            "model": "none",
            "description": "Free - earns gold"
        },
        "rewards": {
            "gold": 10  # Base reward (taxed)
        }
    },
    "scout": {
        "display_name": "Scout",
        "icon": "eye.fill",
        "description": "Gather intelligence on enemy kingdom. Higher tiers unlock better outcomes!",
        "category": "hostile",
        "cooldown_minutes": 30,
        "theme_color": "royalEmerald",
        "display_order": 5,
        "endpoint": "/actions/scout",
        "always_unlocked": False,
        "requirements": {
            "skill": "intelligence",
            "skill_level": 1,
            "location": "enemy_kingdom",
            "requirement_text": "Intelligence T1+ (100g). T3: military intel, T5: disruption, T7: heist"
        },
        # COSTS: Fixed gold per scout action
        "costs": {
            "model": "fixed_gold",
            "gold": 100,
            "description": "100g to scout enemy kingdom"
        }
    },
    "training": {
        "display_name": "Training",
        "icon": "figure.run",
        "description": "Train your skills - Pay-As-You-Go",
        "category": "training",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "buttonPrimary",
        "display_order": 1,
        "endpoint": "/actions/train/{contract_id}",
        "always_unlocked": True,
        "requirements": {
            "property": "house",
            "property_tier": 2,
            "requirement_text": "House (Tier 2 property) required in some kingdom"
        },
        # COSTS: Dynamic gold per action (from TRAINING_CONFIG)
        "costs": {
            "model": "dynamic_formula",
            "config_ref": "TRAINING_CONFIG",
            "formula": "10 + 2 * total_skill_points",
            "tax_model": "on_top",  # Tax added on top, base burned
            "description": "Gold per action scales with total skill points. Base burned, tax to kingdom."
        },
        "rewards": {
            "experience": 10,
            "experience_on_complete": 25
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
        },
        # COSTS: Upfront gold + resources (from EQUIPMENT_TIERS)
        "costs": {
            "model": "upfront_all",
            "config_ref": "EQUIPMENT_TIERS[tier]",
            "description": "Gold and resources paid upfront. Costs from equipment tier."
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
        },
        # COSTS: Gold upfront + resources per action (from PROPERTY_TIERS)
        "costs": {
            "model": "upfront_gold_per_action_resources",
            "config_ref": "PROPERTY_TIERS[tier]",
            "description": "Gold paid upfront to start. Wood/iron consumed each action."
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
        },
        "costs": {
            "model": "fixed_gold",
            "gold": 1000,  # Base cost (reduced by Leadership 5)
            "gold_with_leadership_5": 500,
            "description": "1000g to initiate coup (500g with Leadership 5)"
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
        },
        "costs": {
            "model": "fixed_gold",
            "gold": 5000,
            "description": "5000g from YOUR kingdom treasury to declare invasion"
        }
    },
    "propose_alliance": {
        "display_name": "Propose Alliance",
        "icon": "person.2.fill",
        "description": "Form a strategic alliance with this empire",
        "category": "political",
        "cooldown_minutes": 0,  # No cooldown
        "theme_color": "buttonSuccess",
        "display_order": 2,
        "endpoint": "/alliances/propose",
        "always_unlocked": False,
        "requirements": {
            "location": "enemy_kingdom",
            "must_be_ruler": True,
            "not_allied": True,
            "requirement_text": "Must rule a kingdom. Target must have a ruler. Cannot be already allied."
        },
        "costs": {
            "model": "none",
            "description": "Free to propose alliance"
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
    
    # PERSONAL SLOT - Training
    "training": "personal",
    
    # CRAFTING SLOT - Workshop crafting
    "crafting": "crafting",
    "workshop_craft": "crafting",
    
    # POLITICAL SLOT - Power struggles (initiate coups)
    "stage_coup": "political",
    
    # WARFARE SLOT - External conquest (declare invasions)
    "declare_invasion": "warfare",
    
    # POLITICAL SLOT - Also includes alliance proposals (enemy territory)
    "propose_alliance": "political",
    
    # ACTIVE BATTLES SLOT - View/participate in battles you've joined (shows ANYWHERE)
    "view_coup": "active_battles",
    "view_invasion": "active_battles",
    "view_battle": "active_battles",
    "spectate_battle": "active_battles",  # Spectate battles in cities you're visiting
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
        "location": "any",
        "content_type": "training_contracts",
    },
    "crafting": {
        "id": "crafting",
        "display_name": "Crafting",
        "icon": "hammer.fill",
        "color_theme": "buttonWarning",
        "display_order": 2,
        "description": "Craft equipment from blueprints",
        "location": "any",
        "content_type": "workshop_contracts",
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
        "display_name": "Political",
        "icon": "shield.lefthalf.filled.badge.checkmark",
        "color_theme": "buttonDanger",
        "display_order": 0,  # Show at top
        "description": "Political actions - coups and alliances",
        "location": "any",  # Shows in both home (coups) and enemy (alliances)
        "content_type": "actions",
    },
    "warfare": {
        "id": "warfare",
        "display_name": "Warfare",
        "icon": "flag.2.crossed.fill",
        "color_theme": "buttonDanger",
        "display_order": 0,  # Show at top - invasions are important!
        "description": "Declare war and conquer enemy kingdoms",
        "location": "enemy",  # Only shows in enemy territory
        "content_type": "actions",
    },
    "active_battles": {
        "id": "active_battles",
        "display_name": "Active Battle",
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

