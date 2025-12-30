"""
Intelligence & Military Strength System
- View your own kingdom's military strength
- Gather intelligence on enemy kingdoms
- Share intel with your kingdom
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
from typing import Optional
import random

from db.base import get_db
from db.models import User, Kingdom, PlayerState, KingdomIntelligence
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from config import DEV_MODE

router = APIRouter(prefix="/intelligence", tags=["intelligence"])

# Constants
INTELLIGENCE_COST = 500
INTELLIGENCE_COOLDOWN_HOURS = 24
INTELLIGENCE_EXPIRY_DAYS = 7
MIN_INTELLIGENCE_LEVEL = 3


# ===== Helper Functions =====

def _calculate_total_attack(db: Session, kingdom_id: str) -> int:
    """Calculate total attack power of all active citizens in a kingdom"""
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    
    result = db.query(func.sum(PlayerState.attack_power)).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.last_check_in > cutoff_time,
        PlayerState.is_alive == True
    ).scalar()
    
    return result or 0


def _calculate_total_defense(db: Session, kingdom_id: str) -> int:
    """Calculate total defense power of all active citizens in a kingdom"""
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    
    result = db.query(func.sum(PlayerState.defense_power)).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.last_check_in > cutoff_time,
        PlayerState.is_alive == True
    ).scalar()
    
    return result or 0


def _count_active_citizens(db: Session, kingdom_id: str) -> int:
    """Count active citizens (checked in within 24h)"""
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    
    count = db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.last_check_in > cutoff_time,
        PlayerState.is_alive == True
    ).count()
    
    return count


def _get_population(db: Session, kingdom_id: str) -> int:
    """Get total population (all citizens regardless of activity)"""
    count = db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).count()
    
    return count


def _get_top_players(db: Session, kingdom_id: str, intelligence_level: int) -> Optional[list]:
    """Get top 5 strongest players if intelligence is high enough"""
    if intelligence_level < 6:
        return None
    
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    
    # Get top 5 by combined combat power
    players = db.query(PlayerState).join(User).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.last_check_in > cutoff_time,
        PlayerState.is_alive == True
    ).order_by(
        (PlayerState.attack_power + PlayerState.defense_power).desc()
    ).limit(5).all()
    
    return [
        {
            "name": db.query(User).filter(User.id == p.user_id).first().username,
            "attack": p.attack_power,
            "defense": p.defense_power
        }
        for p in players
    ]


def _count_active_patrols(db: Session, kingdom_id: str) -> int:
    """Count how many players are currently on patrol"""
    now = datetime.utcnow()
    
    count = db.query(PlayerState).filter(
        PlayerState.current_kingdom_id == kingdom_id,
        PlayerState.patrol_expires_at > now
    ).count()
    
    return count


def _calculate_intel_success_chance(
    intelligence: int,
    vault_level: int,
    active_patrols: int
) -> float:
    """Calculate success chance for gathering intelligence"""
    base_success = 0.40  # 40% base
    intelligence_bonus = intelligence * 0.08  # +8% per level
    patrol_penalty = active_patrols * 0.05  # -5% per patrol
    vault_penalty = vault_level * 0.03  # +3% security per vault level
    
    success_chance = base_success + intelligence_bonus - patrol_penalty - vault_penalty
    
    # Clamp between 10% and 90%
    return max(0.10, min(0.90, success_chance))


# ===== API Endpoints =====

@router.get("/military-strength/{kingdom_id}")
def get_military_strength(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get military strength of a kingdom
    
    If it's your home kingdom: full real-time details
    If it's enemy kingdom: only intel you've gathered (or just walls)
    """
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if this is user's home kingdom
    is_home_kingdom = state.hometown_kingdom_id == kingdom_id
    
    if is_home_kingdom:
        # Full real-time details for own kingdom
        total_attack = _calculate_total_attack(db, kingdom_id)
        total_defense = _calculate_total_defense(db, kingdom_id)
        active_citizens = _count_active_citizens(db, kingdom_id)
        population = _get_population(db, kingdom_id)
        
        return {
            "kingdom_id": kingdom_id,
            "kingdom_name": kingdom.name,
            "wall_level": kingdom.wall_level,
            "total_attack": total_attack,
            "total_defense": total_defense,
            "total_defense_with_walls": total_defense + (kingdom.wall_level * 5),
            "active_citizens": active_citizens,
            "population": population,
            "is_own_kingdom": True,
            "has_intel": False,
            "intel_level": None
        }
    else:
        # Check if we have intel on this kingdom
        intel = db.query(KingdomIntelligence).filter(
            KingdomIntelligence.kingdom_id == kingdom_id,
            KingdomIntelligence.gatherer_kingdom_id == state.hometown_kingdom_id,
            KingdomIntelligence.expires_at > datetime.utcnow()
        ).first()
        
        if intel:
            # Return intel based on level gathered
            intel_level = intel.intelligence_level
            days_old = (datetime.utcnow() - intel.gathered_at).days
            
            response = {
                "kingdom_id": kingdom_id,
                "kingdom_name": kingdom.name,
                "wall_level": kingdom.wall_level,  # Always visible
                "is_own_kingdom": False,
                "has_intel": True,
                "intel_level": intel_level,
                "intel_age_days": days_old,
                "gathered_by": intel.gatherer_name,
                "gathered_at": intel.gathered_at.isoformat()
            }
            
            # Level 3+: Basic info
            if intel_level >= 3:
                response["population"] = intel.population_estimate
                response["active_citizens"] = intel.active_citizen_count
            
            # Level 4+: Patrol info
            if intel_level >= 4:
                response["patrol_strength"] = "Low" if intel.active_citizen_count < 10 else "Medium" if intel.active_citizen_count < 30 else "High"
            
            # Level 5+: Full military stats
            if intel_level >= 5:
                response["total_attack"] = intel.total_attack_power
                response["total_defense"] = intel.total_defense_power
                response["total_defense_with_walls"] = intel.total_defense_power + (intel.wall_level * 5)
            
            # Level 6+: Top players
            if intel_level >= 6 and intel.top_players:
                response["top_players"] = intel.top_players
            
            # Level 7+: Building levels
            if intel_level >= 7 and intel.building_levels:
                response["building_levels"] = intel.building_levels
            
            return response
        else:
            # No intel - only walls visible
            return {
                "kingdom_id": kingdom_id,
                "kingdom_name": kingdom.name,
                "wall_level": kingdom.wall_level,  # Walls can be seen from outside
                "is_own_kingdom": False,
                "has_intel": False,
                "intel_level": None
            }


@router.post("/gather/{kingdom_id}")
def gather_intelligence(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Gather intelligence on an enemy kingdom
    
    Requirements:
    - Intelligence 3+
    - 500g cost (always paid upfront)
    - Must be checked into target kingdom
    - 24h cooldown
    - Cannot target your own kingdom
    
    Success: Reveal military stats for 7 days (shared with your kingdom)
    Failure: Caught, lose gold + reputation, temporarily banned
    """
    state = current_user.player_state
    
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if player has a home kingdom
    if not state.hometown_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must have a home kingdom to gather intelligence"
        )
    
    # Check intelligence level requirement
    if state.intelligence < MIN_INTELLIGENCE_LEVEL:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Requires intelligence level {MIN_INTELLIGENCE_LEVEL}+. Current: {state.intelligence}"
        )
    
    # Check gold
    if state.gold < INTELLIGENCE_COST:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient gold. Need {INTELLIGENCE_COST}g, have {state.gold}g"
        )
    
    # Check cooldown
    if state.last_intelligence_action and not DEV_MODE:
        time_since = datetime.utcnow() - state.last_intelligence_action
        cooldown = timedelta(hours=INTELLIGENCE_COOLDOWN_HOURS)
        
        if time_since < cooldown:
            remaining = cooldown - time_since
            hours = int(remaining.total_seconds() / 3600)
            minutes = int((remaining.total_seconds() % 3600) / 60)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Intelligence action on cooldown. Wait {hours}h {minutes}m."
            )
    
    # Check if checked into target kingdom
    if state.current_kingdom_id != kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into target kingdom to gather intelligence"
        )
    
    # Cannot target own kingdom
    if state.hometown_kingdom_id == kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot gather intelligence on your own kingdom"
        )
    
    # Get target kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Cannot spy on allies
    home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if home_kingdom and are_empires_allied(
        db, 
        home_kingdom.empire_id or home_kingdom.id,
        kingdom.empire_id or kingdom.id
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot spy on allies! This would violate your alliance."
        )
    
    # Deduct gold (always paid upfront)
    state.gold -= INTELLIGENCE_COST
    state.last_intelligence_action = datetime.utcnow()
    
    # Calculate success chance
    active_patrols = _count_active_patrols(db, kingdom_id)
    success_chance = _calculate_intel_success_chance(
        intelligence=state.intelligence,
        vault_level=kingdom.vault_level,
        active_patrols=active_patrols
    )
    
    # Roll the dice
    roll = random.random()
    caught = roll >= success_chance
    
    if not caught:
        # SUCCESS - Gather intelligence
        
        # Calculate intel data
        total_attack = _calculate_total_attack(db, kingdom_id)
        total_defense = _calculate_total_defense(db, kingdom_id)
        active_citizens = _count_active_citizens(db, kingdom_id)
        population = _get_population(db, kingdom_id)
        top_players = _get_top_players(db, kingdom_id, state.intelligence)
        
        building_levels = None
        if state.intelligence >= 7:
            building_levels = {
                "walls": kingdom.wall_level,
                "vault": kingdom.vault_level,
                "mine": kingdom.mine_level,
                "market": kingdom.market_level,
                "farm": kingdom.farm_level,
                "education": kingdom.education_level
            }
        
        # Store or update intel
        existing_intel = db.query(KingdomIntelligence).filter(
            KingdomIntelligence.kingdom_id == kingdom_id,
            KingdomIntelligence.gatherer_kingdom_id == state.hometown_kingdom_id
        ).first()
        
        if existing_intel:
            # Update existing intel
            existing_intel.gatherer_id = current_user.id
            existing_intel.gatherer_name = current_user.username
            existing_intel.wall_level = kingdom.wall_level
            existing_intel.total_attack_power = total_attack
            existing_intel.total_defense_power = total_defense
            existing_intel.active_citizen_count = active_citizens
            existing_intel.population_estimate = population
            existing_intel.top_players = top_players
            existing_intel.building_levels = building_levels
            existing_intel.intelligence_level = state.intelligence
            existing_intel.gathered_at = datetime.utcnow()
            existing_intel.expires_at = datetime.utcnow() + timedelta(days=INTELLIGENCE_EXPIRY_DAYS)
        else:
            # Create new intel
            new_intel = KingdomIntelligence(
                kingdom_id=kingdom_id,
                gatherer_id=current_user.id,
                gatherer_kingdom_id=state.hometown_kingdom_id,
                gatherer_name=current_user.username,
                wall_level=kingdom.wall_level,
                total_attack_power=total_attack,
                total_defense_power=total_defense,
                active_citizen_count=active_citizens,
                population_estimate=population,
                top_players=top_players,
                building_levels=building_levels,
                intelligence_level=state.intelligence,
                gathered_at=datetime.utcnow(),
                expires_at=datetime.utcnow() + timedelta(days=INTELLIGENCE_EXPIRY_DAYS)
            )
            db.add(new_intel)
        
        # Reward reputation in home kingdom
        if state.kingdom_reputation is None:
            state.kingdom_reputation = {}
        
        home_rep = state.kingdom_reputation.get(state.hometown_kingdom_id, 0)
        state.kingdom_reputation[state.hometown_kingdom_id] = home_rep + 50
        
        db.commit()
        
        return {
            "success": True,
            "caught": False,
            "message": f"Successfully gathered intelligence on {kingdom.name}!",
            "cost_paid": INTELLIGENCE_COST,
            "reputation_gained": 50,
            "detection_chance": round(success_chance * 100, 1),
            "intel_expires_in_days": INTELLIGENCE_EXPIRY_DAYS,
            "intel_level": state.intelligence,
            "intel_data": {
                "wall_level": kingdom.wall_level,
                "total_attack": total_attack if state.intelligence >= 5 else None,
                "total_defense": total_defense if state.intelligence >= 5 else None,
                "active_citizens": active_citizens if state.intelligence >= 3 else None,
                "population": population if state.intelligence >= 3 else None
            }
        }
    else:
        # CAUGHT - Penalties
        
        # Lose reputation in target kingdom
        if state.kingdom_reputation is None:
            state.kingdom_reputation = {}
        
        target_rep = state.kingdom_reputation.get(kingdom_id, 0)
        state.kingdom_reputation[kingdom_id] = target_rep - 200
        
        # TODO: Add temporary ban system
        
        db.commit()
        
        return {
            "success": False,
            "caught": True,
            "message": f"Caught gathering intelligence on {kingdom.name}! Lost {INTELLIGENCE_COST}g and 200 reputation.",
            "cost_paid": INTELLIGENCE_COST,
            "reputation_lost": 200,
            "detection_chance": round(success_chance * 100, 1),
            "roll": round(roll * 100, 1)
        }

