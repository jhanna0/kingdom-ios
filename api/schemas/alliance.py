"""
Alliance schemas - Request/Response models for alliance system
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ===== Request Schemas =====

class AllianceProposeRequest(BaseModel):
    """Request to propose alliance to another empire"""
    target_empire_id: str


# ===== Response Schemas =====

class AllianceResponse(BaseModel):
    """Alliance details"""
    id: int
    initiator_empire_id: str
    target_empire_id: str
    initiator_ruler_id: int
    target_ruler_id: Optional[int] = None
    initiator_ruler_name: str
    target_ruler_name: Optional[str] = None
    status: str
    created_at: datetime
    proposal_expires_at: datetime
    accepted_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    days_remaining: int = 0
    hours_to_respond: int = 0
    is_active: bool = False
    
    class Config:
        from_attributes = True


class AllianceProposeResponse(BaseModel):
    """Response after proposing alliance"""
    success: bool
    message: str
    alliance_id: int
    proposal_expires_at: datetime


class AllianceAcceptResponse(BaseModel):
    """Response after accepting alliance"""
    success: bool
    message: str
    alliance_id: int
    expires_at: datetime
    benefits: List[str]


class AllianceDeclineResponse(BaseModel):
    """Response after declining alliance"""
    success: bool
    message: str


class AllianceListResponse(BaseModel):
    """List of alliances"""
    alliances: List[AllianceResponse]
    count: int


class PendingAlliancesResponse(BaseModel):
    """Pending alliance proposals"""
    sent: List[AllianceResponse]
    received: List[AllianceResponse]
    sent_count: int
    received_count: int



