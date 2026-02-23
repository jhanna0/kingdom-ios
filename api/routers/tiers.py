"""
UNIFIED TIER SYSTEM - Single Source of Truth for ALL game tier descriptions
Handles: Properties, Skills, Buildings, Crafting, Training, Actions
NO MORE HARDCODING DESCRIPTIONS IN FRONTEND!
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from db import get_db, User
from routers.auth import get_current_user

router = APIRouter(prefix="/tiers", tags=["tiers"])


# ===== SCALING CONSTANTS =====
# Kingdom building contract costs scale with level and population

BUILDING_BASE_CONSTRUCTION_COST = 1000

# ===== FOOD COST SYSTEM =====
# Actions cost food based on their cooldown duration
# This gives food a meaningful purpose and creates resource trade-offs

FOOD_COST_PER_COOLDOWN_MINUTE = 0.25  # 0.4 food per minute of cooldown (minutes / 2.5)
BUILDING_LEVEL_COST_EXPONENT = 1.7
BUILDING_POPULATION_COST_DIVISOR = 50

# NOTE: Building action scaling constants moved to kingdom_service.py
# Formula: max(100, active_citizens × 13) × level_multiplier
# See kingdom_service.py for: BUILDING_ACTIONS_PER_CITIZEN, BUILDING_ACTIONS_MINIMUM, BUILDING_LEVEL_MULTIPLIERS


def calculate_food_cost(cooldown_minutes: float) -> int:
    """Calculate food cost for an action based on its cooldown duration.
    
    Formula: floor(cooldown_minutes / 2.5)
    
    Examples (at 0.4 food/min):
    - 10 min cooldown (farm, patrol): 4 food
    - 30 min cooldown (scout): 12 food  
    - 90 min cooldown (work, training, crafting): 36 food
    
    Returns integer (floored, minimum 1)
    """
    import math
    return max(1, math.floor(cooldown_minutes * FOOD_COST_PER_COOLDOWN_MINUTE))


# ===== TRAINING SCALING PARAMETERS =====
# Gold and action costs for personal skill training
# Tunable params - adjust these to balance economy
#
# DESIGN: Actions are now the primary limiter, not gold
# - Gold scales linearly with tier (low tiers cheap, high tiers expensive)
# - Actions scale with BOTH current tier AND total skill points owned
#
# Gold formula: BASE + (target_tier × PER_TIER)
# Actions formula: BASE + (current_tier × PER_TIER) + (total_points × PER_POINT)

TRAINING_GOLD_BASE = 20          # Base gold per action
TRAINING_GOLD_PER_TIER = 18      # Additional gold per target tier
TRAINING_GOLD_PER_POINT = 3      # Additional gold per total skill point owned
TRAINING_BASE_ACTIONS = 10       # Minimum actions for any training
TRAINING_ACTIONS_PER_TIER = 10   # Extra actions per current tier level (specializing is hard)
TRAINING_ACTIONS_PER_POINT = 1.5 # Extra actions per total skill point owned (diversifying costs more)
TRAINING_MIN_ACTIONS = 10         # Floor (never fewer than this)
TRAINING_MAX_ACTIONS = 500       # Cap (never more than this)


# gold = 20 + (target_tier × 18) + (total_skill_points × 3)
# actions = 10 + (current_tier × 10) + (total_skill_points × 1.5)

def calculate_training_gold_per_action(target_tier: int, total_skill_points: int = 0) -> float:
    """Gold cost per training action.
    
    Scales with BOTH tier AND total skill points owned.
    Tax is added on top at action time.
    
    Formula: BASE + (target_tier × PER_TIER) + (total_points × PER_POINT)
    
    Examples (with 0 skill points):
    - Tier 1 (0→1): 20 + 18 + 0 = 38g per action
    - Tier 2 (1→2): 20 + 36 + 0 = 56g per action
    
    Examples (with 6 skill points, training 7th skill):
    - Tier 1 (0→1): 20 + 18 + 18 = 56g per action
    - Tier 2 (1→2): 20 + 36 + 18 = 74g per action
    """
    return TRAINING_GOLD_BASE + (target_tier * TRAINING_GOLD_PER_TIER) + (total_skill_points * TRAINING_GOLD_PER_POINT)


def calculate_training_actions(current_tier: int, total_skill_points: int) -> int:
    """Number of actions to complete training.
    
    Scales with:
    - Current tier of the skill (higher tiers need more work) - PRIMARY factor
    - Total skill points owned across ALL skills - MINOR factor
    
    Formula: BASE + (current_tier × PER_TIER) + (total_points × PER_POINT)
    
    Examples:
    - 0→1, 1st skill (tier=0, points=0): 10 + 0 + 0 = 10 actions
    - 0→1, 7th skill (tier=0, points=6): 10 + 0 + 9 = 19 actions
    - 4→5, with 9 total points: 10 + 40 + 13 = 63 actions
    """
    actions = int(
        TRAINING_BASE_ACTIONS 
        + (current_tier * TRAINING_ACTIONS_PER_TIER) 
        + (total_skill_points * TRAINING_ACTIONS_PER_POINT)
    )
    return max(TRAINING_MIN_ACTIONS, min(TRAINING_MAX_ACTIONS, actions))


# ===== PROPERTY SCALING PARAMETERS =====
# Gold and action costs for property construction/upgrades
# Properties cost MORE than training - they're permanent investments!
#
# Gold formula: BASE + (tier × PER_TIER)
# Actions formula: BASE + (tier × PER_TIER)

PROPERTY_GOLD_BASE = 40          # Higher than training (permanent investment)
PROPERTY_GOLD_PER_TIER = 35      # Scales faster than training
PROPERTY_BASE_ACTIONS = 10       # Base actions for tier 1
PROPERTY_ACTIONS_PER_TIER = 10   # Extra actions per tier


def calculate_property_gold_per_action(tier: int) -> float:
    """Gold cost per property action. Same formula as training."""
    return PROPERTY_GOLD_BASE + (tier * PROPERTY_GOLD_PER_TIER)


def calculate_property_actions(tier: int) -> int:
    """Base actions required for property tier (before building skill reduction)."""
    return PROPERTY_BASE_ACTIONS + (tier * PROPERTY_ACTIONS_PER_TIER)


# ===== PROPERTY TIERS - FULLY DYNAMIC =====
# Add new tiers here and they'll appear in iOS automatically!
# NOTE: gold_cost and base_actions are now calculated dynamically from params above
# per_action_costs: Resources required PER WORK ACTION (wood, iron, etc.)
#
# MULTI-OPTION SUPPORT:
# Each tier can have an "options" array for multiple buildable rooms at that level.
# - Legacy fields (name, icon, description, benefits) are kept for backwards compatibility
# - New iOS apps should iterate through "options" to show all available rooms
# - The first option in the array is the "default" (used by legacy clients)

PROPERTY_TIERS = {
    1: {
        # Legacy fields (backwards compatibility)
        "name": "Land",
        "icon": "square.dashed",
        "description": "Cleared land with travel benefits",
        "benefits": ["Free travel to this kingdom"],
        "per_action_costs": [],  # No resource cost for clearing land
        # Multi-option support: array of buildable options at this level
        "options": [
            {
                "id": "land",
                "name": "Land",
                "icon": "square.dashed",
                "description": "Cleared land with travel benefits",
                "benefits": ["Free travel to this kingdom"],
                "resource_ratios": [],
            }
        ]
    },
    2: {
        # Legacy fields (backwards compatibility)
        "name": "House",
        "icon": "house.fill",
        "description": "A comfy home with garden",
        "benefits": ["All Land benefits", "A comfy home with garden"],
        "resource_ratios": [{"resource": "wood", "ratio": 1.0}],  # 100% wood
        # Multi-option support
        "options": [
            {
                "id": "house",
                "name": "House",
                "icon": "house.fill",
                "description": "A comfy home with garden",
                "benefits": ["All Land benefits", "A comfy home with garden"],
                "resource_ratios": [{"resource": "wood", "ratio": 1.0}],
            }
        ]
    },
    3: {
        # Legacy fields (backwards compatibility - uses first option)
        "name": "Workshop & Kitchen",
        "icon": "hammer.fill",
        "description": "Crafting workshop",
        "benefits": ["All House benefits", "Unlocks crafting of weapons and armor", "Unlocks cooking and baking"],
        "resource_ratios": [{"resource": "wood", "ratio": 0.6}, {"resource": "iron", "ratio": 0.4}],
        # Multi-option support: multiple rooms available at tier 3!
        "options": [
            {
                "id": "workshop",
                "name": "Workshop",
                "icon": "hammer.fill",
                "description": "Crafting workshop",
                "benefits": ["All House benefits", "Unlocks crafting of weapons and armor"],
                "resource_ratios": [{"resource": "wood", "ratio": 0.5}, {"resource": "iron", "ratio": 0.5}],
                "free_at_tier": 3,  # Backwards compat: auto-available at tier 3+
                "color": "buttonPrimary",
                "route": "/workshop",
            },
            {
                "id": "kitchen",
                "name": "Kitchen",
                "icon": "fork.knife",
                "description": "Cook meals for buffs",
                "benefits": ["All House benefits", "Unlocks cooking and baking"],
                "resource_ratios": [{"resource": "wood", "ratio": 0.5}, {"resource": "stone", "ratio": 0.5}],
                # No free_at_tier - must be built via contract
                "color": "buttonWarning",
                "route": "/kitchen",
            }
        ]
    },
    4: {
        # Legacy fields (backwards compatibility)
        "name": "Beautiful Property",
        "icon": "building.columns.fill",
        "description": "Animals & Gardens",
        "benefits": ["All Workshop benefits", "You can raise animals and take care of your pets!"],
        "resource_ratios": [{"resource": "wood", "ratio": 0.55}, {"resource": "iron", "ratio": 0.45}],
        # Multi-option support
        "options": [
            {
                "id": "beautiful_property",
                "name": "Beautiful Maison",
                "icon": "building.columns.fill",
                "description": "Animals & Gardens",
                "benefits": ["All Workshop benefits", "You can raise animals and take care of your pets!"],
                "resource_ratios": [{"resource": "wood", "ratio": 0.45}, {"resource": "iron", "ratio": 0.55}],
            }
        ]
    },
    5: {
        # Legacy fields (backwards compatibility)
        "name": "Defensive Walls",
        "icon": "shield.fill",
        "description": "Grand estate",
        "benefits": ["All Beautiful Property benefits", "50% less chance property gets destroyed in invasion"],
        "resource_ratios": [{"resource": "wood", "ratio": 0.5}, {"resource": "iron", "ratio": 0.5}],
        # Multi-option support
        "options": [
            {
                "id": "defensive_walls",
                "name": "Defensive Walls",
                "icon": "shield.fill",
                "description": "Grand estate",
                "benefits": ["All Beautiful Property benefits", "50% less chance property gets destroyed in invasion"],
                "resource_ratios": [{"resource": "wood", "ratio": 0.5}, {"resource": "iron", "ratio": 0.5}],
            }
        ]
    }
}


def get_property_max_tier() -> int:
    """Get max property tier dynamically"""
    return max(PROPERTY_TIERS.keys())


def get_property_gold_cost(to_tier: int) -> int:
    """Get TOTAL gold cost for a tier (gold_per_action × actions).
    Note: With pay-per-action system, this is for display only.
    """
    gold_per_action = calculate_property_gold_per_action(to_tier)
    actions = calculate_property_actions(to_tier)
    return int(gold_per_action * actions)


def get_property_per_action_costs(to_tier: int) -> list:
    """Get per-action resource costs required during each work action.
    
    Resource amounts are calculated from gold cost × ratio.
    This ensures resources always match gold cost.
    """
    tier_data = PROPERTY_TIERS.get(to_tier, {})
    ratios = tier_data.get("resource_ratios", [])
    
    if not ratios:
        return []
    
    gold_per_action = calculate_property_gold_per_action(to_tier)
    
    return [
        {"resource": r["resource"], "amount": int(gold_per_action * r["ratio"])}
        for r in ratios
    ]


def get_property_base_actions(to_tier: int) -> int:
    """Get base actions required for a tier (before building skill reduction)"""
    return calculate_property_actions(to_tier)


# ===== SKILL TIERS (1-10) =====

SKILL_TIER_NAMES = {
    1: "Novice",
    2: "Apprentice",
    3: "Journeyman",
    4: "Adept",
    5: "Expert",
    6: "Master",
    7: "Grandmaster",
    8: "Legendary",
    9: "Mythic",
    10: "Divine"
}


# ===== BUILDING TYPES - SINGLE SOURCE OF TRUTH =====
# Add new building types HERE and they'll appear everywhere!
#
# IMPORTANT: Keys MUST match database column prefixes exactly!
# e.g., key "wall" maps to Kingdom.wall_level
# e.g., key "education" maps to Kingdom.education_level
#
# Use "display_name" for UI/human-readable names.

BUILDING_TYPES = {
    "wall": {
        "display_name": "Walls",
        "icon": "building.2.fill",
        "category": "defense",
        "description": "Adds defense against invasions",
        "max_tier": 5,
        "sort_order": 20,
        "benefit_formula": "+{level * 1} defense in battles",
        "tiers": {
            1: {
                "name": "Wooden Palisade",
                "benefit": "+1 defense to all citizens during invasions",
                "description": "Basic wooden wall",
                "per_action_costs": [{"resource": "wood", "amount": 50}]
            },
            2: {
                "name": "Hardwood Wall",
                "benefit": "+2 defense to all citizens during invasions",
                "description": "Reinforced wooden fortification",
                "per_action_costs": [{"resource": "wood", "amount": 100}]
            },
            3: {
                "name": "Stone Wall",
                "benefit": "+3 defense to all citizens during invasions",
                "description": "Solid stone fortification",
                "per_action_costs": [{"resource": "stone", "amount": 50}]
            },
            4: {
                "name": "Fortress Wall",
                "benefit": "+4 defense to all citizens during invasions",
                "description": "Imposing stone fortress wall",
                "per_action_costs": [{"resource": "stone", "amount": 100}]
            },
            5: {
                "name": "Iron-Reinforced Wall",
                "benefit": "+5 defense to all citizens during invasions",
                "description": "Massive iron-reinforced castle wall",
                "per_action_costs": [{"resource": "iron", "amount": 100}]
            },
        }
    },
    "vault": {
        "display_name": "Vault",
        "icon": "lock.shield.fill",
        "category": "defense",
        "description": "Protects treasury gold from looting",
        "max_tier": 5,
        "sort_order": 30,
        "benefit_formula": "{level * 20}% treasury protected",
        "tiers": {
            1: {"name": "Small Chest", "benefit": "20% protected", "description": "Basic storage"},
            2: {"name": "Large Chest", "benefit": "40% protected", "description": "Larger storage"},
            3: {"name": "Vault Room", "benefit": "60% protected", "description": "Dedicated vault"},
            4: {"name": "Treasury", "benefit": "80% protected", "description": "Kingdom treasury"},
            5: {"name": "Grand Treasury", "benefit": "100% protected", "description": "Maximum security"},
        }
    },
    "mine": {
        "display_name": "Mine",
        "icon": "hammer.fill",
        "category": "economy",
        "description": "Produces stone and iron resources",
        "max_tier": 5,
        "sort_order": 40,
        "benefit_formula": "Produces stone and iron resources",
        "click_action": {"type": "gathering", "resource": "stone"},
        "tiers": {
            1: {"name": "Quarry", "benefit": "200 stone/day", "description": "Basic stone quarry"},
            2: {"name": "Iron Mine", "benefit": "400 resources/day, 50% iron", "description": "Unlocks iron ore extraction"},
            3: {"name": "Deep Mine", "benefit": "600 resources/day, 60% iron", "description": "Deeper ore veins"},
            4: {"name": "Industrial Mine", "benefit": "800 resources/day, 70% iron", "description": "Advanced extraction"},
            5: {"name": "Mining Complex", "benefit": "1000 resources/day, 80% iron", "description": "Full-scale mining operation"},
        }
    },
    "market": {
        "display_name": "Market",
        "icon": "cart.fill",
        "category": "economy",
        "description": "Enables trading and generates income",
        "max_tier": 5,
        "sort_order": 50,
        "benefit_formula": "Trading unlocks and citizen income",
        "click_action": {"type": "market"},
        "tiers": {
            1: {"name": "Stalls", "benefit": "Unlocks intrakingdom trading", "income": 0, "description": "Unlocks intrakingdom trading"},
            2: {"name": "Market Square", "benefit": "1 gold to treasury per citizen per day", "income": 0, "description": "1 gold to treasury per citizen per day"},
            3: {"name": "Trading Post", "benefit": "Market trade with allied kingdoms", "income": 0, "description": "Market trade with allied kingdoms"},
            4: {"name": "Commercial District", "benefit": "2 gold per citizen per day", "income": 0, "description": "2 gold per citizen per day"},
            5: {"name": "Trade Empire", "benefit": "Market trade with any neighboring kingdom", "income": 0, "description": "Market trade with any neighboring kingdom"},
        }
    },
    "farm": {
        "display_name": "Farm",
        "icon": "leaf.fill",
        "category": "economy",
        "description": "Reduces building actions required for citizens",
        "max_tier": 5,
        "sort_order": 60,
        "benefit_formula": "Building contracts require {reduction}% fewer actions",
        "tiers": {
            1: {"name": "Garden", "benefit": "Building contracts require 5% fewer actions", "reduction": 5, "description": "Small farm plots"},
            2: {"name": "Fields", "benefit": "Building contracts require 7.5% fewer actions", "reduction": 7.5, "description": "Farming fields"},
            3: {"name": "Estate Farm", "benefit": "Building contracts require 10% fewer actions", "reduction": 10, "description": "Large farm estate"},
            4: {"name": "Agricultural Complex", "benefit": "Building contracts require 12.5% fewer actions", "reduction": 12.5, "description": "Advanced farming"},
            5: {"name": "Agricultural Empire", "benefit": "Building contracts require 15% fewer actions", "reduction": 15, "description": "Massive food production"},
        }
    },
    "education": {
        "display_name": "Education Hall",
        "icon": "graduationcap.fill",
        "category": "civic",
        "description": "Reduces training actions required for citizens",
        "max_tier": 5,
        "sort_order": 70,
        "benefit_formula": "Training requires {reduction}% fewer actions",
        "tiers": {
            1: {"name": "School", "benefit": "Training requires 5% fewer actions", "reduction": 5, "description": "Basic education"},
            2: {"name": "Academy", "benefit": "Training requires 7.5% fewer actions", "reduction": 7.5, "description": "Advanced learning"},
            3: {"name": "University", "benefit": "Training requires 10% fewer actions", "reduction": 10, "description": "Higher education"},
            4: {"name": "Institute", "benefit": "Training requires 12.5% fewer actions", "reduction": 12.5, "description": "Elite institution"},
            5: {"name": "Grand Library", "benefit": "Training requires 15% fewer actions", "reduction": 15, "description": "Knowledge center"},
        }
    },
    "lumbermill": {
        "display_name": "Lumbermill",
        "icon": "tree.fill",
        "category": "economy",
        "description": "Produces wood resources for construction",
        "max_tier": 5,
        "sort_order": 80,
        "benefit_formula": "Unlocks wood gathering at each level",
        "click_action": {"type": "gathering", "resource": "wood"},
        "tiers": {
            1: {"name": "Logging Camp", "benefit": "Provides 200 wood per day", "wood_per_action": 10, "description": "Basic logging operation"},
            2: {"name": "Sawmill", "benefit": "Provides 400 wood per day", "wood_per_action": 20, "description": "Improved wood processing"},
            3: {"name": "Lumber Yard", "benefit": "Provides 600 wood per day", "wood_per_action": 35, "description": "Large-scale lumber operation"},
            4: {"name": "Industrial Mill", "benefit": "Provides 800 wood per day", "wood_per_action": 50, "description": "Advanced lumber processing"},
            5: {"name": "Lumber Empire", "benefit": "Provides 1000 wood per day", "wood_per_action": 75, "description": "Massive wood production"},
        }
    },
    "townhall": {
        "display_name": "Town Hall",
        "icon": "building.columns.fill",
        "category": "civic",
        "description": "Community center that unlocks group activities",
        "max_tier": 5,
        "sort_order": 0,
        "benefit_formula": "Unlocks group hunting and social features",
        "click_action": {"type": "townhall"},
        "tiers": {
            1: {"name": "Meeting Hall", "benefit": "Unlocks Group Hunting", "description": "Basic gathering place for citizens"},
            2: {"name": "Town Hall", "benefit": "Group Hunting + larger parties", "description": "Organized community center"},
            3: {"name": "Grand Hall", "benefit": "Enhanced hunting rewards", "description": "Impressive civic building"},
            4: {"name": "Council Chamber", "benefit": "Advanced group activities", "description": "Strategic planning center"},
            5: {"name": "Great Hall", "benefit": "Maximum hunting benefits", "description": "Legendary meeting place"},
        }
    }
}

# Legacy format for backwards compatibility
BUILDING_TIERS = {
    building_type: {
        tier: {
            "name": data["name"],
            "description": data["description"],
            **{k: v for k, v in data.items() if k not in ["name", "description", "benefit"]}
        }
        for tier, data in building_data["tiers"].items()
    }
    for building_type, building_data in BUILDING_TYPES.items()
}


# ===== CRAFTING/EQUIPMENT TIERS (1-5) =====

EQUIPMENT_TIERS = {
    1: {
        "name": "Basic",
        "description": "Simple equipment",
        "stat_bonus": 1,
        "gold_cost": 100,
        "iron_cost": 10,
        "steel_cost": 0,
        "actions_required": 1
    },
    2: {
        "name": "Quality",
        "description": "Well-crafted equipment",
        "stat_bonus": 2,
        "gold_cost": 300,
        "iron_cost": 20,
        "steel_cost": 0,
        "actions_required": 3
    },
    3: {
        "name": "Superior",
        "description": "Expertly crafted equipment",
        "stat_bonus": 3,
        "gold_cost": 700,
        "iron_cost": 0,
        "steel_cost": 10,
        "actions_required": 7
    },
    4: {
        "name": "Masterwork",
        "description": "Master-crafted equipment",
        "stat_bonus": 5,
        "gold_cost": 1500,
        "iron_cost": 0,
        "steel_cost": 20,
        "actions_required": 14
    },
    5: {
        "name": "Legendary",
        "description": "Legendary equipment",
        "stat_bonus": 8,
        "gold_cost": 3000,
        "iron_cost": 10,
        "steel_cost": 10,
        "actions_required": 30
    }
}


# ===== TRAINING TIERS (1-10) =====

def get_training_tier_info(tier: int) -> dict:
    """Get training tier info - uses skill tier names"""
    return {
        "tier": tier,
        "name": SKILL_TIER_NAMES.get(tier, f"Tier {tier}"),
        "description": f"Train to {SKILL_TIER_NAMES.get(tier, f'tier {tier}')} level"
    }


# ===== REPUTATION TIERS =====

REPUTATION_TIERS = {
    1: {
        "name": "Stranger",
        "requirement": 0,
        "icon": "person.fill",
        "abilities": [
            "Accept building contracts",
            "Work on properties",
            "Basic game access"
        ]
    },
    2: {
        "name": "Resident",
        "requirement": 500,
        "icon": "house.fill",
        "abilities": [
            "Buy property in cities",
            "Upgrade owned properties",
            "Farm resources"
        ]
    },
    3: {
        "name": "Citizen",
        "requirement": 1000,
        "icon": "person.2.fill",
        "abilities": [
            "Vote on city coups",
            "Join alliances",
            "Participate in city governance"
        ]
    },
    4: {
        "name": "Notable",
        "requirement": 15000,
        "icon": "star.fill",
        "abilities": [
            "Propose city coups (with Leadership 3+)",
            "Lead strategic initiatives",
            "Enhanced influence"
        ]
    },
    5: {
        "name": "Champion",
        "requirement": 25000,
        "icon": "crown.fill",
        "abilities": [
            "Vote weight counts 2x",
            "Significantly increased influence",
            "Respected leader status"
        ]
    },
    6: {
        "name": "Legendary",
        "requirement": 50000,
        "icon": "sparkles",
        "abilities": [
            "Vote weight counts 3x",
            "Maximum influence",
            "Most prestigious rank"
        ]
    }
}


# ===== SKILL SYSTEM - SINGLE SOURCE OF TRUTH =====
# Add new skills HERE and they'll work everywhere automatically!

SKILLS = {
    "attack": {
        "display_name": "Attack",
        "stat_attribute": "attack_power",  # PlayerState model attribute
        "icon": "bolt.fill",
        "category": "combat",
        "description": "Increases hit chance and damage dealt",
        "benefits": {
            1: ["+1 Attack Power and Hit Chance in combat"],
            2: ["+2 Attack Power and Hit Chance in combat"],
            3: ["+3 Attack Power and Hit Chance in combat"],
            4: ["+4 Attack Power and Hit Chance in combat"],
            5: ["+5 Attack Power and Hit Chance in combat"]
        }
    },
    "defense": {
        "display_name": "Defense",
        "stat_attribute": "defense_power",
        "icon": "shield.fill",
        "category": "combat",
        "description": "Reduces damage taken in combat",
        "benefits": {
            1: ["+1 Defense Power and slows enemy capture in combat"],
            2: ["+2 Defense Power and slows enemy capture in combat"],
            3: ["+3 Defense Power and slows enemy capture in combat"],
            4: ["+4 Defense Power and slows enemy capture in combat"],
            5: ["+5 Defense Power and slows enemy capture in combat"]
        }
    },
    "leadership": {
        "display_name": "Leadership",
        "stat_attribute": "leadership",
        "icon": "crown.fill",
        "category": "political",
        "description": "Increases voting power and combat coordination",
        "benefits": {
            1: ["Vote weight: 1.0", "Can vote on coups (with 500 rep)"],
            2: ["Vote weight: 1.2", "Stronger push in combat"],
            3: ["Vote weight: 1.4", "Can start coups (with 1000 rep in kingdom)", "Stronger push in combat"],
            4: ["Vote weight: 1.6", "Stronger push in combat"],
            5: ["Vote weight: 1.8", "Stronger push in combat"]
        }
    },
    "building": {
        "display_name": "Building",
        "stat_attribute": "building_skill",
        "icon": "hammer.fill",
        "category": "economy",
        "description": "Reduces building cooldowns",
        "benefits": {
            1: ["-5% building cooldowns"],
            2: ["-10% building cooldowns"],
            3: ["-15% building cooldowns"],
            4: ["-20% building cooldowns", "5% chance to refund building cooldown"],
            5: ["-25% building cooldowns", "10% chance to refund building cooldown"]
        },
        "mechanics": {
            "cooldown_reduction": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.20, 5: 0.25},
            "refund_chance": {4: 0.05, 5: 0.10}
        }
    },
    "intelligence": {
        "display_name": "Intelligence",
        "stat_attribute": "intelligence",
        "icon": "eye.fill",
        "category": "espionage",
        "description": "Unlocks scout abilities and improves success chance",
        "benefits": {
            1: ["Unlocks Infiltrate action", "Chance to Gather Basic Intel: Reveal population & citizen count"],
            2: ["+10% scout success", "Chance to Gather Military Intel: Reveal attack/defense/walls"],
            3: ["+22% scout success", "Chance to Gather Building Intel: Reveal all building levels"],
            4: ["+35% scout success", "Chance to Cause Disruption: Delay enemy contracts by 10%"],
            5: ["+50% scout success", "Chance to Vault Heist: Steal 10% of enemy vault gold"]
        }
    },
    "science": {
        "display_name": "Science",
        "stat_attribute": "science",
        "icon": "flask.fill",
        "category": "education",
        "description": "Reduces skill training cooldowns",
        "benefits": {
            1: ["-5% training cooldowns"],
            2: ["-10% training cooldowns"],
            3: ["-15% training cooldowns"],
            4: ["-20% training cooldowns", "5% chance to refund training cooldown"],
            5: ["-25% training cooldowns", "10% chance to refund training cooldown"]
        },
        "mechanics": {
            "cooldown_reduction": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.20, 5: 0.25},
            "refund_chance": {4: 0.05, 5: 0.10}
        }
    },
    "faith": {
        "display_name": "Faith",
        "stat_attribute": "faith",
        "icon": "hands.sparkles.fill",
        "category": "enhancement",
        "description": "Provides combat buffs and increases odds",
        "benefits": {
            1: ["5% chance: random ally in battle gets +1 attack OR enemy gets -1 attack"],
            2: ["10% chance: random ally gets +2 attack OR enemy gets -2 defense"],
            3: ["15% chance: random ally gets +3 defense OR enemy gets -3 defense"],
            4: ["20% chance: 2 random allies get +2 attack OR 2 enemies get -2 attack"],
            5: ["25% chance: Revive 3 allies or smite 3 enemies during a battle"]
        }
    },
    "philosophy": { # could be cool to have perk that exchanges rep for gold?
        "display_name": "Philosophy",
        "stat_attribute": "philosophy",
        "icon": "book.fill",
        "category": "civic",
        "description": "Increases reputation gains and reduces penalties",
        "benefits": {
            1: ["+10% reputation from all actions", "-10% reputation loss from failed coups"],
            2: ["+20% reputation from all actions", "-20% reputation loss from failed coups"],
            3: ["+30% reputation from all actions", "-30% rep loss from fails"],
            4: ["+40% reputation from all actions", "-40% reputation loss from failed actions"],
            5: ["+50% reputation from all actions", "-50% reputation loss"]
        }
    },
    "merchant": {
        "display_name": "Merchant",
        "stat_attribute": "merchant",
        "icon": "dollarsign.circle.fill",
        "category": "economy",
        "description": "Unlocks trading capabilities and market advantages",
        "benefits": {
            1: ["Unlocks player-to-player trading"],
            2: ["Keep excess gold when your market buy offer is higher than the seller's price (otherwise goes to kingdom treasury)"],
            3: ["Access markets in foreign kingdoms (not just your home kingdom)"],
            4: ["Receive bonus gold when market buyers pay more than your asking price (otherwise goes to kingdom treasury)"],
            5: ["50% reduced taxes on all market transactions"]
        }
    }
}

# Helper: Get all skill type strings (for backward compatibility)
SKILL_TYPES = list(SKILLS.keys())

# Legacy format for backward compatibility
SKILL_BENEFITS = {
    skill_id: {
        "per_tier": "",
        "tier_bonuses": skill_data["benefits"]
    }
    for skill_id, skill_data in SKILLS.items()
}


# ===== SKILL HELPER FUNCTIONS =====

def get_stat_value(state, skill_type: str) -> int:
    """Get current stat value for a skill type from PlayerState"""
    if skill_type not in SKILLS:
        return 1  # Default
    attr_name = SKILLS[skill_type]["stat_attribute"]
    return getattr(state, attr_name, 1)


def set_stat_value(state, skill_type: str, value: int) -> tuple[str, int]:
    """Set stat value and return (display_name, new_value)"""
    if skill_type not in SKILLS:
        return "Unknown", value
    
    skill_data = SKILLS[skill_type]
    attr_name = skill_data["stat_attribute"]
    setattr(state, attr_name, value)
    return skill_data["display_name"], value


def increment_stat(state, skill_type: str) -> tuple[str, int]:
    """Increment a stat and return (display_name, new_value)"""
    if skill_type not in SKILLS:
        return "Unknown", 0
    
    skill_data = SKILLS[skill_type]
    attr_name = skill_data["stat_attribute"]
    current_value = getattr(state, attr_name, 1)
    new_value = current_value + 1
    setattr(state, attr_name, new_value)
    return skill_data["display_name"], new_value


def get_total_skill_points(state) -> int:
    """Get total skill points across ALL skills"""
    total = 0
    for skill_data in SKILLS.values():
        attr_name = skill_data["stat_attribute"]
        total += getattr(state, attr_name, 0)
    return total


def get_all_skill_values(state) -> dict:
    """Get current values for all skills"""
    return {
        skill_type: get_stat_value(state, skill_type)
        for skill_type in SKILLS.keys()
    }


def get_training_costs_for_player(state) -> dict:
    """CENTRALIZED: Get gold_per_action for each skill.
    
    This is the SINGLE SOURCE OF TRUTH for training costs.
    All endpoints should use this function.
    
    Returns: {skill_type: gold_per_action}
    """
    current_stats = get_all_skill_values(state)
    total_skill_points = get_total_skill_points(state)
    
    costs = {}
    for skill_type in SKILL_TYPES:
        current_tier = current_stats.get(skill_type, 0)
        target_tier = current_tier + 1  # Training towards the NEXT tier
        gold_per_action = calculate_training_gold_per_action(target_tier, total_skill_points)
        costs[skill_type] = int(gold_per_action)
    return costs


def get_training_info_for_skill(state, skill_type: str) -> dict:
    """CENTRALIZED: Get full training info for a specific skill.
    
    Returns: {current_tier, target_tier, gold_per_action, actions_required}
    """
    current_tier = get_stat_value(state, skill_type)
    target_tier = current_tier + 1
    total_skill_points = get_total_skill_points(state)
    
    gold_per_action = calculate_training_gold_per_action(target_tier, total_skill_points)
    actions_required = calculate_training_actions(current_tier, total_skill_points)
    
    return {
        "current_tier": current_tier,
        "target_tier": target_tier,
        "gold_per_action": gold_per_action,
        "actions_required": actions_required,
    }


def get_skill_mechanic(skill_type: str, mechanic_name: str, tier: int) -> float:
    """Get a specific mechanic value for a skill at a given tier.
    
    Example: get_skill_mechanic("building", "cooldown_reduction", 3) -> 0.12
    Example: get_skill_mechanic("science", "refund_chance", 5) -> 0.10
    
    Returns 0.0 if mechanic not found or tier not defined.
    """
    skill_data = SKILLS.get(skill_type, {})
    mechanics = skill_data.get("mechanics", {})
    mechanic_values = mechanics.get(mechanic_name, {})
    return mechanic_values.get(tier, 0.0)


def get_building_cooldown_reduction(tier: int) -> float:
    """Get building skill cooldown reduction multiplier for a tier.
    
    Returns: multiplier to apply (e.g., 0.95 for 5% reduction)
    """
    reduction = get_skill_mechanic("building", "cooldown_reduction", tier)
    return 1.0 - reduction


def get_building_refund_chance(tier: int) -> float:
    """Get building skill cooldown refund chance for a tier."""
    return get_skill_mechanic("building", "refund_chance", tier)


def get_building_action_reduction(building_skill: int) -> float:
    """Get building skill action reduction multiplier.
    
    Reduces actions required for property upgrades, catch-up work, etc.
    Formula: 5% reduction per skill level, max 50% at level 10.
    
    Args:
        building_skill: Player's building skill level (1-10)
    
    Returns: multiplier to apply (e.g., 0.95 for 5% reduction, 0.50 for 50% reduction)
    """
    # 5% per level, capped at 50%
    reduction = min(building_skill * 0.05, 0.5)
    return 1.0 - reduction


def get_science_cooldown_reduction(tier: int) -> float:
    """Get science skill training COOLDOWN reduction multiplier for a tier.
    
    Science skill reduces training cooldowns (personal skill).
    Returns: multiplier to apply (e.g., 0.95 for 5% reduction)
    """
    reduction = get_skill_mechanic("science", "cooldown_reduction", tier)
    return 1.0 - reduction


def get_science_refund_chance(tier: int) -> float:
    """Get science skill training cooldown refund chance for a tier."""
    return get_skill_mechanic("science", "refund_chance", tier)


def get_farm_action_reduction(farm_level: int) -> float:
    """Get farm building action reduction multiplier for building contracts.
    
    Farm building reduces building contract ACTIONS (kingdom building).
    Returns: multiplier to apply (e.g., 0.95 for 5% reduction)
    Values come from BUILDING_TYPES["farm"]["tiers"][level]["reduction"]
    """
    if farm_level <= 0:
        return 1.0
    reduction_percent = get_building_tier_value("farm", farm_level, "reduction", 0)
    return 1.0 - (reduction_percent / 100.0)


def get_building_tier_value(building_type: str, tier: int, value_name: str, default: float = 0.0) -> float:
    """Get a specific value from a building tier.
    
    Example: get_building_tier_value("education", 3, "reduction") -> 15
    Example: get_building_tier_value("farm", 2, "reduction") -> 10
    
    Returns default if building/tier/value not found.
    """
    building_data = BUILDING_TYPES.get(building_type, {})
    tiers = building_data.get("tiers", {})
    tier_data = tiers.get(tier, {})
    return tier_data.get(value_name, default)


def get_building_per_action_costs(building_type: str, tier: int) -> list:
    """Get per-action resource costs for a building tier.
    
    Example: get_building_per_action_costs("wall", 2) -> [{"resource": "wood", "amount": 50}]
    
    Returns empty list if no per-action costs defined.
    """
    building_data = BUILDING_TYPES.get(building_type, {})
    tiers = building_data.get("tiers", {})
    tier_data = tiers.get(tier, {})
    return tier_data.get("per_action_costs", [])


def get_education_training_reduction(education_level: int) -> float:
    """Get education building training reduction multiplier.
    
    Returns: multiplier to apply (e.g., 0.95 for 5% reduction)
    Values come from BUILDING_TYPES["education"]["tiers"][level]["reduction"]
    """
    if education_level <= 0:
        return 1.0
    reduction_percent = get_building_tier_value("education", education_level, "reduction", 0)
    return 1.0 - (reduction_percent / 100.0)


def get_skills_data_for_player(state, training_costs: dict = None) -> list:
    """
    Get complete skill data for player state response.
    Returns a list of skill objects with all info needed for dynamic UI rendering.
    Frontend can render skills without hardcoding any skill types!
    
    Args:
        state: PlayerState object
        training_costs: Optional dict of {skill_type: cost}. If None, calculates automatically.
    """
    skills_data = []
    total_skill_points = get_total_skill_points(state)
    
    for skill_type, skill_config in SKILLS.items():
        current_value = get_stat_value(state, skill_type)
        
        # Get benefits for current tier (capped at 5 for display)
        current_tier_benefits = skill_config["benefits"].get(
            min(current_value, 5), 
            skill_config["benefits"].get(5, [])
        )
        
        # Calculate cost for this specific skill (gold_per_action - no upfront payment!)
        if training_costs and skill_type in training_costs:
            cost = training_costs[skill_type]
        else:
            # Calculate dynamically: just gold_per_action (pay per action, not upfront)
            target_tier = current_value + 1
            cost = int(calculate_training_gold_per_action(target_tier, total_skill_points))
        
        skills_data.append({
            "skill_type": skill_type,
            "display_name": skill_config["display_name"],
            "icon": skill_config["icon"],
            "category": skill_config["category"],
            "description": skill_config["description"],
            "current_tier": current_value,
            "max_tier": 5,
            "training_cost": cost,  # Total gold for this skill
            "current_benefits": current_tier_benefits,
            "display_order": list(SKILLS.keys()).index(skill_type) * 10,  # 0, 10, 20, etc.
        })
    
    return skills_data


# ===== HELPER FUNCTIONS =====

def _get_training_actions_dict(total_skill_points: int) -> dict:
    """Get training actions required for each tier based on player's total skill points"""
    # Uses centralized calculate_training_actions from this file
    return {
        str(level): calculate_training_actions(level, total_skill_points=total_skill_points)
        for level in range(10)
    }


def _get_training_gold_dict(total_skill_points: int) -> dict:
    """Get gold cost per action for each target tier based on player's total skill points"""
    # Uses centralized calculate_training_gold_per_action from this file
    return {
        str(target_tier): calculate_training_gold_per_action(target_tier, total_skill_points=total_skill_points)
        for target_tier in range(1, 11)  # Target tiers 1-10
    }


# ===== API ENDPOINTS =====

@router.get("")
def get_all_tiers(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get ALL tier information for the entire game
    Single source of truth - NO MORE HARDCODING IN FRONTEND!
    """
    from .actions.action_config import ACTION_TYPES
    from .resources import RESOURCES
    
    # Get player's total skill points for training actions calculation
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    total_skill_points = get_total_skill_points(state)
    
    # Build property tiers with calculated costs (matches /tiers/properties format)
    property_tiers_with_costs = {}
    for tier in range(1, 6):
        info = PROPERTY_TIERS[tier]
        gold_per_action = calculate_property_gold_per_action(tier)
        base_actions = calculate_property_actions(tier)
        total_gold = int(gold_per_action * base_actions)
        
        # Build options array with calculated costs
        options = []
        for opt in info.get("options", []):
            ratios = opt.get("resource_ratios", [])
            opt_per_action_costs = [
                {"resource": r["resource"], "amount": int(gold_per_action * r["ratio"])}
                for r in ratios
            ] if ratios else []
            
            options.append({
                "id": opt.get("id", f"tier_{tier}"),
                "name": opt.get("name", info["name"]),
                "icon": opt.get("icon", info.get("icon", "house.fill")),
                "description": opt.get("description", info["description"]),
                "benefits": opt.get("benefits", info["benefits"]),
                "gold_per_action": gold_per_action,
                "base_actions_required": base_actions,
                "total_gold_cost": total_gold,
                "per_action_costs": opt_per_action_costs,
            })
        
        # Use first option's name for legacy field (e.g., "Workshop" instead of "Workshop & Kitchen")
        first_option = options[0] if options else {}
        property_tiers_with_costs[str(tier)] = {
            # Legacy fields (backwards compatibility)
            "name": first_option.get("name", info["name"]),
            "icon": first_option.get("icon", info.get("icon", "house.fill")),
            "description": first_option.get("description", info["description"]),
            "benefits": first_option.get("benefits", info["benefits"]),
            "gold_per_action": gold_per_action,
            "base_actions_required": base_actions,
            "total_gold_cost": total_gold,
            "per_action_costs": get_property_per_action_costs(tier),
            # NEW: Multiple options at this tier
            "options": options,
        }
    
    return {
        "resources": {
            "types": RESOURCES  # Import from resources.py
        },
        "properties": {
            "max_tier": get_property_max_tier(),
            "tiers": property_tiers_with_costs
        },
        "skills": {
            "max_tier": 10,
            "tier_names": SKILL_TIER_NAMES,
            "skills": SKILLS,  # Full skill configuration
            "skill_types": SKILL_TYPES,  # Just the keys
            "skill_benefits": SKILL_BENEFITS  # Legacy format
        },
        "buildings": {
            "max_tier": 5,
            "types": BUILDING_TYPES  # Full building info with icons, categories, etc.
        },
        "equipment": {
            "max_tier": 5,
            "tiers": {str(k): v for k, v in EQUIPMENT_TIERS.items()}
        },
        "training": {
            "max_tier": 10,
            "tier_names": SKILL_TIER_NAMES,
            "actions_required": _get_training_actions_dict(total_skill_points),
            "gold_per_action": _get_training_gold_dict(total_skill_points)
        },
        "reputation": {
            "max_tier": 6,
            "tiers": {str(k): v for k, v in REPUTATION_TIERS.items()}
        },
        "actions": {
            "types": ACTION_TYPES,
            "categories": ["beneficial", "hostile", "training", "crafting", "property"]
        }
    }


def get_property_option_per_action_costs(tier: int, option_id: str = None) -> list:
    """Get per-action resource costs for a specific option at a tier.
    
    If option_id is None, returns costs for the first/default option.
    """
    tier_data = PROPERTY_TIERS.get(tier, {})
    options = tier_data.get("options", [])
    
    if not options:
        # Fallback to legacy resource_ratios
        ratios = tier_data.get("resource_ratios", [])
        if not ratios:
            return []
        gold_per_action = calculate_property_gold_per_action(tier)
        return [
            {"resource": r["resource"], "amount": int(gold_per_action * r["ratio"])}
            for r in ratios
        ]
    
    # Find the requested option or use first
    target_option = options[0]
    if option_id:
        for opt in options:
            if opt.get("id") == option_id:
                target_option = opt
                break
    
    ratios = target_option.get("resource_ratios", [])
    if not ratios:
        return []
    
    gold_per_action = calculate_property_gold_per_action(tier)
    return [
        {"resource": r["resource"], "amount": int(gold_per_action * r["ratio"])}
        for r in ratios
    ]


@router.get("/properties")
def get_property_tiers():
    """Get property tier info with costs - ALL VALUES FROM centralized config
    
    Returns:
        - Legacy fields (name, icon, etc.) for backwards compatibility
        - NEW: "options" array for each tier with all buildable rooms at that level
    """
    tiers_dict = {}
    for tier in range(1, 6):
        info = PROPERTY_TIERS[tier]
        gold_per_action = calculate_property_gold_per_action(tier)
        base_actions = calculate_property_actions(tier)
        total_gold = int(gold_per_action * base_actions)
        
        # Build options array with calculated costs
        options = []
        for opt in info.get("options", []):
            # Calculate per-action costs for this specific option
            ratios = opt.get("resource_ratios", [])
            opt_per_action_costs = [
                {"resource": r["resource"], "amount": int(gold_per_action * r["ratio"])}
                for r in ratios
            ] if ratios else []
            
            options.append({
                "id": opt.get("id", f"tier_{tier}"),
                "name": opt.get("name", info["name"]),
                "icon": opt.get("icon", info.get("icon", "house.fill")),
                "description": opt.get("description", info["description"]),
                "benefits": opt.get("benefits", info["benefits"]),
                "gold_per_action": gold_per_action,
                "base_actions_required": base_actions,
                "total_gold_cost": total_gold,
                "per_action_costs": opt_per_action_costs,
            })
        
        tiers_dict[str(tier)] = {
            # Legacy fields (backwards compatibility)
            "tier": tier,
            "name": info["name"],
            "icon": info.get("icon", "house.fill"),
            "description": info["description"],
            "benefits": info["benefits"],
            "gold_per_action": gold_per_action,
            "base_actions_required": base_actions,
            "total_gold_cost": total_gold,
            "per_action_costs": get_property_per_action_costs(tier),
            # NEW: Multiple options at this tier (for new UI)
            "options": options,
        }
    
    return {
        "max_tier": 5,
        "tiers": tiers_dict,
        "notes": {
            "pay_per_action": "Gold is paid per action, not upfront. Tax added on top at action time.",
            "actions": "Base actions required, reduced by Building skill (up to 50% reduction)",
            "reputation_required": "500 reputation required to purchase land in a kingdom",
            "multi_option": "Each tier may have multiple buildable options. Use 'options' array for new UI."
        }
    }


@router.get("/skills/{skill_name}")
def get_skill_tiers(skill_name: str):
    """Get tier info for a specific skill"""
    tiers = []
    for tier in range(1, 11):
        tiers.append({
            "tier": tier,
            "name": SKILL_TIER_NAMES[tier],
            "description": f"{SKILL_TIER_NAMES[tier]} level in {skill_name}"
        })
    
    return {
        "skill": skill_name,
        "max_tier": 10,
        "tiers": tiers
    }


@router.get("/buildings")
def get_all_building_types():
    """Get all available building types with full info"""
    return {
        "building_types": BUILDING_TYPES,
        "categories": ["economy", "defense", "civic"],
        "notes": {
            "adding_buildings": "Add new building types to BUILDING_TYPES dict in tiers.py",
            "upgrade_costs": "Costs scale with building level and kingdom population"
        }
    }


@router.get("/buildings/{building_type}")
def get_building_tiers(building_type: str):
    """Get tier info for a specific building type"""
    if building_type not in BUILDING_TYPES:
        return {"error": f"Unknown building type: {building_type}"}
    
    building_data = BUILDING_TYPES[building_type]
    
    return {
        "building_type": building_type,
        "display_name": building_data["display_name"],
        "icon": building_data["icon"],
        "category": building_data["category"],
        "description": building_data["description"],
        "max_tier": building_data["max_tier"],
        "benefit_formula": building_data["benefit_formula"],
        "tiers": building_data["tiers"]
    }


@router.get("/equipment")
def get_equipment_tiers():
    """Get equipment/crafting tier info"""
    tiers = []
    for tier in range(1, 6):
        info = EQUIPMENT_TIERS[tier]
        tiers.append({
            "tier": tier,
            **info
        })
    
    return {
        "max_tier": 5,
        "tiers": tiers,
        "notes": {
            "workshop_required": "Property Tier 3+ (Workshop) required to craft equipment",
            "cooldown": "2 hour cooldown between crafting actions (reduced by Building skill)"
        }
    }


@router.get("/training")
def get_training_tiers():
    """Get training tier info"""
    tiers = []
    for tier in range(1, 11):
        tiers.append(get_training_tier_info(tier))
    
    return {
        "max_tier": 10,
        "tiers": tiers,
        "notes": {
            "skill_cap": "Each skill can be trained to tier 10",
            "cooldown": "8 hour cooldown per training session (reduced by skill level)"
        }
    }


@router.get("/reputation")
def get_reputation_tiers():
    """Get reputation tier info"""
    tiers = []
    for tier in range(1, 7):
        info = REPUTATION_TIERS[tier]
        tiers.append({
            "tier": tier,
            "name": info["name"],
            "requirement": info["requirement"],
            "icon": info["icon"],
            "abilities": info["abilities"]
        })
    
    return {
        "max_tier": 6,
        "tiers": tiers,
        "notes": {
            "earning": "Earn reputation through check-ins, contracts, and helping the kingdom",
            "per_kingdom": "Reputation is tracked per-kingdom (local reputation)"
        }
    }


@router.get("/skills/{skill_name}/benefits")
def get_skill_benefits(skill_name: str):
    """Get detailed benefits for a specific skill at each tier"""
    if skill_name not in SKILL_BENEFITS:
        return {"error": f"Unknown skill: {skill_name}"}
    
    skill_data = SKILL_BENEFITS[skill_name]
    tiers = []
    
    for tier in range(1, 6):
        # ONLY use tier_bonuses - nothing else!
        tier_bonuses = skill_data.get("tier_bonuses", {})
        benefits = tier_bonuses.get(tier, [])
        
        tiers.append({
            "tier": tier,
            "name": SKILL_TIER_NAMES[tier],
            "benefits": benefits
        })
    
    return {
        "skill": skill_name,
        "max_tier": 5,
        "tiers": tiers
    }


@router.get("/actions")
def get_all_actions():
    """
    Get ALL action configurations including cooldowns, icons, descriptions
    Single source of truth for action metadata - NO MORE HARDCODING!
    """
    from .actions.action_config import ACTION_TYPES, get_actions_by_category
    
    return {
        "actions": ACTION_TYPES,
        "categories": {
            "beneficial": get_actions_by_category("beneficial"),
            "hostile": get_actions_by_category("hostile"),
            "training": get_actions_by_category("training"),
            "crafting": get_actions_by_category("crafting"),
            "property": get_actions_by_category("property")
        },
        "notes": {
            "cooldowns": "All cooldown_minutes values are in minutes",
            "endpoints": "Use the endpoint field for API calls (may include path params like {contract_id})",
            "requirements": "Check requirements field for unlock conditions"
        }
    }


@router.get("/actions/{action_type}")
def get_action_config_endpoint(action_type: str):
    """Get configuration for a specific action type"""
    from .actions.action_config import get_action_config
    
    config = get_action_config(action_type)
    if not config:
        return {"error": f"Unknown action type: {action_type}"}
    
    return {
        "action_type": action_type,
        **config
    }
