"""
RESOURCES SYSTEM - Single Source of Truth for inventory/resource definitions
Frontend renders ALL resources dynamically from this config - NO HARDCODING!

This file is AUTHORITATIVE. The `items` DB table is synced from this on startup.
"""
from fastapi import APIRouter
from sqlalchemy.orm import Session

router = APIRouter(prefix="/resources", tags=["resources"])


# ===== RESOURCE DEFINITIONS - SINGLE SOURCE OF TRUTH =====
# These define how items look in the UI (icon, color, name, etc.)
# Storage: gold/iron/steel/wood are legacy columns in PlayerState
#          meat/sinew/etc use the player_inventory table (proper design!)
#
# is_tradeable: Can be sold on the market (default True)
# storage_type: "column" = PlayerState column, "inventory" = player_inventory table
#
# ORGANIZED BY ORIGIN/TYPE:
#   0-9:   Currency
#   10-19: Core Materials (iron, steel, wood)
#   20-29: Hunting Drops (meat, sinew, fur, trinkets)
#   30-39: Fishing
#   40-49: Foraging (wild gathering)
#   50-59: Farming (cultivated outputs)
#   90-99: Special/Crafting (blueprints, etc)

# I DO NOT LIKE HOW WE HAVE THIS WEIRD HAVE RESOURCE HALF IN TABLE WITHOUT FK DESIGN!

RESOURCES = {
    # ===== CURRENCY (0-9) =====
    "gold": {
        "display_name": "Gold",
        "icon": "g.circle.fill",
        "color": "goldLight",
        "description": "Primary currency used for purchasing and trading",
        "category": "currency",
        "display_order": 0,
        "is_tradeable": False,  # Gold is currency, not a tradeable item
        "storage_type": "column",
    },

    # ===== CORE MATERIALS (10-19) =====
    # Basic crafting/building resources
    "iron": {
        "display_name": "Iron",
        "icon": "cube.fill",
        "color": "gray",
        "description": "Basic crafting material for weapons and armor",
        "category": "material",
        "display_order": 10,
        "is_tradeable": True,
        "storage_type": "column",
    },
    "steel": {
        "display_name": "Steel",
        "icon": "cube.fill",
        "color": "blue",
        "description": "Advanced crafting material for superior equipment",
        "category": "material",
        "display_order": 11,
        "is_tradeable": True,
        "storage_type": "column",
    },
    "wood": {
        "display_name": "Wood",
        "icon": "tree.fill",
        "color": "brown",
        "description": "Building material used for construction",
        "category": "material",
        "display_order": 12,
        "is_tradeable": True,
        "storage_type": "column",
    },

    # ===== HUNTING DROPS (20-29) =====
    # Resources from hunting animals
    "meat": {
        "display_name": "Meat",
        "icon": "flame.fill",
        "color": "red",
        "description": "Fresh game meat from hunting. A filling food source.",
        "category": "consumable",
        "display_order": 20,
        "is_tradeable": True,
        "storage_type": "inventory",
        "is_food": True,  # Can be consumed to pay action food costs
    },
    "sinew": {
        "display_name": "Sinew",
        "icon": "line.diagonal",
        "color": "brown",
        "description": "Animal sinew. Rare drop from hunting - used to craft a hunting bow.",
        "category": "crafting",
        "display_order": 21,
        "is_tradeable": True,
        "storage_type": "inventory",
    },
    "fur": {
        "display_name": "Fur",
        "icon": "rectangle.portrait.fill",
        "color": "orange",
        "description": "Animal fur. I can craft this into some armor.",
        "category": "crafting",
        "display_order": 22,
        "is_tradeable": True,
        "storage_type": "inventory",
    },
    "lucky_rabbits_foot": {
        "display_name": "Rabbit Foot",
        "icon": "hare.fill",
        "color": "purple",
        "description": "A lucky charm from the hunt. Increases tracking success chance by 10%.",
        "category": "trinket",
        "display_order": 23,
        "is_tradeable": True,
        "storage_type": "inventory",
        "tracking_hit_chance_bonus": 0.10,  # +10% tracking hit chance
    },

    # ===== FISHING (30-39) =====
    # Resources from fishing
    "pet_fish": {
        "display_name": "Pet Fish",
        "icon": "fish.circle.fill",
        "color": "cyan",
        "description": "A rare companion fish. Decorative trophy from fishing.",
        "category": "pet",  # Pets have their own category!
        "display_order": 30,
        "is_tradeable": True,
        "storage_type": "inventory",
        "is_pet": True,  # Flag to identify pets
    },

    # ===== FORAGING (40-49) =====
    # Wild gathering - seeds, berries, found items
    "wheat_seed": {
        "display_name": "Seed",
        "icon": "leaf.fill",
        "color": "gold",
        "description": "Seeds gathered from wild bushes. Used for farming.",
        "category": "material",
        "display_order": 40,
        "is_tradeable": True,
        "storage_type": "inventory",
    },
    "berries": {
        "display_name": "Berries",
        "icon": "seal.fill",
        "color": "buttonDanger",
        "description": "Fresh wild berries gathered from bushes. A tasty source of food.",
        "category": "consumable",
        "display_order": 41,
        "is_tradeable": True,
        "storage_type": "inventory",
        "is_food": True,  # Can be consumed to pay action food costs
    },
    "rare_egg": {
        "display_name": "Rare Egg",
        "icon": "oval.fill",
        "color": "imperialGold",
        "description": "A mysterious golden egg found while foraging. Will hatch into a chicken pet!",
        "category": "material",
        "display_order": 42,
        "is_tradeable": False,
        "storage_type": "inventory",
    },

    # ===== FARMING (50-59) =====
    # Cultivated crops - outputs from planting seeds
    "wheat": {
        "display_name": "Wheat",
        "icon": "leaf",
        "color": "goldLight",
        "description": "Fresh wheat. Used to bake bread.",
        "category": "material",
        "display_order": 50,
        "is_tradeable": True,
        "storage_type": "inventory",
    },

    # ===== SPECIAL / CRAFTING (90-99) =====
    # Blueprints, tokens, special items
    "blueprint": {
        "display_name": "Blueprint",
        "icon": "scroll.fill",
        "color": "royalBlue",
        "description": "A crafting blueprint. Take to your Workshop to craft items.",
        "category": "crafting",
        "display_order": 90,
        "is_tradeable": True,
        "storage_type": "inventory",
    },
}


# ===== PETS - Companion creatures collected from activities =====
# Pets are a special category shown in their own UI card
# They're stored in player_inventory like other items

PETS = {
    "pet_fish": {
        "display_name": "Pet Fish",
        "icon": "fish.circle.fill",
        "color": "cyan",
        "description": "A rare companion fish caught while fishing. Shows your mastery of the waters!",
        "source": "Rare drop from Catfish and Legendary Carp",
    },
}

# Empty state config for pets card - sent to frontend
PETS_EMPTY_STATE = {
    "title": "No pets yet",
    "message": "Complete activities to find rare companions!",
    "icon": "pawprint.circle",
}


def sync_items_to_db(db: Session):
    """
    Sync RESOURCES dict to the items table on startup.
    Code is authoritative - this just provides DB queryability and FK constraints.
    """
    from db.models import Item
    
    for item_id, config in RESOURCES.items():
        existing = db.query(Item).filter(Item.id == item_id).first()
        
        if existing:
            # Update existing item
            existing.display_name = config["display_name"]
            existing.icon = config["icon"]
            existing.color = config["color"]
            existing.description = config.get("description", "")
            existing.category = config["category"]
            existing.display_order = config.get("display_order", 0)
            existing.is_tradeable = config.get("is_tradeable", True)
        else:
            # Create new item
            item = Item(
                id=item_id,
                display_name=config["display_name"],
                icon=config["icon"],
                color=config["color"],
                description=config.get("description", ""),
                category=config["category"],
                display_order=config.get("display_order", 0),
                is_tradeable=config.get("is_tradeable", True),
            )
            db.add(item)
    
    db.commit()
    print(f"✅ Synced {len(RESOURCES)} items to database")

# ===== HUNTING BOW - Craftable with sinew + wood =====

HUNTING_BOW = {
    "id": "hunting_bow",
    "display_name": "Hunting Bow",
    "icon": "arrow.up.right",
    "color": "green",
    "description": "A sturdy bow for hunting. Gives +2 attack during hunts.",
    "attack_bonus": 2,
    "recipe": {"wood": 10, "sinew": 3},
}


@router.get("")
def get_all_resources():
    """
    Get ALL resource configurations with icons, colors, display names
    Frontend renders inventory dynamically - NO MORE HARDCODING!
    """
    return {
        "resources": RESOURCES,
        "hunting_bow": HUNTING_BOW,
        "categories": ["currency", "material", "consumable", "crafting", "trinket", "pet"],
        "notes": {
            "dynamic_rendering": "Frontend should render all resources from this config",
            "storage": "gold/iron/steel/wood are PlayerState columns. meat/sinew use player_inventory table.",
            "hunting": "Hunts drop meat + gold (equal amounts, taxed) + sinew (rare). Craft hunting bow with 10 wood + 3 sinew."
        }
    }


@router.get("/{resource_id}")
def get_resource_config(resource_id: str):
    """Get configuration for a specific resource"""
    if resource_id not in RESOURCES:
        return {"error": f"Unknown resource: {resource_id}"}
    
    return {
        "resource_id": resource_id,
        **RESOURCES[resource_id]
    }


def get_pets_config() -> dict:
    """Get pets configuration including empty state for frontend."""
    return {
        "pets": PETS,
        "empty_state": PETS_EMPTY_STATE,
    }


def get_player_pets(db: Session, user_id: int) -> list:
    """
    Get all pets owned by a player.
    Returns list of pet data with quantities.
    """
    from db.models.inventory import PlayerInventory
    
    pets_data = []
    for pet_id, pet_config in PETS.items():
        # Query inventory for this pet
        inv = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == user_id,
            PlayerInventory.item_id == pet_id
        ).first()
        
        quantity = inv.quantity if inv else 0
        if quantity > 0:
            pets_data.append({
                "id": pet_id,
                "quantity": quantity,
                "display_name": pet_config["display_name"],
                "icon": pet_config["icon"],
                "color": pet_config["color"],
                "description": pet_config["description"],
                "source": pet_config.get("source", ""),
            })
    
    return pets_data


@router.get("/pets/config")
def get_pets_config_endpoint():
    """Get all pet configurations for frontend rendering"""
    return get_pets_config()

