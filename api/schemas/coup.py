"""
Coup event schemas for API requests/responses (V2)

Two-phase coup system with full character sheet display.
Battle phase with territory conquest mechanics.
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Any
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


# ============================================================
# BATTLE PHASE SCHEMAS
# ============================================================

class CoupTerritoryResponse(BaseModel):
    """Territory status in a coup battle"""
    name: str  # coupers_territory, crowns_territory, throne_room
    display_name: str
    icon: str
    control_bar: float  # 0-100 (0 = attackers captured, 100 = defenders captured)
    captured_by: Optional[str] = None  # 'attackers', 'defenders', or None
    captured_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class RollResult(BaseModel):
    """Single roll result"""
    value: float  # Raw roll value (0-1)
    outcome: str  # 'miss', 'hit', 'injure'


class CoupFightRequest(BaseModel):
    """Request to fight in a territory"""
    territory: str = Field(..., description="Territory to fight in: coupers_territory, crowns_territory, throne_room")


class CoupFightResponse(BaseModel):
    """Response after fighting in a territory (legacy - all rolls at once)"""
    success: bool
    message: str
    
    # Roll results
    roll_count: int
    rolls: List[RollResult]
    best_outcome: str  # 'miss', 'hit', 'injure'
    
    # Bar movement
    push_amount: float
    bar_before: float
    bar_after: float
    
    # Territory status after fight
    territory: CoupTerritoryResponse
    
    # Injury info (if inflicted)
    injured_player_name: Optional[str] = None
    
    # Battle status
    battle_won: bool = False  # True if this fight won the battle
    winner_side: Optional[str] = None  # 'attackers' or 'defenders' if battle won
    
    # Cooldown for next action
    cooldown_seconds: int


# ============================================================
# FIGHT SESSION SCHEMAS (roll-by-roll like hunting)
# ============================================================

class FightSessionResponse(BaseModel):
    """Current state of a fight session"""
    success: bool
    message: str = ""
    
    # Session info
    territory_name: str
    territory_display_name: str
    territory_icon: str
    side: str  # 'attackers' or 'defenders'
    
    # Roll state
    max_rolls: int
    rolls_completed: int
    rolls_remaining: int
    rolls: List[RollResult]
    
    # Roll bar percentages - backend calculates, frontend just displays
    miss_chance: int   # 0-100
    hit_chance: int    # 0-100
    injure_chance: int # 0-100
    
    best_outcome: str  # 'miss', 'hit', 'injure'
    can_roll: bool
    
    # Bar info
    bar_before: float
    
    class Config:
        from_attributes = True


class FightRollResponse(BaseModel):
    """Response after doing one roll"""
    success: bool
    message: str
    
    # The roll that was just done
    roll: RollResult
    roll_number: int  # 1-indexed
    
    # Updated session state
    rolls_completed: int
    rolls_remaining: int
    best_outcome: str
    can_roll: bool


class FightResolveResponse(BaseModel):
    """Response after resolving a fight"""
    success: bool
    message: str
    
    # Roll summary
    roll_count: int
    rolls: List[RollResult]
    best_outcome: str
    
    # Bar movement
    push_amount: float
    bar_before: float
    bar_after: float
    
    # Territory status
    territory: CoupTerritoryResponse
    
    # Injury info
    injured_player_name: Optional[str] = None
    
    # Battle status
    battle_won: bool = False
    winner_side: Optional[str] = None
    
    # Cooldown
    cooldown_seconds: int


class CoupEventResponse(BaseModel):
    """Response for coup event details"""
    id: int
    kingdom_id: str
    kingdom_name: Optional[str] = None
    initiator_id: int
    initiator_name: str
    initiator_stats: Optional[InitiatorStats] = None  # Full character sheet for challenger
    ruler_id: Optional[int] = None  # Current ruler being challenged
    ruler_name: Optional[str] = None  # Current ruler's name
    ruler_stats: Optional[InitiatorStats] = None  # Full character sheet for ruler
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
    
    # Battle phase data (only during battle phase)
    territories: List[CoupTerritoryResponse] = []  # 3 territories with bar values
    battle_cooldown_seconds: int = 0  # User's remaining cooldown
    is_injured: bool = False  # Is user currently injured (sitting out)?
    injury_expires_seconds: int = 0  # Seconds until injury clears
    
    # Resolution (if resolved)
    is_resolved: bool
    attacker_victory: Optional[bool] = None
    resolved_at: Optional[datetime] = None
    winner_side: Optional[str] = None  # 'attackers' or 'defenders'
    
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

