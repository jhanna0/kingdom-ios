"""
COVERT INCIDENT SYSTEM
======================
Multi-player intelligence events using hunt-style probability bar.

ONE BUTTON, ONE ENDPOINT - outcomes scale with Intelligence tier!
- T1: intel
- T3: + disruption
- T5: + contract_sabotage, vault_heist

Usage:
    from systems.incidents import IncidentManager, IncidentConfig
    
    manager = IncidentManager()
    
    # Attempt to trigger an incident (patrol determines if it happens)
    # Attacker's intelligence tier determines which outcomes are possible
    result = manager.attempt_trigger(
        attacker_kingdom_id="kingdom_a",
        defender_kingdom_id="kingdom_b",
        attacker_id=123,
        attacker_name="Alice",
        attacker_stats={"intelligence": 5},  # T5 = all outcomes unlocked
        active_patrols=3
    )
    
    # If triggered, players can roll to shift the probability bar
    if result["triggered"]:
        incident_id = result["incident_id"]
        roll_result = manager.execute_roll(incident_id, player_id=123, side="attacker")
        
    # Resolve when ready - master roll determines outcome
    final_result = manager.resolve_incident(incident_id)
"""

from .config import IncidentConfig, INCIDENT_DROP_TABLE, INCIDENT_SHIFT_PER_SUCCESS
from .incident_manager import IncidentManager, IncidentSession, IncidentStatus

__all__ = [
    "IncidentManager",
    "IncidentSession",
    "IncidentStatus",
    "IncidentConfig",
    "INCIDENT_DROP_TABLE",
    "INCIDENT_SHIFT_PER_SUCCESS",
]
