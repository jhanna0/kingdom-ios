"""
WORKSHOP SYSTEM - Blueprint-based crafting with CONTRACT SYSTEM
================================================================
Blueprints are generic crafting tokens. You need 1 blueprint + materials to craft ANY item.
Crafting uses the contract system like everything else in the game:
  1. Start craft → creates contract, deducts materials
  2. Work on craft → cooldown-based actions
  3. Complete → item created
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta

from db import get_db, User, Property, PlayerItem, UnifiedContract, ContractContribution
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.resources import RESOURCES
from routers.actions.utils import (
    check_and_set_slot_cooldown_atomic, 
    format_datetime_iso, 
    calculate_cooldown, 
    set_cooldown,
    check_and_deduct_food_cost
)
from routers.actions.constants import WORK_BASE_COOLDOWN
from config import DEV_MODE


router = APIRouter(prefix="/workshop", tags=["workshop"])


# ===== CRAFTABLE ITEMS =====
# Each item has a recipe. Player needs 1 blueprint + materials to craft.

CRAFTABLE_ITEMS = {
    "hunting_bow": {
        "display_name": "Hunting Bow",
        "icon": "arrow.up.right",
        "color": "buttonSuccess",
        "description": "A bow strung with sinew. +10% strike chance during hunts.",
        "type": "weapon",
        "tier": 1,
        "attack_bonus": 0,
        "defense_bonus": 0,
        "strike_hit_chance_bonus": 0.10,  # +10% strike phase hit chance (like rabbit foot for tracking)
        "actions_required": 10,  # Crafting takes real effort over time
        "recipe": {
            "sinew": 5,
            "wood": 100,
        },
    },
    "fur_armor": {
        "display_name": "Fur Armor",
        "icon": "shield.lefthalf.filled",
        "color": "buttonWarning",
        "description": "Crude but warm armor made from animal fur. +1 defense.",
        "type": "armor",
        "tier": 1,
        "attack_bonus": 0,
        "defense_bonus": 1,
        "actions_required": 10,  # Crafting takes real effort over time
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


def get_active_workshop_contract(db: Session, user_id: int):
    """Get active workshop crafting contract if any."""
    return db.query(UnifiedContract).filter(
        UnifiedContract.user_id == user_id,
        UnifiedContract.category == "workshop_craft",
        UnifiedContract.completed_at.is_(None)
    ).first()


@router.get("/status")
def get_workshop_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get workshop status - blueprints owned, active contract, what can be crafted.
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
    
    # Get active crafting contract
    active_contract = get_active_workshop_contract(db, current_user.id)
    active_contract_data = None
    
    if active_contract:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == active_contract.id
        ).scalar()
        
        item_config = CRAFTABLE_ITEMS.get(active_contract.type, {})
        
        active_contract_data = {
            "id": active_contract.id,
            "item_id": active_contract.type,
            "display_name": item_config.get("display_name", active_contract.type),
            "icon": item_config.get("icon", "hammer"),
            "color": item_config.get("color", "gray"),
            "actions_required": active_contract.actions_required,
            "actions_completed": actions_completed,
            "progress_percent": int((actions_completed / active_contract.actions_required) * 100) if active_contract.actions_required > 0 else 0,
            "created_at": format_datetime_iso(active_contract.created_at) if active_contract.created_at else None,
        }
    
    # Build list of craftable items with recipe status
    craftable_items = []
    # Common resources everyone has - don't use these to decide if recipe should show
    COMMON_MATERIALS = {"wood", "iron", "gold", "steel"}
    
    if has_workshop:
        for item_id, item_config in CRAFTABLE_ITEMS.items():
            recipe = item_config["recipe"]
            can_craft = blueprint_count > 0 and active_contract is None  # Can't start new if one is active
            materials_status = []
            has_rare_material = False
            
            for mat_id, required in recipe.items():
                player_has = get_player_material_count(db, current_user.id, mat_id)
                has_enough = player_has >= required
                can_craft = can_craft and has_enough
                
                # Only show recipe if player has a RARE material (not common shit like wood)
                if player_has > 0 and mat_id not in COMMON_MATERIALS:
                    has_rare_material = True
                
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
            
            if has_rare_material:
                craftable_items.append({
                    "id": item_id,
                    "display_name": item_config["display_name"],
                    "icon": item_config["icon"],
                    "color": item_config["color"],
                    "description": item_config["description"],
                    "type": item_config["type"],
                    "attack_bonus": item_config.get("attack_bonus", 0),
                    "defense_bonus": item_config.get("defense_bonus", 0),
                    "actions_required": item_config.get("actions_required", 3),
                    "recipe": materials_status,
                    "can_craft": can_craft,
                })
    
    return {
        "has_workshop": has_workshop,
        "workshop_property": {
            "id": str(workshop_property.id),
            "kingdom_name": workshop_property.kingdom_name,
            "tier": workshop_property.tier,
        } if workshop_property else None,
        "blueprint_count": blueprint_count,
        "active_contract": active_contract_data,
        "craftable_items": craftable_items,
        "workshop_requirement": "Upgrade your property to Tier 3 to unlock Workshop.",
    }


@router.post("/craft/{item_id}/start")
def start_craft(
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Start crafting an item. Creates a contract, deducts blueprint + materials.
    Must complete actions to finish crafting.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Check workshop requirement
    workshop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    if not workshop_property:
        raise HTTPException(status_code=400, detail="You need a Workshop (Property Tier 3) to craft items.")
    
    # Check no active contract
    active_contract = get_active_workshop_contract(db, current_user.id)
    if active_contract:
        raise HTTPException(status_code=400, detail="You already have a craft in progress. Complete it first!")
    
    # Check item exists
    if item_id not in CRAFTABLE_ITEMS:
        raise HTTPException(status_code=404, detail="Unknown item")
    
    item_config = CRAFTABLE_ITEMS[item_id]
    
    # Check blueprint
    blueprint_count = get_blueprint_count(db, current_user.id)
    if blueprint_count < 1:
        raise HTTPException(status_code=400, detail="You need a blueprint to craft items")
    
    # Check materials
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
    
    # Create the contract
    contract = UnifiedContract(
        user_id=current_user.id,
        category="workshop_craft",
        type=item_id,
        tier=item_config.get("tier", 1),
        actions_required=item_config.get("actions_required", 3),
        kingdom_id=state.current_kingdom_id,
    )
    db.add(contract)
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Started crafting {item_config['display_name']}! Complete {contract.actions_required} work actions to finish.",
        "contract": {
            "id": contract.id,
            "item_id": item_id,
            "display_name": item_config["display_name"],
            "icon": item_config["icon"],
            "color": item_config["color"],
            "actions_required": contract.actions_required,
            "actions_completed": 0,
        },
        "blueprints_remaining": get_blueprint_count(db, current_user.id),
    }


@router.post("/craft/work")
def work_on_craft(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Work on active crafting contract. Uses cooldown system like all other actions.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Get active contract
    contract = get_active_workshop_contract(db, current_user.id)
    if not contract:
        raise HTTPException(status_code=400, detail="No active craft. Start one first!")
    
    item_config = CRAFTABLE_ITEMS.get(contract.type, {})
    
    # Calculate skill-adjusted cooldown
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    
    # Check and deduct food cost
    food_result = check_and_deduct_food_cost(db, current_user.id, cooldown_minutes, "crafting")
    if not food_result["success"]:
        raise HTTPException(status_code=400, detail=food_result["error"])
    
    # Cooldown check
    if not DEV_MODE:
        cooldown_result = check_and_set_slot_cooldown_atomic(
            db, current_user.id,
            action_type="workshop_craft",
            cooldown_minutes=cooldown_minutes,
            expires_at=cooldown_expires
        )
        
        if not cooldown_result["ready"]:
            remaining = cooldown_result["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            raise HTTPException(
                status_code=429,
                detail=f"Crafting on cooldown. Wait {minutes}m {seconds}s."
            )
    else:
        set_cooldown(db, current_user.id, "workshop_craft", cooldown_expires)
    
    # Add contribution
    xp_earned = 15
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id,
        xp_earned=xp_earned
    )
    db.add(contribution)
    state.experience += xp_earned
    
    # Count actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar() + 1  # +1 for the one we just added
    
    is_complete = actions_completed >= contract.actions_required
    new_item = None
    
    if is_complete:
        contract.completed_at = datetime.utcnow()
        
        # Create the item
        new_item = PlayerItem(
            user_id=current_user.id,
            item_id=contract.type,  # "fur_armor", "hunting_bow", etc.
            type=item_config.get("type", "weapon"),
            tier=item_config.get("tier", 1),
            attack_bonus=item_config.get("attack_bonus", 0),
            defense_bonus=item_config.get("defense_bonus", 0),
            is_equipped=False,
        )
        db.add(new_item)
        
        # Bonus XP for completion
        bonus_xp = 50
        xp_earned += bonus_xp
        state.experience += bonus_xp
    
    # Level up check
    xp_needed = 100 * (2 ** (state.level - 1))
    leveled_up = False
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 1
        leveled_up = True
    
    db.commit()
    
    if new_item:
        db.refresh(new_item)
    
    return {
        "success": True,
        "message": "Crafting progress!" + (" Item crafted!" if is_complete else ""),
        "contract_id": contract.id,
        "actions_completed": actions_completed,
        "actions_required": contract.actions_required,
        "progress_percent": int((actions_completed / contract.actions_required) * 100),
        "is_complete": is_complete,
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "food_cost": food_result["food_cost"],
        "food_remaining": food_result["food_remaining"],
        "xp_earned": xp_earned,
        "leveled_up": leveled_up,
        "item": {
            "id": new_item.id,
            "display_name": item_config.get("display_name", contract.type),
            "icon": item_config.get("icon", "hammer"),
            "color": item_config.get("color", "gray"),
            "type": new_item.type,
            "tier": new_item.tier,
            "attack_bonus": new_item.attack_bonus,
            "defense_bonus": new_item.defense_bonus,
        } if new_item else None,
    }


@router.get("/recipes")
def get_all_recipes():
    """Get all craftable item recipes (for reference)."""
    return {"craftable_items": CRAFTABLE_ITEMS}
