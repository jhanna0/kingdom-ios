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
    
    Shows badge if any notification is newer than user's last_notifications_viewed.
    """
    state = get_player_state(db, current_user)
    
    last_viewed = state.last_notifications_viewed
    
    # Gather ALL notifications
    notifications = []
    notifications.extend(get_coup_notifications(db, current_user, state))
    notifications.extend(get_invasion_notifications(db, current_user, state))
    notifications.extend(get_kingdom_event_notifications(db, current_user, state))
    notifications.extend(get_alliance_notifications(db, current_user, state))
    
    # Check if any notification is newer than last viewed
    has_unread = False
    if notifications:
        if not last_viewed:
            # Never viewed notifications = all are new
            has_unread = True
        else:
            # IMPORTANT: Strip microseconds to match notification timestamps
            # (notifications are serialized without microseconds for iOS compatibility)
            from dateutil.parser import parse as parse_datetime
            last_viewed_no_micro = last_viewed.replace(microsecond=0)
            for n in notifications:
                created_at_str = n.get("created_at")
                if created_at_str:
                    try:
                        created_at = parse_datetime(created_at_str).replace(tzinfo=None)
                        if created_at > last_viewed_no_micro:
                            has_unread = True
                            break
                    except:
                        pass
    
    return {
        "has_unread": has_unread
    }


@router.post("/mark-read")
def mark_notifications_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Mark all notifications as read.
    
    Call this when user opens the notifications panel.
    """
    state = get_player_state(db, current_user)
    state.last_notifications_viewed = datetime.utcnow()
    db.commit()
    
    return {"success": True}

