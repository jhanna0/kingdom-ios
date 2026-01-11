"""
Coup notifications builder (V2)

Handles notifications for both pledge and battle phases.
"""
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from datetime import datetime, timedelta
from db import User, PlayerState, Kingdom, CoupEvent, UserKingdom
from routers.actions.utils import format_datetime_iso


def _get_initiator_stats(db: Session, coup: CoupEvent) -> Dict[str, Any]:
    """Get full initiator character sheet for notifications"""
    initiator = db.query(User).filter(User.id == coup.initiator_id).first()
    initiator_state = db.query(PlayerState).filter(PlayerState.user_id == coup.initiator_id).first()
    
    if not initiator or not initiator_state:
        return None
    
    # Get kingdom reputation
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == coup.initiator_id,
        UserKingdom.kingdom_id == coup.kingdom_id
    ).first()
    kingdom_rep = user_kingdom.local_reputation if user_kingdom else 0
    
    return {
        "level": initiator_state.level,
        "kingdom_reputation": kingdom_rep,
        "attack_power": initiator_state.attack_power,
        "defense_power": initiator_state.defense_power,
        "leadership": initiator_state.leadership,
        "building_skill": initiator_state.building_skill,
        "intelligence": initiator_state.intelligence,
        "contracts_completed": initiator_state.contracts_completed,
        "total_work_contributed": initiator_state.total_work_contributed,
        "coups_won": initiator_state.coups_won,
        "coups_failed": initiator_state.coups_failed
    }


def get_coup_notifications(db: Session, user: User, state: PlayerState) -> List[Dict[str, Any]]:
    """Get all coup-related notifications for the user"""
    notifications = []
    
    # ===== Active coups (not resolved) - phase is computed from time =====
    active_coups = db.query(CoupEvent).filter(
        CoupEvent.resolved_at.is_(None)
    ).all()
    
    for coup in active_coups:
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        if not kingdom:
            continue
        
        initiator_stats = _get_initiator_stats(db, coup)
        
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        user_has_pledged = user.id in attacker_ids or user.id in defender_ids
        user_side = None
        if user.id in attacker_ids:
            user_side = 'attackers'
        elif user.id in defender_ids:
            user_side = 'defenders'
        
        # Base coup data for all notifications
        # Phase is computed from time, not stored
        coup_data = {
            "id": coup.id,
            "kingdom_id": coup.kingdom_id,
            "kingdom_name": kingdom.name,
            "initiator_name": coup.initiator_name,
            "initiator_stats": initiator_stats,
            "status": coup.current_phase,  # Computed from time
            "time_remaining_seconds": coup.time_remaining_seconds,
            "attacker_count": len(attacker_ids),
            "defender_count": len(defender_ids),
            "user_side": user_side,
            "can_pledge": False
        }
        
        # === PLEDGE PHASE ===
        if coup.is_pledge_phase:
            # Check if user is a citizen of this kingdom (hometown)
            is_citizen = state.hometown_kingdom_id == coup.kingdom_id
            is_ruler = kingdom.ruler_id == user.id
            
            can_pledge = (
                is_citizen and
                not user_has_pledged and
                coup.is_pledge_open
            )
            coup_data["can_pledge"] = can_pledge
            
            # Notify ALL citizens of the kingdom
            if is_citizen or is_ruler:
                if user_has_pledged:
                    # User already pledged - MEDIUM priority
                    hours_remaining = coup.pledge_time_remaining_seconds // 3600
                    notifications.append({
                        "type": "coup_pledge_waiting",
                        "priority": "medium",
                        "title": f"Coup Pledge Phase in {kingdom.name}",
                        "message": f"You joined the {user_side}. Battle begins in {hours_remaining}h.",
                        "action": "view_coup",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
                elif is_ruler:
                    # User is the ruler being targeted - CRITICAL priority
                    notifications.append({
                        "type": "coup_against_you",
                        "priority": "critical",
                        "title": f"⚔️ COUP AGAINST YOU!",
                        "message": f"{coup.initiator_name} is trying to overthrow you! Choose your side!",
                        "action": "pledge_coup",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
                elif can_pledge:
                    # Citizen can pledge - HIGH priority
                    notifications.append({
                        "type": "coup_pledge_needed",
                        "priority": "high",
                        "title": f"⚔️ Coup in {kingdom.name}!",
                        "message": f"{coup.initiator_name} is attempting to overthrow the ruler. Choose your side!",
                        "action": "pledge_coup",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
        
        # === BATTLE PHASE (continues until someone resolves) ===
        elif coup.is_battle_phase:
            is_citizen = state.hometown_kingdom_id == coup.kingdom_id
            is_ruler = kingdom.ruler_id == user.id
            
            # Notify all citizens and ruler
            if is_citizen or is_ruler or user_has_pledged:
                if user_has_pledged:
                    # User is in the battle - HIGH priority
                    notifications.append({
                        "type": "coup_battle_active",
                        "priority": "high",
                        "title": f"⚔️ Battle in {kingdom.name}!",
                        "message": f"The coup battle is underway. Awaiting resolution.",
                        "action": "view_coup_battle",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
                elif is_ruler:
                    # Ruler is under attack but didn't pledge
                    notifications.append({
                        "type": "coup_battle_against_you",
                        "priority": "critical",
                        "title": f"⚔️ YOUR THRONE IS UNDER ATTACK!",
                        "message": f"The battle for {kingdom.name} is underway!",
                        "action": "view_coup_battle",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
                else:
                    # Citizen watching the battle
                    notifications.append({
                        "type": "coup_battle_ongoing",
                        "priority": "medium",
                        "title": f"⚔️ Battle in {kingdom.name}",
                        "message": f"A coup battle is underway in your kingdom.",
                        "action": "view_coup_battle",
                        "action_id": str(coup.id),
                        "created_at": format_datetime_iso(coup.start_time),
                        "coup_data": coup_data
                    })
    
    # ===== Recently resolved coups =====
    recently_resolved_coups = db.query(CoupEvent).filter(
        CoupEvent.resolved_at.isnot(None),
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
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom.name if kingdom else None,
                    "attacker_victory": coup.attacker_victory,
                    "user_won": user_won
                }
            })
    
    return notifications



