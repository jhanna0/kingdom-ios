"""
Invasion notifications builder
"""
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from datetime import datetime, timedelta
from db import User, PlayerState, Kingdom, InvasionEvent
from routers.alliances import are_empires_allied


def get_invasion_notifications(db: Session, user: User, state: PlayerState) -> List[Dict[str, Any]]:
    """Get all invasion-related notifications for the user"""
    notifications = []
    
    # ===== Active invasions =====
    active_invasions = db.query(InvasionEvent).filter(
        InvasionEvent.status == 'declared'
    ).all()
    
    for invasion in active_invasions:
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.target_kingdom_id).first()
        attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.attacking_from_kingdom_id).first()
        
        if not target_kingdom or not attacking_kingdom:
            continue
        
        attacker_ids = invasion.get_attacker_ids()
        defender_ids = invasion.get_defender_ids()
        user_has_joined = user.id in attacker_ids or user.id in defender_ids
        
        # Check if user is AT the target city
        at_target = state.current_kingdom_id == invasion.target_kingdom_id
        
        # Check if user's empire is allied with target
        home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first() if state.hometown_kingdom_id else None
        is_allied = home_kingdom and are_empires_allied(
            db,
            home_kingdom.empire_id or home_kingdom.id,
            target_kingdom.empire_id or target_kingdom.id
        )
        
        # Check if user's empire IS the target empire
        is_same_empire = home_kingdom and (
            (home_kingdom.empire_id or home_kingdom.id) == (target_kingdom.empire_id or target_kingdom.id)
        )
        
        # Can defend if: at target AND (is local, same empire, or allied)
        is_local = state.hometown_kingdom_id == invasion.target_kingdom_id
        can_defend = at_target and (is_local or is_same_empire or is_allied) and not user_has_joined
        
        # Create notifications based on user's relationship to invasion
        if target_kingdom.ruler_id == user.id and not user_has_joined:
            # User's city is being invaded - CRITICAL
            notifications.append({
                "type": "invasion_against_you",
                "priority": "critical",
                "title": f"🏴 YOUR CITY UNDER ATTACK!",
                "message": f"{invasion.initiator_name} from {attacking_kingdom.name} is invading {target_kingdom.name}!",
                "action": "view_invasion",
                "action_id": str(invasion.id),
                "created_at": invasion.declared_at.isoformat(),
                "invasion_data": {
                    "id": invasion.id,
                    "target_kingdom_id": invasion.target_kingdom_id,
                    "target_kingdom_name": target_kingdom.name,
                    "attacking_from_kingdom_id": invasion.attacking_from_kingdom_id,
                    "attacking_from_kingdom_name": attacking_kingdom.name,
                    "initiator_name": invasion.initiator_name,
                    "time_remaining_seconds": invasion.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "can_join": at_target,
                    "user_is_ruler": True
                }
            })
        elif is_allied and not user_has_joined:
            # Allied city under attack - HIGH priority
            notifications.append({
                "type": "ally_under_attack",
                "priority": "high",
                "title": f"⚔️ Ally Under Attack!",
                "message": f"Your ally {target_kingdom.name} is being invaded by {attacking_kingdom.name}. Help defend!",
                "action": "view_invasion",
                "action_id": str(invasion.id),
                "created_at": invasion.declared_at.isoformat(),
                "invasion_data": {
                    "id": invasion.id,
                    "target_kingdom_id": invasion.target_kingdom_id,
                    "target_kingdom_name": target_kingdom.name,
                    "attacking_from_kingdom_id": invasion.attacking_from_kingdom_id,
                    "attacking_from_kingdom_name": attacking_kingdom.name,
                    "initiator_name": invasion.initiator_name,
                    "time_remaining_seconds": invasion.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "can_join": can_defend,
                    "is_allied": True
                }
            })
        elif can_defend:
            # User can defend (same empire or local) - HIGH priority
            notifications.append({
                "type": "invasion_defense_needed",
                "priority": "high",
                "title": f"🛡️ Defense Needed!",
                "message": f"{target_kingdom.name} is under attack! Join the defense!",
                "action": "view_invasion",
                "action_id": str(invasion.id),
                "created_at": invasion.declared_at.isoformat(),
                "invasion_data": {
                    "id": invasion.id,
                    "target_kingdom_id": invasion.target_kingdom_id,
                    "target_kingdom_name": target_kingdom.name,
                    "attacking_from_kingdom_id": invasion.attacking_from_kingdom_id,
                    "attacking_from_kingdom_name": attacking_kingdom.name,
                    "initiator_name": invasion.initiator_name,
                    "time_remaining_seconds": invasion.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "can_join": True
                }
            })
        elif user_has_joined:
            # User already joined - MEDIUM priority
            user_side = 'attackers' if user.id in attacker_ids else 'defenders'
            notifications.append({
                "type": "invasion_in_progress",
                "priority": "medium",
                "title": f"Invasion Ongoing",
                "message": f"You joined as {user_side}. Battle in {invasion.time_remaining_seconds // 60} minutes.",
                "action": "view_invasion",
                "action_id": str(invasion.id),
                "created_at": invasion.declared_at.isoformat(),
                "invasion_data": {
                    "id": invasion.id,
                    "target_kingdom_id": invasion.target_kingdom_id,
                    "target_kingdom_name": target_kingdom.name,
                    "attacking_from_kingdom_id": invasion.attacking_from_kingdom_id,
                    "attacking_from_kingdom_name": attacking_kingdom.name,
                    "initiator_name": invasion.initiator_name,
                    "time_remaining_seconds": invasion.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "user_side": user_side,
                    "can_join": False
                }
            })
    
    # ===== Recently resolved invasions =====
    recently_resolved_invasions = db.query(InvasionEvent).filter(
        InvasionEvent.status == 'resolved',
        InvasionEvent.resolved_at >= datetime.utcnow() - timedelta(hours=24)
    ).all()
    
    for invasion in recently_resolved_invasions:
        attacker_ids = invasion.get_attacker_ids()
        defender_ids = invasion.get_defender_ids()
        
        if user.id in attacker_ids or user.id in defender_ids:
            target_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.target_kingdom_id).first()
            attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.attacking_from_kingdom_id).first()
            
            user_was_attacker = user.id in attacker_ids
            user_won = (user_was_attacker and invasion.attacker_victory) or (not user_was_attacker and not invasion.attacker_victory)
            
            notifications.append({
                "type": "invasion_resolved",
                "priority": "high",
                "title": f"Invasion Resolved",
                "message": f"{'Victory!' if user_won else 'Defeat.'} {target_kingdom.name if target_kingdom else 'The battle'} is over.",
                "action": "view_invasion_results",
                "action_id": str(invasion.id),
                "created_at": invasion.resolved_at.isoformat(),
                "invasion_data": {
                    "id": invasion.id,
                    "target_kingdom_id": invasion.target_kingdom_id,
                    "target_kingdom_name": target_kingdom.name if target_kingdom else None,
                    "attacking_from_kingdom_name": attacking_kingdom.name if attacking_kingdom else None,
                    "attacker_victory": invasion.attacker_victory,
                    "user_won": user_won,
                    "user_was_attacker": user_was_attacker
                }
            })
    
    return notifications



