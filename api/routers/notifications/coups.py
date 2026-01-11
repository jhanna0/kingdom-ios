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
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        kingdom_name = kingdom.name if kingdom else "Kingdom"
        
        from systems.coup.config import (
            WINNER_REP_GAIN, LOSER_REP_LOSS,
            LOSER_ATTACK_LOSS, LOSER_DEFENSE_LOSS, LOSER_LEADERSHIP_LOSS
        )
        
        # Check if notification is unread
        last_read = state.last_notifications_viewed
        is_unread = last_read is None or coup.resolved_at > last_read
        
        gold_won = coup.gold_per_winner or 0
        
        # === Case 1: User is the NEW RULER (initiator who won) ===
        if coup.attacker_victory and user.id == coup.initiator_id:
            notifications.append({
                "type": "coup_new_ruler",
                "priority": "critical",
                "title": f"👑 You Are Now Ruler!",
                "message": f"Your coup succeeded! You now rule {kingdom_name}!",
                "action": "view_kingdom",
                "action_id": coup.kingdom_id,
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "gold_per_winner": gold_won,
                    "rep_gained": WINNER_REP_GAIN
                }
            })
        
        # === Case 2: User WAS the ruler and LOST their throne ===
        elif coup.attacker_victory and user.id == coup.old_ruler_id:
            # User was the ruler who got overthrown!
            notifications.append({
                "type": "coup_lost_throne",
                "priority": "critical",
                "title": "👑 You Lost Your Throne!",
                "message": f"{coup.initiator_name} has overthrown you in {kingdom_name}!",
                "action": "view_coup_results",
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "attacker_victory": True,
                    "user_won": False,
                    "new_ruler_name": coup.initiator_name,
                    "gold_lost_percent": 50,
                    "rep_lost": LOSER_REP_LOSS,
                    "attack_lost": LOSER_ATTACK_LOSS,
                    "defense_lost": LOSER_DEFENSE_LOSS,
                    "leadership_lost": LOSER_LEADERSHIP_LOSS
                }
            })
        
        # === Case 2b: User was defender and lost (but not the ruler) ===
        elif user.id in defender_ids and coup.attacker_victory:
            notifications.append({
                "type": "coup_side_lost",
                "priority": "high",
                "title": f"⚔️ Defeat in {kingdom_name}",
                "message": f"Your side was defeated. Lost 50% gold, -{LOSER_REP_LOSS} rep, -{LOSER_ATTACK_LOSS} atk, -{LOSER_DEFENSE_LOSS} def, -{LOSER_LEADERSHIP_LOSS} leadership",
                "action": "view_coup_results",
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "attacker_victory": coup.attacker_victory,
                    "user_won": False,
                    "gold_lost_percent": 50,
                    "rep_lost": LOSER_REP_LOSS,
                    "attack_lost": LOSER_ATTACK_LOSS,
                    "defense_lost": LOSER_DEFENSE_LOSS,
                    "leadership_lost": LOSER_LEADERSHIP_LOSS
                }
            })
        
        # === Case 3: User was on WINNING side (but not the new ruler) ===
        elif user.id in attacker_ids and coup.attacker_victory and user.id != coup.initiator_id:
            notifications.append({
                "type": "coup_side_won",
                "priority": "high",
                "title": f"⚔️ Victory in {kingdom_name}!",
                "message": f"Your side won! Spoils: {gold_won} gold, +{WINNER_REP_GAIN} rep",
                "action": "view_coup_results",
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "attacker_victory": True,
                    "user_won": True,
                    "gold_per_winner": gold_won,
                    "rep_gained": WINNER_REP_GAIN
                }
            })
        
        # === Case 4: Defenders WON (coup failed) ===
        elif user.id in defender_ids and not coup.attacker_victory:
            notifications.append({
                "type": "coup_side_won",
                "priority": "high",
                "title": f"🛡️ Coup Defeated in {kingdom_name}!",
                "message": f"You defended the kingdom! Spoils: {gold_won} gold, +{WINNER_REP_GAIN} rep",
                "action": "view_coup_results",
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "attacker_victory": False,
                    "user_won": True,
                    "gold_per_winner": gold_won,
                    "rep_gained": WINNER_REP_GAIN
                }
            })
        
        # === Case 5: Attackers LOST (coup failed) ===
        elif user.id in attacker_ids and not coup.attacker_victory:
            notifications.append({
                "type": "coup_side_lost",
                "priority": "high",
                "title": f"⚔️ Coup Failed in {kingdom_name}",
                "message": f"Your rebellion was crushed. Lost 50% gold, -{LOSER_REP_LOSS} rep, -{LOSER_ATTACK_LOSS} atk, -{LOSER_DEFENSE_LOSS} def, -{LOSER_LEADERSHIP_LOSS} leadership",
                "action": "view_coup_results",
                "action_id": str(coup.id),
                "created_at": format_datetime_iso(coup.resolved_at),
                "show_popup": is_unread,
                "coup_data": {
                    "id": coup.id,
                    "kingdom_id": coup.kingdom_id,
                    "kingdom_name": kingdom_name,
                    "attacker_victory": False,
                    "user_won": False,
                    "gold_lost_percent": 50,
                    "rep_lost": LOSER_REP_LOSS,
                    "attack_lost": LOSER_ATTACK_LOSS,
                    "defense_lost": LOSER_DEFENSE_LOSS,
                    "leadership_lost": LOSER_LEADERSHIP_LOSS
                }
            })
    
    return notifications



