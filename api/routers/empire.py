"""
Empire management endpoints - Aggregated empire view and treasury management

SERVER-DRIVEN UI: All display metadata (icons, colors, labels) defined here.
Frontend renders dynamically - NO hardcoded UI strings in iOS!

Endpoints:
- GET /empire/my-empire - Get full empire overview (kingdoms, treasury, wars, alliances)
- POST /empire/transfer-funds - Transfer gold between kingdoms you rule
- POST /empire/kingdoms/{kingdom_id}/treasury/withdraw - Withdraw from treasury to personal gold
- POST /empire/kingdoms/{kingdom_id}/treasury/deposit - Deposit personal gold to treasury
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import datetime, timezone

from db import get_db, User, Kingdom
from db.models.battle import Battle
from db.models.alliance import Alliance
from routers.auth import get_current_user
from routers.player import get_or_create_player_state
from routers.alliances import _get_player_empire_id, get_allied_empire_ids, _get_empire_name
from schemas.empire import (
    EmpireOverviewResponse,
    EmpireKingdomSummary,
    ActiveWarSummary,
    AllianceSummary,
    TransferFundsRequest,
    TransferFundsResponse,
    TreasuryWithdrawRequest,
    TreasuryWithdrawResponse,
    TreasuryDepositRequest,
    TreasuryDepositResponse,
    EmpireUIConfig,
    StatConfig,
    TreasuryActionConfig,
    SectionConfig,
    TreasuryLocationOption,
)


router = APIRouter(prefix="/empire", tags=["empire"])


# ===== SERVER-DRIVEN UI CONFIG =====
# All UI metadata defined here - frontend renders dynamically!
# Change these values and the app updates WITHOUT a new release
#
# COLOR VALUES: Use KingdomTheme color names (e.g., "imperialGold", "inkMedium")
# iOS uses KingdomTheme.Colors.color(fromThemeName:) to resolve these

EMPIRE_UI_CONFIG = {
    # Header section
    "header": {
        "icon": "crown.fill",
        "icon_color": "imperialGold",
        "subtitle_template": "Empire of {kingdom_count} Kingdom{plural}",
    },
    
    # Stats displayed in overview
    "stats": [
        {
            "id": "total_treasury",
            "label": "Total Treasury",
            "icon": "building.columns.fill",
            "color": "imperialGold",
            "format": "number",
        },
        {
            "id": "personal_gold",
            "label": "Personal Gold",
            "icon": "g.circle.fill",
            "color": "goldLight",
            "format": "number",
        },
        {
            "id": "total_subjects",
            "label": "Total Citizens",
            "icon": "person.3.fill",
            "color": "inkMedium",
            "format": "number",
        },
        {
            "id": "active_wars",
            "label": "Active Wars",
            "icon": "flag.2.crossed.fill",
            "color": "royalCrimson",
            "color_inactive": "inkLight",
            "format": "number",
        },
        {
            "id": "alliance_count",
            "label": "Alliances",
            "icon": "person.2.fill",
            "color": "inkMedium",
            "format": "number",
        },
    ],
    
    # Sections in the empire view
    "sections": {
        "wars": {
            "title": "Active Wars",
            "icon": "flag.2.crossed.fill",
            "color": "royalCrimson",
            "empty_message": None,
            "attacking_icon": "arrow.right.circle.fill",
            "defending_icon": "shield.fill",
            "attacking_color": "royalCrimson",
            "defending_color": "inkMedium",
        },
        "alliances": {
            "title": "Alliances",
            "icon": "handshake.fill",
            "color": "royalEmerald",
            "empty_message": None,
            "ally_icon": "handshake.fill",
            "days_label": "days remaining",
            "kingdoms_label": "kingdoms",
        },
        "kingdoms": {
            "title": "Your Kingdoms",
            "icon": "map.fill",
            "color": "inkMedium",
            "capital_badge": "Capital",
            "capital_icon": "star.fill",
            "capital_color": "imperialGold",
        },
    },
    
    # Kingdom card stats
    "kingdom_stats": [
        {"id": "treasury", "icon": "building.columns.fill", "label": "Treasury", "color": "inkMedium", "format": "number"},
        {"id": "subjects", "icon": "person.3.fill", "label": "Citizens", "color": "inkMedium", "format": "number"},
        {"id": "tax_rate", "icon": "percent", "label": "Tax", "color": "inkMedium", "format": "number", "suffix": "%"},
    ],
    
    # Kingdom card actions
    "kingdom_actions": [
        {"id": "treasury", "label": "Treasury", "icon": "banknote.fill", "color": "imperialGold"},
        {"id": "manage", "label": "Manage", "icon": "gearshape.fill", "color": "buttonPrimary"},
    ],
    
    # Treasury location toggles
    "treasury_allow_personal": False,  # Allow withdraw/deposit to ruler's personal gold
    "treasury_allow_transfers": True,   # Allow transfers between kingdom treasuries
    
    # Treasury management actions (legacy, kept for reference)
    "treasury_actions": [
        {
            "id": "withdraw",
            "label": "Withdraw",
            "icon": "arrow.down.circle.fill",
            "description": "Move gold from treasury to your personal wallet",
            "source": "treasury",
            "target": "personal",
        },
        {
            "id": "deposit",
            "label": "Deposit",
            "icon": "arrow.up.circle.fill",
            "description": "Move gold from your wallet to the treasury",
            "source": "personal",
            "target": "treasury",
        },
        {
            "id": "transfer",
            "label": "Transfer",
            "icon": "arrow.left.arrow.right.circle.fill",
            "description": "Move gold between kingdom treasuries",
            "source": "treasury",
            "target": "other_kingdom",
            "requires_multiple_kingdoms": True,
        },
    ],
    
    # Quick amount buttons
    "quick_amounts": [100, 500, 1000],
    "quick_max_label": "Max",
    
    # Messages
    "messages": {
        "no_empire_title": "No Empire Yet",
        "no_empire_subtitle": "Conquer a kingdom to establish your empire!",
        "no_empire_icon": "crown.fill",
        "loading": "Loading Empire...",
        "error_title": "Error",
        "error_retry": "Retry",
        "transfer_no_kingdoms": "You need to rule more than one kingdom to transfer funds",
    },
}


# ===== Helper Functions =====

def _build_ui_config() -> dict:
    """Build the UI config dict from EMPIRE_UI_CONFIG for the response"""
    cfg = EMPIRE_UI_CONFIG
    
    return {
        # Header
        "header_icon": cfg["header"]["icon"],
        "header_icon_color": cfg["header"]["icon_color"],
        "subtitle_template": cfg["header"]["subtitle_template"],
        
        # Stats
        "stats": cfg["stats"],
        
        # Wars section
        "wars_section": {
            "title": cfg["sections"]["wars"]["title"],
            "icon": cfg["sections"]["wars"]["icon"],
            "color": cfg["sections"]["wars"]["color"],
            "empty_message": cfg["sections"]["wars"].get("empty_message"),
        },
        "wars_attacking_icon": cfg["sections"]["wars"]["attacking_icon"],
        "wars_defending_icon": cfg["sections"]["wars"]["defending_icon"],
        "wars_attacking_color": cfg["sections"]["wars"]["attacking_color"],
        "wars_defending_color": cfg["sections"]["wars"]["defending_color"],
        
        # Alliances section
        "alliances_section": {
            "title": cfg["sections"]["alliances"]["title"],
            "icon": cfg["sections"]["alliances"]["icon"],
            "color": cfg["sections"]["alliances"]["color"],
            "empty_message": cfg["sections"]["alliances"].get("empty_message"),
        },
        "alliances_ally_icon": cfg["sections"]["alliances"]["ally_icon"],
        "alliances_days_label": cfg["sections"]["alliances"]["days_label"],
        "alliances_kingdoms_label": cfg["sections"]["alliances"]["kingdoms_label"],
        
        # Kingdoms section
        "kingdoms_section": {
            "title": cfg["sections"]["kingdoms"]["title"],
            "icon": cfg["sections"]["kingdoms"]["icon"],
            "color": cfg["sections"]["kingdoms"]["color"],
            "empty_message": cfg["sections"]["kingdoms"].get("empty_message"),
        },
        "kingdoms_capital_badge": cfg["sections"]["kingdoms"]["capital_badge"],
        "kingdoms_capital_icon": cfg["sections"]["kingdoms"]["capital_icon"],
        "kingdoms_capital_color": cfg["sections"]["kingdoms"]["capital_color"],
        
        # Kingdom card
        "kingdom_stats": cfg["kingdom_stats"],
        "kingdom_actions": cfg["kingdom_actions"],
        
        # Treasury management (options are now per-kingdom in kingdom summaries)
        "treasury_actions": cfg["treasury_actions"],
        "quick_amounts": cfg["quick_amounts"],
        "quick_max_label": cfg["quick_max_label"],
        
        # Messages
        "no_empire_title": cfg["messages"]["no_empire_title"],
        "no_empire_subtitle": cfg["messages"]["no_empire_subtitle"],
        "no_empire_icon": cfg["messages"]["no_empire_icon"],
        "loading_message": cfg["messages"]["loading"],
        "error_title": cfg["messages"]["error_title"],
        "error_retry": cfg["messages"]["error_retry"],
        "transfer_no_kingdoms_message": cfg["messages"]["transfer_no_kingdoms"],
    }


def _get_ruled_kingdoms(db: Session, user: User) -> list[Kingdom]:
    """Get all kingdoms ruled by this user"""
    return db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()


def _get_empire_kingdoms(db: Session, empire_id: str) -> list[Kingdom]:
    """Get all kingdoms belonging to an empire"""
    return db.query(Kingdom).filter(
        or_(Kingdom.empire_id == empire_id, Kingdom.id == empire_id)
    ).all()


def _get_active_wars_for_empire(db: Session, empire_id: str, kingdom_ids: list[str]) -> list[dict]:
    """Get all active wars (invasions) for an empire"""
    now = datetime.now(timezone.utc)
    
    # Get active battles (not resolved) that involve our kingdoms
    active_battles = db.query(Battle).filter(
        Battle.resolved_at.is_(None),
        Battle.type == "invasion",
        or_(
            Battle.kingdom_id.in_(kingdom_ids),  # We're defending
            Battle.attacking_from_kingdom_id.in_(kingdom_ids)  # We're attacking
        )
    ).all()
    
    wars = []
    for battle in active_battles:
        # Determine if we're attacking or defending
        is_attacking = battle.attacking_from_kingdom_id in kingdom_ids
        
        # Get kingdom names
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == battle.kingdom_id).first()
        target_name = target_kingdom.name if target_kingdom else battle.kingdom_id
        
        attacking_name = None
        if battle.attacking_from_kingdom_id:
            attacking_kingdom = db.query(Kingdom).filter(
                Kingdom.id == battle.attacking_from_kingdom_id
            ).first()
            attacking_name = attacking_kingdom.name if attacking_kingdom else battle.attacking_from_kingdom_id
        
        # Determine phase
        if battle.pledge_end_time:
            pledge_end_aware = battle.pledge_end_time.replace(tzinfo=timezone.utc) if battle.pledge_end_time.tzinfo is None else battle.pledge_end_time
            phase = "pledge" if now < pledge_end_aware else "battle"
        else:
            phase = "battle"
        
        wars.append({
            "battle_id": battle.id,
            "type": "attacking" if is_attacking else "defending",
            "target_kingdom_id": battle.kingdom_id,
            "target_kingdom_name": target_name,
            "attacking_from_kingdom_id": battle.attacking_from_kingdom_id,
            "attacking_from_kingdom_name": attacking_name,
            "initiator_name": battle.initiator_name,
            "pledge_end_time": battle.pledge_end_time,
            "phase": phase,
            "attacker_count": len(battle.attackers or []),
            "defender_count": len(battle.defenders or []),
        })
    
    return wars


def _get_alliances_for_empire(db: Session, empire_id: str) -> list[dict]:
    """Get all active alliances for an empire"""
    now = datetime.now(timezone.utc)
    
    alliances = db.query(Alliance).filter(
        Alliance.status == "active",
        or_(
            Alliance.initiator_empire_id == empire_id,
            Alliance.target_empire_id == empire_id
        )
    ).all()
    
    result = []
    for alliance in alliances:
        # Determine which side is the ally
        if alliance.initiator_empire_id == empire_id:
            allied_empire_id = alliance.target_empire_id
        else:
            allied_empire_id = alliance.initiator_empire_id
        
        # Get allied empire name and kingdom count
        allied_name = _get_empire_name(db, allied_empire_id)
        allied_kingdoms = _get_empire_kingdoms(db, allied_empire_id)
        
        # Calculate days remaining
        days_remaining = 0
        if alliance.expires_at:
            expires_aware = alliance.expires_at.replace(tzinfo=timezone.utc) if alliance.expires_at.tzinfo is None else alliance.expires_at
            delta = expires_aware - now
            days_remaining = max(0, delta.days)
        
        result.append({
            "alliance_id": alliance.id,
            "allied_empire_id": allied_empire_id,
            "allied_empire_name": allied_name,
            "allied_kingdom_count": len(allied_kingdoms),
            "expires_at": alliance.expires_at,
            "days_remaining": days_remaining,
        })
    
    return result


# ===== Endpoints =====

@router.get("/my-empire", response_model=EmpireOverviewResponse)
async def get_my_empire(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get full empire overview for the current ruler.
    
    Returns aggregated stats across all kingdoms in your empire,
    active wars (invasions), and alliances.
    
    Requires: Must rule at least one kingdom
    """
    state = get_or_create_player_state(db, current_user)
    
    # Get player's empire ID
    empire_id = _get_player_empire_id(db, current_user, state)
    if not empire_id:
        raise HTTPException(
            status_code=400,
            detail="You must rule a kingdom to view your empire"
        )
    
    # Get all kingdoms in the empire
    kingdoms = _get_empire_kingdoms(db, empire_id)
    if not kingdoms:
        raise HTTPException(
            status_code=404,
            detail="No kingdoms found in your empire"
        )
    
    # Find capital (the kingdom with id == empire_id, or first one)
    capital = next((k for k in kingdoms if k.id == empire_id), kingdoms[0])
    
    # Get kingdom IDs for war queries
    kingdom_ids = [k.id for k in kingdoms]
    
    # Aggregate stats
    total_treasury = sum(int(k.treasury_gold or 0) for k in kingdoms)
    total_subjects = sum(k.checked_in_players or 0 for k in kingdoms)
    
    # Build kingdom summaries with treasury options
    cfg = EMPIRE_UI_CONFIG
    kingdom_summaries = []
    for k in kingdoms:
        # Build FROM options for this kingdom
        from_options = []
        if cfg["treasury_allow_personal"]:
            from_options.append(TreasuryLocationOption(
                id="personal",
                type="personal",
                label="Your Gold",
                icon="person.fill",
                balance=state.gold or 0,
            ))
        from_options.append(TreasuryLocationOption(
            id=k.id,
            type="current_kingdom",
            label=k.name,
            icon="building.columns.fill",
            balance=int(k.treasury_gold or 0),
        ))
        
        # Build TO options for this kingdom
        to_options = []
        if cfg["treasury_allow_personal"]:
            to_options.append(TreasuryLocationOption(
                id="personal",
                type="personal",
                label="Your Gold",
                icon="person.fill",
                balance=state.gold or 0,
            ))
        to_options.append(TreasuryLocationOption(
            id=k.id,
            type="current_kingdom",
            label=k.name,
            icon="building.columns.fill",
            balance=int(k.treasury_gold or 0),
        ))
        # Add other kingdoms as TO options
        if cfg["treasury_allow_transfers"]:
            for other in kingdoms:
                if other.id != k.id:
                    to_options.append(TreasuryLocationOption(
                        id=other.id,
                        type="other_kingdom",
                        label=other.name,
                        icon="building.columns",
                        balance=int(other.treasury_gold or 0),
                    ))
        
        kingdom_summaries.append(EmpireKingdomSummary(
            id=k.id,
            name=k.name,
            treasury_gold=int(k.treasury_gold or 0),
            tax_rate=k.tax_rate or 10,
            travel_fee=k.travel_fee or 10,
            checked_in_players=k.checked_in_players or 0,
            wall_level=k.get_building_level("wall") or k.wall_level or 0,
            vault_level=k.get_building_level("vault") or k.vault_level or 0,
            is_capital=(k.id == empire_id),
            ruler_started_at=k.ruler_started_at,
            treasury_from_options=from_options,
            treasury_to_options=to_options,
        ))
    
    # Sort: capital first, then by treasury
    kingdom_summaries.sort(key=lambda x: (not x.is_capital, -x.treasury_gold))
    
    # Get active wars
    wars = _get_active_wars_for_empire(db, empire_id, kingdom_ids)
    war_summaries = [ActiveWarSummary(**w) for w in wars]
    wars_attacking = sum(1 for w in wars if w["type"] == "attacking")
    wars_defending = sum(1 for w in wars if w["type"] == "defending")
    
    # Get alliances
    alliances = _get_alliances_for_empire(db, empire_id)
    alliance_summaries = [AllianceSummary(**a) for a in alliances]
    
    return EmpireOverviewResponse(
        empire_id=empire_id,
        empire_name=capital.name,
        total_treasury=total_treasury,
        total_subjects=total_subjects,
        kingdom_count=len(kingdoms),
        personal_gold=state.gold or 0,
        kingdoms=kingdom_summaries,
        active_wars=war_summaries,
        wars_attacking=wars_attacking,
        wars_defending=wars_defending,
        alliances=alliance_summaries,
        alliance_count=len(alliances),
        ui_config=_build_ui_config(),
    )


@router.post("/transfer-funds", response_model=TransferFundsResponse)
async def transfer_funds(
    request: TransferFundsRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Transfer gold from one kingdom's treasury to another.
    
    Requirements:
    - Must be the ruler of BOTH kingdoms
    - Source kingdom must have sufficient treasury
    - Amount must be positive
    """
    # Validate amount
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    # Get source kingdom
    source = db.query(Kingdom).filter(Kingdom.id == request.source_kingdom_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source kingdom not found")
    
    # Get target kingdom
    target = db.query(Kingdom).filter(Kingdom.id == request.target_kingdom_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target kingdom not found")
    
    # Verify ruler of source
    if source.ruler_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="You must be the ruler of the source kingdom"
        )
    
    # Verify ruler of target
    if target.ruler_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="You must be the ruler of the target kingdom"
        )
    
    # Check source has enough
    source_treasury = int(source.treasury_gold or 0)
    if source_treasury < request.amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient treasury. {source.name} only has {source_treasury} gold."
        )
    
    # Perform transfer
    source.treasury_gold = (source.treasury_gold or 0) - request.amount
    target.treasury_gold = (target.treasury_gold or 0) + request.amount
    
    db.commit()
    db.refresh(source)
    db.refresh(target)
    
    return TransferFundsResponse(
        success=True,
        message=f"Transferred {request.amount} gold from {source.name} to {target.name}",
        amount_transferred=request.amount,
        source_kingdom_id=source.id,
        source_kingdom_name=source.name,
        source_treasury_remaining=int(source.treasury_gold or 0),
        target_kingdom_id=target.id,
        target_kingdom_name=target.name,
        target_treasury_new=int(target.treasury_gold or 0),
    )


@router.post("/kingdoms/{kingdom_id}/treasury/withdraw", response_model=TreasuryWithdrawResponse)
async def withdraw_from_treasury(
    kingdom_id: str,
    request: TreasuryWithdrawRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Withdraw gold from kingdom treasury to personal wallet.
    
    Requirements:
    - Must be the ruler of the kingdom
    - Kingdom must have sufficient treasury
    """
    # Validate amount
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    # Verify ruler
    if kingdom.ruler_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the ruler can withdraw from the treasury"
        )
    
    # Check treasury has enough
    treasury = int(kingdom.treasury_gold or 0)
    if treasury < request.amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient treasury. Only {treasury} gold available."
        )
    
    # Get player state
    state = get_or_create_player_state(db, current_user)
    
    # Perform withdrawal
    kingdom.treasury_gold = (kingdom.treasury_gold or 0) - request.amount
    state.gold = (state.gold or 0) + request.amount
    
    db.commit()
    db.refresh(kingdom)
    db.refresh(state)
    
    return TreasuryWithdrawResponse(
        success=True,
        message=f"Withdrew {request.amount} gold from {kingdom.name}'s treasury",
        amount_withdrawn=request.amount,
        kingdom_id=kingdom.id,
        kingdom_name=kingdom.name,
        treasury_remaining=int(kingdom.treasury_gold or 0),
        personal_gold_new=state.gold or 0,
    )


@router.post("/kingdoms/{kingdom_id}/treasury/deposit", response_model=TreasuryDepositResponse)
async def deposit_to_treasury(
    kingdom_id: str,
    request: TreasuryDepositRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Deposit personal gold into kingdom treasury.
    
    Requirements:
    - Must be the ruler of the kingdom
    - Must have sufficient personal gold
    """
    # Validate amount
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    # Verify ruler
    if kingdom.ruler_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the ruler can deposit to the treasury"
        )
    
    # Get player state
    state = get_or_create_player_state(db, current_user)
    
    # Check player has enough
    personal_gold = state.gold or 0
    if personal_gold < request.amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient personal gold. You only have {personal_gold} gold."
        )
    
    # Perform deposit
    kingdom.treasury_gold = (kingdom.treasury_gold or 0) + request.amount
    state.gold = (state.gold or 0) - request.amount
    
    db.commit()
    db.refresh(kingdom)
    db.refresh(state)
    
    return TreasuryDepositResponse(
        success=True,
        message=f"Deposited {request.amount} gold into {kingdom.name}'s treasury",
        amount_deposited=request.amount,
        kingdom_id=kingdom.id,
        kingdom_name=kingdom.name,
        treasury_new=int(kingdom.treasury_gold or 0),
        personal_gold_remaining=state.gold or 0,
    )
