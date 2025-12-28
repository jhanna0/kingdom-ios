"""
Authentication-related Pydantic schemas
"""
from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime


# ===== Registration & Login =====

class AppleSignIn(BaseModel):
    """Sign in with Apple"""
    apple_user_id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    hometown_kingdom_id: Optional[str] = None


class TokenResponse(BaseModel):
    """JWT token response"""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int  # seconds


# ===== User Profile =====

class UserProfile(BaseModel):
    """Public user profile"""
    id: str
    display_name: str
    avatar_url: Optional[str] = None
    level: int
    reputation: int
    honor: int
    total_conquests: int
    kingdoms_ruled: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserPrivate(BaseModel):
    """Private user data (only shown to the user themselves)"""
    id: str
    email: Optional[str] = None
    display_name: str
    avatar_url: Optional[str] = None
    hometown_kingdom_id: Optional[str] = None
    
    # Game stats
    gold: int
    level: int
    experience: int
    reputation: int
    honor: int
    
    # Activity
    total_checkins: int
    total_conquests: int
    kingdoms_ruled: int
    
    # Premium
    is_premium: bool
    premium_expires_at: Optional[datetime] = None
    
    # Account
    is_verified: bool
    last_login: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """Update user profile"""
    display_name: Optional[str] = Field(None, min_length=1, max_length=50)
    avatar_url: Optional[str] = None
    email: Optional[str] = None
    hometown_kingdom_id: Optional[str] = None


class PasswordChange(BaseModel):
    """Change password"""
    old_password: str
    new_password: str = Field(..., min_length=8, max_length=100)


# ===== User Kingdoms =====

class UserKingdomInfo(BaseModel):
    """Info about a user's relationship with a kingdom"""
    kingdom_id: str
    kingdom_name: str
    is_ruler: bool
    is_subject: bool
    times_conquered: int
    local_reputation: int
    checkins_count: int
    last_checkin: Optional[datetime] = None
    first_visited: datetime
    became_ruler_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class UserKingdomsList(BaseModel):
    """List of user's kingdoms"""
    ruled_kingdoms: list[UserKingdomInfo]
    subject_kingdoms: list[UserKingdomInfo]
    visited_kingdoms: list[UserKingdomInfo]


# ===== Stats & Leaderboard =====

class UserStats(BaseModel):
    """Detailed user statistics"""
    user_id: str
    display_name: str
    
    # Combat & Territory
    total_conquests: int
    kingdoms_ruled: int
    current_kingdoms_count: int
    
    # Activity
    total_checkins: int
    
    # Economy
    gold: int
    
    # Reputation
    reputation: int
    honor: int
    
    # Progression
    level: int
    experience: int


class LeaderboardEntry(BaseModel):
    """Single leaderboard entry"""
    rank: int
    user_id: str
    display_name: str
    avatar_url: Optional[str] = None
    score: int  # Could be reputation, kingdoms, gold, etc.
    level: int

