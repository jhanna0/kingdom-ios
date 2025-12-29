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
    """Get cooldown status for all actions AND available contracts in current kingdom"""
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
    training_cooldown = 120  # 2 hours for training actions
    
    # Count active patrollers in current kingdom
    active_patrollers = 0
    if state.current_kingdom_id:
        active_patrollers = db.query(PlayerState).filter(
            PlayerState.current_kingdom_id == state.current_kingdom_id,
            PlayerState.patrol_expires_at > datetime.utcnow()
        ).count()
    
    # Get contracts for current kingdom
    contracts = []
    if state.current_kingdom_id:
        from routers.contracts import contract_to_response
        contracts_query = db.query(Contract).filter(
            Contract.kingdom_id == state.current_kingdom_id,
            Contract.status.in_(["open", "in_progress"])
        ).all()
        contracts = [contract_to_response(c) for c in contracts_query]
    
    return {
        "work": {
            **check_cooldown(state.last_work_action, work_cooldown),
            "cooldown_minutes": work_cooldown
        },
        "patrol": {
            **check_cooldown(state.last_patrol_action, patrol_cooldown),
            "cooldown_minutes": patrol_cooldown,
            "is_patrolling": state.patrol_expires_at and state.patrol_expires_at > datetime.utcnow(),
            "active_patrollers": active_patrollers
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
        },
        "train_attack": {
            **check_cooldown(state.last_train_attack_action, training_cooldown),
            "cooldown_minutes": training_cooldown,
            "current_stat": state.attack_power,
            "sessions_available": state.training_sessions_attack,
            "purchase_cost": calculate_training_cost(state.attack_power)
        },
        "train_defense": {
            **check_cooldown(state.last_train_defense_action, training_cooldown),
            "cooldown_minutes": training_cooldown,
            "current_stat": state.defense_power,
            "sessions_available": state.training_sessions_defense,
            "purchase_cost": calculate_training_cost(state.defense_power)
        },
        "train_leadership": {
            **check_cooldown(state.last_train_leadership_action, training_cooldown),
            "cooldown_minutes": training_cooldown,
            "current_stat": state.leadership,
            "sessions_available": state.training_sessions_leadership,
            "purchase_cost": calculate_training_cost(state.leadership)
        },
        "train_building": {
            **check_cooldown(state.last_train_building_action, training_cooldown),
            "cooldown_minutes": training_cooldown,
            "current_stat": state.building_skill,
            "sessions_available": state.training_sessions_building,
            "purchase_cost": calculate_training_cost(state.building_skill)
        },
        "contracts": contracts
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
    
    if contract.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contract is already completed"
        )
    
    # Check if user is checked into the kingdom
    if state.current_kingdom_id != contract.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into the kingdom to work on contracts"
        )
    
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
    
    # Calculate reward per action (gold per action = reward_pool / total_actions_required)
    gold_per_action = contract.reward_pool / contract.total_actions_required
    gold_earned = int(gold_per_action)
    
    # Award gold only for this action
    state.gold += gold_earned
    
    # Check if contract is complete
    is_complete = contract.actions_completed >= contract.total_actions_required
    
    if is_complete:
        contract.status = "completed"
        contract.completed_at = datetime.utcnow()
        
        # Mark contract as completed for all contributors
        for worker_id_str in contributions.keys():
            worker_id = int(worker_id_str)
            worker_state = db.query(PlayerState).filter(PlayerState.user_id == worker_id).first()
            if worker_state:
                worker_state.contracts_completed += 1
        
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
            "gold": gold_earned,
            "experience": None,
            "reputation": None,
            "iron": None
        }
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
    
    # Award reputation for patrol (civic duty)
    rep_earned = 10
    state.reputation += rep_earned
    
    db.commit()
    
    return {
        "success": True,
        "message": "Patrol started! Guard duty for 10 minutes.",
        "expires_at": format_datetime_iso(state.patrol_expires_at),
        "rewards": {
            "gold": None,
            "reputation": rep_earned,
            "experience": None,
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


# ===== Training Actions =====

def calculate_training_cost(stat_level: int) -> int:
    """Calculate gold cost to purchase training based on current stat level
    
    Formula: 100 * (level^1.5)
    Level 1→2: 100g
    Level 5→6: 559g
    Level 10→11: 1581g
    """
    return int(100.0 * pow(float(stat_level), 1.5))


# ===== Purchase Training Sessions =====

@router.post("/train/attack/purchase")
def purchase_attack_training(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase an attack training session (costs gold)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Calculate gold cost
    training_cost = calculate_training_cost(state.attack_power)
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    # Purchase training session
    state.gold -= training_cost
    state.training_sessions_attack += 1
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased attack training session for {training_cost}g",
        "training_type": "attack",
        "cost": training_cost,
        "sessions_available": state.training_sessions_attack
    }


@router.post("/train/attack")
def train_attack(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Perform attack training (requires purchased session, 2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if user has a training session
    if state.training_sessions_attack <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No attack training sessions available. Purchase one first!"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_train_attack_action, 120)  # 2 hours
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        minutes = (cooldown_status["seconds_remaining"] % 3600) // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Training on cooldown. Wait {hours}h {minutes}m"
        )
    
    # Check if user is checked in
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to train"
        )
    
    # Consume session and train!
    state.training_sessions_attack -= 1
    state.attack_power += 1
    state.last_train_attack_action = datetime.utcnow()
    
    # Award XP for training
    xp_earned = 25
    state.experience += xp_earned
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50  # Bonus gold on level up
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Combat training complete! Attack Power increased to {state.attack_power}",
        "stat_type": "attack",
        "new_value": state.attack_power,
        "sessions_remaining": state.training_sessions_attack,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }


@router.post("/train/defense/purchase")
def purchase_defense_training(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a defense training session (costs gold)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    training_cost = calculate_training_cost(state.defense_power)
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    state.gold -= training_cost
    state.training_sessions_defense += 1
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased defense training session for {training_cost}g",
        "training_type": "defense",
        "cost": training_cost,
        "sessions_available": state.training_sessions_defense
    }


@router.post("/train/defense")
def train_defense(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Perform defense training (requires purchased session, 2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if state.training_sessions_defense <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No defense training sessions available. Purchase one first!"
        )
    
    cooldown_status = check_cooldown(state.last_train_defense_action, 120)
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        minutes = (cooldown_status["seconds_remaining"] % 3600) // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Training on cooldown. Wait {hours}h {minutes}m"
        )
    
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to train"
        )
    
    state.training_sessions_defense -= 1
    state.defense_power += 1
    state.last_train_defense_action = datetime.utcnow()
    
    xp_earned = 25
    state.experience += xp_earned
    
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Defense training complete! Defense Power increased to {state.defense_power}",
        "stat_type": "defense",
        "new_value": state.defense_power,
        "sessions_remaining": state.training_sessions_defense,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }


@router.post("/train/leadership/purchase")
def purchase_leadership_training(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a leadership training session (costs gold)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    training_cost = calculate_training_cost(state.leadership)
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    state.gold -= training_cost
    state.training_sessions_leadership += 1
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased leadership training session for {training_cost}g",
        "training_type": "leadership",
        "cost": training_cost,
        "sessions_available": state.training_sessions_leadership
    }


@router.post("/train/leadership")
def train_leadership(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Perform leadership training (requires purchased session, 2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if state.training_sessions_leadership <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No leadership training sessions available. Purchase one first!"
        )
    
    cooldown_status = check_cooldown(state.last_train_leadership_action, 120)
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        minutes = (cooldown_status["seconds_remaining"] % 3600) // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Training on cooldown. Wait {hours}h {minutes}m"
        )
    
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to train"
        )
    
    state.training_sessions_leadership -= 1
    state.leadership += 1
    state.last_train_leadership_action = datetime.utcnow()
    
    xp_earned = 25
    state.experience += xp_earned
    
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Leadership training complete! Leadership increased to {state.leadership}",
        "stat_type": "leadership",
        "new_value": state.leadership,
        "sessions_remaining": state.training_sessions_leadership,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }


@router.post("/train/building/purchase")
def purchase_building_training(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a building training session (costs gold)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    training_cost = calculate_training_cost(state.building_skill)
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    state.gold -= training_cost
    state.training_sessions_building += 1
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased building training session for {training_cost}g",
        "training_type": "building",
        "cost": training_cost,
        "sessions_available": state.training_sessions_building
    }


@router.post("/train/building")
def train_building(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Perform building training (requires purchased session, 2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if state.training_sessions_building <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No building training sessions available. Purchase one first!"
        )
    
    cooldown_status = check_cooldown(state.last_train_building_action, 120)
    if not DEV_MODE and not cooldown_status["ready"]:
        hours = cooldown_status["seconds_remaining"] // 3600
        minutes = (cooldown_status["seconds_remaining"] % 3600) // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Training on cooldown. Wait {hours}h {minutes}m"
        )
    
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to train"
        )
    
    state.training_sessions_building -= 1
    state.building_skill += 1
    state.last_train_building_action = datetime.utcnow()
    
    xp_earned = 25
    state.experience += xp_earned
    
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Building training complete! Building Skill increased to {state.building_skill}",
        "stat_type": "building",
        "new_value": state.building_skill,
        "sessions_remaining": state.training_sessions_building,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }

