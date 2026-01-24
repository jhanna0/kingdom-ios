"""
Alliance notifications builder
"""
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from datetime import datetime
from db import User, PlayerState, Kingdom, Alliance
from routers.actions.utils import format_datetime_iso


def get_alliance_notifications(db: Session, user: User, state: PlayerState) -> List[Dict[str, Any]]:
    """Get all alliance-related notifications for the user"""
    notifications = []
    
    # Get player's empire ID (if they rule a kingdom)
    ruled_kingdom = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).first()
    if not ruled_kingdom:
        return notifications  # Only rulers get alliance notifications
    
    my_empire_id = ruled_kingdom.empire_id or ruled_kingdom.id
    
    # ===== Pending alliance proposals RECEIVED (critical - requires action) =====
    received_proposals = db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at > datetime.utcnow(),
        Alliance.target_empire_id == my_empire_id
    ).all()
    
    for proposal in received_proposals:
        # Get initiator kingdom name
        initiator_kingdom = db.query(Kingdom).filter(
            Kingdom.id == proposal.initiator_empire_id
        ).first()
        if not initiator_kingdom:
            initiator_kingdom = db.query(Kingdom).filter(
                Kingdom.empire_id == proposal.initiator_empire_id
            ).first()
        
        initiator_name = initiator_kingdom.name if initiator_kingdom else "Unknown Kingdom"
        
        notifications.append({
            "type": "alliance_request_received",
            "priority": "critical",  # Critical - ruler must respond
            "title": "Alliance Proposal!",
            "message": f"{proposal.initiator_ruler_name} of {initiator_name} seeks an alliance!",
            "action": "view_alliance_request",
            "action_id": str(proposal.id),
            "created_at": format_datetime_iso(proposal.created_at),
            "alliance_data": {
                "id": proposal.id,
                "initiator_empire_id": proposal.initiator_empire_id,
                "initiator_empire_name": initiator_name,
                "initiator_ruler_name": proposal.initiator_ruler_name,
                "hours_to_respond": proposal.hours_to_respond,
                "created_at": format_datetime_iso(proposal.created_at),
                "proposal_expires_at": format_datetime_iso(proposal.proposal_expires_at)
            }
        })
    
    # ===== Pending alliance proposals SENT (medium - awaiting response) =====
    sent_proposals = db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at > datetime.utcnow(),
        Alliance.initiator_empire_id == my_empire_id
    ).all()
    
    for proposal in sent_proposals:
        # Get target kingdom name
        target_kingdom = db.query(Kingdom).filter(
            Kingdom.id == proposal.target_empire_id
        ).first()
        if not target_kingdom:
            target_kingdom = db.query(Kingdom).filter(
                Kingdom.empire_id == proposal.target_empire_id
            ).first()
        
        target_name = target_kingdom.name if target_kingdom else "Unknown Kingdom"
        
        notifications.append({
            "type": "alliance_request_sent",
            "priority": "medium",
            "title": "Alliance Pending",
            "message": f"Awaiting response from {target_name}",
            "action": "view_alliance_request",
            "action_id": str(proposal.id),
            "created_at": format_datetime_iso(proposal.created_at),
            "alliance_data": {
                "id": proposal.id,
                "target_empire_id": proposal.target_empire_id,
                "target_empire_name": target_name,
                "hours_to_respond": proposal.hours_to_respond,
                "proposal_expires_at": format_datetime_iso(proposal.proposal_expires_at)
            }
        })
    
    # ===== Recently accepted alliances (high - good news!) =====
    # Get alliances accepted in last 24 hours
    from datetime import timedelta
    recent_accepted = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.accepted_at >= datetime.utcnow() - timedelta(hours=24),
        (Alliance.initiator_empire_id == my_empire_id) | (Alliance.target_empire_id == my_empire_id)
    ).all()
    
    for alliance in recent_accepted:
        # Determine the other party
        if alliance.initiator_empire_id == my_empire_id:
            other_empire_id = alliance.target_empire_id
            other_ruler_name = alliance.target_ruler_name
        else:
            other_empire_id = alliance.initiator_empire_id
            other_ruler_name = alliance.initiator_ruler_name
        
        # Get kingdom name
        other_kingdom = db.query(Kingdom).filter(
            Kingdom.id == other_empire_id
        ).first()
        if not other_kingdom:
            other_kingdom = db.query(Kingdom).filter(
                Kingdom.empire_id == other_empire_id
            ).first()
        
        other_name = other_kingdom.name if other_kingdom else "Unknown Kingdom"
        
        notifications.append({
            "type": "alliance_accepted",
            "priority": "high",
            "title": "Alliance Formed!",
            "message": f"Alliance with {other_name} is now active!",
            "action": "view_alliance",
            "action_id": str(alliance.id),
            "created_at": format_datetime_iso(alliance.accepted_at),
            "alliance_data": {
                "id": alliance.id,
                "other_empire_id": other_empire_id,
                "other_empire_name": other_name,
                "other_ruler_name": other_ruler_name,
                "days_remaining": alliance.days_remaining,
                "expires_at": format_datetime_iso(alliance.expires_at) if alliance.expires_at else None
            }
        })
    
    # ===== Recently declined alliances (medium - info) =====
    recent_declined = db.query(Alliance).filter(
        Alliance.status == 'declined',
        Alliance.created_at >= datetime.utcnow() - timedelta(hours=24),
        Alliance.initiator_empire_id == my_empire_id  # Only notify initiator of decline
    ).all()
    
    for alliance in recent_declined:
        target_kingdom = db.query(Kingdom).filter(
            Kingdom.id == alliance.target_empire_id
        ).first()
        if not target_kingdom:
            target_kingdom = db.query(Kingdom).filter(
                Kingdom.empire_id == alliance.target_empire_id
            ).first()
        
        target_name = target_kingdom.name if target_kingdom else "Unknown Kingdom"
        
        notifications.append({
            "type": "alliance_declined",
            "priority": "medium",
            "title": "Alliance Declined",
            "message": f"{target_name} declined your alliance proposal",
            "action": "view_kingdom",
            "action_id": alliance.target_empire_id,
            "created_at": format_datetime_iso(alliance.created_at),
            "alliance_data": {
                "id": alliance.id,
                "target_empire_id": alliance.target_empire_id,
                "target_empire_name": target_name
            }
        })
    
    return notifications


def get_pending_alliance_requests(db: Session, user: User, state: PlayerState) -> List[Dict[str, Any]]:
    """
    Get pending alliance requests for the ActionsView.
    Returns structured data for rendering accept/decline buttons.
    """
    # Get player's empire ID (if they rule a kingdom)
    ruled_kingdom = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).first()
    if not ruled_kingdom:
        return []
    
    my_empire_id = ruled_kingdom.empire_id or ruled_kingdom.id
    
    # Get pending proposals received
    received_proposals = db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at > datetime.utcnow(),
        Alliance.target_empire_id == my_empire_id
    ).all()
    
    requests = []
    for proposal in received_proposals:
        # Get initiator kingdom name
        initiator_kingdom = db.query(Kingdom).filter(
            Kingdom.id == proposal.initiator_empire_id
        ).first()
        if not initiator_kingdom:
            initiator_kingdom = db.query(Kingdom).filter(
                Kingdom.empire_id == proposal.initiator_empire_id
            ).first()
        
        initiator_name = initiator_kingdom.name if initiator_kingdom else "Unknown Kingdom"
        
        requests.append({
            "id": proposal.id,
            "initiator_empire_id": proposal.initiator_empire_id,
            "initiator_empire_name": initiator_name,
            "initiator_ruler_name": proposal.initiator_ruler_name,
            "hours_to_respond": proposal.hours_to_respond,
            "created_at": format_datetime_iso(proposal.created_at),
            "proposal_expires_at": format_datetime_iso(proposal.proposal_expires_at),
            # Endpoints for frontend to call
            "accept_endpoint": f"/alliances/{proposal.id}/accept",
            "decline_endpoint": f"/alliances/{proposal.id}/decline"
        })
    
    return requests
