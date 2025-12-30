"""
Crafting system - Purchase and work on equipment crafting
Similar to training system but costs gold + resources (iron/steel)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import uuid
import json

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, check_global_action_cooldown, format_datetime_iso, calculate_cooldown
from .constants import WORK_BASE_COOLDOWN


router = APIRouter()


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


@router.post("/craft/purchase")
def purchase_craft(
    equipment_type: str,  # "weapon" or "armor"
    tier: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Purchase a crafting contract
    
    Args:
        equipment_type: "weapon" or "armor"
        tier: 1-5
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate equipment type
    valid_types = ["weapon", "armor"]
    if equipment_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid equipment type. Must be one of: {', '.join(valid_types)}"
        )
    
    # Validate tier
    if tier < 1 or tier > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tier must be between 1 and 5"
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
    crafting_queue = state.crafting_queue or []
    for item in crafting_queue:
        if isinstance(item, dict) and item.get("status") != "completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You must complete your current {item.get('equipment_type')} tier {item.get('tier')} craft before starting a new one"
            )
    
    # Create crafting contract
    contract_id = str(uuid.uuid4())
    new_craft = {
        "id": contract_id,
        "equipment_type": equipment_type,
        "tier": tier,
        "actions_required": actions_required,
        "actions_completed": 0,
        "gold_paid": gold_cost,
        "iron_paid": iron_required,
        "steel_paid": steel_required,
        "created_at": datetime.utcnow().isoformat(),
        "status": "in_progress"
    }
    
    # Spend resources and add contract
    state.gold -= gold_cost
    state.iron -= iron_required
    state.steel -= steel_required
    crafting_queue.append(new_craft)
    state.crafting_queue = crafting_queue
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Started crafting tier {tier} {equipment_type}! Complete {actions_required} actions to finish.",
        "equipment_type": equipment_type,
        "tier": tier,
        "contract_id": contract_id,
        "actions_required": actions_required,
        "stat_bonus": get_stat_bonus(tier)
    }


@router.post("/craft/{contract_id}")
def work_on_craft(
    contract_id: str,
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
        global_cooldown = check_global_action_cooldown(state, work_cooldown=work_cooldown)
        
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
    crafting_queue = state.crafting_queue or []
    contract = None
    contract_index = None
    for i, c in enumerate(crafting_queue):
        if isinstance(c, dict) and c.get("id") == contract_id:
            contract = c
            contract_index = i
            break
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Crafting contract not found"
        )
    
    if contract.get("status") == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Crafting contract already completed"
        )
    
    # Increment actions completed
    contract["actions_completed"] = contract.get("actions_completed", 0) + 1
    state.last_crafting_action = datetime.utcnow()
    
    # Check if craft is complete
    is_complete = contract["actions_completed"] >= contract["actions_required"]
    
    # Award XP for each action
    xp_earned = 15  # 15 XP per crafting action
    state.experience += xp_earned
    
    if is_complete:
        contract["status"] = "completed"
        contract["completed_at"] = datetime.utcnow().isoformat()
        
        # Add equipment to inventory
        equipment_type = contract["equipment_type"]
        tier = contract["tier"]
        stat_bonus = get_stat_bonus(tier)
        
        inventory = state.inventory or []
        new_equipment = {
            "id": str(uuid.uuid4()),
            "type": equipment_type,
            "tier": tier,
            "attack_bonus": stat_bonus if equipment_type == "weapon" else 0,
            "defense_bonus": stat_bonus if equipment_type == "armor" else 0,
            "crafted_at": datetime.utcnow().isoformat()
        }
        inventory.append(new_equipment)
        state.inventory = inventory
        
        # Bonus XP for completing craft
        xp_earned += 50  # Total 65 XP when complete
        state.experience += 50
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 1
    
    # Update state
    crafting_queue[contract_index] = contract
    state.crafting_queue = crafting_queue
    
    db.commit()
    
    cooldown_minutes = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
    
    return {
        "success": True,
        "message": "Crafting action completed!" + (" - Equipment crafted!" if is_complete else ""),
        "contract_id": contract_id,
        "actions_completed": contract["actions_completed"],
        "actions_required": contract["actions_required"],
        "progress_percent": int((contract["actions_completed"] / contract["actions_required"]) * 100),
        "is_complete": is_complete,
        "next_craft_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "rewards": {
            "xp": xp_earned,
            "equipment": new_equipment if is_complete else None
        }
    }


@router.post("/equip/{equipment_id}")
def equip_item(
    equipment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Equip an item from inventory"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Find equipment in inventory
    inventory = state.inventory or []
    equipment = None
    equipment_index = None
    for i, item in enumerate(inventory):
        if isinstance(item, dict) and item.get("id") == equipment_id:
            equipment = item
            equipment_index = i
            break
    
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Equipment not found in inventory"
        )
    
    equipment_type = equipment.get("type")
    
    # Unequip current item of same type if exists
    if equipment_type == "weapon" and state.equipped_weapon:
        inventory.append(state.equipped_weapon)
    elif equipment_type == "armor" and state.equipped_armor:
        inventory.append(state.equipped_armor)
    
    # Equip new item
    if equipment_type == "weapon":
        state.equipped_weapon = equipment
    elif equipment_type == "armor":
        state.equipped_armor = equipment
    
    # Remove from inventory
    inventory.pop(equipment_index)
    state.inventory = inventory
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Equipped tier {equipment.get('tier')} {equipment_type}",
        "equipped": equipment
    }


@router.post("/unequip/{equipment_type}")
def unequip_item(
    equipment_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Unequip an item and return it to inventory"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if equipment_type not in ["weapon", "armor"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid equipment type"
        )
    
    inventory = state.inventory or []
    
    if equipment_type == "weapon":
        if not state.equipped_weapon:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No weapon equipped"
            )
        inventory.append(state.equipped_weapon)
        state.equipped_weapon = None
    elif equipment_type == "armor":
        if not state.equipped_armor:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No armor equipped"
            )
        inventory.append(state.equipped_armor)
        state.equipped_armor = None
    
    state.inventory = inventory
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Unequipped {equipment_type}"
    }

