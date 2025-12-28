"""
Equipment and Property schemas
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class EquipmentItem(BaseModel):
    """Equipment item data"""
    id: str
    type: str  # sword, armor, shield, bow, lance
    tier: int  # 1-5
    craft_start_time: Optional[datetime] = None
    craft_duration: Optional[float] = None  # seconds
    
    class Config:
        from_attributes = True


class PropertyItem(BaseModel):
    """Property data"""
    id: str
    type: str  # house, shop, personal_mine
    kingdom_id: str
    kingdom_name: str
    owner_id: str
    owner_name: str
    tier: int = 1
    purchased_at: Optional[datetime] = None
    last_upgraded: Optional[datetime] = None
    last_income_collection: Optional[datetime] = None
    
    class Config:
        from_attributes = True

