"""
Alliance model - Formal pacts between empires
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey, Boolean
from datetime import datetime, timedelta

from ..base import Base


class Alliance(Base):
    """Alliance between two empires"""
    __tablename__ = "alliances"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Participants (empires, not individual cities)
    initiator_empire_id = Column(String, nullable=False, index=True)
    target_empire_id = Column(String, nullable=False, index=True)
    
    # Rulers at time of alliance
    initiator_ruler_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    target_ruler_id = Column(BigInteger, ForeignKey("users.id"), nullable=True)
    initiator_ruler_name = Column(String, nullable=False)
    target_ruler_name = Column(String, nullable=True)
    
    # Status: 'pending', 'active', 'expired', 'declined'
    status = Column(String, nullable=False, default='pending')
    
    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    proposal_expires_at = Column(DateTime, nullable=False)
    accepted_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    
    # Track if expiry notification was sent (for lazy notification on login/fetch)
    expiry_notified = Column(Boolean, nullable=False, default=False)
    
    # Constants
    PROPOSAL_EXPIRY_DAYS = 7
    ALLIANCE_DURATION_DAYS = 30
    
    @property
    def is_pending(self) -> bool:
        """Check if alliance is pending acceptance"""
        return self.status == 'pending' and datetime.utcnow() < self.proposal_expires_at
    
    @property
    def is_active(self) -> bool:
        """Check if alliance is currently active"""
        if self.status != 'active':
            return False
        if not self.expires_at:
            return False
        return datetime.utcnow() < self.expires_at
    
    @property
    def is_expired(self) -> bool:
        """Check if alliance has expired"""
        if self.status == 'expired':
            return True
        if self.status == 'active' and self.expires_at:
            return datetime.utcnow() >= self.expires_at
        if self.status == 'pending' and self.proposal_expires_at:
            return datetime.utcnow() >= self.proposal_expires_at
        return False
    
    @property
    def days_remaining(self) -> int:
        """Get days remaining on active alliance"""
        if not self.is_active or not self.expires_at:
            return 0
        delta = self.expires_at - datetime.utcnow()
        return max(0, delta.days)
    
    @property
    def hours_to_respond(self) -> int:
        """Get hours remaining to respond to pending proposal"""
        if not self.is_pending:
            return 0
        delta = self.proposal_expires_at - datetime.utcnow()
        return max(0, int(delta.total_seconds() / 3600))
    
    def accept(self, ruler_id: int, ruler_name: str):
        """Accept the alliance proposal"""
        self.status = 'active'
        self.target_ruler_id = ruler_id
        self.target_ruler_name = ruler_name
        self.accepted_at = datetime.utcnow()
        self.expires_at = datetime.utcnow() + timedelta(days=self.ALLIANCE_DURATION_DAYS)
    
    def decline(self):
        """Decline the alliance proposal"""
        self.status = 'declined'
    
    def expire(self):
        """Mark alliance as expired"""
        self.status = 'expired'
    
    def involves_empire(self, empire_id: str) -> bool:
        """Check if this alliance involves a specific empire"""
        return self.initiator_empire_id == empire_id or self.target_empire_id == empire_id
    
    def get_other_empire_id(self, empire_id: str) -> str:
        """Get the other empire's ID in this alliance"""
        if self.initiator_empire_id == empire_id:
            return self.target_empire_id
        return self.initiator_empire_id
    
    def __repr__(self):
        return f"<Alliance(id={self.id}, {self.initiator_empire_id} <-> {self.target_empire_id}, status='{self.status}')>"



