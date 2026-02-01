"""
Activity Log Schemas
"""
from pydantic import BaseModel, field_serializer
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
    
    # Display info (icon and color for frontend)
    icon: Optional[str] = None
    color: Optional[str] = None
    
    # Optional user info (for friend activity feeds)
    username: Optional[str] = None
    display_name: Optional[str] = None
    user_level: Optional[int] = None

    class Config:
        from_attributes = True
    
    @field_serializer('created_at')
    def serialize_datetime(self, dt: datetime) -> str:
        """Serialize datetime for iOS TimeFormatter.parseISO"""
        if dt is None:
            return None
        # Output without Z suffix to match iOS parseISO format
        return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%S')


class PlayerActivityResponse(BaseModel):
    """Response for player activity list"""
    success: bool = True
    total: int
    activities: List[ActivityLogEntry]
