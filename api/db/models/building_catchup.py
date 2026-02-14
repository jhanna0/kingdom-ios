"""
Building Catchup system - Track player contributions before using kingdom buildings

Players who join a kingdom after a building was constructed must complete
"catch-up" work before they can use that building's benefits.

Formula: actions_required = 15 * building_level
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey, Index, UniqueConstraint
from datetime import datetime

from ..base import Base


class BuildingCatchup(Base):
    """
    Tracks a player's catch-up progress for a specific building in a kingdom.
    
    When a player tries to use a building they haven't contributed to,
    they must complete catch-up work first.
    """
    __tablename__ = "building_catchups"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    # Who needs to catch up
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Which kingdom's building
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=False, index=True)
    
    # Which building type (e.g., "lumbermill", "mine", "farm")
    building_type = Column(String(32), nullable=False)
    
    # Progress tracking
    actions_required = Column(Integer, nullable=False)  # Set based on building level at time of first use attempt
    actions_completed = Column(Integer, nullable=False, default=0)
    
    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)  # Set when actions_completed >= actions_required
    
    # Allow multiple catchup records per user per building (one per level-up)
    __table_args__ = (
        Index('idx_catchup_user_kingdom', 'user_id', 'kingdom_id'),
        Index('idx_catchup_user_kingdom_building', 'user_id', 'kingdom_id', 'building_type'),
        Index('idx_catchup_incomplete', 'user_id', 'completed_at'),
    )
    
    @property
    def is_complete(self) -> bool:
        """Check if catch-up is complete"""
        return self.completed_at is not None or self.actions_completed >= self.actions_required
    
    @property
    def progress_percent(self) -> int:
        """Progress as percentage"""
        if self.actions_required == 0:
            return 100
        return min(100, int((self.actions_completed / self.actions_required) * 100))
    
    @property
    def actions_remaining(self) -> int:
        """How many more actions needed"""
        return max(0, self.actions_required - self.actions_completed)
    
    def __repr__(self):
        status = "complete" if self.is_complete else f"{self.actions_completed}/{self.actions_required}"
        return f"<BuildingCatchup(user={self.user_id}, kingdom='{self.kingdom_id}', building='{self.building_type}', {status})>"
