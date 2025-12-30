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
    total_actions_required: Optional[int] = None  # Auto-calculated if not provided


class ContractResponse(BaseModel):
    """Contract response"""
    id: int
    kingdom_id: str
    kingdom_name: str
    building_type: str
    building_level: int
    base_population: int
    base_hours_required: float
    work_started_at: Optional[datetime] = None
    
    # Action-based system
    total_actions_required: int
    actions_completed: int = 0
    action_contributions: dict = {}  # {user_id: action_count}
    
    # Costs & Rewards
    construction_cost: int = 0  # What ruler paid upfront to START building
    reward_pool: int
    created_by: int
    created_at: datetime
    completed_at: Optional[datetime] = None
    status: str = "open"
    
    class Config:
        from_attributes = True


class ContractUpdate(BaseModel):
    """Update contract"""
    status: Optional[str] = None
    work_started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

