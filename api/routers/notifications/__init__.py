"""
Notifications and updates endpoint
Returns everything a user needs to know when they open the app
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Dict, Any

from db import get_db, User, PlayerState, Contract, Kingdom, CoupEvent, InvasionEvent
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from routers.actions.utils import format_datetime_iso

from .utils import get_player_state
from .player_summary import build_player_summary
from .contracts import build_contract_updates
from .kingdoms import build_kingdom_updates
from .coups import get_coup_notifications
from .invasions import get_invasion_notifications
from .kingdom_events import get_kingdom_event_notifications, get_unread_kingdom_events_count
from .alliances import get_alliance_notifications, get_pending_alliance_requests
from .config import enrich_notification

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/updates")
def get_user_updates(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all relevant updates for the user
    
    Called when app opens to show:
    - Completed contracts ready to claim
    - Active contracts progress
    - Kingdom updates (if ruler)
    - Rewards available
    - Important notifications
    """
    
    state = get_player_state(db, current_user)
    
    # Build all data in parallel
    player_summary = build_player_summary(db, current_user, state)
    contracts_data = build_contract_updates(db, current_user)
    kingdoms_list = build_kingdom_updates(db, current_user)
    
    # Gather all notifications
    notifications = []
    notifications.extend(get_coup_notifications(db, current_user, state))
    notifications.extend(get_invasion_notifications(db, current_user, state))
    notifications.extend(get_kingdom_event_notifications(db, current_user, state))
    notifications.extend(get_alliance_notifications(db, current_user, state))
    
    # Enrich all notifications with icon/color from config (SINGLE SOURCE OF TRUTH)
    notifications = [enrich_notification(n) for n in notifications]
    
    # Sort by most recent first
    sorted_notifications = sorted(
        notifications,
        key=lambda x: x.get("created_at", ""),
        reverse=True
    )
    
    # Count unread kingdom events since last check-in
    unread_kingdom_events = get_unread_kingdom_events_count(db, current_user, state)
    
    # Get pending alliance requests for ActionsView (rulers only)
    pending_alliance_requests = get_pending_alliance_requests(db, current_user, state)
    
    return {
        "success": True,
        "summary": player_summary,
        "notifications": sorted_notifications,
        "contracts": contracts_data,
        "kingdoms": kingdoms_list,
        "unread_kingdom_events": unread_kingdom_events,
        "pending_alliance_requests": pending_alliance_requests,
        "server_time": format_datetime_iso(datetime.utcnow())
    }


@router.get("/summary")
def get_quick_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Quick summary for app badge/widget
    Returns counts only, no detailed data
    """
    state = get_player_state(db, current_user)
    
    # Count contracts where user has contributed
    user_id_str = str(current_user.id)
    all_contracts = db.query(Contract).all()
    
    ready_contracts = sum(1 for c in all_contracts 
                         if c.status == 'completed' 
                         and c.action_contributions 
                         and user_id_str in c.action_contributions)
    
    active_contracts = sum(1 for c in all_contracts 
                          if c.status == 'in_progress' 
                          and c.action_contributions 
                          and user_id_str in c.action_contributions)
    
    # Count active coups where user can participate or is involved
    active_coups = db.query(CoupEvent).filter(CoupEvent.status == 'voting').all()
    
    relevant_coups = 0
    for coup in active_coups:
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        user_involved = current_user.id in attacker_ids or current_user.id in defender_ids
        can_join = state.current_kingdom_id == coup.kingdom_id and not user_involved
        
        if user_involved or can_join:
            relevant_coups += 1
    
    # Count active invasions where user can participate or is involved
    active_invasions = db.query(InvasionEvent).filter(InvasionEvent.status == 'declared').all()
    
    relevant_invasions = 0
    for invasion in active_invasions:
        attacker_ids = invasion.get_attacker_ids()
        defender_ids = invasion.get_defender_ids()
        user_involved = current_user.id in attacker_ids or current_user.id in defender_ids
        
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.target_kingdom_id).first()
        if target_kingdom:
            # Check if user's city is being attacked or user is allied
            home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first() if state.hometown_kingdom_id else None
            is_allied = home_kingdom and are_empires_allied(
                db,
                home_kingdom.empire_id or home_kingdom.id,
                target_kingdom.empire_id or target_kingdom.id
            )
            is_ruler = target_kingdom.ruler_id == current_user.id
            
            if user_involved or is_ruler or is_allied:
                relevant_invasions += 1
    
    return {
        "ready_contracts": ready_contracts,
        "active_contracts": active_contracts,
        "skill_points": state.skill_points,
        "unread_notifications": relevant_coups + relevant_invasions
    }

