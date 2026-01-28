"""
HUNT PERSISTENCE LAYER
======================
Handles saving/loading hunt sessions to/from PostgreSQL.
Replaces the in-memory storage that didn't work with Lambda.
"""

from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy.orm import Session

from db.models import HuntSession as HuntSessionModel
from .config import HuntPhase, HuntConfig


# Default hunt expiry: 24 hours
HUNT_EXPIRY_HOURS = 24


def save_hunt(db: Session, hunt_session) -> None:
    """
    Save a hunt session to the database.
    
    Args:
        db: SQLAlchemy database session
        hunt_session: HuntSession dataclass instance
    """
    from .hunt_manager import HuntSession, HuntStatus
    
    # Convert to storage format
    session_data = _serialize_hunt(hunt_session)
    
    # Check if exists
    existing = db.query(HuntSessionModel).filter(
        HuntSessionModel.hunt_id == hunt_session.hunt_id
    ).first()
    
    if existing:
        # Update existing
        existing.status = hunt_session.status.value
        existing.session_data = session_data
        existing.started_at = hunt_session.started_at
        existing.completed_at = hunt_session.completed_at
    else:
        # Create new
        db_hunt = HuntSessionModel(
            hunt_id=hunt_session.hunt_id,
            created_by=hunt_session.created_by,
            kingdom_id=hunt_session.kingdom_id,
            status=hunt_session.status.value,
            session_data=session_data,
            created_at=hunt_session.created_at,
            started_at=hunt_session.started_at,
            completed_at=hunt_session.completed_at,
            expires_at=datetime.utcnow() + timedelta(hours=HUNT_EXPIRY_HOURS),
        )
        db.add(db_hunt)
    
    db.commit()


def load_hunt(db: Session, hunt_id: str) -> Optional["HuntSession"]:
    """
    Load a hunt session from the database.
    
    Args:
        db: SQLAlchemy database session
        hunt_id: The hunt ID to load
        
    Returns:
        HuntSession dataclass instance, or None if not found/expired
    """
    db_hunt = db.query(HuntSessionModel).filter(
        HuntSessionModel.hunt_id == hunt_id
    ).first()
    
    if not db_hunt:
        return None
    
    # Check if expired
    if db_hunt.is_expired:
        # Clean up expired hunt
        db.delete(db_hunt)
        db.commit()
        return None
    
    return _deserialize_hunt(db_hunt.session_data)


def get_active_hunt_for_player(db: Session, player_id: int) -> Optional["HuntSession"]:
    """
    Get the active hunt for a player (as creator or participant).
    
    Args:
        db: SQLAlchemy database session
        player_id: The player ID to check
        
    Returns:
        HuntSession if player has an active hunt, None otherwise
    """
    # First check hunts they created
    db_hunt = db.query(HuntSessionModel).filter(
        HuntSessionModel.created_by == player_id,
        HuntSessionModel.status.in_(['lobby', 'in_progress'])
    ).first()
    
    if db_hunt and not db_hunt.is_expired:
        return _deserialize_hunt(db_hunt.session_data)
    
    # Also check if they're a participant in any hunt
    # We need to search the JSONB session_data for participant IDs
    # This is a bit expensive but hunts are short-lived
    active_hunts = db.query(HuntSessionModel).filter(
        HuntSessionModel.status.in_(['lobby', 'in_progress'])
    ).all()
    
    for db_hunt in active_hunts:
        if db_hunt.is_expired:
            continue
        participants = db_hunt.session_data.get("participants", {})
        if str(player_id) in participants:
            return _deserialize_hunt(db_hunt.session_data)
    
    return None


def get_active_hunt_for_kingdom(db: Session, kingdom_id: str) -> Optional["HuntSession"]:
    """
    Get the active hunt in a kingdom, if any.
    
    Note: This is now optional - multiple hunts can exist per kingdom.
    This function is kept for backwards compatibility with the API.
    
    Args:
        db: SQLAlchemy database session
        kingdom_id: The kingdom ID to check
        
    Returns:
        HuntSession if there's an active hunt in the kingdom, None otherwise
    """
    db_hunt = db.query(HuntSessionModel).filter(
        HuntSessionModel.kingdom_id == kingdom_id,
        HuntSessionModel.status.in_(['lobby', 'in_progress'])
    ).order_by(HuntSessionModel.created_at.desc()).first()
    
    if db_hunt and not db_hunt.is_expired:
        return _deserialize_hunt(db_hunt.session_data)
    
    return None


def delete_hunt(db: Session, hunt_id: str) -> bool:
    """Delete a hunt from the database."""
    result = db.query(HuntSessionModel).filter(
        HuntSessionModel.hunt_id == hunt_id
    ).delete()
    db.commit()
    return result > 0


def cleanup_expired_hunts(db: Session) -> int:
    """Remove expired hunts from the database."""
    result = db.query(HuntSessionModel).filter(
        HuntSessionModel.expires_at < datetime.utcnow()
    ).delete()
    db.commit()
    return result


# ============================================================
# SERIALIZATION HELPERS
# ============================================================

def _serialize_hunt(hunt_session) -> dict:
    """
    Serialize a HuntSession dataclass to a dict for storage.
    Handles nested dataclasses and enums.
    """
    from .hunt_manager import HuntSession, HuntParticipant, PhaseState, PhaseResult, PhaseRoundResult
    
    def serialize_datetime(dt):
        if dt is None:
            return None
        return dt.isoformat()
    
    def serialize_participant(p: "HuntParticipant") -> dict:
        return {
            "player_id": p.player_id,
            "player_name": p.player_name,
            "stats": p.stats,
            "joined_at": serialize_datetime(p.joined_at),
            "is_ready": p.is_ready,
            "is_injured": p.is_injured,
            "total_contribution": p.total_contribution,
            "successful_rolls": p.successful_rolls,
            "critical_rolls": p.critical_rolls,
            "meat_earned": p.meat_earned,
            "items_earned": p.items_earned,
        }
    
    def serialize_round_result(r: "PhaseRoundResult") -> dict:
        return {
            "round_number": r.round_number,
            "player_id": r.player_id,
            "player_name": r.player_name,
            "roll_value": r.roll_value,
            "stat_value": r.stat_value,
            "is_success": r.is_success,
            "is_critical": r.is_critical,
            "contribution": r.contribution,
            "effect_message": r.effect_message,
        }
    
    def serialize_phase_state(ps: "PhaseState") -> dict:
        if ps is None:
            return None
        return {
            "phase": ps.phase.value,
            "rounds_completed": ps.rounds_completed,
            "total_score": ps.total_score,
            "round_results": [serialize_round_result(r) for r in ps.round_results],
            "max_rolls": ps.max_rolls,
            "stat_value": ps.stat_value,
            "damage_dealt": ps.damage_dealt,
            "animal_remaining_hp": ps.animal_remaining_hp,
            "escape_risk": ps.escape_risk,
            "blessing_bonus": ps.blessing_bonus,
            "drop_table_slots": ps.drop_table_slots,
            "creature_probabilities": ps.creature_probabilities,
            "is_resolved": ps.is_resolved,
            "resolution_roll": ps.resolution_roll,
            "resolution_outcome": ps.resolution_outcome,
        }
    
    def serialize_phase_result(pr: "PhaseResult") -> dict:
        return {
            "phase": pr.phase.value,
            "group_roll": pr.group_roll.to_dict() if pr.group_roll else None,
            "phase_score": pr.phase_score,
            "outcome_message": pr.outcome_message,
            "effects": pr.effects,
        }
    
    return {
        "hunt_id": hunt_session.hunt_id,
        "kingdom_id": hunt_session.kingdom_id,
        "created_by": hunt_session.created_by,
        "created_at": serialize_datetime(hunt_session.created_at),
        "status": hunt_session.status.value,
        "current_phase": hunt_session.current_phase.value,
        "participants": {
            str(pid): serialize_participant(p)
            for pid, p in hunt_session.participants.items()
        },
        "animal_id": hunt_session.animal_id,
        "animal_data": hunt_session.animal_data,
        "track_score": hunt_session.track_score,
        "max_tier_unlocked": hunt_session.max_tier_unlocked,
        "is_spooked": hunt_session.is_spooked,
        "animal_escaped": hunt_session.animal_escaped,
        "current_phase_state": serialize_phase_state(hunt_session.current_phase_state),
        "phase_results": [serialize_phase_result(pr) for pr in hunt_session.phase_results],
        "total_meat": hunt_session.total_meat,
        "bonus_meat": hunt_session.bonus_meat,
        "items_dropped": hunt_session.items_dropped,
        "started_at": serialize_datetime(hunt_session.started_at),
        "completed_at": serialize_datetime(hunt_session.completed_at),
        # Streak bonus fields
        "streak_active": hunt_session.streak_active,
        "show_streak_popup": hunt_session.show_streak_popup,
        "streak_info": hunt_session.streak_info,
    }


def _deserialize_hunt(data: dict) -> "HuntSession":
    """
    Deserialize a dict from storage back to a HuntSession dataclass.
    """
    from .hunt_manager import (
        HuntSession, HuntStatus, HuntParticipant, 
        PhaseState, PhaseResult, PhaseRoundResult
    )
    from ..rolls import GroupRollResult, RollResult as EngineRollResult
    from ..rolls.engine import RollOutcome
    
    def parse_datetime(s):
        if s is None:
            return None
        if isinstance(s, datetime):
            return s
        return datetime.fromisoformat(s.replace('Z', '+00:00').replace('+00:00', ''))
    
    def deserialize_participant(d: dict) -> HuntParticipant:
        return HuntParticipant(
            player_id=d["player_id"],
            player_name=d["player_name"],
            stats=d["stats"],
            joined_at=parse_datetime(d.get("joined_at")),
            is_ready=d.get("is_ready", False),
            is_injured=d.get("is_injured", False),
            total_contribution=d.get("total_contribution", 0.0),
            successful_rolls=d.get("successful_rolls", 0),
            critical_rolls=d.get("critical_rolls", 0),
            meat_earned=d.get("meat_earned", 0),
            items_earned=d.get("items_earned", []),
        )
    
    def deserialize_round_result(d: dict) -> PhaseRoundResult:
        return PhaseRoundResult(
            round_number=d["round_number"],
            player_id=d["player_id"],
            player_name=d["player_name"],
            roll_value=d["roll_value"],
            stat_value=d["stat_value"],
            is_success=d["is_success"],
            is_critical=d["is_critical"],
            contribution=d["contribution"],
            effect_message=d["effect_message"],
        )
    
    def deserialize_phase_state(d: dict) -> Optional[PhaseState]:
        if d is None:
            return None
        return PhaseState(
            phase=HuntPhase(d["phase"]),
            rounds_completed=d.get("rounds_completed", 0),
            total_score=d.get("total_score", 0.0),
            round_results=[deserialize_round_result(r) for r in d.get("round_results", [])],
            max_rolls=d.get("max_rolls", 1),
            stat_value=d.get("stat_value", 0),
            damage_dealt=d.get("damage_dealt", 0),
            animal_remaining_hp=d.get("animal_remaining_hp", 0),
            escape_risk=d.get("escape_risk", 0.0),
            blessing_bonus=d.get("blessing_bonus", 0.0),
            drop_table_slots=d.get("drop_table_slots", {}),
            creature_probabilities=d.get("creature_probabilities", {}),
            is_resolved=d.get("is_resolved", False),
            resolution_roll=d.get("resolution_roll"),
            resolution_outcome=d.get("resolution_outcome"),
        )
    
    def deserialize_phase_result(d: dict) -> PhaseResult:
        # Reconstruct GroupRollResult if present
        group_roll_data = d.get("group_roll")
        group_roll = None
        if group_roll_data:
            individual_rolls = []
            for roll_data in group_roll_data.get("individual_rolls", []):
                # Convert outcome string back to enum
                outcome_str = roll_data.get("outcome", "failure")
                try:
                    outcome = RollOutcome[outcome_str.upper()]
                except (KeyError, AttributeError):
                    outcome = RollOutcome.FAILURE
                
                individual_rolls.append(EngineRollResult(
                    player_id=roll_data.get("player_id", 0),
                    player_name=roll_data.get("player_name", ""),
                    stat_name=roll_data.get("stat_name", ""),
                    stat_value=roll_data.get("stat_value", 0),
                    roll_value=roll_data.get("roll_value", 0.5),
                    success_threshold=roll_data.get("success_threshold", 0.5),
                    outcome=outcome,
                    contribution=roll_data.get("contribution", 0.0),
                ))
            
            group_roll = GroupRollResult(
                phase_name=group_roll_data.get("phase_name", ""),
                individual_rolls=individual_rolls,
                total_contribution=group_roll_data.get("total_contribution", 0.0),
                success_count=group_roll_data.get("success_count", 0),
                critical_count=group_roll_data.get("critical_count", 0),
                group_size=group_roll_data.get("group_size", 1),
                group_bonus=group_roll_data.get("group_bonus", 0.0),
            )
        
        return PhaseResult(
            phase=HuntPhase(d["phase"]),
            group_roll=group_roll,
            phase_score=d.get("phase_score", 0.0),
            outcome_message=d.get("outcome_message", ""),
            effects=d.get("effects", {}),
        )
    
    # Build participants dict with int keys
    participants = {}
    for pid_str, p_data in data.get("participants", {}).items():
        pid = int(pid_str)
        participants[pid] = deserialize_participant(p_data)
    
    return HuntSession(
        hunt_id=data["hunt_id"],
        kingdom_id=data.get("kingdom_id", ""),
        created_by=data["created_by"],
        created_at=parse_datetime(data.get("created_at")),
        status=HuntStatus(data.get("status", "lobby")),
        current_phase=HuntPhase(data.get("current_phase", "lobby")),
        participants=participants,
        animal_id=data.get("animal_id"),
        animal_data=data.get("animal_data"),
        track_score=data.get("track_score", 0.0),
        max_tier_unlocked=data.get("max_tier_unlocked", 0),
        is_spooked=data.get("is_spooked", False),
        animal_escaped=data.get("animal_escaped", False),
        current_phase_state=deserialize_phase_state(data.get("current_phase_state")),
        phase_results=[deserialize_phase_result(pr) for pr in data.get("phase_results", [])],
        total_meat=data.get("total_meat", 0),
        bonus_meat=data.get("bonus_meat", 0),
        items_dropped=data.get("items_dropped", []),
        started_at=parse_datetime(data.get("started_at")),
        completed_at=parse_datetime(data.get("completed_at")),
        # Streak bonus fields
        streak_active=data.get("streak_active", False),
        show_streak_popup=data.get("show_streak_popup", False),
        streak_info=data.get("streak_info"),
    )
