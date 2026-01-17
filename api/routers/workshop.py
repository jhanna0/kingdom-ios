"""
WORKSHOP SYSTEM - Blueprint-based crafting
==========================================
Blueprints are generic crafting tokens. You need 1 blueprint + materials to craft ANY item.
The Workshop shows what you CAN craft based on your materials.

Think Minecraft crafting table - blueprint is just the "permission to craft".
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from db import get_db, User, Property, PlayerItem
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.resources import RESOURCES


router = APIRouter(prefix="/workshop", tags=["workshop"])


# ===== CRAFTABLE ITEMS =====
# Each item has a recipe. Player needs 1 blueprint + materials to craft.

CRAFTABLE_ITEMS = {
    "hunting_bow": {
        "display_name": "Hunting Bow",
        "icon": "arrow.up.right",
        "color": "buttonSuccess",
        "description": "A sturdy bow for hunting. Gives +2 attack during hunts.",
        "type": "weapon",
        "tier": 1,
        "attack_bonus": 2,
        "defense_bonus": 0,
        "recipe": {
            "sinew": 5,
            "wood": 100,
        },
    },
    "fur_armor": {
        "display_name": "Fur Armor",
        "icon": "shield.lefthalf.filled",
        "color": "buttonWarning",
        "description": "Crude but effective armor made from animal fur.",
        "type": "armor",
        "tier": 1,
        "attack_bonus": 0,
        "defense_bonus": 2,
        "recipe": {
            "fur": 10
        },
    },
}


def get_player_material_count(db: Session, user_id: int, material_id: str) -> int:
    """Get how much of a material the player has."""
    from db.models.player_state import PlayerState
    
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    if not state:
        return 0
    
    # Column-based resources
    if material_id == "gold":
        return int(state.gold)
    elif material_id == "iron":
        return state.iron
    elif material_id == "steel":
        return state.steel
    elif material_id == "wood":
        return state.wood
    
    # Inventory-based resources
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == material_id
    ).first()
    
    return inv.quantity if inv else 0


def deduct_material(db: Session, user_id: int, material_id: str, amount: int) -> bool:
    """Deduct materials from player. Returns True if successful."""
    from db.models.player_state import PlayerState
    
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    if not state:
        return False
    
    # Column-based resources
    if material_id == "gold":
        if state.gold < amount:
            return False
        state.gold -= amount
        return True
    elif material_id == "iron":
        if state.iron < amount:
            return False
        state.iron -= amount
        return True
    elif material_id == "steel":
        if state.steel < amount:
            return False
        state.steel -= amount
        return True
    elif material_id == "wood":
        if state.wood < amount:
            return False
        state.wood -= amount
        return True
    
    # Inventory-based resources
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == material_id
    ).first()
    
    if not inv or inv.quantity < amount:
        return False
    
    inv.quantity -= amount
    if inv.quantity <= 0:
        db.delete(inv)
    
    return True


def get_blueprint_count(db: Session, user_id: int) -> int:
    """Get how many blueprints the player owns."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == "blueprint"
    ).first()
    return inv.quantity if inv else 0


def consume_blueprint(db: Session, user_id: int) -> bool:
    """Consume one blueprint. Returns True if successful."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == "blueprint"
    ).first()
    
    if not inv or inv.quantity < 1:
        return False
    
    inv.quantity -= 1
    if inv.quantity <= 0:
        db.delete(inv)
    
    return True


@router.get("/status")
def get_workshop_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get workshop status - blueprints owned, what can be crafted.
    Frontend renders everything from this response.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check workshop requirement (tier 3+)
    workshop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    has_workshop = workshop_property is not None
    
    # Get blueprint count
    blueprint_count = get_blueprint_count(db, current_user.id)
    
    # Build list of craftable items with recipe status
    # ONLY show items if:
    # 1. Player has workshop access
    # 2. Player has at least ONE of the required materials (like Minecraft!)
    craftable_items = []
    if has_workshop:
        for item_id, item_config in CRAFTABLE_ITEMS.items():
            recipe = item_config["recipe"]
            can_craft = blueprint_count > 0
            materials_status = []
            has_any_material = False  # Track if player has ANY required material
            
            for mat_id, required in recipe.items():
                player_has = get_player_material_count(db, current_user.id, mat_id)
                has_enough = player_has >= required
                can_craft = can_craft and has_enough
                
                # Check if player has ANY of this material
                if player_has > 0:
                    has_any_material = True
                
                # Get material display info
                mat_info = RESOURCES.get(mat_id, {})
                
                materials_status.append({
                    "id": mat_id,
                    "display_name": mat_info.get("display_name", mat_id.replace("_", " ").title()),
                    "icon": mat_info.get("icon", "questionmark.circle"),
                    "color": mat_info.get("color", "gray"),
                    "required": required,
                    "player_has": player_has,
                    "has_enough": has_enough,
                })
            
            # ONLY show item if player has at least one required material
            if has_any_material:
                craftable_items.append({
                    "id": item_id,
                    "display_name": item_config["display_name"],
                    "icon": item_config["icon"],
                    "color": item_config["color"],
                    "description": item_config["description"],
                    "type": item_config["type"],
                    "attack_bonus": item_config.get("attack_bonus", 0),
                    "defense_bonus": item_config.get("defense_bonus", 0),
                    "recipe": materials_status,
                    "can_craft": can_craft,
                })
    
    return {
        "has_workshop": has_workshop,
        "workshop_property": {
            "id": workshop_property.id,
            "kingdom_name": workshop_property.kingdom_name,
            "tier": workshop_property.tier,
        } if workshop_property else None,
        "blueprint_count": blueprint_count,
        "craftable_items": craftable_items,
        "workshop_requirement": "Upgrade your property to unlock Workshop access.",
    }


@router.post("/craft/{item_id}")
def craft_item(
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Craft an item. Consumes 1 blueprint + required materials.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check workshop requirement (tier 3+)
    workshop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    if not workshop_property:
        raise HTTPException(
            status_code=400,
            detail="You need a Workshop (Property Tier 3) to craft items."
        )
    
    # Check item exists
    if item_id not in CRAFTABLE_ITEMS:
        raise HTTPException(status_code=404, detail="Unknown item")
    
    item_config = CRAFTABLE_ITEMS[item_id]
    
    # Check player has a blueprint
    blueprint_count = get_blueprint_count(db, current_user.id)
    if blueprint_count < 1:
        raise HTTPException(status_code=400, detail="You need a blueprint to craft items")
    
    # Check player has all materials
    recipe = item_config["recipe"]
    for mat_id, required in recipe.items():
        player_has = get_player_material_count(db, current_user.id, mat_id)
        if player_has < required:
            mat_name = RESOURCES.get(mat_id, {}).get("display_name", mat_id)
            raise HTTPException(
                status_code=400,
                detail=f"Not enough {mat_name}. Need {required}, have {player_has}."
            )
    
    # All checks passed - consume blueprint and materials
    if not consume_blueprint(db, current_user.id):
        raise HTTPException(status_code=400, detail="Failed to consume blueprint")
    
    for mat_id, required in recipe.items():
        if not deduct_material(db, current_user.id, mat_id, required):
            db.rollback()
            raise HTTPException(status_code=500, detail="Failed to deduct materials")
    
    # Create the item (equipment goes to player_items table)
    new_item = PlayerItem(
        user_id=current_user.id,
        type=item_config["type"],
        tier=item_config.get("tier", 1),
        attack_bonus=item_config.get("attack_bonus", 0),
        defense_bonus=item_config.get("defense_bonus", 0),
        is_equipped=False,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    
    return {
        "success": True,
        "message": f"Crafted {item_config['display_name']}!",
        "item": {
            "id": new_item.id,
            "display_name": item_config["display_name"],
            "icon": item_config["icon"],
            "color": item_config["color"],
            "type": new_item.type,
            "tier": new_item.tier,
            "attack_bonus": new_item.attack_bonus,
            "defense_bonus": new_item.defense_bonus,
        },
        "blueprints_remaining": get_blueprint_count(db, current_user.id),
    }


@router.get("/recipes")
def get_all_recipes():
    """Get all craftable item recipes (for reference)."""
    return {"craftable_items": CRAFTABLE_ITEMS}
