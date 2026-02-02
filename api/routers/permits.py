"""
Building Permits API
====================
Endpoints for checking and purchasing building permits in foreign kingdoms.

Permits allow visitors to use buildings (lumbermill, mine, market, townhall)
in kingdoms they don't live in and aren't allied with.

- 10 gold for 10 minutes of access
- Gold goes to kingdom treasury
- Free if allied or same empire
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from db import get_db, User, Kingdom
from routers.auth import get_current_user
from services.building_permit_service import (
    check_building_access,
    buy_permit,
    PERMIT_COST_GOLD,
    PERMIT_DURATION_MINUTES,
    PERMIT_REQUIRED_BUILDINGS,
)


router = APIRouter(prefix="/permits", tags=["permits"])


# ============================================================
# SCHEMAS
# ============================================================

class PermitStatusResponse(BaseModel):
    """Response for permit status check"""
    building_type: str
    can_access: bool
    reason: str
    is_hometown: bool
    is_allied: bool
    needs_permit: bool
    has_valid_permit: bool
    permit_expires_at: Optional[datetime] = None
    permit_minutes_remaining: int = 0
    
    # Blockers
    hometown_has_building: bool
    hometown_building_level: int
    has_active_catchup: bool
    catchup_actions_remaining: int = 0
    
    # Purchase info
    can_buy_permit: bool
    permit_cost: int
    permit_duration_minutes: int


class BuyPermitRequest(BaseModel):
    """Request to buy a permit"""
    kingdom_id: str
    building_type: str


class BuyPermitResponse(BaseModel):
    """Response after buying a permit"""
    success: bool
    message: str
    permit_expires_at: Optional[datetime] = None
    permit_minutes_remaining: int = 0
    gold_spent: int = 0
    player_gold: int = 0
    treasury_gold: int = 0


# ============================================================
# ENDPOINTS
# ============================================================

@router.get("/status/{kingdom_id}/{building_type}", response_model=PermitStatusResponse)
def get_permit_status(
    kingdom_id: str,
    building_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Check permit status for a building in a specific kingdom.
    
    Returns whether the player can access the building and why/why not.
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate building type
    building_type = building_type.lower()
    if building_type not in PERMIT_REQUIRED_BUILDINGS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Building type '{building_type}' doesn't require permits. Valid types: {', '.join(PERMIT_REQUIRED_BUILDINGS)}"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check access
    access = check_building_access(db, current_user, state, kingdom, building_type)
    
    return PermitStatusResponse(
        building_type=building_type,
        can_access=access["can_access"],
        reason=access["reason"],
        is_hometown=access["is_hometown"],
        is_allied=access["is_allied"],
        needs_permit=access["needs_permit"],
        has_valid_permit=access["has_valid_permit"],
        permit_expires_at=access["permit_expires_at"],
        permit_minutes_remaining=access["permit_minutes_remaining"],
        hometown_has_building=access["hometown_has_building"],
        hometown_building_level=access["hometown_building_level"],
        has_active_catchup=access["has_active_catchup"],
        catchup_actions_remaining=access["catchup_actions_remaining"],
        can_buy_permit=access["can_buy_permit"],
        permit_cost=access["permit_cost"],
        permit_duration_minutes=access["permit_duration_minutes"],
    )


@router.post("/buy", response_model=BuyPermitResponse)
def purchase_permit(
    request: BuyPermitRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Purchase a building permit.
    
    Costs 10 gold, lasts 10 minutes.
    Gold goes to kingdom treasury.
    
    Requirements:
    - Must have same building in hometown
    - Must not have active catchup for that building
    - Must have enough gold
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate building type
    building_type = request.building_type.lower()
    if building_type not in PERMIT_REQUIRED_BUILDINGS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Building type '{building_type}' doesn't require permits"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Must be in the kingdom to buy permit
    if state.current_kingdom_id != kingdom.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be in the kingdom to buy a permit"
        )
    
    # Try to buy permit
    success, message, permit = buy_permit(db, current_user, state, kingdom, building_type)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
    
    db.commit()
    
    return BuyPermitResponse(
        success=True,
        message=message,
        permit_expires_at=permit.expires_at if permit else None,
        permit_minutes_remaining=permit.minutes_remaining if permit else 0,
        gold_spent=PERMIT_COST_GOLD,
        player_gold=int(state.gold),
        treasury_gold=int(kingdom.treasury or 0),
    )


@router.get("/buildings")
def get_permit_buildings():
    """
    Get list of buildings that require permits for visitors.
    """
    return {
        "buildings": list(PERMIT_REQUIRED_BUILDINGS),
        "permit_cost": PERMIT_COST_GOLD,
        "permit_duration_minutes": PERMIT_DURATION_MINUTES,
    }
