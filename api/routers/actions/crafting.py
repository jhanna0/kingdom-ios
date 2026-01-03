"""
Crafting system - Purchase and work on equipment crafting
Uses unified contract system and player_items table (no more JSONB!)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta

from db import get_db, User, Kingdom, UnifiedContract, ContractContribution, PlayerItem, Property
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import WORK_BASE_COOLDOWN


router = APIRouter()

# Crafting types
CRAFTING_TYPES = ["weapon", "armor"]


def get_craft_cost(tier: int) -> int:
    """Gold cost to start crafting"""
    costs = {1: 100, 2: 300, 3: 700, 4: 1500, 5: 3000}
    return costs.get(tier, 100)


def get_iron_required(tier: int) -> int:
    """Iron required for crafting"""
    requirements = {1: 10, 2: 20, 3: 0, 4: 0, 5: 10}
    return requirements.get(tier, 10)


def get_steel_required(tier: int) -> int:
    """Steel required for crafting"""
    requirements = {1: 0, 2: 0, 3: 10, 4: 20, 5: 10}
    return requirements.get(tier, 0)


def get_actions_required(tier: int) -> int:
    """Actions required to complete crafting"""
    requirements = {1: 1, 2: 3, 3: 7, 4: 14, 5: 30}
    return requirements.get(tier, 1)


def get_stat_bonus(tier: int) -> int:
    """Stat bonus from equipment (attack for weapons, defense for armor)"""
    bonuses = {1: 1, 2: 2, 3: 3, 4: 5, 5: 8}
    return bonuses.get(tier, 1)


@router.get("/craft/costs")
def get_crafting_costs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get crafting costs and requirements for all tiers"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    costs = {}
    for tier in range(1, 6):
        costs[f"tier_{tier}"] = {
            "gold": get_craft_cost(tier),
            "iron": get_iron_required(tier),
            "steel": get_steel_required(tier),
            "actions_required": get_actions_required(tier),
            "stat_bonus": get_stat_bonus(tier)
        }
    
    return {
        "costs": costs,
        "player_resources": {
            "gold": state.gold,
            "iron": state.iron,
            "steel": state.steel
        }
    }


@router.get("/craft/contracts")
def get_crafting_contracts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's crafting contracts"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    contracts = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type.in_(CRAFTING_TYPES)
    ).order_by(UnifiedContract.created_at.desc()).all()
    
    result = []
    for contract in contracts:
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id
        ).scalar()
        
        result.append({
            "id": str(contract.id),
            "equipment_type": contract.type,
            "tier": contract.tier,
            "actions_required": contract.actions_required,
            "actions_completed": actions_completed,
            "status": contract.status,
            "gold_paid": contract.gold_paid,
            "iron_paid": contract.iron_paid,
            "steel_paid": contract.steel_paid,
            "created_at": contract.created_at.isoformat() if contract.created_at else None,
            "completed_at": contract.completed_at.isoformat() if contract.completed_at else None
        })
    
    return {"contracts": result}


@router.post("/craft/purchase")
def purchase_craft(
    equipment_type: str,
    tier: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a crafting contract"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate equipment type
    if equipment_type not in CRAFTING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid equipment type. Must be one of: {', '.join(CRAFTING_TYPES)}"
        )
    
    # Validate tier
    if tier < 1 or tier > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tier must be between 1 and 5"
        )
    
    # CHECK WORKSHOP REQUIREMENT (Property Tier 3+)
    workshop_property = db.query(Property).filter(
        Property.owner_id == current_user.id,
        Property.tier >= 3
    ).first()
    
    if not workshop_property:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You need a Workshop (Property Tier 3+) to craft equipment. Purchase and upgrade property first."
        )
    
    # Calculate costs
    gold_cost = get_craft_cost(tier)
    iron_required = get_iron_required(tier)
    steel_required = get_steel_required(tier)
    actions_required = get_actions_required(tier)
    
    # Check resources
    if state.gold < gold_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {gold_cost}g, have {state.gold}g"
        )
    
    if state.iron < iron_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough iron. Need {iron_required}, have {state.iron}"
        )
    
    if state.steel < steel_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough steel. Need {steel_required}, have {state.steel}"
        )
    
    # Check if already have active crafting contract
    active_contract = db.query(UnifiedContract).filter(
        UnifiedContract.user_id == current_user.id,
        UnifiedContract.type.in_(CRAFTING_TYPES),
        UnifiedContract.status == 'in_progress'
    ).first()
    
    if active_contract:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You must complete your current {active_contract.type} tier {active_contract.tier} craft before starting a new one"
        )
    
    # Create the contract
    contract = UnifiedContract(
        user_id=current_user.id,
        type=equipment_type,
        tier=tier,
        actions_required=actions_required,
        gold_paid=gold_cost,
        iron_paid=iron_required,
        steel_paid=steel_required,
        status='in_progress',
        kingdom_id=state.current_kingdom_id
    )
    db.add(contract)
    
    # Spend resources
    state.gold -= gold_cost
    state.iron -= iron_required
    state.steel -= steel_required
    
    db.commit()
    db.refresh(contract)
    
    return {
        "success": True,
        "message": f"Started crafting tier {tier} {equipment_type}! Complete {actions_required} actions to finish.",
        "equipment_type": equipment_type,
        "tier": tier,
        "contract_id": str(contract.id),
        "actions_required": actions_required,
        "stat_bonus": get_stat_bonus(tier)
    }


@router.post("/craft/{contract_id}")
def work_on_craft(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a crafting contract (2hr cooldown, reduced by building skill)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=work_cooldown)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to craft"
        )
    
    # Find the crafting contract
    contract = db.query(UnifiedContract).filter(
        UnifiedContract.id == contract_id,
        UnifiedContract.user_id == current_user.id
    ).first()
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Crafting contract not found"
        )
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Crafting contract already completed"
        )
    
    # Count current actions
    actions_completed = db.query(func.count(ContractContribution.id)).filter(
        ContractContribution.contract_id == contract.id
    ).scalar()
    
    if actions_completed >= contract.actions_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Crafting contract already has all required actions"
        )
    
    # Add contribution
    xp_earned = 15
    contribution = ContractContribution(
        contract_id=contract.id,
        user_id=current_user.id,
        xp_earned=xp_earned
    )
    db.add(contribution)
    
    # Update cooldown in action_cooldowns table
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=cooldown_minutes)
    set_cooldown(db, current_user.id, "crafting", cooldown_expires)
    state.experience += xp_earned
    
    # Check if complete
    new_actions_completed = actions_completed + 1
    is_complete = new_actions_completed >= contract.actions_required
    
    new_item = None
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Create the item in player_items table
        stat_bonus = get_stat_bonus(contract.tier)
        new_item = PlayerItem(
            user_id=current_user.id,
            type=contract.type,
            tier=contract.tier,
            attack_bonus=stat_bonus if contract.type == "weapon" else 0,
            defense_bonus=stat_bonus if contract.type == "armor" else 0,
            is_equipped=False
        )
        db.add(new_item)
        
        # Bonus XP
        bonus_xp = 50
        xp_earned += bonus_xp
        state.experience += bonus_xp
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 1
    
    db.commit()
    
    if new_item:
        db.refresh(new_item)
    
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    return {
        "success": True,
        "message": "Crafting action completed!" + (" - Equipment crafted!" if is_complete else ""),
        "contract_id": str(contract.id),
        "actions_completed": new_actions_completed,
        "actions_required": contract.actions_required,
        "progress_percent": int((new_actions_completed / contract.actions_required) * 100),
        "is_complete": is_complete,
        "next_craft_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "rewards": {
            "xp": xp_earned,
            "equipment": {
                "id": new_item.id,
                "type": new_item.type,
                "tier": new_item.tier,
                "attack_bonus": new_item.attack_bonus,
                "defense_bonus": new_item.defense_bonus
            } if new_item else None
        }
    }


@router.get("/inventory")
def get_inventory(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get player's inventory from player_items table"""
    items = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id
    ).order_by(PlayerItem.crafted_at.desc()).all()
    
    return {
        "items": [
            {
                "id": item.id,
                "type": item.type,
                "tier": item.tier,
                "attack_bonus": item.attack_bonus,
                "defense_bonus": item.defense_bonus,
                "is_equipped": item.is_equipped,
                "crafted_at": item.crafted_at.isoformat() if item.crafted_at else None
            }
            for item in items
        ]
    }


@router.post("/equip/{item_id}")
def equip_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Equip an item from inventory"""
    # Find the item
    item = db.query(PlayerItem).filter(
        PlayerItem.id == item_id,
        PlayerItem.user_id == current_user.id
    ).first()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found in inventory"
        )
    
    if item.is_equipped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Item is already equipped"
        )
    
    # Unequip any currently equipped item of same type
    currently_equipped = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.type == item.type,
        PlayerItem.is_equipped == True
    ).first()
    
    if currently_equipped:
        currently_equipped.is_equipped = False
    
    # Equip the new item
    item.is_equipped = True
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Equipped tier {item.tier} {item.type}",
        "equipped": {
            "id": item.id,
            "type": item.type,
            "tier": item.tier,
            "attack_bonus": item.attack_bonus,
            "defense_bonus": item.defense_bonus
        }
    }


@router.post("/unequip/{item_id}")
def unequip_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Unequip an item"""
    item = db.query(PlayerItem).filter(
        PlayerItem.id == item_id,
        PlayerItem.user_id == current_user.id
    ).first()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found"
        )
    
    if not item.is_equipped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Item is not equipped"
        )
    
    item.is_equipped = False
    db.commit()
    
    return {
        "success": True,
        "message": f"Unequipped {item.type}"
    }


@router.get("/equipped")
def get_equipped_items(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get currently equipped items"""
    equipped = db.query(PlayerItem).filter(
        PlayerItem.user_id == current_user.id,
        PlayerItem.is_equipped == True
    ).all()
    
    result = {
        "weapon": None,
        "armor": None
    }
    
    for item in equipped:
        result[item.type] = {
            "id": item.id,
            "type": item.type,
            "tier": item.tier,
            "attack_bonus": item.attack_bonus,
            "defense_bonus": item.defense_bonus
        }
    
    return result
