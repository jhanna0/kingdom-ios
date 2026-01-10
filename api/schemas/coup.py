"""
Coup event schemas for API requests/responses (V2)

Two-phase coup system with full character sheet display.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class CoupInitiateRequest(BaseModel):
    """Request to initiate a coup"""
    kingdom_id: str = Field(..., description="Kingdom where coup is being initiated")


class CoupJoinRequest(BaseModel):
    """Request to join a coup side (pledge)"""
    side: str = Field(..., description="Side to join: 'attackers' or 'defenders'")


class CoupParticipant(BaseModel):
    """A player participating in a coup - includes stats for display"""
    player_id: int
    player_name: str
    kingdom_reputation: int = 0  # For sorting
    attack_power: int = 0
    defense_power: int = 0
    leadership: int = 0
    level: int = 1
    
    class Config:
        from_attributes = True


class InitiatorStats(BaseModel):
    """
    Full character sheet for the coup initiator.
    Displayed so voters can evaluate who they're supporting.
    """
    # Identity
    level: int
    
    # Reputation
    kingdom_reputation: int  # In this specific kingdom
    
    # Combat stats
    attack_power: int
    defense_power: int
    leadership: int
    
    # Other skills
    building_skill: int
    intelligence: int
    
    # Track record
    contracts_completed: int
    total_work_contributed: int
    coups_won: int
    coups_failed: int
    
    class Config:
        from_attributes = True


class CoupEventResponse(BaseModel):
    """Response for coup event details"""
    id: int
    kingdom_id: str
    kingdom_name: Optional[str] = None
    initiator_id: int
    initiator_name: str
    initiator_stats: Optional[InitiatorStats] = None  # Full character sheet
    status: str  # 'pledge', 'battle', 'resolved'
    
    # Timing
    start_time: datetime
    pledge_end_time: datetime
    battle_end_time: Optional[datetime] = None
    time_remaining_seconds: int  # For current phase
    
    # Participants - full details, sorted by kingdom_reputation descending
    attackers: List[CoupParticipant] = []
    defenders: List[CoupParticipant] = []
    attacker_count: int
    defender_count: int
    
    # User participation
    user_side: Optional[str] = None  # 'attackers', 'defenders', or None
    can_pledge: bool  # Can the user still pledge?
    
    # Resolution (if resolved)
    is_resolved: bool
    attacker_victory: Optional[bool] = None
    resolved_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CoupInitiateResponse(BaseModel):
    """Response after initiating a coup"""
    success: bool
    message: str
    coup_id: int
    pledge_end_time: datetime  # When pledge phase ends


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

