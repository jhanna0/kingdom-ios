"""
INCIDENT MANAGER
================
Orchestrates covert incident sessions.
Handles trigger checks, participation, bar shifting, and resolution.

Similar to HuntManager but simpler - no phases, just one probability bar.
"""

import random
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from enum import Enum

from ..rolls import RollEngine, RollResult
from .config import IncidentConfig


class IncidentStatus(Enum):
    """Current status of an incident"""
    ACTIVE = "active"           # Incident is live, accepting rolls
    RESOLVED = "resolved"       # Incident completed
    EXPIRED = "expired"         # Incident timed out


@dataclass
class IncidentParticipant:
    """A player participating in an incident"""
    player_id: int
    player_name: str
    side: str                   # "attacker" or "defender"
    stats: Dict[str, int]
    kingdom_id: str
    joined_at: datetime = field(default_factory=datetime.utcnow)
    
    # Tracking
    rolls_made: int = 0
    successful_rolls: int = 0
    critical_rolls: int = 0
    
    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "player_name": self.player_name,
            "side": self.side,
            "kingdom_id": self.kingdom_id,
            "rolls_made": self.rolls_made,
            "successful_rolls": self.successful_rolls,
            "critical_rolls": self.critical_rolls,
        }


@dataclass
class RollRecord:
    """Record of a single roll in the incident"""
    player_id: int
    player_name: str
    side: str
    roll_value: int             # 1-100 for display
    stat_value: int
    is_success: bool
    is_critical: bool
    shift_applied: Dict[str, int]
    timestamp: datetime = field(default_factory=datetime.utcnow)
    
    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "player_name": self.player_name,
            "side": self.side,
            "roll": self.roll_value,
            "stat": self.stat_value,
            "is_success": self.is_success,
            "is_critical": self.is_critical,
            "shift_applied": self.shift_applied,
            "timestamp": self.timestamp.isoformat(),
        }


@dataclass
class IncidentSession:
    """A covert incident between two kingdoms"""
    incident_id: str
    attacker_kingdom_id: str
    defender_kingdom_id: str
    triggered_by: int           # User ID who triggered it
    attacker_tier: int = 1      # Intelligence tier of triggering attacker (determines available outcomes)
    created_at: datetime = field(default_factory=datetime.utcnow)
    expires_at: datetime = field(default_factory=lambda: datetime.utcnow() + timedelta(seconds=IncidentConfig.DURATION_SECONDS))
    
    # Status
    status: IncidentStatus = IncidentStatus.ACTIVE
    
    # Participants
    participants: Dict[int, IncidentParticipant] = field(default_factory=dict)
    
    # The probability bar (drop table slots) - initialized based on attacker tier
    slots: Dict[str, int] = field(default_factory=dict)
    
    # Roll history
    roll_history: List[RollRecord] = field(default_factory=list)
    
    # Roll counts per side
    attacker_rolls: int = 0
    defender_rolls: int = 0
    
    # Resolution
    resolved_at: Optional[datetime] = None
    resolution_roll: Optional[int] = None
    outcome: Optional[str] = None
    
    def add_participant(self, player_id: int, player_name: str, side: str, 
                        stats: Dict[str, int], kingdom_id: str) -> bool:
        """Add a participant. Returns False if already participating."""
        if player_id in self.participants:
            return False
        if self.status != IncidentStatus.ACTIVE:
            return False
            
        self.participants[player_id] = IncidentParticipant(
            player_id=player_id,
            player_name=player_name,
            side=side,
            stats=stats,
            kingdom_id=kingdom_id,
        )
        return True
    
    def can_roll(self, player_id: int) -> Tuple[bool, str]:
        """Check if a player can roll. Returns (can_roll, reason)."""
        if self.status != IncidentStatus.ACTIVE:
            return False, "Incident is not active"
        
        if datetime.utcnow() > self.expires_at:
            return False, "Incident has expired"
        
        if player_id not in self.participants:
            return False, "Not a participant"
        
        participant = self.participants[player_id]
        
        if participant.rolls_made >= IncidentConfig.MAX_ROLLS_PLAYER:
            return False, f"Maximum {IncidentConfig.MAX_ROLLS_PLAYER} rolls per player"
        
        # Check side limits
        if participant.side == "attacker" and self.attacker_rolls >= IncidentConfig.MAX_ROLLS_SIDE:
            return False, "Attacker side has reached max rolls"
        if participant.side == "defender" and self.defender_rolls >= IncidentConfig.MAX_ROLLS_SIDE:
            return False, "Defender side has reached max rolls"
        
        return True, "OK"
    
    def can_resolve(self) -> Tuple[bool, str]:
        """Check if incident can be resolved."""
        if self.status != IncidentStatus.ACTIVE:
            return False, "Incident is not active"
        
        total_rolls = self.attacker_rolls + self.defender_rolls
        if total_rolls < IncidentConfig.MIN_ROLLS:
            return False, f"Need at least {IncidentConfig.MIN_ROLLS} roll(s)"
        
        return True, "OK"
    
    def get_probabilities(self) -> Dict[str, float]:
        """Convert slots to probabilities"""
        total = sum(self.slots.values())
        if total == 0:
            return {k: 0.0 for k in self.slots}
        return {k: v / total for k, v in self.slots.items()}
    
    def is_expired(self) -> bool:
        """Check if incident has timed out"""
        return datetime.utcnow() > self.expires_at
    
    def to_dict(self) -> dict:
        """Convert to JSON-serializable dict"""
        probs = self.get_probabilities()
        return {
            "incident_id": self.incident_id,
            "attacker_kingdom_id": self.attacker_kingdom_id,
            "defender_kingdom_id": self.defender_kingdom_id,
            "triggered_by": self.triggered_by,
            "attacker_tier": self.attacker_tier,
            "status": self.status.value,
            "created_at": self.created_at.isoformat(),
            "expires_at": self.expires_at.isoformat(),
            "time_remaining_seconds": max(0, int((self.expires_at - datetime.utcnow()).total_seconds())),
            "participants": {
                str(pid): p.to_dict() for pid, p in self.participants.items()
            },
            "slots": self.slots.copy(),
            "probabilities": {k: round(v, 3) for k, v in probs.items()},
            "attacker_rolls": self.attacker_rolls,
            "defender_rolls": self.defender_rolls,
            "total_rolls": self.attacker_rolls + self.defender_rolls,
            "roll_history": [r.to_dict() for r in self.roll_history[-10:]],  # Last 10 rolls
            "can_resolve": self.can_resolve()[0],
            "outcome": self.outcome,
            "resolution_roll": self.resolution_roll,
            "resolved_at": self.resolved_at.isoformat() if self.resolved_at else None,
        }


class IncidentManager:
    """
    Manages incident sessions.
    
    In-memory storage (like hunts). Can be backed by Redis for production scale.
    
    Key design: incidents are keyed by (attacker_kingdom -> defender_kingdom),
    so one defender can have multiple incidents from different attackers.
    """
    
    def __init__(self, seed: Optional[int] = None):
        self.roll_engine = RollEngine(seed)
        self.rng = random.Random(seed)
        self._incidents: Dict[str, IncidentSession] = {}
    
    def _make_incident_id(self, attacker_kingdom_id: str, defender_kingdom_id: str) -> str:
        """Create incident ID from kingdom pair"""
        return f"incident_{attacker_kingdom_id}_{defender_kingdom_id}"
    
    def get_incident(self, incident_id: str) -> Optional[IncidentSession]:
        """Get incident by ID"""
        return self._incidents.get(incident_id)
    
    def get_incident_for_pair(self, attacker_kingdom_id: str, defender_kingdom_id: str) -> Optional[IncidentSession]:
        """Get active incident for a kingdom pair"""
        incident_id = self._make_incident_id(attacker_kingdom_id, defender_kingdom_id)
        incident = self._incidents.get(incident_id)
        
        if incident and incident.status == IncidentStatus.ACTIVE and not incident.is_expired():
            return incident
        return None
    
    def get_incidents_for_defender(self, defender_kingdom_id: str) -> List[IncidentSession]:
        """Get all active incidents targeting a defender kingdom"""
        result = []
        for incident in self._incidents.values():
            if (incident.defender_kingdom_id == defender_kingdom_id and 
                incident.status == IncidentStatus.ACTIVE and
                not incident.is_expired()):
                result.append(incident)
        return result
    
    def attempt_trigger(
        self,
        attacker_kingdom_id: str,
        defender_kingdom_id: str,
        attacker_id: int,
        attacker_name: str,
        attacker_stats: Dict[str, int],
        active_patrols: int
    ) -> dict:
        """
        Attempt to trigger an incident using TWO-PHASE logic:
        
        PHASE 1: Initial Success Roll
        - Based on attacker's intelligence tier vs enemy patrol count
        - Higher int tier = better chance, more patrols = worse chance
        - If FAILS: operation fails entirely, attacker gets nothing
        
        PHASE 2: Incident Triggers (only if Phase 1 succeeds)
        - Tug-of-war probability bar begins
        - Both sides can roll to shift the bar
        - Master roll determines final outcome
        
        Returns dict with:
        - success: bool (did the initial roll succeed?)
        - triggered: bool (is there now an active incident?)
        - incident_id: str (if triggered)
        - success_chance: float (for display)
        - message: str
        """
        # Get attacker's intelligence tier
        attacker_tier = attacker_stats.get("intelligence", 1)
        
        # Check if incident already exists for this pair
        existing = self.get_incident_for_pair(attacker_kingdom_id, defender_kingdom_id)
        if existing:
            # Join existing incident instead
            existing.add_participant(
                player_id=attacker_id,
                player_name=attacker_name,
                side="attacker",
                stats=attacker_stats,
                kingdom_id=attacker_kingdom_id,
            )
            return {
                "success": True,
                "triggered": True,
                "incident_id": existing.incident_id,
                "success_chance": 1.0,  # Already existed
                "roll": None,
                "message": "Joined existing operation",
                "incident": existing.to_dict(),
                "already_existed": True,
            }
        
        # PHASE 1: Calculate initial success chance (int tier vs patrols)
        success_chance = IncidentConfig.calculate_initial_success_chance(attacker_tier, active_patrols)
        
        # Roll for initial success
        roll = self.rng.random()
        initial_success = roll < success_chance
        
        if not initial_success:
            # FAILED - operation fails entirely
            # Attacker paid gold and is on cooldown but gets nothing
            return {
                "success": False,
                "triggered": False,
                "incident_id": None,
                "success_chance": success_chance,
                "roll": round(roll, 3),
                "message": f"Operation failed! Enemy patrols ({active_patrols}) were too vigilant.",
                "incident": None,
                "intelligence_tier": attacker_tier,
                "active_patrols": active_patrols,
            }
        
        # PHASE 2: Initial success! Create incident for tug-of-war
        incident_id = self._make_incident_id(attacker_kingdom_id, defender_kingdom_id)
        
        session = IncidentSession(
            incident_id=incident_id,
            attacker_kingdom_id=attacker_kingdom_id,
            defender_kingdom_id=defender_kingdom_id,
            triggered_by=attacker_id,
            attacker_tier=attacker_tier,
            slots=IncidentConfig.get_initial_slots(attacker_tier),
        )
        
        # Add triggering player as first participant
        session.add_participant(
            player_id=attacker_id,
            player_name=attacker_name,
            side="attacker",
            stats=attacker_stats,
            kingdom_id=attacker_kingdom_id,
        )
        
        self._incidents[incident_id] = session
        
        return {
            "success": True,
            "triggered": True,
            "incident_id": incident_id,
            "success_chance": success_chance,
            "roll": round(roll, 3),
            "message": "Operation successful! Infiltration in progress...",
            "incident": session.to_dict(),
            "already_existed": False,
            "intelligence_tier": attacker_tier,
            "active_patrols": active_patrols,
        }
    
    def join_incident(
        self,
        incident_id: str,
        player_id: int,
        player_name: str,
        side: str,
        stats: Dict[str, int],
        kingdom_id: str
    ) -> dict:
        """Join an existing incident as attacker or defender"""
        incident = self.get_incident(incident_id)
        if not incident:
            return {"success": False, "message": "Incident not found"}
        
        if incident.status != IncidentStatus.ACTIVE:
            return {"success": False, "message": "Incident is not active"}
        
        if incident.is_expired():
            return {"success": False, "message": "Incident has expired"}
        
        # Validate side
        if side == "attacker" and kingdom_id != incident.attacker_kingdom_id:
            return {"success": False, "message": "Must be from attacking kingdom"}
        if side == "defender" and kingdom_id != incident.defender_kingdom_id:
            return {"success": False, "message": "Must be from defending kingdom"}
        
        if not incident.add_participant(player_id, player_name, side, stats, kingdom_id):
            return {"success": False, "message": "Already participating"}
        
        return {
            "success": True,
            "message": f"Joined as {side}",
            "incident": incident.to_dict(),
        }
    
    def execute_roll(self, incident_id: str, player_id: int) -> dict:
        """
        Execute a roll for a participant.
        
        Shifts the probability bar based on success/failure.
        """
        incident = self.get_incident(incident_id)
        if not incident:
            return {"success": False, "message": "Incident not found"}
        
        can_roll, reason = incident.can_roll(player_id)
        if not can_roll:
            return {"success": False, "message": reason}
        
        participant = incident.participants[player_id]
        
        # Execute roll using intelligence stat
        stat_value = participant.stats.get("intelligence", 1)
        roll_result = self.roll_engine.roll(
            player_id=player_id,
            player_name=participant.player_name,
            stat_name="intelligence",
            stat_value=stat_value,
        )
        
        # Calculate shift
        shift_applied = {}
        if roll_result.is_success:
            base_shift = IncidentConfig.get_shift_for_side(participant.side)
            multiplier = IncidentConfig.CRITICAL_MULTIPLIER if roll_result.is_critical else 1
            
            for outcome, shift in base_shift.items():
                actual_shift = shift * multiplier
                if outcome in incident.slots:
                    incident.slots[outcome] = max(1, incident.slots[outcome] + actual_shift)
                    shift_applied[outcome] = actual_shift
        
        # Record the roll
        record = RollRecord(
            player_id=player_id,
            player_name=participant.player_name,
            side=participant.side,
            roll_value=int(roll_result.roll_value * 100),
            stat_value=stat_value,
            is_success=roll_result.is_success,
            is_critical=roll_result.is_critical,
            shift_applied=shift_applied,
        )
        incident.roll_history.append(record)
        
        # Update counts
        participant.rolls_made += 1
        if roll_result.is_success:
            participant.successful_rolls += 1
        if roll_result.is_critical:
            participant.critical_rolls += 1
        
        if participant.side == "attacker":
            incident.attacker_rolls += 1
        else:
            incident.defender_rolls += 1
        
        return {
            "success": True,
            "roll": record.to_dict(),
            "incident": incident.to_dict(),
            "message": "Critical success!" if roll_result.is_critical and roll_result.is_success else (
                "Success!" if roll_result.is_success else "Failed"
            ),
        }
    
    def resolve_incident(self, incident_id: str) -> dict:
        """
        Resolve the incident with a master roll.
        
        Picks outcome based on current probability bar.
        """
        incident = self.get_incident(incident_id)
        if not incident:
            return {"success": False, "message": "Incident not found"}
        
        can_resolve, reason = incident.can_resolve()
        if not can_resolve:
            return {"success": False, "message": reason}
        
        # Master roll: pick outcome based on probabilities
        probs = incident.get_probabilities()
        master_roll = self.rng.random()
        incident.resolution_roll = int(master_roll * 100)
        
        cumulative = 0.0
        selected_outcome = None
        for outcome, prob in probs.items():
            cumulative += prob
            if master_roll <= cumulative:
                selected_outcome = outcome
                break
        
        # Fallback
        if not selected_outcome:
            selected_outcome = max(probs, key=probs.get)
        
        incident.outcome = selected_outcome
        incident.status = IncidentStatus.RESOLVED
        incident.resolved_at = datetime.utcnow()
        
        # Build result message
        if selected_outcome == "prevent":
            message = "Operation prevented! Defenders successfully countered the threat."
            winner = "defender"
        elif selected_outcome == "intel":
            message = "Intelligence gathered! Attackers obtained valuable information."
            winner = "attacker"
        elif selected_outcome == "disruption":
            message = "Disruption successful! Attackers caused temporary chaos."
            winner = "attacker"
        elif selected_outcome == "contract_sabotage":
            message = "Sabotage successful! Attackers delayed kingdom construction."
            winner = "attacker"
        else:
            message = f"Outcome: {selected_outcome}"
            winner = "attacker" if selected_outcome != "prevent" else "defender"
        
        return {
            "success": True,
            "outcome": selected_outcome,
            "winner": winner,
            "master_roll": incident.resolution_roll,
            "probabilities": probs,
            "message": message,
            "incident": incident.to_dict(),
        }
    
    def cleanup_expired(self) -> int:
        """Mark expired incidents and clean up old ones. Returns count cleaned."""
        now = datetime.utcnow()
        cleaned = 0
        
        # Mark expired
        for incident in self._incidents.values():
            if incident.status == IncidentStatus.ACTIVE and incident.is_expired():
                # Auto-resolve expired incidents
                self.resolve_incident(incident.incident_id)
                cleaned += 1
        
        # Remove old resolved incidents (older than 1 hour)
        cutoff = now - timedelta(hours=1)
        to_remove = [
            iid for iid, inc in self._incidents.items()
            if inc.resolved_at and inc.resolved_at < cutoff
        ]
        for iid in to_remove:
            del self._incidents[iid]
            cleaned += 1
        
        return cleaned
