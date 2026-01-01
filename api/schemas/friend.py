from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ===== Friend Request/Response Schemas =====

class FriendRequest(BaseModel):
    """Request to add a friend by username or user_id"""
    username: Optional[str] = None
    user_id: Optional[int] = None


class FriendResponse(BaseModel):
    """Friend information"""
    id: int
    user_id: int
    friend_user_id: int
    friend_username: str
    friend_display_name: str
    status: str  # 'pending', 'accepted', 'rejected', 'blocked'
    created_at: str
    updated_at: str
    
    # Friend activity data (if accepted)
    is_online: Optional[bool] = None
    level: Optional[int] = None
    current_kingdom_id: Optional[str] = None
    current_kingdom_name: Optional[str] = None
    last_seen: Optional[str] = None
    activity: Optional[dict] = None


class FriendListResponse(BaseModel):
    """List of friends"""
    success: bool
    friends: List[FriendResponse]
    pending_received: List[FriendResponse]  # Requests you received
    pending_sent: List[FriendResponse]  # Requests you sent


class AddFriendResponse(BaseModel):
    """Response after sending friend request"""
    success: bool
    message: str
    friend: Optional[FriendResponse] = None


class FriendActionResponse(BaseModel):
    """Generic response for friend actions"""
    success: bool
    message: str


class SearchUsersResponse(BaseModel):
    """Search results for users"""
    success: bool
    users: List[dict]  # List of user info


class FriendActivityUpdate(BaseModel):
    """Real-time update of friend activity"""
    friend_id: int
    is_online: bool
    activity: Optional[dict] = None
    current_kingdom_name: Optional[str] = None



