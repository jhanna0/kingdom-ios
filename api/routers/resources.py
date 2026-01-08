"""
RESOURCES SYSTEM - Single Source of Truth for inventory/resource definitions
Frontend renders ALL resources dynamically from this config - NO HARDCODING!
"""
from fastapi import APIRouter

router = APIRouter(prefix="/resources", tags=["resources"])


# ===== RESOURCE DEFINITIONS - SINGLE SOURCE OF TRUTH =====
# These define how items look in the UI (icon, color, name, etc.)
# Storage: gold/iron/steel/wood are legacy columns in PlayerState
#          meat/sinew/etc use the player_inventory table (proper design!)

RESOURCES = {
    "gold": {
        "display_name": "Gold",
        "icon": "g.circle.fill",
        "color": "goldLight",  # Use theme color name - frontend maps to Color(red: 0.7, green: 0.5, blue: 0.2)
        "description": "Primary currency used for purchasing and trading",
        "category": "currency",
        "display_order": 0
    },
    "iron": {
        "display_name": "Iron",
        "icon": "cube.fill",
        "color": "gray",  # Standard SwiftUI .gray
        "description": "Basic crafting material for weapons and armor",
        "category": "material",
        "display_order": 1
    },
    "steel": {
        "display_name": "Steel",
        "icon": "cube.fill",
        "color": "blue",  # Standard SwiftUI .blue
        "description": "Advanced crafting material for superior equipment",
        "category": "material",
        "display_order": 2
    },
    "wood": {
        "display_name": "Wood",
        "icon": "tree.fill",
        "color": "brown",  # Standard SwiftUI .brown
        "description": "Building material used for construction",
        "category": "material",
        "display_order": 3
    },
    "meat": {
        "display_name": "Meat",
        "icon": "flame.fill",
        "color": "red",
        "description": "Fresh game meat from hunting. Sell at market or use for food.",
        "category": "consumable",
        "display_order": 4
    },
    "sinew": {
        "display_name": "Sinew",
        "icon": "line.diagonal",
        "color": "brown",
        "description": "Animal sinew. Rare drop from hunting - used to craft a hunting bow.",
        "category": "crafting",
        "display_order": 5
    },
}

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
        "categories": ["currency", "material", "consumable", "crafting"],
        "notes": {
            "dynamic_rendering": "Frontend should render all resources from this config",
            "storage": "gold/iron/steel/wood are PlayerState columns. meat/sinew use player_inventory table.",
            "hunting": "Hunts drop meat (always) + sinew (rare). Craft hunting bow with 10 wood + 3 sinew."
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

