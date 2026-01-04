"""
Player schemas for public profiles and player lists
"""
from pydantic import BaseModel
from typing import Optional, Dict
from datetime import datetime


class PlayerActivity(BaseModel):
    """Current activity status for a player"""
    type: str  # "idle", "working", "patrolling", "training", "crafting", "scouting"
    details: Optional[str] = None  # e.g., "Training Attack", "Working on Wall Level 5"
    expires_at: Optional[datetime] = None  # For time-limited activities
    
    # Structured data for specific activity types
    training_type: Optional[str] = None  # "attack", "defense", "leadership", "building", "intelligence", "science", "faith"
    equipment_type: Optional[str] = None  # "weapon", "armor"
    tier: Optional[int] = None  # For crafting/training tiers


class PlayerEquipment(BaseModel):
    """Player's equipped items"""
    weapon_tier: Optional[int] = None
    weapon_attack_bonus: Optional[int] = None
    armor_tier: Optional[int] = None
    armor_defense_bonus: Optional[int] = None


class PlayerPublicProfile(BaseModel):
    """Public profile for any player - visible to others"""
    # Identity
    id: int
    display_name: str
    avatar_url: Optional[str] = None
    
    # Location
    current_kingdom_id: Optional[str] = None
    current_kingdom_name: Optional[str] = None
    hometown_kingdom_id: Optional[str] = None
    
    # Stats (public)
    level: int
    reputation: int
    honor: int
    
    # Combat stats
    attack_power: int
    defense_power: int
    leadership: int
    building_skill: int
    intelligence: int
    science: int
    faith: int
    
    # Equipment
    equipment: PlayerEquipment
    
    # Achievements
    total_checkins: int
    total_conquests: int
    kingdoms_ruled: int
    coups_won: int
    contracts_completed: int
    
    # Current activity
    activity: PlayerActivity
    
    # Timestamps
    last_login: Optional[datetime] = None
    created_at: datetime


class PlayerInKingdom(BaseModel):
    """Condensed player info for kingdom player lists"""
    id: int
    display_name: str
    avatar_url: Optional[str] = None
    level: int
    reputation: int
    attack_power: int
    defense_power: int
    leadership: int
    activity: PlayerActivity
    is_ruler: bool
    is_online: bool  # Active in last 5 minutes


class PlayersInKingdomResponse(BaseModel):
    """Response for players in a kingdom"""
    kingdom_id: str
    kingdom_name: str
    total_players: int
    online_count: int
    players: list[PlayerInKingdom]


class ActivePlayersResponse(BaseModel):
    """Response for recently active players"""
    total: int
    players: list[PlayerInKingdom]



