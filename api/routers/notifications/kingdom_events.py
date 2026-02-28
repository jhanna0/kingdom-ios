"""
Kingdom event notifications
"""
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from typing import List, Dict, Any, Tuple
from datetime import datetime, timedelta

from db import User, PlayerState, Kingdom
from db.models.kingdom_event import KingdomEvent
from routers.actions.utils import format_datetime_iso


def get_kingdom_event_notifications(
    db: Session,
    user: User,
    state: PlayerState,
    days: int = 7
) -> List[Dict[str, Any]]:
    """Get kingdom event notifications for the user's relevant kingdoms."""
    from db.models import UnifiedContract
    from services.kingdom_service import get_active_project_kingdoms
    
    # Get relevant kingdom IDs
    # Only hometown and ruled kingdoms - NOT current_kingdom_id
    # Players shouldn't see events from kingdoms they're just visiting
    # (otherwise spies would see the "Intelligence Operation Detected" alert they caused!)
    relevant_kingdom_ids = set()
    
    if state.hometown_kingdom_id:
        relevant_kingdom_ids.add(state.hometown_kingdom_id)
    
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()
    for k in ruled_kingdoms:
        relevant_kingdom_ids.add(k.id)
    
    if not relevant_kingdom_ids:
        return []
    
    cutoff = datetime.utcnow() - timedelta(days=days)
    
    events = db.query(KingdomEvent).filter(
        KingdomEvent.kingdom_id.in_(relevant_kingdom_ids),
        KingdomEvent.created_at >= cutoff
    ).order_by(desc(KingdomEvent.created_at)).limit(20).all()
    
    notifications = []
    for event in events:
        notifications.append({
            "type": "kingdom_event",
            "priority": "low",
            "title": event.title,
            "message": event.description,
            "action": "view",
            "action_id": str(event.id),
            "created_at": format_datetime_iso(event.created_at),
        })
    
    # Add synthetic "no project" notification for rulers without active building projects
    if ruled_kingdoms:
        ruled_kingdom_ids = [k.id for k in ruled_kingdoms]
        active_projects = get_active_project_kingdoms(db, ruled_kingdom_ids)
        
        for kingdom in ruled_kingdoms:
            if kingdom.id not in active_projects:
                notifications.insert(0, {
                    "type": "kingdom_event",
                    "priority": "high",
                    "title": f"No Building Project in {kingdom.name}!",
                    "message": "Start a project: My Empire → Manage → Manage Buildings",
                    "action": "manage_buildings",
                    "action_id": kingdom.id,
                    "created_at": format_datetime_iso(datetime.utcnow()),
                    "is_synthetic": True,  # Frontend can style differently if needed
                })
    
    return notifications


def get_unread_kingdom_events_count(
    db: Session,
    user: User,
    state: PlayerState
) -> int:
    """Count kingdom events since user last viewed notifications."""
    last_viewed = state.last_notifications_viewed
    
    if not last_viewed:
        return 0
    
    # Get relevant kingdom IDs (same as get_kingdom_event_notifications)
    # Only hometown and ruled kingdoms - NOT current_kingdom_id
    relevant_kingdom_ids = set()
    if state.hometown_kingdom_id:
        relevant_kingdom_ids.add(state.hometown_kingdom_id)
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()
    for k in ruled_kingdoms:
        relevant_kingdom_ids.add(k.id)
    
    if not relevant_kingdom_ids:
        return 0
    
    # Count events since last viewed
    count = db.query(func.count(KingdomEvent.id)).filter(
        KingdomEvent.kingdom_id.in_(relevant_kingdom_ids),
        KingdomEvent.created_at > last_viewed
    ).scalar()
    
    return count or 0
