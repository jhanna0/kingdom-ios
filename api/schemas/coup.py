"""
Coup event schemas for API requests/responses
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class CoupInitiateRequest(BaseModel):
    """Request to initiate a coup"""
    kingdom_id: str = Field(..., description="Kingdom where coup is being initiated")


class CoupJoinRequest(BaseModel):
    """Request to join a coup side"""
    side: str = Field(..., description="Side to join: 'attackers' or 'defenders'")


class CoupParticipant(BaseModel):
    """A player participating in a coup"""
    player_id: int
    player_name: str
    attack_power: Optional[int] = None
    defense_power: Optional[int] = None
    
    class Config:
        from_attributes = True


class InitiatorStats(BaseModel):
    """Stats about the coup initiator"""
    reputation: int
    kingdom_reputation: int
    attack_power: int
    defense_power: int
    leadership: int
    building_skill: int
    intelligence: int
    contracts_completed: int
    total_work_contributed: int
    level: int
    
    class Config:
        from_attributes = True


class CoupEventResponse(BaseModel):
    """Response for coup event details"""
    id: int
    kingdom_id: str
    kingdom_name: Optional[str] = None
    initiator_id: int
    initiator_name: str
    initiator_stats: Optional[InitiatorStats] = None  # Stats of the coup initiator
    status: str
    
    # Timing
    start_time: datetime
    end_time: datetime
    time_remaining_seconds: int
    
    # Participants
    attacker_ids: List[int]
    defender_ids: List[int]
    attacker_count: int
    defender_count: int
    
    # User participation
    user_side: Optional[str] = None  # 'attackers', 'defenders', or None
    can_join: bool
    
    # Resolution (if resolved)
    is_resolved: bool
    attacker_victory: Optional[bool] = None
    attacker_strength: Optional[int] = None
    defender_strength: Optional[int] = None
    total_defense_with_walls: Optional[int] = None
    resolved_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CoupInitiateResponse(BaseModel):
    """Response after initiating a coup"""
    success: bool
    message: str
    coup_id: int
    cost_paid: int
    end_time: datetime


class CoupJoinResponse(BaseModel):
    """Response after joining a coup"""
    success: bool
    message: str
    side: str
    attacker_count: int
    defender_count: int


class CoupResolveResponse(BaseModel):
    """Response after resolving a coup"""
    success: bool
    coup_id: int
    attacker_victory: bool
    
    # Battle stats
    attacker_strength: int
    defender_strength: int
    total_defense_with_walls: int
    required_attack_strength: int
    
    # Participants
    attackers: List[CoupParticipant]
    defenders: List[CoupParticipant]
    
    # Ruler change
    old_ruler_id: Optional[int] = None
    old_ruler_name: Optional[str] = None
    new_ruler_id: Optional[int] = None
    new_ruler_name: Optional[str] = None
    
    # Rewards summary
    message: str


class ActiveCoupsResponse(BaseModel):
    """Response with list of active coups"""
    active_coups: List[CoupEventResponse]
    count: int

