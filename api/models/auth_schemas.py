"""
Authentication-related Pydantic schemas
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


# ===== Registration & Login =====

class AppleSignIn(BaseModel):
    """Sign in with Apple"""
    apple_user_id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    
    @field_validator('display_name')
    @classmethod
    def validate_display_name(cls, v: Optional[str]) -> Optional[str]:
        """Validate and sanitize display name"""
        if v is None:
            return v
        
        from utils.validation import validate_username, sanitize_username
        
        # Sanitize first
        v = sanitize_username(v)
        
        # Then validate
        is_valid, error_msg = validate_username(v)
        if not is_valid:
            raise ValueError(error_msg)
        
        return v


class TokenResponse(BaseModel):
    """JWT token response"""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int  # seconds


# ===== User Profile =====

class UserProfile(BaseModel):
    """Public user profile"""
    id: int
    display_name: str
    avatar_url: Optional[str] = None
    level: int
    reputation: int
    total_conquests: int
    kingdoms_ruled: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserPrivate(BaseModel):
    """Private user data (only shown to the user themselves)"""
    id: int
    email: Optional[str] = None
    display_name: str
    avatar_url: Optional[str] = None
    
    # Game stats (from player_state)
    hometown_kingdom_id: Optional[str] = None
    gold: int
    level: int
    experience: int
    reputation: int
    
    # Activity
    total_checkins: int
    total_conquests: int
    kingdoms_ruled: int
    
    # Account
    is_verified: bool
    last_login: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """Update user profile"""
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    email: Optional[str] = None
    hometown_kingdom_id: Optional[str] = None  # For onboarding
    
    @field_validator('display_name')
    @classmethod
    def validate_display_name(cls, v: Optional[str]) -> Optional[str]:
        """Validate and sanitize display name"""
        if v is None:
            return v
        
        from utils.validation import validate_username, sanitize_username
        
        # Sanitize first
        v = sanitize_username(v)
        
        # Then validate
        is_valid, error_msg = validate_username(v)
        if not is_valid:
            raise ValueError(error_msg)
        
        return v


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
    user_id: int
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
    
    # Progression
    level: int
    experience: int


class LeaderboardEntry(BaseModel):
    """Single leaderboard entry"""
    rank: int
    user_id: int
    display_name: str
    avatar_url: Optional[str] = None
    score: int  # Could be reputation, kingdoms, gold, etc.
    level: int

