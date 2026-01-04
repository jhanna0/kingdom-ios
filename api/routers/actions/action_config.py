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
            "gold": 5,
            "reputation": 5
        }
    },
    "farm": {
        "display_name": "Farm",
        "icon": "leaf.fill",
        "description": "Work the fields to earn gold",
        "category": "beneficial",
        "cooldown_minutes": 1,
        "theme_color": "buttonSuccess",
        "display_order": 30,
        "endpoint": "/actions/farm",
        "always_unlocked": True,
        "requirements": None,
        "rewards": {
            "gold": 10  # Base reward
        }
    },
    "chop_wood": {
        "display_name": "Chop Wood",
        "icon": "tree.fill",
        "description": "Gather wood from the lumbermill",
        "category": "beneficial",
        "cooldown_minutes": 10,
        "theme_color": "buttonSuccess",
        "display_order": 35,
        "endpoint": "/actions/chop-wood",
        "always_unlocked": False,
        "requirements": {
            "building": "lumbermill",
            "building_level": 1,
            "requirement_text": "Kingdom must have a Lumbermill"
        },
        "rewards": {
            "wood": "varies_by_lumbermill_level"
        }
    },
    "sabotage": {
        "display_name": "Sabotage",
        "icon": "bolt.fill",
        "description": "Damage enemy kingdom infrastructure",
        "category": "hostile",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "buttonDanger",
        "display_order": 10,
        "endpoint": "/actions/sabotage",
        "always_unlocked": True,
        "requirements": {
            "location": "enemy_kingdom",
            "requirement_text": "Must be in an enemy kingdom"
        }
    },
    "scout": {
        "display_name": "Scout",
        "icon": "eye.circle.fill",
        "description": "Gather intelligence on enemy defenses",
        "category": "hostile",
        "cooldown_minutes": 120,  # 2 hours
        "theme_color": "buttonDanger",
        "display_order": 20,
        "endpoint": "/actions/scout",
        "always_unlocked": True,
        "requirements": {
            "location": "enemy_kingdom",
            "requirement_text": "Must be in an enemy kingdom"
        },
        "rewards": {
            "gold": 10
        }
    },
    "vault_heist": {
        "display_name": "Vault Heist",
        "icon": "banknote.fill",
        "description": "Steal 10% of enemy vault (high risk!)",
        "category": "hostile",
        "cooldown_minutes": 10080,  # 7 days (168 hours)
        "cooldown_hours": 168,
        "theme_color": "buttonDanger",
        "display_order": 30,
        "endpoint": "/actions/intelligence/vault-heist",
        "always_unlocked": False,
        "requirements": {
            "skill": "intelligence",
            "skill_level": 5,
            "location": "enemy_kingdom",
            "requirement_text": "Intelligence Tier 5+ required",
            "cost": 1000  # Gold cost
        },
        "rewards": {
            "gold": "10%_of_enemy_vault"
        }
    },
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
        "endpoint": "/actions/property/{contract_id}/work",
        "always_unlocked": False,
        "requirements": {
            "property": "owned",
            "requirement_text": "Must own a property with active upgrade"
        }
    }
}


# ===== HELPER FUNCTIONS =====

def get_action_config(action_type: str) -> dict:
    """Get configuration for a specific action type"""
    return ACTION_TYPES.get(action_type, {})


def get_action_cooldown(action_type: str) -> float:
    """Get cooldown in minutes for an action"""
    config = get_action_config(action_type)
    return config.get("cooldown_minutes", 120)  # Default 2 hours


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
# These pull from ACTION_TYPES to maintain compatibility with existing code

WORK_BASE_COOLDOWN = ACTION_TYPES["work"]["cooldown_minutes"]
PATROL_COOLDOWN = ACTION_TYPES["patrol"]["cooldown_minutes"]
FARM_COOLDOWN = ACTION_TYPES["farm"]["cooldown_minutes"]
SABOTAGE_COOLDOWN = ACTION_TYPES["sabotage"]["cooldown_minutes"]
SCOUT_COOLDOWN = ACTION_TYPES["scout"]["cooldown_minutes"]
TRAINING_COOLDOWN = ACTION_TYPES["training"]["cooldown_minutes"]
CRAFTING_BASE_COOLDOWN = ACTION_TYPES["crafting"]["cooldown_minutes"]

# Vault heist configuration
VAULT_HEIST_COOLDOWN = ACTION_TYPES["vault_heist"]["cooldown_minutes"]
VAULT_HEIST_COOLDOWN_HOURS = ACTION_TYPES["vault_heist"]["cooldown_hours"]
MIN_INTELLIGENCE_REQUIRED = 5
HEIST_COST = ACTION_TYPES["vault_heist"]["requirements"]["cost"]
HEIST_PERCENT = 0.10
MIN_HEIST_AMOUNT = 500
BASE_HEIST_DETECTION = 0.3
VAULT_LEVEL_BONUS = 0.05
INTELLIGENCE_REDUCTION = 0.04
PATROL_BONUS = 0.02
HEIST_REP_LOSS = 500
HEIST_BAN = True

# Action rewards
FARM_GOLD_REWARD = ACTION_TYPES["farm"]["rewards"]["gold"]
SCOUT_GOLD_REWARD = ACTION_TYPES["scout"]["rewards"]["gold"]
PATROL_GOLD_REWARD = ACTION_TYPES["patrol"]["rewards"]["gold"]
PATROL_REPUTATION_REWARD = ACTION_TYPES["patrol"]["rewards"]["reputation"]

# Patrol duration
PATROL_DURATION_MINUTES = ACTION_TYPES["patrol"]["duration_minutes"]

