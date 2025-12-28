"""
Contract schemas
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ContractCreate(BaseModel):
    """Create a new contract"""
    kingdom_id: str
    kingdom_name: str
    building_type: str
    building_level: int
    reward_pool: int
    base_population: int = 0


class ContractResponse(BaseModel):
    """Contract response"""
    id: str
    kingdom_id: str
    kingdom_name: str
    building_type: str
    building_level: int
    base_population: int
    base_hours_required: float
    work_started_at: Optional[datetime] = None
    reward_pool: int
    workers: List[str] = []
    created_by: str
    created_at: datetime
    completed_at: Optional[datetime] = None
    status: str = "open"
    
    class Config:
        from_attributes = True


class ContractUpdate(BaseModel):
    """Update contract"""
    status: Optional[str] = None
    workers: Optional[List[str]] = None
    work_started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

