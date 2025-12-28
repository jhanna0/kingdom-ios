"""
Kingdom schemas
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class Kingdom(BaseModel):
    """Basic kingdom response"""
    id: str
    name: str
    ruler_id: Optional[str] = None
    ruler_name: Optional[str] = None
    treasury: int = 0
    population: int = 0
    created_at: Optional[datetime] = None


class KingdomState(BaseModel):
    """Complete kingdom state"""
    id: str
    name: str
    ruler_id: Optional[str] = None
    ruler_name: Optional[str] = None
    
    # Location
    city_boundary_osm_id: Optional[str] = None
    
    # Game state
    population: int = 0
    level: int = 1
    treasury_gold: int = 0
    checked_in_players: int = 0
    
    # Buildings
    wall_level: int = 0
    vault_level: int = 0
    mine_level: int = 0
    market_level: int = 0
    
    # Tax & Income
    tax_rate: int = 10
    subject_reward_rate: int = 15
    total_income_collected: int = 0
    total_rewards_distributed: int = 0
    
    # Alliances
    allies: List[str] = []
    enemies: List[str] = []
    
    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class KingdomUpdate(BaseModel):
    """Partial update for kingdom"""
    ruler_id: Optional[str] = None
    ruler_name: Optional[str] = None
    treasury: Optional[int] = None
    population: Optional[int] = None
    wall_level: Optional[int] = None
    vault_level: Optional[int] = None
    mine_level: Optional[int] = None
    market_level: Optional[int] = None
    tax_rate: Optional[int] = None
    subject_reward_rate: Optional[int] = None
    allies: Optional[List[str]] = None
    enemies: Optional[List[str]] = None

