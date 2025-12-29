"""
Market endpoint - Purchase materials from kingdom market
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from db import get_db, User, Kingdom
from routers.auth import get_current_user


router = APIRouter(prefix="/market", tags=["market"])


class PurchaseMaterialRequest(BaseModel):
    material_type: str  # "stone", "iron", "steel", "titanium"
    quantity: int = 1


class PurchaseMaterialResponse(BaseModel):
    success: bool
    message: str
    material_type: str
    quantity_purchased: int
    gold_spent: int
    new_gold_balance: int
    new_material_balance: int


# Material costs (gold per unit)
MATERIAL_COSTS = {
    "stone": 10,
    "iron": 25,
    "steel": 50,
    "titanium": 100
}


def get_available_materials(mine_level: int) -> list[str]:
    """Get list of materials available based on mine level"""
    if mine_level == 0:
        return []
    elif mine_level == 1:
        return ["stone"]
    elif mine_level == 2:
        return ["stone", "iron"]
    elif mine_level == 3:
        return ["stone", "iron", "steel"]
    elif mine_level >= 4:
        return ["stone", "iron", "steel", "titanium"]
    return []


def get_purchase_multiplier(market_level: int, mine_level: int) -> float:
    """Get quantity multiplier based on market and mine levels"""
    # T5 Mine + any market = 2x quantity
    if mine_level >= 5:
        return 2.0
    
    # Otherwise, market level determines multiplier
    if market_level == 0:
        return 0.0  # No market = can't buy
    elif market_level in [1, 2]:
        return 1.0
    elif market_level in [3, 4]:
        return 1.5
    elif market_level >= 5:
        return 2.0
    return 1.0


@router.post("/purchase", response_model=PurchaseMaterialResponse)
def purchase_material(
    request: PurchaseMaterialRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase materials from the kingdom market"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if player is in a kingdom
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to purchase materials"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if market exists
    if kingdom.market_level < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This kingdom has no market. The ruler must build a market first."
        )
    
    # Validate material type
    material_type = request.material_type.lower()
    if material_type not in MATERIAL_COSTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid material type. Available: {', '.join(MATERIAL_COSTS.keys())}"
        )
    
    # Check if material is available based on mine level
    available_materials = get_available_materials(kingdom.mine_level)
    if material_type not in available_materials:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Material '{material_type}' not available. Kingdom mine level {kingdom.mine_level} only provides: {', '.join(available_materials) if available_materials else 'none'}"
        )
    
    # Calculate quantity with multiplier
    base_quantity = request.quantity
    multiplier = get_purchase_multiplier(kingdom.market_level, kingdom.mine_level)
    actual_quantity = int(base_quantity * multiplier)
    
    # Calculate cost (cost is per BASE quantity, not multiplied)
    unit_cost = MATERIAL_COSTS[material_type]
    total_cost = unit_cost * base_quantity
    
    # Check if player has enough gold
    if state.gold < total_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {total_cost}g, have {state.gold}g"
        )
    
    # Process purchase
    state.gold -= total_cost
    
    # Add materials to player inventory
    if material_type == "stone":
        if not hasattr(state, 'stone'):
            # If stone column doesn't exist yet, we'll need to add it via migration
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Stone resource not yet implemented in database"
            )
        state.stone += actual_quantity
        new_balance = state.stone
    elif material_type == "iron":
        state.iron += actual_quantity
        new_balance = state.iron
    elif material_type == "steel":
        state.steel += actual_quantity
        new_balance = state.steel
    elif material_type == "titanium":
        if not hasattr(state, 'titanium'):
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Titanium resource not yet implemented in database"
            )
        state.titanium += actual_quantity
        new_balance = state.titanium
    
    db.commit()
    
    return PurchaseMaterialResponse(
        success=True,
        message=f"Purchased {actual_quantity} {material_type} for {total_cost}g" + 
                (f" (x{multiplier} multiplier)" if multiplier > 1.0 else ""),
        material_type=material_type,
        quantity_purchased=actual_quantity,
        gold_spent=total_cost,
        new_gold_balance=state.gold,
        new_material_balance=new_balance
    )


@router.get("/info")
def get_market_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get market information for current kingdom"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    available_materials = get_available_materials(kingdom.mine_level)
    multiplier = get_purchase_multiplier(kingdom.market_level, kingdom.mine_level)
    
    materials_info = []
    for material in available_materials:
        materials_info.append({
            "type": material,
            "cost_per_unit": MATERIAL_COSTS[material],
            "quantity_per_purchase": int(1 * multiplier)
        })
    
    return {
        "kingdom_name": kingdom.name,
        "market_level": kingdom.market_level,
        "mine_level": kingdom.mine_level,
        "market_active": kingdom.market_level >= 1,
        "purchase_multiplier": multiplier,
        "available_materials": materials_info,
        "player_gold": state.gold,
        "player_resources": {
            "iron": state.iron,
            "steel": state.steel
        }
    }

