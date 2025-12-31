"""
Activity Log Schemas
"""
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime


class ActivityLogEntry(BaseModel):
    """Single activity log entry"""
    id: int
    user_id: int
    action_type: str
    action_category: str
    description: str
    kingdom_id: Optional[str] = None
    kingdom_name: Optional[str] = None
    amount: Optional[int] = None
    details: Dict[str, Any] = {}
    visibility: str = 'friends'
    created_at: datetime
    
    # Optional user info (for friend activity feeds)
    username: Optional[str] = None
    display_name: Optional[str] = None
    user_level: Optional[int] = None

    class Config:
        from_attributes = True


class PlayerActivityResponse(BaseModel):
    """Response for player activity list"""
    success: bool = True
    total: int
    activities: List[ActivityLogEntry]
