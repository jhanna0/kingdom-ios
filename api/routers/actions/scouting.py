"""
Scouting action - Gather intelligence on kingdoms
"""
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from db import get_db, User, Kingdom, Contract
from routers.auth import get_current_user
from config import DEV_MODE
from .utils import check_global_action_cooldown_from_table, format_datetime_iso, calculate_cooldown, set_cooldown
from .constants import WORK_BASE_COOLDOWN, SCOUT_COOLDOWN, SCOUT_GOLD_REWARD, MIN_INTELLIGENCE_REQUIRED
from .tax_utils import apply_kingdom_tax


router = APIRouter()


# Intelligence tier requirements for different information levels
INTEL_TIER_BASIC = 1        # Basic info (name, ruler, population)
INTEL_TIER_BUILDINGS = 2    # Building levels
INTEL_TIER_ECONOMY = 3      # Treasury gold, tax rates
INTEL_TIER_CONTRACTS = 4    # Active contracts (for sabotage)
INTEL_TIER_VAULT = 5        # Vault details (for heist planning)


@router.post("/scout/{kingdom_id}")
def scout_kingdom(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Scout an enemy kingdom to gather intelligence (2 hour cooldown)"""
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
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
    
    # Update cooldown (both new table and legacy column)
    cooldown_expires = datetime.utcnow() + timedelta(minutes=SCOUT_COOLDOWN)
    set_cooldown(db, current_user.id, "scout", cooldown_expires)
    
    # Give gold reward for successful scouting (with tax)
    net_income, tax_amount, tax_rate = apply_kingdom_tax(
        db=db,
        kingdom_id=kingdom_id,
        player_state=state,
        gross_income=SCOUT_GOLD_REWARD
    )
    state.gold += net_income
    
    db.commit()
    
    # Get player's intelligence level
    player_intelligence = state.intelligence
    
    # Build intelligence report based on intelligence level
    intelligence_data = {
        "kingdom_name": kingdom.name,
        "ruler_name": kingdom.ruler_name,
        "population": kingdom.population,
        "checked_in_players": kingdom.checked_in_players,
    }
    
    # Tier 2+: Building levels
    if player_intelligence >= INTEL_TIER_BUILDINGS:
        intelligence_data.update({
            "wall_level": kingdom.wall_level,
            "vault_level": kingdom.vault_level,
            "mine_level": kingdom.mine_level,
            "market_level": kingdom.market_level,
            "farm_level": kingdom.farm_level,
            "education_level": kingdom.education_level,
        })
    
    # Tier 3+: Economic information
    if player_intelligence >= INTEL_TIER_ECONOMY:
        intelligence_data.update({
            "treasury_gold": kingdom.treasury_gold,
            "tax_rate": kingdom.tax_rate,
            "travel_fee": kingdom.travel_fee,
        })
    
    # Tier 4+: Active contracts (for sabotage planning)
    active_contracts = []
    if player_intelligence >= INTEL_TIER_CONTRACTS:
        contracts = db.query(Contract).filter(
            Contract.kingdom_id == kingdom_id,
            Contract.status.in_(["open", "in_progress"])
        ).all()
        
        for contract in contracts:
            progress_percent = int((contract.actions_completed / contract.total_actions_required) * 100)
            active_contracts.append({
                "contract_id": contract.id,
                "building_type": contract.building_type,
                "building_level": contract.building_level,
                "progress": f"{contract.actions_completed}/{contract.total_actions_required}",
                "progress_percent": progress_percent
            })
        
        intelligence_data["active_contracts"] = active_contracts
    
    # Determine available malicious actions based on intelligence and kingdom status
    available_actions = []
    
    # Check if this is their own kingdom
    is_own_kingdom = kingdom.ruler_id == current_user.id
    is_hometown = state.hometown_kingdom_id == kingdom_id
    
    if not is_own_kingdom and not is_hometown:
        # Sabotage available at Tier 4+
        if player_intelligence >= INTEL_TIER_CONTRACTS:
            available_actions.append({
                "action": "sabotage",
                "name": "Sabotage Contract",
                "description": "Delay an active contract by 10%",
                "cost": 300,
                "cooldown_hours": 24,
                "requires_intelligence": INTEL_TIER_CONTRACTS,
                "available": len(active_contracts) > 0
            })
        
        # Vault heist available at Tier 5
        if player_intelligence >= INTEL_TIER_VAULT:
            heist_amount = int(kingdom.treasury_gold * 0.10) if player_intelligence >= INTEL_TIER_ECONOMY else None
            available_actions.append({
                "action": "vault_heist",
                "name": "Vault Heist",
                "description": "Attempt to steal 10% of kingdom vault",
                "cost": 1000,
                "cooldown_hours": 168,  # 7 days
                "requires_intelligence": INTEL_TIER_VAULT,
                "available": kingdom.treasury_gold >= 500 if player_intelligence >= INTEL_TIER_ECONOMY else True,
                "potential_reward": heist_amount
            })
    
    # Return intelligence
    return {
        "success": True,
        "message": f"Scouted {kingdom.name}!",
        "intelligence": intelligence_data,
        "intelligence_level": player_intelligence,
        "available_actions": available_actions,
        "next_scout_available_at": format_datetime_iso(datetime.utcnow() + timedelta(minutes=SCOUT_COOLDOWN)),
        "rewards": {
            "gold": net_income,
            "gold_before_tax": SCOUT_GOLD_REWARD,
            "tax_amount": tax_amount,
            "tax_rate": tax_rate,
            "reputation": None,
            "iron": None,
            "experience": None
        }
    }
