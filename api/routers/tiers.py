"""
UNIFIED TIER SYSTEM - Single Source of Truth for ALL game tier descriptions
Handles: Properties, Skills, Buildings, Crafting, Training
NO MORE HARDCODING DESCRIPTIONS IN FRONTEND!
"""
from fastapi import APIRouter

router = APIRouter(prefix="/tiers", tags=["tiers"])


# ===== PROPERTY TIERS (1-5) =====

PROPERTY_TIERS = {
    1: {
        "name": "Land",
        "description": "Cleared land with travel benefits",
        "benefits": [
            "Instant travel to this kingdom (no cooldown)",
            "50% off travel cost to this kingdom"
        ]
    },
    2: {
        "name": "House",
        "description": "Basic dwelling",
        "benefits": [
            "All Land benefits",
            "Personal residence in kingdom"
        ]
    },
    3: {
        "name": "Workshop",
        "description": "Crafting workshop",
        "benefits": [
            "All House benefits",
            "Unlock equipment crafting (weapons & armor)",
            "15% faster crafting speed"
        ]
    },
    4: {
        "name": "Beautiful Property",
        "description": "Luxurious property",
        "benefits": [
            "All Workshop benefits",
            "Tax exemption in this kingdom"
        ]
    },
    5: {
        "name": "Estate",
        "description": "Grand estate",
        "benefits": [
            "All Beautiful Property benefits",
            "Protection during kingdom conquest (50% chance to keep property)"
        ]
    }
}


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
        "description": "Generates passive gold income",
        "max_tier": 5,
        "benefit_formula": "+{income}g per day",
        "tiers": {
            1: {"name": "Stalls", "benefit": "+15g per day", "income": 15, "description": "Basic market stalls"},
            2: {"name": "Market Square", "benefit": "+35g per day", "income": 35, "description": "Town market"},
            3: {"name": "Trading Post", "benefit": "+65g per day", "income": 65, "description": "Regional trading hub"},
            4: {"name": "Commercial District", "benefit": "+100g per day", "income": 100, "description": "Large commercial area"},
            5: {"name": "Trade Empire", "benefit": "+150g per day", "income": 150, "description": "Major trade center"},
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


# ===== SKILL BENEFITS =====

SKILL_BENEFITS = {
    "attack": {
        "per_tier": "+{tier} Attack Power in coups",
        "benefits": [
            "Increases coup success chance",
            "Stacks with equipment bonuses"
        ]
    },
    "defense": {
        "per_tier": "+{tier} Defense Power in coups",
        "benefits": [
            "Reduces coup damage taken",
            "Helps defend your kingdom"
        ]
    },
    "leadership": {
        "per_tier": "Vote weight: +{weight}",
        "tier_bonuses": {
            1: ["Can vote on coups (with rep)"],
            2: ["+50% rewards from ruler distributions"],
            3: ["Can propose coups (300+ rep)"],
            4: ["+100% rewards from ruler"],
            5: ["-50% coup cost (500g instead of 1000g)"]
        }
    },
    "building": {
        "per_tier": "-{discount}% property upgrade costs",
        "tier_bonuses": {
            1: ["Work on contracts & properties"],
            2: ["+10% gold from building contracts"],
            3: ["+20% gold from contracts", "+1 daily Assist action"],
            4: ["+30% gold from contracts", "10% chance to refund action cooldown"],
            5: ["+40% gold from contracts", "25% chance to double contract progress"]
        }
    },
    "intelligence": {
        "per_tier": "-{bonus}% detection when sabotaging, +{bonus}% catch chance when patrolling",
        "tier_bonuses": {
            5: ["Vault Heist: Steal 10% of enemy vault (1000g cost)"]
        }
    }
}


# ===== API ENDPOINTS =====

@router.get("")
def get_all_tiers():
    """
    Get ALL tier information for the entire game
    Single source of truth - NO MORE HARDCODING IN FRONTEND!
    """
    return {
        "properties": {
            "max_tier": 5,
            "tiers": {str(k): v for k, v in PROPERTY_TIERS.items()}
        },
        "skills": {
            "max_tier": 10,
            "tier_names": SKILL_TIER_NAMES,
            "skill_benefits": SKILL_BENEFITS
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
            "tier_names": SKILL_TIER_NAMES
        },
        "reputation": {
            "max_tier": 6,
            "tiers": {str(k): v for k, v in REPUTATION_TIERS.items()}
        }
    }


@router.get("/properties")
def get_property_tiers():
    """Get property tier info with costs"""
    tiers = []
    for tier in range(1, 6):
        info = PROPERTY_TIERS[tier]
        
        # Calculate costs
        if tier == 1:
            base_cost = 500  # Base land price
        else:
            base_cost = 500 * (2 ** (tier - 2))  # Upgrade cost formula
        
        base_actions = 5 + ((tier - 1) * 2)
        
        tiers.append({
            "tier": tier,
            "name": info["name"],
            "description": info["description"],
            "benefits": info["benefits"],
            "base_gold_cost": base_cost,
            "base_actions_required": base_actions,
            "unlocks_crafting": tier >= 3
        })
    
    return {
        "tiers": tiers,
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
        benefits = []
        
        # Add per-tier benefit with interpolation
        per_tier = skill_data.get("per_tier", "")
        if per_tier:
            if skill_name == "leadership":
                weight = 1.0 + (tier - 1) * 0.2
                benefits.append(per_tier.format(weight=f"{weight:.1f}"))
            elif skill_name == "building":
                discount = tier * 5
                benefits.append(per_tier.format(discount=discount))
            elif skill_name == "intelligence":
                bonus = tier * 2
                benefits.append(per_tier.format(bonus=bonus))
            else:
                benefits.append(per_tier.format(tier=tier))
        
        # Add static benefits
        for b in skill_data.get("benefits", []):
            benefits.append(b)
        
        # Add tier-specific bonuses
        tier_bonuses = skill_data.get("tier_bonuses", {})
        if tier in tier_bonuses:
            benefits.extend(tier_bonuses[tier])
        
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

