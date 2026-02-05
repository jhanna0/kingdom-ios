"""
User/Player state schemas
"""
from pydantic import BaseModel, field_serializer
from typing import Optional, List, Dict
from datetime import datetime

from .equipment import EquipmentItem, PropertyItem


def serialize_datetime_with_z(dt: Optional[datetime]) -> Optional[str]:
    """Serialize datetime to ISO8601 string with Z suffix for iOS compatibility"""
    if dt is None:
        return None
    # Strip microseconds - Swift's .iso8601 decoder can't parse them
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        # Naive datetime - assume UTC and add Z
        return iso_str + 'Z'
    return iso_str


class TravelEvent(BaseModel):
    """Information about a kingdom entry/travel event"""
    entered_kingdom: bool  # Whether this was a new kingdom entry
    kingdom_name: str
    travel_fee_paid: int  # Amount paid (0 if free)
    free_travel_reason: Optional[str] = None  # "ruler", "property_owner", "allied", or None
    denied: bool = False  # Whether entry was denied
    denial_reason: Optional[str] = None  # Why entry was denied
    
    
class PlayerState(BaseModel):
    """Complete player state for API responses"""
    # Identity
    id: int
    display_name: str
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    
    # Territory
    hometown_kingdom_id: Optional[str] = None
    hometown_kingdom_name: Optional[str] = None  # Computed on read
    current_kingdom_id: Optional[str] = None
    current_kingdom_name: Optional[str] = None  # Computed on read
    
    # Progression
    gold: int = 100
    food: int = 0  # Total food (meat + berries + other is_food resources)
    level: int = 1
    experience: int = 0
    skill_points: int = 0
    
    # Stats (T0-T5)
    attack_power: int = 0
    defense_power: int = 0
    leadership: int = 0
    building_skill: int = 0
    intelligence: int = 0
    science: int = 0
    faith: int = 0
    
    # Combat debuff
    attack_debuff: int = 0
    debuff_expires_at: Optional[datetime] = None
    
    # Reputation
    reputation: int = 0  # Per-kingdom rep is in user_kingdoms, this is for API compatibility
    
    # Activity (TODO: should be computed from other tables)
    total_checkins: int = 0
    total_conquests: int = 0
    kingdoms_ruled: int = 0
    coups_won: int = 0
    coups_failed: int = 0
    times_executed: int = 0
    executions_ordered: int = 0
    contracts_completed: int = 0
    total_work_contributed: int = 0
    total_training_purchases: int = 0
    
    # Flags
    has_claimed_starting_city: bool = False
    is_alive: bool = True
    is_ruler: bool = False  # Computed on read
    is_verified: bool = False
    is_subscriber: bool = False  # Has active subscription
    
    # Subscriber customization (server-driven colors and titles)
    subscriber_customization: Optional[dict] = None  # SubscriberCustomization as dict
    
    # Resources (computed from player_inventory table for backwards compatibility)
    # These fields are populated by the API from inventory queries
    iron: int = 0
    wood: int = 0
    steel: int = 0  # Legacy field for iOS compatibility
    
    # Equipment (from player_items table)
    equipped_weapon: Optional[EquipmentItem] = None
    equipped_armor: Optional[EquipmentItem] = None
    
    # Properties (from properties table)
    properties: List[PropertyItem] = []
    
    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    last_login: Optional[datetime] = None
    
    # Dynamic data computed on read
    training_costs: Optional[dict] = None
    travel_event: Optional[TravelEvent] = None
    active_perks: Optional[dict] = None
    skills_data: Optional[list] = None
    resources_data: Optional[list] = None  # Includes inventory items
    inventory: Optional[list] = None  # From player_inventory table
    pets: Optional[list] = None  # Pet companions from player_inventory
    
    @field_serializer('debuff_expires_at', 'created_at', 'updated_at', 'last_login')
    def serialize_timestamps(self, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)
    
    @field_serializer('gold')
    def serialize_gold(self, value: float) -> int:
        """Floor gold to integer for frontend display (stored as float for precise tax math)"""
        return int(value)
    
    class Config:
        from_attributes = True


class PlayerStateUpdate(BaseModel):
    """Partial update for player state - only fields that can actually be updated"""
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    
    # Territory
    hometown_kingdom_id: Optional[str] = None
    current_kingdom_id: Optional[str] = None
    
    # Progression
    gold: Optional[int] = None
    level: Optional[int] = None
    experience: Optional[int] = None
    skill_points: Optional[int] = None
    
    # Stats
    attack_power: Optional[int] = None
    defense_power: Optional[int] = None
    leadership: Optional[int] = None
    building_skill: Optional[int] = None
    intelligence: Optional[int] = None
    science: Optional[int] = None
    faith: Optional[int] = None
    
    # Combat
    attack_debuff: Optional[int] = None
    debuff_expires_at: Optional[datetime] = None
    
    # NOTE: Resources (iron, wood, stone) are no longer updatable via this schema
    # They are managed through inventory operations only
    
    # Status
    is_alive: Optional[bool] = None
    has_claimed_starting_city: Optional[bool] = None


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
    
    @field_serializer('server_time')
    def serialize_server_time(self, dt: datetime) -> str:
        return serialize_datetime_with_z(dt)


# Legacy schemas for backwards compatibility
class Player(BaseModel):
    id: str
    name: str
    gold: int = 0
    level: int = 1
    created_at: Optional[datetime] = None
    
    @field_serializer('created_at')
    def serialize_created_at(self, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


class PlayerCreate(BaseModel):
    id: str
    name: str


class PlayerUpdate(BaseModel):
    gold: Optional[int] = None
    level: Optional[int] = None

