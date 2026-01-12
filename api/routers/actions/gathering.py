"""
Resource Gathering action - Click to gather wood/iron
No backend cooldown - frontend handles 0.5s tap cooldown
"""
from fastapi import APIRouter, HTTPException, Depends, status, Query
from sqlalchemy.orm import Session

from db import get_db, User
from routers.auth import get_current_user
from systems.gathering import GatherManager, GatherConfig
from .utils import log_activity

router = APIRouter()

# Singleton manager
_gather_manager = GatherManager()


@router.post("/gather")
def gather_resource(
    resource_type: str = Query(..., description="Resource type: 'wood' or 'iron'"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Gather a resource (wood or iron).
    
    NO BACKEND COOLDOWN - this is meant to be clicked rapidly.
    Frontend handles 0.5s cooldown to prevent spam.
    
    Returns tier (black/brown/green/gold) and amount gathered (0-3).
    Resources are automatically added to player inventory.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate resource type
    resource_config = GatherConfig.get_resource(resource_type)
    if not resource_config:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid resource type: {resource_type}. Must be 'wood' or 'iron'."
        )
    
    # Get current amount of this resource
    player_field = resource_config["player_field"]
    current_amount = getattr(state, player_field, 0)
    
    # Execute gather roll
    result = _gather_manager.gather(resource_type, current_amount)
    
    # Add gathered resources to player's inventory
    if result.amount > 0:
        setattr(state, player_field, result.new_total)
        
        # Log activity only if we gathered something
        log_activity(
            db=db,
            user_id=current_user.id,
            action_type=f"gather_{resource_type}",
            action_category="gathering",
            description=f"Gathered {resource_type}",
            kingdom_id=state.current_kingdom_id,
            amount=result.amount,
            details={
                "tier": result.tier,
                "amount": result.amount,
                "new_total": result.new_total,
            }
        )
    
    db.commit()
    
    return result.to_dict()


@router.get("/gather/config")
def get_gather_config(
    current_user: User = Depends(get_current_user),
):
    """
    Get gathering configuration for frontend display.
    Includes resource types and tier probabilities.
    """
    return {
        "resources": GatherConfig.get_all_resources(),
        "tiers": GatherConfig.get_tier_display_info(),
    }
