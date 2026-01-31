"""
Achievement System Schemas
"""
from pydantic import BaseModel, field_serializer
from typing import Optional, Dict, Any, List
from datetime import datetime


class AchievementRewards(BaseModel):
    """Rewards structure for an achievement tier"""
    gold: int = 0
    experience: int = 0
    items: List[Dict[str, Any]] = []
    
    class Config:
        extra = 'allow'  # Allow additional reward types


class AchievementTier(BaseModel):
    """A single tier of an achievement"""
    id: int
    tier: int
    target_value: int
    rewards: AchievementRewards
    display_name: str
    description: Optional[str] = None
    
    # Progress and status
    is_completed: bool = False  # Has met target
    is_claimed: bool = False    # Has claimed reward
    claimed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
    
    @field_serializer('claimed_at')
    def serialize_datetime(self, dt: Optional[datetime]) -> Optional[str]:
        if dt is None:
            return None
        return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


class Achievement(BaseModel):
    """An achievement type with all its tiers"""
    achievement_type: str
    display_name: str  # Name of the first unclaimed tier, or last tier if all claimed
    description: Optional[str] = None
    icon: Optional[str] = None
    category: str = 'general'
    type_display_name: Optional[str] = None  # Optional clear description like "Total Fish Caught"
    
    # Progress
    current_value: int = 0
    
    # Tiers
    tiers: List[AchievementTier]
    
    # Computed helpers for UI
    current_tier: int = 0          # Highest completed tier (0 if none)
    next_tier_target: Optional[int] = None  # Target for next unclaimed tier
    progress_percent: float = 0.0  # Progress to next unclaimed tier
    has_claimable: bool = False    # Has a completed but unclaimed tier
    
    class Config:
        from_attributes = True


class AchievementCategory(BaseModel):
    """Grouped achievements by category"""
    category: str
    display_name: str
    icon: str
    achievements: List[Achievement]


class AchievementsResponse(BaseModel):
    """Response for achievements list"""
    success: bool = True
    categories: List[AchievementCategory]
    total_achievements: int  # Number of unique achievement types
    total_tiers: int  # Total number of claimable tiers across all achievements
    total_completed: int  # Number of tiers completed (met target)
    total_claimed: int  # Number of tiers with rewards claimed
    total_claimable: int  # Number of tiers completed but not yet claimed
    overall_progress_percent: float  # Claimed tiers / total tiers * 100


class ClaimRewardRequest(BaseModel):
    """Request to claim an achievement tier reward"""
    achievement_tier_id: int


class ClaimRewardResponse(BaseModel):
    """Response after claiming a reward"""
    success: bool = True
    message: str
    rewards_granted: AchievementRewards
    
    # Updated player values after reward
    new_gold: int
    new_experience: int
    new_level: Optional[int] = None  # If leveled up
    
    # The claimed achievement info
    achievement_type: str
    tier: int
    display_name: str
