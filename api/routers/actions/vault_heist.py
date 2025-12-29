"""
Vault Heist action - Steal gold from enemy kingdom vault (Intelligence T5)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import random
import math

from db import get_db, User, Kingdom, PlayerState
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, check_global_action_cooldown, format_datetime_iso, calculate_cooldown


router = APIRouter()


# ==========================================
# VAULT HEIST CONFIGURATION
# ==========================================

# Requirements
MIN_INTELLIGENCE_REQUIRED = 5       # Must have Intelligence T5 to attempt
VAULT_HEIST_COOLDOWN_HOURS = 168   # Once per week (7 days)

# Economic balance
HEIST_COST = 1000                   # Gold cost to attempt heist
HEIST_PERCENT = 0.10                # Steal 10% of vault
MIN_HEIST_AMOUNT = 500              # Minimum vault size to target

# Detection mechanics
BASE_HEIST_DETECTION = 0.3          # 30% base detection chance
VAULT_LEVEL_BONUS = 0.05            # +5% detection per vault level
INTELLIGENCE_REDUCTION = 0.04       # -4% detection per intelligence above 5
PATROL_BONUS = 0.02                 # +2% detection per active patrol

# Consequences
HEIST_REP_LOSS = 500                # Reputation lost in target kingdom when caught
HEIST_BAN = True                    # Whether to ban from kingdom when caught

# ==========================================


def calculate_heist_detection_chance(
    vault_level: int,
    intelligence: int,
    active_patrols: int
) -> float:
    """
    Calculate chance of being caught during vault heist
    
    Formula:
    - Base detection: 30%
    - Vault level: +5% per level
    - Intelligence: -4% per level above 5
    - Patrols: +2% per active patrol
    
    Returns: probability of being caught (0.0 to 1.0)
    """
    # Base chance
    detection_chance = BASE_HEIST_DETECTION
    
    # Vault security bonus
    detection_chance += vault_level * VAULT_LEVEL_BONUS
    
    # Intelligence reduction (only levels above 5)
    intel_above_5 = max(0, intelligence - 5)
    detection_chance -= intel_above_5 * INTELLIGENCE_REDUCTION
    
    # Patrol bonus
    detection_chance += active_patrols * PATROL_BONUS
    
    # Clamp between 1% and 95%
    return max(0.01, min(0.95, detection_chance))


@router.post("/vault-heist/{kingdom_id}")
def attempt_vault_heist(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Attempt to steal 10% of a kingdom's vault (Intelligence T5 required)
    
    High-stakes action with:
    - Significant gold cost upfront
    - Week-long cooldown
    - Detection based on vault level, intelligence, and patrols
    - Severe consequences if caught (ban + reputation loss)
    - Requires being in the target kingdom
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check intelligence requirement
    if state.intelligence < MIN_INTELLIGENCE_REQUIRED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Intelligence level {MIN_INTELLIGENCE_REQUIRED} required for vault heists"
        )
    
    # GLOBAL ACTION LOCK: Check if ANY action is on cooldown
    if not DEV_MODE:
        work_cooldown = calculate_cooldown(120, state.building_skill)
        global_cooldown = check_global_action_cooldown(
            state, 
            work_cooldown=work_cooldown,
            patrol_cooldown=10,
            sabotage_cooldown=1440,
            mine_cooldown=1440,
            scout_cooldown=1440,
            training_cooldown=120
        )
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Check vault heist specific cooldown
    last_heist = None
    if state.game_data and isinstance(state.game_data, dict):
        last_heist_str = state.game_data.get("last_vault_heist")
        if last_heist_str:
            try:
                last_heist = datetime.fromisoformat(last_heist_str.replace('Z', '+00:00'))
            except:
                pass
    
    if last_heist:
        cooldown_status = check_cooldown(last_heist, VAULT_HEIST_COOLDOWN_HOURS * 60)
        if not DEV_MODE and not cooldown_status["ready"]:
            hours = cooldown_status["seconds_remaining"] // 3600
            days = hours // 24
            hours = hours % 24
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Vault heist on cooldown. Wait {days}d {hours}h"
            )
    
    # Check gold cost
    if state.gold < HEIST_COST:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough gold. Heist costs {HEIST_COST}g"
        )
    
    # Get target kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if player is in the kingdom
    if state.current_kingdom_id != kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into target kingdom to attempt heist"
        )
    
    # Check if it's their own kingdom
    if kingdom.ruler_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot steal from your own kingdom"
        )
    
    # Check minimum vault amount
    heist_amount = int(kingdom.treasury_gold * HEIST_PERCENT)
    if heist_amount < MIN_HEIST_AMOUNT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kingdom vault has insufficient gold (min {MIN_HEIST_AMOUNT}g for heist)"
        )
    
    # Deduct heist cost
    state.gold -= HEIST_COST
    
    # Count active patrols
    active_patrols = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == kingdom_id,
        PlayerState.patrol_expires_at > datetime.utcnow()
    ).count()
    
    # Calculate detection chance
    detection_chance = calculate_heist_detection_chance(
        vault_level=kingdom.vault_level,
        intelligence=state.intelligence,
        active_patrols=active_patrols
    )
    
    # Roll for detection
    caught = random.random() < detection_chance
    
    # Update last heist time
    game_data = state.game_data or {}
    game_data["last_vault_heist"] = datetime.utcnow().isoformat()
    
    if caught:
        # CAUGHT! Severe consequences
        
        # Lose reputation
        kingdom_rep = state.kingdom_reputation or {}
        current_rep = kingdom_rep.get(kingdom_id, 0)
        kingdom_rep[kingdom_id] = current_rep - HEIST_REP_LOSS
        state.kingdom_reputation = kingdom_rep
        
        # Ban from kingdom if configured
        if HEIST_BAN:
            banned_kingdoms = game_data.get("banned_from_kingdoms", [])
            if kingdom_id not in banned_kingdoms:
                banned_kingdoms.append(kingdom_id)
            game_data["banned_from_kingdoms"] = banned_kingdoms
        
        # Record in game data
        if "heist_history" not in game_data:
            game_data["heist_history"] = []
        
        game_data["heist_history"].append({
            "kingdom_id": kingdom_id,
            "kingdom_name": kingdom.name,
            "timestamp": datetime.utcnow().isoformat(),
            "caught": True,
            "cost": HEIST_COST,
            "detection_chance": detection_chance
        })
        
        state.game_data = game_data
        db.commit()
        
        return {
            "success": False,
            "caught": True,
            "message": f"Caught attempting to rob the vault! Lost {HEIST_REP_LOSS} reputation and banned from {kingdom.name}.",
            "detection_chance": round(detection_chance * 100, 1),
            "cost_paid": HEIST_COST,
            "reputation_lost": HEIST_REP_LOSS,
            "banned": HEIST_BAN,
            "next_heist_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=VAULT_HEIST_COOLDOWN_HOURS))
        }
    
    else:
        # SUCCESS! Steal the gold
        
        # Transfer gold
        kingdom.treasury_gold -= heist_amount
        state.gold += heist_amount
        
        # Add reputation in hometown
        if state.hometown_kingdom_id and state.hometown_kingdom_id != kingdom_id:
            kingdom_rep = state.kingdom_reputation or {}
            hometown_rep = kingdom_rep.get(state.hometown_kingdom_id, 0)
            kingdom_rep[state.hometown_kingdom_id] = hometown_rep + 100
            state.kingdom_reputation = kingdom_rep
        
        # Award XP
        state.experience += 200
        
        # Check for level up
        xp_needed = 100 * (2 ** (state.level - 1))
        if state.experience >= xp_needed:
            state.level += 1
            state.skill_points += 3
            state.experience -= xp_needed
            state.gold += 50
        
        # Record in game data
        if "heist_history" not in game_data:
            game_data["heist_history"] = []
        
        game_data["heist_history"].append({
            "kingdom_id": kingdom_id,
            "kingdom_name": kingdom.name,
            "timestamp": datetime.utcnow().isoformat(),
            "caught": False,
            "cost": HEIST_COST,
            "stolen": heist_amount,
            "detection_chance": detection_chance
        })
        
        if "total_gold_stolen" not in game_data:
            game_data["total_gold_stolen"] = 0
        game_data["total_gold_stolen"] += heist_amount
        
        if "successful_heists" not in game_data:
            game_data["successful_heists"] = 0
        game_data["successful_heists"] += 1
        
        state.game_data = game_data
        db.commit()
        
        return {
            "success": True,
            "caught": False,
            "message": f"Successfully stole {heist_amount}g from {kingdom.name}'s vault!",
            "gold_stolen": heist_amount,
            "detection_chance": round(detection_chance * 100, 1),
            "cost_paid": HEIST_COST,
            "net_profit": heist_amount - HEIST_COST,
            "reputation_gained": 100,
            "experience_gained": 200,
            "next_heist_available_at": format_datetime_iso(datetime.utcnow() + timedelta(hours=VAULT_HEIST_COOLDOWN_HOURS))
        }

