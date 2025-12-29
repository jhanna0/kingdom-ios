"""
Action endpoints - User actions with cooldowns
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Dict
import math

from db import get_db, User, PlayerState, Kingdom, Contract
from routers.auth import get_current_user
from config import DEV_MODE


def format_datetime_iso(dt: datetime) -> str:
    """Format datetime as ISO8601 with Z suffix for UTC"""
    if dt is None:
        return None
    return dt.strftime('%Y-%m-%dT%H:%M:%S.%fZ')


router = APIRouter(prefix="/actions", tags=["actions"])


def calculate_cooldown(base_minutes: float, skill_level: int) -> float:
    """Calculate action cooldown based on skill level
    
    Args:
        base_minutes: Base cooldown in minutes (e.g., 120 for 2 hours)
        skill_level: Player's relevant skill level
    
    Returns:
        Adjusted cooldown in minutes
    """
    # Each skill level reduces cooldown by 5%
    # Formula: base * (0.95 ^ skill_level)
    # Level 1: 100%, Level 5: 77%, Level 10: 60%, Level 20: 36%
    reduction = math.pow(0.95, skill_level - 1)
    return base_minutes * reduction


def check_cooldown(last_action: datetime, cooldown_minutes: float) -> Dict:
    """Check if action is off cooldown
    
    Returns:
        Dict with 'ready' bool and 'seconds_remaining' int
    """
    if not last_action:
        return {"ready": True, "seconds_remaining": 0}
    
    elapsed = (datetime.utcnow() - last_action).total_seconds()
    required = cooldown_minutes * 60
    
    if elapsed >= required:
        return {"ready": True, "seconds_remaining": 0}
    
    remaining = int(required - elapsed)
    return {"ready": False, "seconds_remaining": remaining}


# ===== Get Action Status =====

@router.get("/status")
def get_action_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get cooldown status for all actions"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Calculate cooldowns based on skills
    work_cooldown = calculate_cooldown(120, state.building_skill)  # Base 2 hours
    patrol_cooldown = 10  # Always 10 minutes
    sabotage_cooldown = 1440  # 24 hours (once per day)
    mine_cooldown = 1440  # 24 hours (once per day)
    scout_cooldown = 1440  # 24 hours (once per day)
    
    return {
        "work": {
            **check_cooldown(state.last_work_action, work_cooldown),
            "cooldown_minutes": work_cooldown
        },
        "patrol": {
            **check_cooldown(state.last_patrol_action, patrol_cooldown),
            "cooldown_minutes": patrol_cooldown,
            "is_patrolling": state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow()
        },
        "sabotage": {
            **check_cooldown(state.last_sabotage_action, sabotage_cooldown),
            "cooldown_minutes": sabotage_cooldown
        },
        "mine": {
            **check_cooldown(state.last_mining_action, mine_cooldown),
            "cooldown_minutes": mine_cooldown
        },
        "scout": {
            **check_cooldown(state.last_scout_action, scout_cooldown),
            "cooldown_minutes": scout_cooldown
        }
    }


# ===== Work on Contract =====

@router.post("/work/{contract_id}")
def work_on_contract(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Contribute one action to a contract (base 2hr cooldown, reduced by building skill)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_minutes = calculate_cooldown(120, state.building_skill)
    cooldown_status = check_cooldown(state.last_work_action, cooldown_minutes)
    
    if not DEV_MODE and not cooldown_status["ready"]:
        remaining = cooldown_status["seconds_remaining"]
        minutes = remaining // 60
        seconds = remaining % 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Work action on cooldown. Wait {minutes}m {seconds}s"
        )
    
    # Get contract
    contract = db.query(Contract).filter(Contract.id == contract_id).first()
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contract not found"
        )
    
    if contract.status not in ["open", "in_progress"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is not accepting work"
        )
    
    # Check if user is checked into the kingdom
    if state.current_kingdom_id != contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the kingdom to work on contracts"
        )
    
    # Add user to workers if not already
    workers = contract.workers or []
    if current_user.id not in workers:
        workers.append(current_user.id)
        contract.workers = workers
        
        # Start work timer if first worker
        if contract.work_started_at is None:
            contract.work_started_at = datetime.utcnow()
            contract.status = "in_progress"
    
    # Increment action count
    contract.actions_completed += 1
    
    # Track contribution per user
    contributions = contract.action_contributions or {}
    user_id_str = str(current_user.id)
    contributions[user_id_str] = contributions.get(user_id_str, 0) + 1
    contract.action_contributions = contributions
    
    # Update player state
    state.last_work_action = datetime.utcnow()
    state.total_work_contributed += 1
    state.active_contract_id = contract_id
    
    # Check if contract is complete
    is_complete = contract.actions_completed >= contract.total_actions_required
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Distribute rewards based on contribution
        total_contributions = sum(contributions.values())
        
        # DEV MODE: Boost rewards
        rep_bonus = 100 if DEV_MODE else 10
        
        for worker_id_str, contribution_count in contributions.items():
            worker_id = int(worker_id_str)
            worker_state = db.query(PlayerState).filter(PlayerState.user_id == worker_id).first()
            if worker_state:
                # Proportional reward based on contribution
                reward = int((contribution_count / total_contributions) * contract.reward_pool)
                worker_state.gold += reward
                worker_state.contracts_completed += 1
                worker_state.active_contract_id = None
                worker_state.reputation += rep_bonus
        
        # Upgrade the building
        kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
        if kingdom:
            building_attr = f"{contract.building_type.lower()}_level"
            if hasattr(kingdom, building_attr):
                current_level = getattr(kingdom, building_attr, 0)
                setattr(kingdom, building_attr, current_level + 1)
    
    db.commit()
    db.refresh(contract)
    
    progress_percent = int((contract.actions_completed / contract.total_actions_required) * 100)
    user_contribution = contributions.get(user_id_str, 0)
    
    # Calculate rewards for this action (only if contract completed)
    gold_earned = 0
    rep_earned = 0
    if is_complete:
        # User's proportional reward
        gold_earned = int((user_contribution / sum(contributions.values())) * contract.reward_pool)
        rep_earned = 100 if DEV_MODE else 10
    
    return {
        "success": True,
        "message": "Work action completed! +1 action" + (" - Contract complete!" if is_complete else ""),
        "contract_id": contract_id,
        "actions_completed": contract.actions_completed,
        "total_actions_required": contract.total_actions_required,
        "progress_percent": progress_percent,
        "your_contribution": user_contribution,
        "is_complete": is_complete,
        "next_work_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=cooldown_minutes)),
        "rewards": {
            "gold": gold_earned if gold_earned > 0 else None,
            "reputation": rep_earned if rep_earned > 0 else None,
            "iron": None
        } if is_complete else None
    }


# ===== Patrol =====

@router.post("/patrol")
def start_patrol(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start a 10-minute patrol to guard against saboteurs"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if already patrolling
    if state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow():
        remaining = int((state.patrol_expires_at - datetime.utcnow()).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Already on patrol. {remaining}s remaining"
        )
    
    # Check cooldown (can patrol again after previous one expires)
    cooldown_status = check_cooldown(state.last_patrol_action, 10)
    if not DEV_MODE and not cooldown_status["ready"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Patrol on cooldown. Wait {cooldown_status['seconds_remaining']}s"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to patrol"
        )
    
    # Start patrol
    state.last_patrol_action = datetime.utcnow()
    state.patrol_expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    # Award gold and reputation for patrol
    state.gold += 5
    state.reputation += 5
    
    db.commit()
    
    return {
        "success": True,
        "message": "Patrol started! Guard duty for 10 minutes.",
        "expires_at": format_datetime_iso(state.patrol_expires_at),
        "rewards": {
            "gold": 5,
            "reputation": 5,
            "iron": None
        }
    }


# ===== Mine Resources =====

@router.post("/mine")
def mine_resources(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mine resources (once per day)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_mining_action, 1440)  # 24 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Mining on cooldown. Wait {hours}h"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to mine"
        )
    
    # Get kingdom to check mine level
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Calculate rewards based on mine level
    mine_level = kingdom.mine_level or 0
    base_gold = 20 * mine_level if mine_level > 0 else 10  # Level 0: 10 gold, Level 1: 20, Level 2: 40, etc.
    base_rep = 5  # Fixed reputation reward
    
    # Update player resources
    state.gold += base_gold
    state.reputation += base_rep
    state.last_mining_action = datetime.utcnow()
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Mining complete!",
        "next_mine_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=24)),
        "rewards": {
            "gold": base_gold,
            "reputation": base_rep,
            "iron": None
        }
    }


# ===== Scout Enemy Kingdom =====

@router.post("/scout/{kingdom_id}")
def scout_kingdom(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Scout an enemy kingdom to gather intelligence (once per day)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_scout_action, 1440)  # 24 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Scouting on cooldown. Wait {hours}h"
        )
    
    # Check if user is checked into the target kingdom
    if state.current_kingdom_id != kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the target kingdom to scout"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Update player state
    state.last_scout_action = datetime.utcnow()
    
    # Give gold reward for successful scouting
    state.gold += 10
    
    db.commit()
    
    # Return intelligence
    return {
        "success": True,
        "message": f"Scouted {kingdom.name}!",
        "intelligence": {
            "kingdom_name": kingdom.name,
            "ruler_name": kingdom.ruler_name,
            "wall_level": kingdom.wall_level,
            "vault_level": kingdom.vault_level,
            "mine_level": kingdom.mine_level,
            "market_level": kingdom.market_level,
            "treasury_gold": kingdom.treasury_gold,
            "checked_in_players": kingdom.checked_in_players,
            "population": kingdom.population
        },
        "next_scout_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=24)),
        "rewards": {
            "gold": 10,  # Small reward for scouting
            "reputation": None,
            "iron": None
        }
    }

