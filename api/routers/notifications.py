"""
Notifications and updates endpoint
Returns everything a user needs to know when they open the app
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from datetime import datetime, timedelta
from typing import List, Dict, Any

from db import get_db, User, PlayerState, Contract, Kingdom, UserKingdom
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
    
    # ===== Check for completed contracts =====
    # Find contracts where user has contributed
    all_contracts = db.query(Contract).filter(
        Contract.status.in_(["open", "in_progress"])
    ).all()
    
    user_id_str = str(current_user.id)
    active_contracts = [c for c in all_contracts if user_id_str in (c.action_contributions or {})]
    
    ready_to_complete = []
    in_progress = []
    
    for contract in active_contracts:
        # Check if contract is complete based on actions
        if contract.actions_completed >= contract.total_actions_required:
            user_actions = contract.action_contributions.get(user_id_str, 0)
            total_actions = sum(contract.action_contributions.values())
            proportional_reward = int((user_actions / total_actions) * contract.reward_pool) if total_actions > 0 else 0
            
            ready_to_complete.append({
                "id": contract.id,
                "kingdom_name": contract.kingdom_name,
                "building_type": contract.building_type,
                "building_level": contract.building_level,
                "reward": proportional_reward
            })
            
            notifications.append({
                "type": "contract_ready",
                "priority": "high",
                "title": "Contract Complete!",
                "message": f"{contract.building_type} in {contract.kingdom_name} is ready",
                "action": "complete_contract",
                "action_id": contract.id,
                "created_at": datetime.utcnow().isoformat()
            })
        else:
                remaining_hours = hours_needed - elapsed
                progress = elapsed / hours_needed
                in_progress.append({
                    "id": contract.id,
                    "kingdom_name": contract.kingdom_name,
                    "building_type": contract.building_type,
                    "progress": min(progress, 1.0),
                    "hours_remaining": remaining_hours
                })
    
    # ===== Check kingdoms you rule =====
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).all()
    
    kingdom_updates = []
    for kingdom in ruled_kingdoms:
        # Check for open contracts in your kingdoms
        open_contracts_count = db.query(Contract).filter(
            Contract.kingdom_id == kingdom.id,
            Contract.status == "open"
        ).count()
        
        # Check treasury
        kingdom_updates.append({
            "id": kingdom.id,
            "name": kingdom.name,
            "level": kingdom.level,
            "population": kingdom.population,
            "treasury": kingdom.treasury_gold,
            "open_contracts": open_contracts_count
        })
        
        # Notify if treasury is high
        if kingdom.treasury_gold > 1000:
            notifications.append({
                "type": "treasury_full",
                "priority": "medium",
                "title": f"{kingdom.name} Treasury",
                "message": f"Treasury has {kingdom.treasury_gold} gold available",
                "action": "view_kingdom",
                "action_id": kingdom.id,
                "created_at": datetime.utcnow().isoformat()
            })
    
    # ===== Check for level up available =====
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        notifications.append({
            "type": "level_up",
            "priority": "high",
            "title": "Level Up Available!",
            "message": f"You have enough XP to reach level {state.level + 1}",
            "action": "level_up",
            "action_id": None,
            "created_at": datetime.utcnow().isoformat()
        })
    
    # ===== Check for available skill points =====
    if state.skill_points > 0:
        notifications.append({
            "type": "skill_points",
            "priority": "medium",
            "title": "Skill Points Available",
            "message": f"You have {state.skill_points} skill points to spend",
            "action": "view_character",
            "action_id": None,
            "created_at": datetime.utcnow().isoformat()
        })
    
    # ===== Check for check-in availability =====
    if state.current_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == current_user.id,
            UserKingdom.kingdom_id == state.current_kingdom_id
        ).first()
        
        if user_kingdom and user_kingdom.last_checkin:
            cooldown = timedelta(minutes=5) if DEV_MODE else timedelta(hours=1)
            time_since = datetime.utcnow() - user_kingdom.last_checkin
            
            if time_since >= cooldown:
                notifications.append({
                    "type": "checkin_ready",
                    "priority": "low",
                    "title": "Check-in Available",
                    "message": "You can check in to earn rewards",
                    "action": "checkin",
                    "action_id": state.current_kingdom_id,
                    "created_at": datetime.utcnow().isoformat()
                })
    
    # ===== Summary stats =====
    summary = {
        "gold": state.gold,
        "level": state.level,
        "experience": state.experience,
        "xp_to_next_level": xp_needed - state.experience,
        "skill_points": state.skill_points,
        "reputation": state.reputation,
        "kingdoms_ruled": len(ruled_kingdoms),
        "active_contracts": len(in_progress),
        "ready_contracts": len(ready_to_complete)
    }
    
    return {
        "success": True,
        "summary": summary,
        "notifications": sorted(notifications, key=lambda x: {"high": 0, "medium": 1, "low": 2}[x["priority"]]),
        "contracts": {
            "ready_to_complete": ready_to_complete,
            "in_progress": in_progress
        },
        "kingdoms": kingdom_updates,
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
    state = get_player_state(db, current_user)
    
    # Count ready contracts where user has contributed
    all_contracts = db.query(Contract).filter(
        Contract.status.in_(["open", "in_progress"])
    ).all()
    
    user_id_str = str(current_user.id)
    active_contracts = [c for c in all_contracts if user_id_str in (c.action_contributions or {})]
    
    ready_count = 0
    for contract in active_contracts:
        if contract.actions_completed >= contract.total_actions_required:
            ready_count += 1
    
    return {
        "ready_contracts": ready_count,
        "active_contracts": len(active_contracts),
        "skill_points": state.skill_points,
        "unread_notifications": ready_count + (1 if state.skill_points > 0 else 0)
    }

