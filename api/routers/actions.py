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
        "training": {
            **check_cooldown(state.last_training_action, training_cooldown),
            "cooldown_minutes": training_cooldown
        },
        "training_contracts": state.training_contracts or [],
        "training_costs": {
            "attack": calculate_training_cost(state.attack_power),
            "defense": calculate_training_cost(state.defense_power),
            "leadership": calculate_training_cost(state.leadership),
            "building": calculate_training_cost(state.building_skill)
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


def calculate_training_actions_required(stat_level: int) -> int:
    """Calculate how many actions required to complete training
    
    Formula: 3 + (level // 3)
    Level 1: 3 actions
    Level 5: 4 actions
    Level 10: 6 actions
    Scales with stat level - higher stats take more work
    """
    return 3 + (stat_level // 3)


# ===== Purchase Training Contracts =====

@router.post("/train/purchase")
def purchase_training(
    training_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Purchase a training contract (works like building contracts)
    
    Args:
        training_type: "attack", "defense", "leadership", or "building"
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Validate training type
    valid_types = ["attack", "defense", "leadership", "building"]
    if training_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid training type. Must be one of: {', '.join(valid_types)}"
        )
    
    # Get current stat level
    stat_map = {
        "attack": state.attack_power,
        "defense": state.defense_power,
        "leadership": state.leadership,
        "building": state.building_skill
    }
    current_stat = stat_map[training_type]
    
    # Calculate cost and actions required
    training_cost = calculate_training_cost(current_stat)
    actions_required = calculate_training_actions_required(current_stat)
    
    if state.gold < training_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Need {training_cost}g, have {state.gold}g"
        )
    
    # Check if already have a contract for this type
    training_contracts = state.training_contracts or []
    for contract in training_contracts:
        if contract.get("type") == training_type and contract.get("status") != "completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Already have an active {training_type} training contract"
            )
    
    # Create training contract
    import uuid
    contract_id = str(uuid.uuid4())
    new_contract = {
        "id": contract_id,
        "type": training_type,
        "actions_required": actions_required,
        "actions_completed": 0,
        "cost_paid": training_cost,
        "created_at": datetime.utcnow().isoformat(),
        "status": "in_progress"
    }
    
    # Add contract and spend gold
    training_contracts.append(new_contract)
    state.training_contracts = training_contracts
    state.gold -= training_cost
    
    db.commit()
    
    return {
        "success": True,
        "message": f"Purchased {training_type} training! Complete {actions_required} actions to improve stat.",
        "training_type": training_type,
        "cost": training_cost,
        "contract_id": contract_id,
        "actions_required": actions_required
    }


@router.post("/train/{contract_id}")
def work_on_training(
    contract_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Work on a training contract (2 hour cooldown, like building contracts)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check cooldown
    cooldown_status = check_cooldown(state.last_training_action, 120)  # 2 hours
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
    
    # Find the training contract
    training_contracts = state.training_contracts or []
    contract = None
    contract_index = None
    for i, c in enumerate(training_contracts):
        if c.get("id") == contract_id:
            contract = c
            contract_index = i
            break
    
    if not contract:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Training contract not found"
        )
    
    if contract.get("status") == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Training contract already completed"
        )
    
    # Increment actions completed
    contract["actions_completed"] = contract.get("actions_completed", 0) + 1
    state.last_training_action = datetime.utcnow()
    
    # Check if training is complete
    is_complete = contract["actions_completed"] >= contract["actions_required"]
    
    # Award XP for each action
    xp_earned = 10  # 10 XP per training action
    state.experience += xp_earned
    
    if is_complete:
        contract["status"] = "completed"
        contract["completed_at"] = datetime.utcnow().isoformat()
        
        # Increase the stat!
        training_type = contract["type"]
        if training_type == "attack":
            state.attack_power += 1
            stat_name = "Attack Power"
            new_value = state.attack_power
        elif training_type == "defense":
            state.defense_power += 1
            stat_name = "Defense Power"
            new_value = state.defense_power
        elif training_type == "leadership":
            state.leadership += 1
            stat_name = "Leadership"
            new_value = state.leadership
        elif training_type == "building":
            state.building_skill += 1
            stat_name = "Building Skill"
            new_value = state.building_skill
        
        # Bonus XP for completing training
        xp_earned += 25  # Total 35 XP when complete
        state.experience += 25
    
    # Check for level up
    xp_needed = 100 * (2 ** (state.level - 1))
    if state.experience >= xp_needed:
        state.level += 1
        state.skill_points += 3
        state.experience -= xp_needed
        state.gold += 50
    
    # Update the contract in the list
    training_contracts[contract_index] = contract
    state.training_contracts = training_contracts
    
    db.commit()
    
    progress_percent = int((contract["actions_completed"] / contract["actions_required"]) * 100)
    
    if is_complete:
        message = f"Training complete! {stat_name} increased to {new_value}!"
    else:
        message = f"Training action completed! {contract['actions_completed']}/{contract['actions_required']} actions done."
    
    return {
        "success": True,
        "message": message,
        "contract_id": contract_id,
        "training_type": contract["type"],
        "actions_completed": contract["actions_completed"],
        "actions_required": contract["actions_required"],
        "progress_percent": progress_percent,
        "is_complete": is_complete,
        "next_train_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=2)),
        "rewards": {
            "gold": None,
            "reputation": None,
            "experience": xp_earned
        }
    }
