"""
User/Player state schemas
"""
from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime

from .equipment import EquipmentItem, PropertyItem


class TravelEvent(BaseModel):
    """Information about a kingdom entry/travel event"""
    entered_kingdom: bool  # Whether this was a new kingdom entry
    kingdom_name: str
    travel_fee_paid: int  # Amount paid (0 if free)
    free_travel_reason: Optional[str] = None  # "ruler", "property_owner", "allied", or None
    
    
class PlayerState(BaseModel):
    """Complete player state for sync"""
    # Identity
    id: int  # User ID from database (auto-increment)
    display_name: str
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    
    # Kingdom & Territory
    hometown_kingdom_id: Optional[str] = None
    origin_kingdom_id: Optional[str] = None
    home_kingdom_id: Optional[str] = None
    current_kingdom_id: Optional[str] = None
    fiefs_ruled: List[str] = []
    
    # Core Stats
    gold: int = 100
    level: int = 1
    experience: int = 0
    skill_points: int = 0
    
    # Combat Stats
    attack_power: int = 1
    defense_power: int = 1
    leadership: int = 1
    building_skill: int = 1
    intelligence: int = 1
    
    # Debuffs
    attack_debuff: int = 0
    debuff_expires_at: Optional[datetime] = None
    
    # Reputation
    reputation: int = 0
    honor: int = 100
    kingdom_reputation: Dict[str, int] = {}
    
    # Check-in tracking
    check_in_history: Dict[str, int] = {}
    last_check_in: Optional[datetime] = None
    last_daily_check_in: Optional[datetime] = None
    
    # Activity tracking
    total_checkins: int = 0
    total_conquests: int = 0
    kingdoms_ruled: int = 0
    has_claimed_starting_city: bool = False
    coups_won: int = 0
    coups_failed: int = 0
    times_executed: int = 0
    executions_ordered: int = 0
    last_coup_attempt: Optional[datetime] = None
    
    # Contract & Work
    contracts_completed: int = 0
    total_work_contributed: int = 0
    total_training_purchases: int = 0  # Total training sessions purchased (for cost scaling)
    
    # Resources
    iron: int = 0
    steel: int = 0
    
    # Daily Actions
    last_mining_action: Optional[datetime] = None
    last_crafting_action: Optional[datetime] = None
    last_building_action: Optional[datetime] = None
    last_spy_action: Optional[datetime] = None
    
    # Action System (cooldown-based)
    last_work_action: Optional[datetime] = None
    last_patrol_action: Optional[datetime] = None
    last_sabotage_action: Optional[datetime] = None
    last_scout_action: Optional[datetime] = None
    patrol_expires_at: Optional[datetime] = None
    
    # Equipment
    equipped_weapon: Optional[EquipmentItem] = None
    equipped_armor: Optional[EquipmentItem] = None
    equipped_shield: Optional[EquipmentItem] = None
    inventory: List[EquipmentItem] = []
    crafting_queue: List[EquipmentItem] = []
    crafting_progress: Dict[str, int] = {}
    
    # Properties
    properties: List[PropertyItem] = []
    
    # Rewards
    total_rewards_received: int = 0
    last_reward_received: Optional[datetime] = None
    last_reward_amount: int = 0
    
    # Status
    is_alive: bool = True
    is_ruler: bool = False
    is_premium: bool = False
    is_verified: bool = False
    
    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    last_login: Optional[datetime] = None
    
    # Training costs (calculated dynamically)
    training_costs: Optional[dict] = None
    
    # Travel event (only present when kingdom_id is provided to /player/state)
    travel_event: Optional[TravelEvent] = None
    
    class Config:
        from_attributes = True


class PlayerStateUpdate(BaseModel):
    """Partial update for player state"""
    # All fields optional for partial updates
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    
    # Kingdom & Territory
    hometown_kingdom_id: Optional[str] = None
    origin_kingdom_id: Optional[str] = None
    home_kingdom_id: Optional[str] = None
    current_kingdom_id: Optional[str] = None
    fiefs_ruled: Optional[List[str]] = None
    
    # Core Stats
    gold: Optional[int] = None
    level: Optional[int] = None
    experience: Optional[int] = None
    skill_points: Optional[int] = None
    
    # Combat Stats
    attack_power: Optional[int] = None
    defense_power: Optional[int] = None
    leadership: Optional[int] = None
    building_skill: Optional[int] = None
    intelligence: Optional[int] = None
    
    # Debuffs
    attack_debuff: Optional[int] = None
    debuff_expires_at: Optional[datetime] = None
    
    # Reputation
    reputation: Optional[int] = None
    honor: Optional[int] = None
    kingdom_reputation: Optional[Dict[str, int]] = None
    
    # Check-in tracking
    check_in_history: Optional[Dict[str, int]] = None
    last_check_in: Optional[datetime] = None
    last_daily_check_in: Optional[datetime] = None
    
    # Activity tracking
    total_checkins: Optional[int] = None
    total_conquests: Optional[int] = None
    kingdoms_ruled: Optional[int] = None
    has_claimed_starting_city: Optional[bool] = None
    coups_won: Optional[int] = None
    coups_failed: Optional[int] = None
    times_executed: Optional[int] = None
    executions_ordered: Optional[int] = None
    last_coup_attempt: Optional[datetime] = None
    
    # Contract & Work
    contracts_completed: Optional[int] = None
    total_work_contributed: Optional[int] = None
    total_training_purchases: Optional[int] = None
    
    # Resources
    iron: Optional[int] = None
    steel: Optional[int] = None
    
    # Daily Actions
    last_mining_action: Optional[datetime] = None
    last_crafting_action: Optional[datetime] = None
    last_building_action: Optional[datetime] = None
    last_spy_action: Optional[datetime] = None
    
    # Action System (cooldown-based)
    last_work_action: Optional[datetime] = None
    last_patrol_action: Optional[datetime] = None
    last_sabotage_action: Optional[datetime] = None
    last_scout_action: Optional[datetime] = None
    patrol_expires_at: Optional[datetime] = None
    
    # Equipment
    equipped_weapon: Optional[EquipmentItem] = None
    equipped_armor: Optional[EquipmentItem] = None
    equipped_shield: Optional[EquipmentItem] = None
    inventory: Optional[List[EquipmentItem]] = None
    crafting_queue: Optional[List[EquipmentItem]] = None
    crafting_progress: Optional[Dict[str, int]] = None
    
    # Properties
    properties: Optional[List[PropertyItem]] = None
    
    # Rewards
    total_rewards_received: Optional[int] = None
    last_reward_received: Optional[datetime] = None
    last_reward_amount: Optional[int] = None
    
    # Status
    is_alive: Optional[bool] = None
    is_ruler: Optional[bool] = None


class SyncRequest(BaseModel):
    """Request to sync player state"""
    player_state: PlayerStateUpdate
    last_sync_time: Optional[datetime] = None


class SyncResponse(BaseModel):
    """Response with merged state"""
    success: bool
    message: str
    player_state: PlayerState
    server_time: datetime


# Legacy schemas for backwards compatibility
class Player(BaseModel):
    id: str
    name: str
    gold: int = 0
    level: int = 1
    created_at: Optional[datetime] = None


class PlayerCreate(BaseModel):
    id: str
    name: str


class PlayerUpdate(BaseModel):
    gold: Optional[int] = None
    level: Optional[int] = None

