"""
UNIFIED TIER SYSTEM - Single Source of Truth for ALL game tier descriptions
Handles: Properties, Skills, Buildings, Crafting, Training, Actions
NO MORE HARDCODING DESCRIPTIONS IN FRONTEND!
"""
from fastapi import APIRouter

router = APIRouter(prefix="/tiers", tags=["tiers"])


# ===== SCALING CONSTANTS =====
# Kingdom building contract costs scale with level and population

BUILDING_BASE_CONSTRUCTION_COST = 1000
BUILDING_LEVEL_COST_EXPONENT = 1.7
BUILDING_POPULATION_COST_DIVISOR = 50
BUILDING_BASE_ACTIONS_REQUIRED = 100
BUILDING_LEVEL_ACTIONS_EXPONENT = 1.7
BUILDING_POPULATION_ACTIONS_DIVISOR = 30


# ===== PROPERTY TIERS - FULLY DYNAMIC =====
# Add new tiers here and they'll appear in iOS automatically!
# upgrade_costs: Resources required to upgrade TO this tier (from previous tier)
# base_actions: Base actions required (reduced by building skill)

PROPERTY_TIERS = {
    1: {
        "name": "Land",
        "icon": "square.dashed",
        "description": "Cleared land with travel benefits",
        "benefits": [
            "Free travel to this kingdom"
        ],
        "upgrade_costs": [
            {"resource": "gold", "amount": 500}  # Base price, modified by population
        ],
        "base_actions": 5
    },
    2: {
        "name": "House",
        "icon": "house.fill",
        "description": "Basic dwelling",
        "benefits": [
            "All Land benefits",
            "Ability to train skills in this kingdom"
        ],
        "upgrade_costs": [
            {"resource": "gold", "amount": 500},
            {"resource": "wood", "amount": 40}
        ],
        "base_actions": 7
    },
    3: {
        "name": "Workshop",
        "icon": "hammer.fill",
        "description": "Crafting workshop",
        "benefits": [
            "All House benefits",
            "Allows crafting of weapons and armor"
        ],
        "upgrade_costs": [
            {"resource": "gold", "amount": 1000},
            {"resource": "wood", "amount": 80},
            {"resource": "iron", "amount": 50}
        ],
        "base_actions": 9
    },
    4: {
        "name": "Beautiful Property",
        "icon": "building.columns.fill",
        "description": "Luxurious property",
        "benefits": [
            "All Workshop benefits",
            "Pay 50% less tax on all income"
        ],
        "upgrade_costs": [
            {"resource": "gold", "amount": 2000},
            {"resource": "wood", "amount": 160}
        ],
        "base_actions": 11
    },
    5: {
        "name": "Defensive Walls",
        "icon": "shield.fill",
        "description": "Grand estate",
        "benefits": [
            "All Beautiful Property benefits",
            "If your kingdom is invaded, a 50% less chance your property gets destroyed"
        ],
        "upgrade_costs": [
            {"resource": "gold", "amount": 4000},
            {"resource": "wood", "amount": 320},
            {"resource": "iron", "amount": 100}
        ],
        "base_actions": 13
    }
}


def get_property_max_tier() -> int:
    """Get max property tier dynamically"""
    return max(PROPERTY_TIERS.keys())


def get_property_upgrade_costs(to_tier: int) -> list:
    """Get upgrade costs for a specific tier"""
    tier_data = PROPERTY_TIERS.get(to_tier, {})
    return tier_data.get("upgrade_costs", [])


def get_property_base_actions(to_tier: int) -> int:
    """Get base actions required for a tier"""
    tier_data = PROPERTY_TIERS.get(to_tier, {})
    return tier_data.get("base_actions", 5)


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
        "description": "Defensive walls protect against coups and invasions",
        "max_tier": 5,
        "benefit_formula": "+{level * 2} defenders in battles",
        "tiers": {
            1: {"name": "Wooden Palisade", "benefit": "+2 defenders", "description": "Basic wooden wall"},
            2: {"name": "Stone Wall", "benefit": "+4 defenders", "description": "Sturdy stone fortification"},
            3: {"name": "Reinforced Wall", "benefit": "+6 defenders", "description": "Reinforced stone wall"},
            4: {"name": "Fortress Wall", "benefit": "+8 defenders", "description": "Imposing fortress wall"},
            5: {"name": "Castle Wall", "benefit": "+10 defenders, max fortification", "description": "Massive castle wall"},
        }
    },
    "vault": {
        "display_name": "Vault",
        "icon": "lock.shield.fill",
        "category": "defense",
        "description": "Protects treasury gold from looting",
        "max_tier": 5,
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
        "description": "Produces resources and passive income",
        "max_tier": 5,
        "benefit_formula": "Unlocks resources at each level",
        "click_action": {"type": "gathering", "resource": "iron"},
        "tiers": {
            1: {"name": "Prospect", "benefit": "Unlocks Stone", "description": "Small mining operation"},
            2: {"name": "Shaft", "benefit": "Unlocks Stone, Iron", "description": "Deeper mining shaft"},
            3: {"name": "Deep Mine", "benefit": "Unlocks Stone, Iron, Steel", "description": "Extensive mining operation"},
            4: {"name": "Mining Complex", "benefit": "All materials available", "description": "Large mining complex"},
            5: {"name": "Mining Empire", "benefit": "All materials at 2x quantity", "description": "Massive mining operation"},
        }
    },
    "market": {
        "display_name": "Market",
        "icon": "cart.fill",
        "category": "economy",
        "description": "Enables trading and generates income",
        "max_tier": 5,
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
        "description": "Speeds up contract completion",
        "max_tier": 5,
        "benefit_formula": "Contracts complete {reduction}% faster",
        "tiers": {
            1: {"name": "Garden", "benefit": "Contracts 5% faster", "reduction": 5, "description": "Small farm plots"},
            2: {"name": "Fields", "benefit": "Contracts 10% faster", "reduction": 10, "description": "Farming fields"},
            3: {"name": "Estate Farm", "benefit": "Contracts 20% faster", "reduction": 20, "description": "Large farm estate"},
            4: {"name": "Agricultural Complex", "benefit": "Contracts 25% faster", "reduction": 25, "description": "Advanced farming"},
            5: {"name": "Agricultural Empire", "benefit": "Contracts 33% faster", "reduction": 33, "description": "Massive food production"},
        }
    },
    "education": {
        "display_name": "Education Hall",
        "icon": "graduationcap.fill",
        "category": "civic",
        "description": "Reduces training time for citizens",
        "max_tier": 5,
        "benefit_formula": "Citizens train skills {level * 5}% faster",
        "tiers": {
            1: {"name": "School", "benefit": "Train 5% faster", "reduction": 5, "description": "Basic education"},
            2: {"name": "Academy", "benefit": "Train 10% faster", "reduction": 10, "description": "Advanced learning"},
            3: {"name": "University", "benefit": "Train 15% faster", "reduction": 15, "description": "Higher education"},
            4: {"name": "Institute", "benefit": "Train 20% faster", "reduction": 20, "description": "Elite institution"},
            5: {"name": "Grand Library", "benefit": "Train 25% faster", "reduction": 25, "description": "Knowledge center"},
        }
    },
    "lumbermill": {
        "display_name": "Lumbermill",
        "icon": "tree.fill",
        "category": "economy",
        "description": "Produces wood resources for construction",
        "max_tier": 5,
        "benefit_formula": "Unlocks wood gathering at each level",
        "click_action": {"type": "gathering", "resource": "wood"},
        "tiers": {
            1: {"name": "Logging Camp", "benefit": "Gather 10 wood per action", "wood_per_action": 10, "description": "Basic logging operation"},
            2: {"name": "Sawmill", "benefit": "Gather 20 wood per action", "wood_per_action": 20, "description": "Improved wood processing"},
            3: {"name": "Lumber Yard", "benefit": "Gather 35 wood per action", "wood_per_action": 35, "description": "Large-scale lumber operation"},
            4: {"name": "Industrial Mill", "benefit": "Gather 50 wood per action", "wood_per_action": 50, "description": "Advanced lumber processing"},
            5: {"name": "Lumber Empire", "benefit": "Gather 75 wood per action", "wood_per_action": 75, "description": "Massive wood production"},
        }
    },
    "townhall": {
        "display_name": "Town Hall",
        "icon": "building.columns.fill",
        "category": "civic",
        "description": "Community center that unlocks group activities",
        "max_tier": 5,
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
        "requirement": 50,
        "icon": "house.fill",
        "abilities": [
            "Buy property in cities",
            "Upgrade owned properties",
            "Farm resources"
        ]
    },
    3: {
        "name": "Citizen",
        "requirement": 150,
        "icon": "person.2.fill",
        "abilities": [
            "Vote on city coups",
            "Join alliances",
            "Participate in city governance"
        ]
    },
    4: {
        "name": "Notable",
        "requirement": 300,
        "icon": "star.fill",
        "abilities": [
            "Propose city coups (with Leadership 3+)",
            "Lead strategic initiatives",
            "Enhanced influence"
        ]
    },
    5: {
        "name": "Champion",
        "requirement": 500,
        "icon": "crown.fill",
        "abilities": [
            "Vote weight counts 2x",
            "Significantly increased influence",
            "Respected leader status"
        ]
    },
    6: {
        "name": "Legendary",
        "requirement": 1000,
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
        "description": "Increases coup success chance and damage dealt",
        "benefits": {
            1: ["+1 Attack Power in coups", "Increases coup success chance"],
            2: ["+2 Attack Power in coups", "Increases coup success chance"],
            3: ["+3 Attack Power in coups", "Increases coup success chance"],
            4: ["+4 Attack Power in coups", "Increases coup success chance"],
            5: ["+5 Attack Power in coups", "Increases coup success chance"]
        }
    },
    "defense": {
        "display_name": "Defense",
        "stat_attribute": "defense_power",
        "icon": "shield.fill",
        "category": "combat",
        "description": "Reduces coup damage taken",
        "benefits": {
            1: ["+1 Defense Power in coups", "Reduces coup damage taken"],
            2: ["+2 Defense Power in coups", "Reduces coup damage taken"],
            3: ["+3 Defense Power in coups", "Reduces coup damage taken"],
            4: ["+4 Defense Power in coups", "Reduces coup damage taken"],
            5: ["+5 Defense Power in coups", "Reduces coup damage taken"]
        }
    },
    "leadership": {
        "display_name": "Leadership",
        "stat_attribute": "leadership",
        "icon": "crown.fill",
        "category": "political",
        "description": "Increases voting power and ruler rewards",
        "benefits": {
            1: ["Vote weight: 1.0", "Can vote on coups (with rep)"],
            2: ["Vote weight: 1.2", "+50% rewards from ruler distributions"],
            3: ["Vote weight: 1.4", "Can propose coups (300+ rep)"],
            4: ["Vote weight: 1.6", "+100% rewards from ruler"],
            5: ["Vote weight: 1.8", "-50% coup cost (500g instead of 1000g)"]
        }
    },
    "building": {
        "display_name": "Building",
        "stat_attribute": "building_skill",
        "icon": "hammer.fill",
        "category": "economy",
        "description": "Improves construction and resource gathering",
        "benefits": {
            1: ["-5% action cooldowns", "-5% property upgrade costs", "Work on contracts & properties"],
            2: ["-10% action cooldowns", "-10% property upgrade costs", "+10% gold from building contracts"],
            3: ["-14% action cooldowns", "-15% property upgrade costs", "+20% gold from contracts", "+1 daily Assist action"],
            4: ["-19% action cooldowns", "-20% property upgrade costs", "+30% gold from contracts", "10% chance to refund action cooldown"],
            5: ["-23% action cooldowns", "-25% property upgrade costs", "+40% gold from contracts", "25% chance to double contract progress"]
        }
    },
    "intelligence": {
        "display_name": "Intelligence",
        "stat_attribute": "intelligence",
        "icon": "eye.fill",
        "category": "espionage",
        "description": "Improves sabotage and scouting",
        "benefits": {
            1: ["-2% detection when sabotaging", "+2% catch chance when patrolling"],
            2: ["-4% detection when sabotaging", "+4% catch chance when patrolling"],
            3: ["-6% detection when sabotaging", "+6% catch chance when patrolling"],
            4: ["-8% detection when sabotaging", "+8% catch chance when patrolling"],
            5: ["-10% detection when sabotaging", "+10% catch chance when patrolling", "Vault Heist: Steal 10% of enemy vault (1000g cost)"]
        }
    },
    "science": {
        "display_name": "Science",
        "stat_attribute": "science",
        "icon": "flask.fill",
        "category": "enhancement",
        "description": "Enhances equipment effectiveness",
        "benefits": {
            1: ["+1 to all equipped weapon/armor stats"],
            2: ["+2 to all equipped weapon/armor stats", "10% chance equipment doesn't break on death"],
            3: ["+3 to all equipped weapon/armor stats", "Your weapons deal +1 extra damage in battle"],
            4: ["+4 to all equipped weapon/armor stats", "Your armor blocks +1 extra damage"],
            5: ["+5 to all equipped weapon/armor stats", "Weapons and armor 50% more effective"]
        }
    },
    "faith": {
        "display_name": "Faith",
        "stat_attribute": "faith",
        "icon": "hands.sparkles.fill",
        "category": "enhancement",
        "description": "Provides random battle bonuses",
        "benefits": {
            1: ["5% chance: random ally in battle gets +1 attack OR enemy gets -1 attack"],
            2: ["10% chance: random ally gets +2 attack OR enemy gets -2 defense"],
            3: ["15% chance: random ally gets +3 defense OR enemy gets -3 defense"],
            4: ["20% chance: 2 random allies get +2 attack OR 2 enemies get -2 attack"],
            5: ["25% chance: Revive 3 allies or smite 3 enemies during a battle"]
        }
    },
    "philosophy": {
        "display_name": "Philosophy",
        "stat_attribute": "philosophy",
        "icon": "book.fill",
        "category": "civic",
        "description": "Increases reputation gains and reduces penalties",
        "benefits": {
            1: ["+10% reputation from all actions", "-10% reputation loss from failed coups"],
            2: ["+20% reputation from all actions", "-20% reputation loss from failed coups"],
            3: ["+30% reputation from all actions", "Check-ins award 2x reputation", "-30% rep loss from fails"],
            4: ["+40% reputation from all actions", "-40% reputation loss from failed actions"],
            5: ["+50% reputation from all actions", "-50% reputation loss", "Unlock: Start coup votes in kingdoms where you have 100+ rep (instead of 150)"]
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
            2: ["Instant market purchases refund the difference if seller's price was lower than your bid"],
            3: ["Ability to buy and sell to markets of other kingdoms"],
            4: ["Receive bonus gold when buyers bid higher than your asking price"],
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


def get_skills_data_for_player(state, training_cost: int) -> list:
    """
    Get complete skill data for player state response.
    Returns a list of skill objects with all info needed for dynamic UI rendering.
    Frontend can render skills without hardcoding any skill types!
    """
    skills_data = []
    
    for skill_type, skill_config in SKILLS.items():
        current_value = get_stat_value(state, skill_type)
        
        # Get benefits for current tier (capped at 5 for display)
        current_tier_benefits = skill_config["benefits"].get(
            min(current_value, 5), 
            skill_config["benefits"].get(5, [])
        )
        
        skills_data.append({
            "skill_type": skill_type,
            "display_name": skill_config["display_name"],
            "icon": skill_config["icon"],
            "category": skill_config["category"],
            "description": skill_config["description"],
            "current_tier": current_value,
            "max_tier": 5,
            "training_cost": training_cost,  # Same cost for all skills
            "current_benefits": current_tier_benefits,
            "display_order": list(SKILLS.keys()).index(skill_type) * 10,  # 0, 10, 20, etc.
        })
    
    return skills_data


# ===== HELPER FUNCTIONS =====

def _get_training_actions_dict() -> dict:
    """Get training actions required - runtime import to avoid circular dependency"""
    from .actions.training import calculate_training_actions_required
    return {
        str(level): calculate_training_actions_required(level, education_level=0)
        for level in range(10)
    }


# ===== API ENDPOINTS =====

@router.get("")
def get_all_tiers():
    """
    Get ALL tier information for the entire game
    Single source of truth - NO MORE HARDCODING IN FRONTEND!
    """
    from .actions.action_config import ACTION_TYPES
    from .resources import RESOURCES
    
    return {
        "resources": {
            "types": RESOURCES  # Import from resources.py
        },
        "properties": {
            "max_tier": get_property_max_tier(),
            "tiers": {str(k): v for k, v in PROPERTY_TIERS.items()}
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
            "actions_required": _get_training_actions_dict()
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


@router.get("/properties")
def get_property_tiers():
    """Get property tier info with costs"""
    tiers_dict = {}
    for tier in range(1, 6):
        info = PROPERTY_TIERS[tier]
        
        # Calculate costs
        if tier == 1:
            base_cost = 500  # Base land price
        else:
            base_cost = 500 * (2 ** (tier - 2))  # Upgrade cost formula
        
        base_actions = 5 + ((tier - 1) * 2)
        
        tiers_dict[str(tier)] = {
            "tier": tier,
            "name": info["name"],
            "description": info["description"],
            "benefits": info["benefits"],
            "base_gold_cost": base_cost,
            "base_actions_required": base_actions,
            "unlocks_crafting": tier >= 3
        }
    
    return {
        "max_tier": 5,
        "tiers": tiers_dict,
        "notes": {
            "land_purchase": "Tier 1 land cost varies by kingdom population (base 500g)",
            "upgrade_costs": "Tier 2-5 costs shown are for upgrading from previous tier",
            "actions": "Base actions required, reduced by Building skill (up to 50% reduction)",
            "reputation_required": "50+ reputation required to purchase land in a kingdom"
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
