"""
Unified Battle Schemas - Coups and Invasions

Request/response models for the unified battle system.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ============================================================
# PARTICIPANT SCHEMAS
# ============================================================

class BattleParticipantSchema(BaseModel):
    """A player participating in a battle - includes stats for display"""
    player_id: int
    player_name: str
    kingdom_reputation: int = 0
    attack_power: int = 0
    defense_power: int = 0
    leadership: int = 0
    level: int = 1
    
    class Config:
        from_attributes = True


class InitiatorStats(BaseModel):
    """Full character sheet for the battle initiator."""
    level: int
    kingdom_reputation: int
    attack_power: int
    defense_power: int
    leadership: int
    building_skill: int
    intelligence: int
    contracts_completed: int
    total_work_contributed: int
    coups_won: int
    coups_failed: int
    
    class Config:
        from_attributes = True


# ============================================================
# TERRITORY SCHEMAS
# ============================================================

class BattleTerritoryResponse(BaseModel):
    """Territory status in a battle"""
    name: str
    display_name: str
    icon: str
    control_bar: float  # 0-100 (0 = attackers captured, 100 = defenders captured)
    captured_by: Optional[str] = None
    captured_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# ============================================================
# ROLL SCHEMAS
# ============================================================

class RollResult(BaseModel):
    """Single roll result"""
    value: float
    outcome: str  # 'miss', 'hit', 'injure'


# ============================================================
# INITIATE/DECLARE REQUESTS
# ============================================================

class CoupInitiateRequest(BaseModel):
    """Request to initiate a coup"""
    target_kingdom_id: str = Field(..., description="Kingdom where coup is being initiated")


class InvasionDeclareRequest(BaseModel):
    """Request to declare an invasion"""
    target_kingdom_id: str = Field(..., description="Kingdom to invade")
    # attacking_from_kingdom_id is determined by which kingdom the ruler rules


class BattleInitiateResponse(BaseModel):
    """Response after initiating a coup or declaring invasion"""
    success: bool
    message: str
    battle_id: int
    battle_type: str  # 'coup' or 'invasion'
    pledge_end_time: datetime


# ============================================================
# JOIN REQUESTS
# ============================================================

class BattleJoinRequest(BaseModel):
    """Request to join a battle"""
    side: str = Field(..., description="Side to join: 'attackers' or 'defenders'")


class BattleJoinResponse(BaseModel):
    """Response after joining a battle"""
    success: bool
    message: str
    side: str
    attacker_count: int
    defender_count: int


# ============================================================
# FIGHT REQUESTS
# ============================================================

class FightRequest(BaseModel):
    """Request to fight in a territory"""
    territory: str = Field(..., description="Territory to fight in")


class FightResponse(BaseModel):
    """Response after fighting in a territory (legacy - all rolls at once)"""
    success: bool
    message: str
    roll_count: int
    rolls: List[RollResult]
    best_outcome: str
    push_amount: float
    bar_before: float
    bar_after: float
    territory: BattleTerritoryResponse
    injured_player_name: Optional[str] = None
    battle_won: bool = False
    winner_side: Optional[str] = None
    cooldown_seconds: int


# ============================================================
# FIGHT SESSION SCHEMAS (roll-by-roll)
# ============================================================

class FightSessionResponse(BaseModel):
    """Current state of a fight session"""
    success: bool
    message: str = ""
    territory_name: str
    territory_display_name: str
    territory_icon: str
    side: str
    max_rolls: int
    rolls_completed: int
    rolls_remaining: int
    rolls: List[RollResult]
    miss_chance: int = 0
    hit_chance: int = 0
    injure_chance: int = 0
    best_outcome: str
    can_roll: bool
    bar_before: float
    
    class Config:
        from_attributes = True


class FightRollResponse(BaseModel):
    """Response after doing one roll"""
    success: bool
    message: str
    roll: RollResult
    roll_number: int
    rolls_completed: int
    rolls_remaining: int
    best_outcome: str
    can_roll: bool


class FightResolveResponse(BaseModel):
    """Response after resolving a fight"""
    success: bool
    message: str
    roll_count: int
    rolls: List[RollResult]
    best_outcome: str
    push_amount: float
    bar_before: float
    bar_after: float
    territory: BattleTerritoryResponse
    injured_player_name: Optional[str] = None
    battle_won: bool = False
    winner_side: Optional[str] = None
    cooldown_seconds: int


# ============================================================
# BATTLE EVENT RESPONSE (main detail response)
# ============================================================

class HowItWorksStep(BaseModel):
    """A single step in how the battle works"""
    number: str
    text: str


class BattleEventResponse(BaseModel):
    """Full battle event details"""
    id: int
    type: str  # 'coup' or 'invasion'
    
    # Target kingdom
    kingdom_id: str
    kingdom_name: Optional[str] = None
    
    # For invasions: attacking kingdom
    attacking_from_kingdom_id: Optional[str] = None
    attacking_from_kingdom_name: Optional[str] = None
    
    # Initiator
    initiator_id: int
    initiator_name: str
    initiator_stats: Optional[InitiatorStats] = None
    
    # Current ruler (being challenged/defended)
    ruler_id: Optional[int] = None
    ruler_name: Optional[str] = None
    ruler_stats: Optional[InitiatorStats] = None
    
    # Phase
    status: str  # 'pledge', 'battle', 'resolved'
    
    # Timing
    start_time: datetime
    pledge_end_time: datetime
    time_remaining_seconds: int
    
    # Participants
    attackers: List[BattleParticipantSchema] = []
    defenders: List[BattleParticipantSchema] = []
    attacker_count: int
    defender_count: int
    
    # User's participation
    user_side: Optional[str] = None
    can_join: bool
    
    # Battle phase data
    territories: List[BattleTerritoryResponse] = []
    battle_cooldown_seconds: int = 0
    is_injured: bool = False
    injury_expires_seconds: int = 0
    
    # Invasion-specific
    wall_defense_applied: Optional[int] = None
    
    # Resolution
    is_resolved: bool
    attacker_victory: Optional[bool] = None
    resolved_at: Optional[datetime] = None
    winner_side: Optional[str] = None
    
    # UI Content - populated by backend based on battle type
    how_it_works: List[HowItWorksStep] = []
    consequences: List[str] = []
    attacker_label: str = "ATTACKERS"
    defender_label: str = "DEFENDERS"
    
    class Config:
        from_attributes = True


class ActiveBattlesResponse(BaseModel):
    """Response with list of active battles"""
    active_battles: List[BattleEventResponse]
    count: int


# ============================================================
# RESOLVE RESPONSE
# ============================================================

class BattleResolveResponse(BaseModel):
    """Response after resolving a battle"""
    success: bool
    battle_id: int
    battle_type: str
    attacker_victory: bool
    attacker_strength: int
    defender_strength: int
    total_defense_with_walls: int
    required_attack_strength: int
    attackers: List[BattleParticipantSchema]
    defenders: List[BattleParticipantSchema]
    old_ruler_id: Optional[int] = None
    old_ruler_name: Optional[str] = None
    new_ruler_id: Optional[int] = None
    new_ruler_name: Optional[str] = None
    # Invasion-specific
    loot_per_attacker: Optional[int] = None
    wall_damage: Optional[int] = None
    message: str


# ============================================================
# ELIGIBILITY CHECK (for UI to show/hide buttons)
# ============================================================

class BattleEligibilityResponse(BaseModel):
    """Check if user can initiate a battle in a kingdom"""
    can_initiate_coup: bool
    coup_reason: Optional[str] = None  # Why not, if can't
    
    can_declare_invasion: bool
    invasion_reason: Optional[str] = None  # Why not, if can't
    
    can_join_active_battle: bool
    active_battle_id: Optional[int] = None
    active_battle_type: Optional[str] = None
    join_reason: Optional[str] = None  # Why not, if can't
