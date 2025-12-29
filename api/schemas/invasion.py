"""
Invasion system schemas
"""
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class InvasionDeclareRequest(BaseModel):
    attacking_from_kingdom_id: str
    target_kingdom_id: str


class InvasionDeclareResponse(BaseModel):
    success: bool
    message: str
    invasion_id: int
    battle_time: datetime
    cost_paid: int


class InvasionJoinRequest(BaseModel):
    side: str  # 'attackers' or 'defenders'


class InvasionJoinResponse(BaseModel):
    success: bool
    message: str
    side: str
    attacker_count: int
    defender_count: int


class InvasionParticipant(BaseModel):
    player_id: int
    player_name: str
    attack_power: int
    defense_power: int


class InvasionEventResponse(BaseModel):
    id: int
    attacking_from_kingdom_id: str
    attacking_from_kingdom_name: Optional[str]
    target_kingdom_id: str
    target_kingdom_name: Optional[str]
    initiator_id: int
    initiator_name: str
    status: str
    declared_at: datetime
    battle_time: datetime
    time_remaining_seconds: int
    attacker_ids: List[int]
    defender_ids: List[int]
    attacker_count: int
    defender_count: int
    user_side: Optional[str]
    can_join_attackers: bool
    can_join_defenders: bool
    user_current_kingdom_id: Optional[str]
    is_resolved: bool
    attacker_victory: Optional[bool]
    attacker_strength: Optional[int]
    defender_strength: Optional[int]
    total_defense_with_walls: Optional[int]
    resolved_at: Optional[datetime]


class ActiveInvasionsResponse(BaseModel):
    active_invasions: List[InvasionEventResponse]
    count: int


class InvasionResolveResponse(BaseModel):
    success: bool
    invasion_id: int
    attacker_victory: bool
    attacker_strength: int
    defender_strength: int
    total_defense_with_walls: int
    required_attack_strength: int
    attackers: List[InvasionParticipant]
    defenders: List[InvasionParticipant]
    old_ruler_id: Optional[int]
    old_ruler_name: Optional[str]
    new_ruler_id: Optional[int]
    new_ruler_name: Optional[str]
    loot_per_attacker: int
    wall_damage: int
    message: str

