"""
RESOURCES SYSTEM - Single Source of Truth for inventory/resource definitions
Frontend renders ALL resources dynamically from this config - NO HARDCODING!
"""
from fastapi import APIRouter

router = APIRouter(prefix="/resources", tags=["resources"])


# ===== RESOURCE DEFINITIONS - SINGLE SOURCE OF TRUTH =====
# Keys MUST match PlayerState database columns exactly (gold, iron, steel, wood, etc.)

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
    }
}


@router.get("")
def get_all_resources():
    """
    Get ALL resource configurations with icons, colors, display names
    Frontend renders inventory dynamically - NO MORE HARDCODING!
    """
    return {
        "resources": RESOURCES,
        "categories": ["currency", "material"],
        "notes": {
            "dynamic_rendering": "Frontend should render all resources from this config",
            "database_sync": "Resource keys match PlayerState database columns exactly",
            "adding_resources": "Add new resources to RESOURCES dict - they'll appear everywhere automatically"
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

