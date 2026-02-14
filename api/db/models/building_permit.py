"""
Building Permit system - Temporary access to buildings in foreign kingdoms

Players visiting a kingdom (not hometown, not allied/same empire) must purchase
a permit to use certain buildings (lumbermill, mine, market, townhall).

Rules:
- 10 gold for 10 minutes of access
- Gold goes to kingdom treasury
- Must have same building in hometown (can't bypass progression)
- Cannot have active catchup contract for that building (must complete expansion first)
- Free if allied or same empire
"""
from sqlalchemy import Column, String, BigInteger, DateTime, ForeignKey, Index, UniqueConstraint
from datetime import datetime

from ..base import Base


class BuildingPermit(Base):
    """
    Tracks active building permits for visiting players.
    
    One permit per user per kingdom per building type at a time.
    Expires after 10 minutes.
    """
    __tablename__ = "building_permits"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    # Who has the permit
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Which kingdom's building
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Which building type (e.g., "lumbermill", "mine", "market", "townhall")
    building_type = Column(String(32), nullable=False)
    
    # When the permit expires
    expires_at = Column(DateTime, nullable=False)
    
    # When purchased (for analytics)
    purchased_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    
    # How much was paid
    gold_paid = Column(BigInteger, nullable=False, default=10)
    
    __table_args__ = (
        # One active permit per user per kingdom per building
        UniqueConstraint('user_id', 'kingdom_id', 'building_type', name='unique_user_kingdom_building_permit'),
        Index('idx_permit_user_kingdom', 'user_id', 'kingdom_id'),
        Index('idx_permit_expires', 'expires_at'),
    )
    
    @property
    def is_valid(self) -> bool:
        """Check if permit is still valid"""
        return datetime.utcnow() < self.expires_at
    
    @property
    def minutes_remaining(self) -> int:
        """Minutes until permit expires"""
        if not self.is_valid:
            return 0
        remaining = (self.expires_at - datetime.utcnow()).total_seconds() / 60
        return max(0, int(remaining))
    
    def __repr__(self):
        status = f"{self.minutes_remaining}m left" if self.is_valid else "expired"
        return f"<BuildingPermit(user={self.user_id}, kingdom='{self.kingdom_id}', building='{self.building_type}', {status})>"
