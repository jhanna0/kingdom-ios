"""
Intelligence & Military Strength System
- Rulers can view their kingdom's military strength
- Gather intelligence on enemy kingdoms
- Share intel with your kingdom
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime

from db.base import get_db
from db.models import User, Kingdom, PlayerState, KingdomIntelligence
from db import ActionCooldown
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso
from services.kingdom_service import get_active_citizens_count

router = APIRouter(prefix="/intelligence", tags=["intelligence"])

# NOTE: Old constants removed - scout action now in /actions/scout with its own config


# ===== Helper Functions =====

def _calculate_total_attack(db: Session, kingdom_id: str) -> int:
    """Calculate total attack power of all active citizens in a kingdom"""
    # NOTE: last_check_in was removed from player_state. For now, just sum all citizens.
    # TODO: Use user_kingdoms table or activity_log to filter active players
    
    result = db.query(func.sum(PlayerState.attack_power)).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).scalar()
    
    return result or 0


def _calculate_total_defense(db: Session, kingdom_id: str) -> int:
    """Calculate total defense power of all active citizens in a kingdom"""
    # NOTE: last_check_in was removed from player_state. For now, just sum all citizens.
    # TODO: Use user_kingdoms table or activity_log to filter active players
    
    result = db.query(func.sum(PlayerState.defense_power)).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).scalar()
    
    return result or 0


def _count_active_citizens(db: Session, kingdom_id: str) -> int:
    """Count active citizens (logged in within last 7 days) whose hometown is this kingdom.
    
    Uses the centralized get_active_citizens_count from kingdom_service.
    """
    return get_active_citizens_count(db, kingdom_id)


def _get_population(db: Session, kingdom_id: str) -> int:
    """Get total population (all citizens regardless of activity)"""
    count = db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).count()
    
    return count


def _count_active_patrols(db: Session, kingdom_id: str) -> int:
    """Count how many players are currently on patrol"""
    now = datetime.utcnow()
    
    # Get all players in this kingdom
    players_in_kingdom = db.query(PlayerState.user_id).filter(
        PlayerState.current_kingdom_id == kingdom_id
    ).all()
    
    user_ids = [p.user_id for p in players_in_kingdom]
    
    # Count how many have active patrol cooldowns (expires_at > now)
    count = db.query(ActionCooldown).filter(
        ActionCooldown.user_id.in_(user_ids),
        ActionCooldown.action_type == "patrol",
        ActionCooldown.expires_at > now
    ).count()
    
    return count


# ===== API Endpoints =====

@router.get("/military-strength/{kingdom_id}")
def get_military_strength(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get military strength of a kingdom
    
    If you're the ruler: full real-time details
    If you have intel: gathered intelligence data
    Otherwise: only walls visible
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
    
    # Only rulers can view full military intelligence for a kingdom
    is_ruler = kingdom.ruler_id == current_user.id
    
    if is_ruler:
        # Full real-time details for kingdoms you rule
        total_attack = _calculate_total_attack(db, kingdom_id)
        total_defense = _calculate_total_defense(db, kingdom_id)
        active_citizens = _count_active_citizens(db, kingdom_id)
        population = _get_population(db, kingdom_id)
        active_patrols = _count_active_patrols(db, kingdom_id)
        
        return {
            "kingdom_id": kingdom_id,
            "kingdom_name": kingdom.name,
            "wall_level": kingdom.wall_level,
            "total_attack": total_attack,
            "total_defense": total_defense,
            "total_defense_with_walls": total_defense + (kingdom.wall_level * 5),
            "active_citizens": active_citizens,
            "population": population,
            "patrol_strength": active_patrols,
            "is_own_kingdom": False,  # Not used when viewing as ruler
            "is_ruler": True,
            "has_intel": False,
            "intel_level": None
        }
    else:
        # Get ALL non-expired intel records for this kingdom pair
        intel_records = db.query(KingdomIntelligence).filter(
            KingdomIntelligence.kingdom_id == kingdom_id,
            KingdomIntelligence.gatherer_kingdom_id == state.hometown_kingdom_id,
            KingdomIntelligence.expires_at > datetime.utcnow()
        ).all()
        
        if intel_records:
            # Find the highest intel level we have
            intel_level = max(r.intelligence_level for r in intel_records)
            # Use the most recent record for metadata
            latest_intel = max(intel_records, key=lambda r: r.gathered_at)
            # Find earliest expiry (when we start losing intel)
            earliest_expiry = min(r.expires_at for r in intel_records)
            
            response = {
                "kingdom_id": kingdom_id,
                "kingdom_name": kingdom.name,
                "wall_level": kingdom.wall_level,  # Always visible
                "is_own_kingdom": False,
                "has_intel": True,
                "intel_level": intel_level,
                "gathered_at": format_datetime_iso(latest_intel.gathered_at),
                "expires_at": format_datetime_iso(earliest_expiry),
                "intel_records": len(intel_records),
            }
            
            # Level 1 = basic_intel: population, citizens
            if intel_level >= 1:
                response["population"] = _get_population(db, kingdom_id)
                response["active_citizens"] = _count_active_citizens(db, kingdom_id)
            
            # Level 2 = military_intel: attack, defense, walls
            if intel_level >= 2:
                total_attack = _calculate_total_attack(db, kingdom_id)
                total_defense = _calculate_total_defense(db, kingdom_id)
                response["total_attack"] = total_attack
                response["total_defense"] = total_defense
                response["total_defense_with_walls"] = total_defense + (kingdom.wall_level * 5)
            
            # Level 3 = building_intel: all building levels
            if intel_level >= 3:
                response["building_levels"] = {
                    "walls": kingdom.wall_level,
                    "vault": kingdom.vault_level,
                    "mine": kingdom.mine_level,
                    "market": kingdom.market_level,
                    "farm": kingdom.farm_level,
                    "education": kingdom.education_level,
                }
            
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


# NOTE: Old /gather endpoint removed - replaced by /actions/scout
