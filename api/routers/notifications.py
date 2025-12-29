"""
Notifications and updates endpoint
Returns everything a user needs to know when they open the app
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from datetime import datetime, timedelta
from typing import List, Dict, Any

from db import get_db, User, PlayerState, Contract, Kingdom, UserKingdom, CoupEvent
from routers.auth import get_current_user
from config import DEV_MODE

router = APIRouter(prefix="/notifications", tags=["notifications"])


def get_player_state(db: Session, user: User) -> PlayerState:
    """Get or create player state"""
    if not user.player_state:
        state = PlayerState(
            user_id=user.id,
            hometown_kingdom_id=user.hometown_kingdom_id
        )
        db.add(state)
        db.commit()
        db.refresh(state)
        return state
    return user.player_state


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
    notifications = []
    
    
    # ===== Check for check-in availability =====
    # REMOVED - check-in is not an event, it's just status
    
    # ===== Check for active coups =====
    # Find all active coups where user can participate
    active_coups = db.query(CoupEvent).filter(
        CoupEvent.status == 'voting'
    ).all()
    
    coup_notifications = []
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
        
        # Check if user has already joined
        user_has_joined = current_user.id in attacker_ids or current_user.id in defender_ids
        
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
            # User already joined - MEDIUM priority (keep them updated)
            user_side = 'attackers' if current_user.id in attacker_ids else 'defenders'
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
        elif kingdom.ruler_id == current_user.id:
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
    
    # ===== Check for recently resolved coups user was part of =====
    recently_resolved_coups = db.query(CoupEvent).filter(
        CoupEvent.status == 'resolved',
        CoupEvent.resolved_at >= datetime.utcnow() - timedelta(hours=24)
    ).all()
    
    for coup in recently_resolved_coups:
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        
        if current_user.id in attacker_ids or current_user.id in defender_ids:
            kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
            
            user_was_attacker = current_user.id in attacker_ids
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
    
    # Sort by timestamp (most recent first)
    sorted_notifications = sorted(notifications, key=lambda x: x.get("created_at", ""), reverse=True)
    
    return {
        "success": True,
        "notifications": sorted_notifications,
        "server_time": datetime.utcnow().isoformat()
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
    # Count active coups where user can participate or is involved
    state = get_player_state(db, current_user)
    active_coups = db.query(CoupEvent).filter(CoupEvent.status == 'voting').all()
    
    relevant_coups = 0
    for coup in active_coups:
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        user_involved = current_user.id in attacker_ids or current_user.id in defender_ids
        can_join = state.current_kingdom_id == coup.kingdom_id and not user_involved
        
        if user_involved or can_join:
            relevant_coups += 1
    
    return {
        "unread_notifications": relevant_coups
    }

