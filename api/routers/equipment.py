"""
Equipment endpoints - view and equip weapons/armor
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session

from db import get_db, User, PlayerItem
from routers.auth import get_current_user
from routers.workshop import CRAFTABLE_ITEMS

router = APIRouter(prefix="/equipment", tags=["equipment"])


def item_to_dict(item: PlayerItem) -> dict:
    """Convert PlayerItem to response dict"""
    item_config = CRAFTABLE_ITEMS.get(item.item_id, {}) if item.item_id else {}
    display_name = item_config.get("display_name") if item_config else f"Tier {item.tier} {item.type.title()}"
    return {
        "id": item.id,
        "item_id": item.item_id,
        "display_name": display_name,
        "icon": item_config.get("icon", "shield.fill" if item.type == "armor" else "bolt.fill"),
        "type": item.type,
        "tier": item.tier,
        "attack_bonus": item.attack_bonus,
        "defense_bonus": item.defense_bonus,
    }


@router.get("")
def get_equipment(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get player's weapons and armor"""
    items = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id
    ).order_by(PlayerItem.crafted_at.desc()).all()
    
    equipped_weapon = None
    equipped_armor = None
    unequipped_weapons = []
    unequipped_armor = []
    
    for item in items:
        if item.type == "weapon":
            if item.is_equipped:
                equipped_weapon = item_to_dict(item)
            else:
                unequipped_weapons.append(item_to_dict(item))
        elif item.type == "armor":
            if item.is_equipped:
                equipped_armor = item_to_dict(item)
            else:
                unequipped_armor.append(item_to_dict(item))
    
    return {
        "equipped_weapon": equipped_weapon,
        "equipped_armor": equipped_armor,
        "unequipped_weapons": unequipped_weapons,
        "unequipped_armor": unequipped_armor,
    }


@router.post("/equip/{item_id}")
def equip_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Equip a weapon or armor"""
    item = db.query(PlayerItem).filter(
        PlayerItem.id == item_id,
        PlayerItem.user_id == current_user.id
    ).first()
    
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    if item.is_equipped:
        raise HTTPException(status_code=400, detail="Already equipped")
    
    # Unequip current item of same type
    db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.type == item.type,
        PlayerItem.is_equipped == True
    ).update({"is_equipped": False})
    
    item.is_equipped = True
    db.commit()
    
    return {"success": True, "equipped": item_to_dict(item)}


@router.post("/unequip/{item_id}")
def unequip_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Unequip a weapon or armor"""
    item = db.query(PlayerItem).filter(
        PlayerItem.id == item_id,
        PlayerItem.user_id == current_user.id
    ).first()
    
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    if not item.is_equipped:
        raise HTTPException(status_code=400, detail="Not equipped")
    
    item.is_equipped = False
    db.commit()
    
    return {"success": True}
