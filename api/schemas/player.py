"""
Player schemas for public profiles and player lists
"""
from pydantic import BaseModel, field_serializer
from typing import Optional, Dict
from datetime import datetime


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


class PlayerActivity(BaseModel):
    """Current activity status for a player"""
    type: str  # "idle", "working", "patrolling", "training", "crafting", "scouting", "fishing", "foraging", "hunting", "researching"
    details: Optional[str] = None  # e.g., "Training Attack", "Fishing", "Foraging for resources"
    icon: Optional[str] = None  # SF Symbol name for display (e.g., "leaf.fill", "figure.hunting")
    expires_at: Optional[datetime] = None  # For time-limited activities
    
    # Structured data for specific activity types
    training_type: Optional[str] = None  # "attack", "defense", "leadership", "building", "intelligence", "science", "faith"
    equipment_type: Optional[str] = None  # "weapon", "armor"
    tier: Optional[int] = None  # For crafting/training tiers
    
    @field_serializer('expires_at')
    def serialize_expires_at(self, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


class PlayerEquipment(BaseModel):
    """Player's equipped items"""
    weapon_tier: Optional[int] = None
    weapon_attack_bonus: Optional[int] = None
    armor_tier: Optional[int] = None
    armor_defense_bonus: Optional[int] = None


class PlayerAchievement(BaseModel):
    """A claimed achievement for display on profile"""
    id: int  # achievement_definitions.id
    achievement_type: str
    tier: int
    display_name: str
    icon: Optional[str] = None
    category: str
    color: str = "inkMedium"  # Theme color name for badge display
    claimed_at: Optional[datetime] = None
    
    @field_serializer('claimed_at')
    def serialize_claimed_at(self, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


class AchievementGroup(BaseModel):
    """Achievements grouped by category for profile display"""
    category: str
    display_name: str
    icon: str
    achievements: list[PlayerAchievement]


# ============================================================
# SUBSCRIBER CUSTOMIZATION SCHEMAS (Server-Driven)
# ============================================================

class ThemeData(BaseModel):
    """
    Server-driven theme data.
    
    All theme colors are defined in the database (subscriber_themes table).
    The frontend just renders these hex colors directly.
    """
    id: str
    display_name: str
    description: Optional[str] = None
    background_color: str  # hex e.g., '#6B21A8'
    text_color: str        # hex
    icon_background_color: str  # hex


class TitleData(BaseModel):
    """Selected achievement title for profile display."""
    achievement_id: int
    display_name: str
    icon: str  # SF Symbol name


class SubscriberSettings(BaseModel):
    """Full subscriber settings response (for settings screen)."""
    is_subscriber: bool
    current_theme: Optional[ThemeData] = None
    selected_title: Optional[TitleData] = None
    available_themes: list[ThemeData] = []
    available_titles: list[TitleData] = []


class SubscriberSettingsUpdate(BaseModel):
    """Request body for updating subscriber settings."""
    theme_id: Optional[str] = None
    selected_title_achievement_id: Optional[int] = None


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
    
    # Ruled kingdom (first one if multiple)
    ruled_kingdom_id: Optional[str] = None
    ruled_kingdom_name: Optional[str] = None
    
    # Stats (public)
    level: int
    reputation: int
    
    # Dynamic skills data - frontend renders without hardcoding!
    skills_data: list = []
    
    # Equipment
    equipment: PlayerEquipment
    
    # Pets
    pets: list = []  # Pet companions owned by this player
    
    # Claimed achievements grouped by category (for profile display)
    achievement_groups: list[AchievementGroup] = []
    
    # Subscriber customization (server-driven)
    is_subscriber: bool = False
    subscriber_theme: Optional[ThemeData] = None
    selected_title: Optional[TitleData] = None
    
    # Achievement stats
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
    
    @field_serializer('last_login', 'created_at')
    def serialize_timestamps(self, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


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



