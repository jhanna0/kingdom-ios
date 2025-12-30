"""
Coup notifications builder
"""
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from datetime import datetime, timedelta
from db import User, PlayerState, Kingdom, CoupEvent


def get_coup_notifications(db: Session, user: User, state: PlayerState) -> List[Dict[str, Any]]:
    """Get all coup-related notifications for the user"""
    notifications = []
    
    # ===== Active coups =====
    active_coups = db.query(CoupEvent).filter(
        CoupEvent.status == 'voting'
    ).all()
    
    for coup in active_coups:
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        if not kingdom:
            continue
        
        # Get initiator stats
        initiator = db.query(User).filter(User.id == coup.initiator_id).first()
        initiator_state = db.query(PlayerState).filter(PlayerState.user_id == coup.initiator_id).first()
        
        initiator_stats = None
        if initiator and initiator_state:
            kingdom_rep = initiator_state.kingdom_reputation.get(coup.kingdom_id, 0) if initiator_state.kingdom_reputation else 0
            initiator_stats = {
                "reputation": initiator_state.reputation,
                "kingdom_reputation": kingdom_rep,
                "attack_power": initiator_state.attack_power,
                "defense_power": initiator_state.defense_power,
                "leadership": initiator_state.leadership,
                "building_skill": initiator_state.building_skill,
                "intelligence": initiator_state.intelligence,
                "contracts_completed": initiator_state.contracts_completed,
                "total_work_contributed": initiator_state.total_work_contributed,
                "level": initiator_state.level
            }
        
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        user_has_joined = user.id in attacker_ids or user.id in defender_ids
        
        # Check if user can join (must be checked in)
        can_join = (
            state.current_kingdom_id == coup.kingdom_id and
            not user_has_joined and
            coup.is_voting_open
        )
        
        # Create notification based on user's situation
        if can_join:
            # User can vote - HIGH priority
            notifications.append({
                "type": "coup_vote_needed",
                "priority": "high",
                "title": f"Coup in {kingdom.name}!",
                "message": f"{coup.initiator_name} is attempting to overthrow the ruler. Choose your side!",
                "action": "vote_coup",
                "action_id": coup.id,
                "created_at": coup.start_time.isoformat(),
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom.name,
                    "initiator_name": coup.initiator_name,
                    "initiator_stats": initiator_stats,
                    "time_remaining_seconds": coup.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "can_join": True
                }
            })
        elif user_has_joined:
            # User already joined - MEDIUM priority
            user_side = 'attackers' if user.id in attacker_ids else 'defenders'
            notifications.append({
                "type": "coup_in_progress",
                "priority": "medium",
                "title": f"Coup Ongoing in {kingdom.name}",
                "message": f"You joined the {user_side}. {coup.time_remaining_seconds // 60} minutes remaining.",
                "action": "view_coup",
                "action_id": coup.id,
                "created_at": coup.start_time.isoformat(),
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom.name,
                    "initiator_name": coup.initiator_name,
                    "initiator_stats": initiator_stats,
                    "time_remaining_seconds": coup.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "user_side": user_side,
                    "can_join": False
                }
            })
        elif kingdom.ruler_id == user.id:
            # User is the ruler being targeted - CRITICAL priority
            notifications.append({
                "type": "coup_against_you",
                "priority": "critical",
                "title": f"⚔️ COUP AGAINST YOU!",
                "message": f"{coup.initiator_name} is trying to overthrow you in {kingdom.name}!",
                "action": "view_coup",
                "action_id": coup.id,
                "created_at": coup.start_time.isoformat(),
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom.name,
                    "initiator_name": coup.initiator_name,
                    "initiator_stats": initiator_stats,
                    "time_remaining_seconds": coup.time_remaining_seconds,
                    "attacker_count": len(attacker_ids),
                    "defender_count": len(defender_ids),
                    "can_join": False
                }
            })
    
    # ===== Recently resolved coups =====
    recently_resolved_coups = db.query(CoupEvent).filter(
        CoupEvent.status == 'resolved',
        CoupEvent.resolved_at >= datetime.utcnow() - timedelta(hours=24)
    ).all()
    
    for coup in recently_resolved_coups:
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        
        if user.id in attacker_ids or user.id in defender_ids:
            kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
            
            user_was_attacker = user.id in attacker_ids
            user_won = (user_was_attacker and coup.attacker_victory) or (not user_was_attacker and not coup.attacker_victory)
            
            notifications.append({
                "type": "coup_resolved",
                "priority": "high",
                "title": f"Coup Resolved in {kingdom.name if kingdom else 'Kingdom'}",
                "message": "You won!" if user_won else "You lost.",
                "action": "view_coup_results",
                "action_id": coup.id,
                "created_at": coup.resolved_at.isoformat(),
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom.name if kingdom else None,
                    "attacker_victory": coup.attacker_victory,
                    "user_won": user_won
                }
            })
    
    return notifications

