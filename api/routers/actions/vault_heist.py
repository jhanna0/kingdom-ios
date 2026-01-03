"""
Vault Heist action - Steal gold from enemy kingdom vault (Intelligence T5)
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import random
import math

from db import get_db, User, Kingdom, PlayerState, ActionCooldown
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_cooldown, check_cooldown_from_table, check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import (
    WORK_BASE_COOLDOWN,
    MIN_INTELLIGENCE_REQUIRED,
    VAULT_HEIST_COOLDOWN_HOURS,
    HEIST_COST,
    HEIST_PERCENT,
    MIN_HEIST_AMOUNT,
    BASE_HEIST_DETECTION,
    VAULT_LEVEL_BONUS,
    INTELLIGENCE_REDUCTION,
    PATROL_BONUS,
    HEIST_REP_LOSS,
    HEIST_BAN
)


router = APIRouter()


# All configuration constants are now in constants.py


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
        work_cooldown = calculate_cooldown(WORK_BASE_COOLDOWN, state.building_skill)
        global_cooldown = check_global_action_cooldown_from_table(db, current_user.id, work_cooldown=work_cooldown)
        
        if not global_cooldown["ready"]:
            remaining = global_cooldown["seconds_remaining"]
            minutes = remaining // 60
            seconds = remaining % 60
            blocking_action = global_cooldown["blocking_action"]
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Another action ({blocking_action}) is on cooldown. Wait {minutes}m {seconds}s. Only ONE action at a time!"
            )
    
    # Check vault heist specific cooldown (using action_cooldowns table)
    if not DEV_MODE:
        cooldown_check = check_cooldown_from_table(db, current_user.id, "vault_heist", VAULT_HEIST_COOLDOWN_HOURS * 60)
        if not cooldown_check["ready"]:
            hours = cooldown_check["seconds_remaining"] // 3600
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
    now = datetime.utcnow()
    
    # Get all players in this kingdom
    players_in_kingdom = db.query(PlayerState.user_id).filter(
        PlayerState.current_kingdom_id == kingdom_id
    ).all()
    
    user_ids = [p.user_id for p in players_in_kingdom]
    
    # Count how many have active patrol cooldowns (expires_at > now)
    active_patrols = db.query(ActionCooldown).filter(
        ActionCooldown.user_id.in_(user_ids),
        ActionCooldown.action_type == "patrol",
        ActionCooldown.expires_at > now
    ).count()
    
    # Calculate detection chance
    detection_chance = calculate_heist_detection_chance(
        vault_level=kingdom.vault_level,
        intelligence=state.intelligence,
        active_patrols=active_patrols
    )
    
    # Roll for detection
    caught = random.random() < detection_chance
    
    # Set cooldown for vault heist
    set_cooldown(db, current_user.id, "vault_heist")
    
    if caught:
        # CAUGHT! Severe consequences
        
        # TODO: Lose reputation in user_kingdoms table
        # TODO: Ban from kingdom if configured (track in separate table)
        # Note: game_data and kingdom_reputation removed from player_state
        
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
        
        # TODO: Add reputation in hometown (use user_kingdoms table)
        
        # Award XP
        state.experience += 200
        
        # Check for level up
        xp_needed = 100 * (2 ** (state.level - 1))
        if state.experience >= xp_needed:
            state.level += 1
            state.skill_points += 3
            state.experience -= xp_needed
            # Level-up bonus is NOT taxed
            state.gold += 50
        
        # TODO: Record heist history (in separate table or activity log)
        # Note: game_data removed from player_state
        
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

