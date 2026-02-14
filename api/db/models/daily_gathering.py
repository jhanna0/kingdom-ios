"""
Daily Gathering Limits - Track resources gathered per day (GLOBAL per user)
Prevents autoclicking abuse by capping resources at 200 * building level per day

The daily limit is GLOBAL per user - gathering at any kingdom counts toward the same cap.
Building permits only control ACCESS to buildings, not additional gathering capacity.
"""
from sqlalchemy import Column, Integer, BigInteger, String, Date, ForeignKey, PrimaryKeyConstraint, Index
from datetime import date

from ..base import Base


class DailyGathering(Base):
    """
    Tracks daily resource gathering per user per resource type.
    Resets at midnight UTC.
    
    Limit: 200 * HOMETOWN building level per resource per day (GLOBAL)
    - Your limit is always based on YOUR hometown's building level
    - The limit is shared across all kingdoms (permits only control access)
    
    Example: Hometown has L3 lumbermill (600/day limit)
    - Can gather 600 wood TOTAL across all kingdoms you have access to
    
    Composite primary key: (user_id, resource_type, gather_date)
    kingdom_id is stored for analytics but not part of the limit calculation.
    """
    __tablename__ = "daily_gathering"
    
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    resource_type = Column(String(16), nullable=False)  # 'wood', 'iron', 'stone'
    gather_date = Column(Date, nullable=False, default=date.today)
    
    # Last kingdom where gathering occurred (for analytics, not part of limit)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=True)
    
    # Total amount gathered today (across all kingdoms)
    amount_gathered = Column(Integer, default=0, nullable=False)
    
    # Composite primary key - does NOT include kingdom_id (limit is global)
    __table_args__ = (
        PrimaryKeyConstraint('user_id', 'resource_type', 'gather_date'),
        Index('idx_daily_gathering_kingdom', 'user_id', 'kingdom_id', 'resource_type', 'gather_date'),
    )
    
    def __repr__(self):
        kingdom_str = f", kingdom='{self.kingdom_id}'" if self.kingdom_id else ""
        return f"<DailyGathering(user_id={self.user_id}, resource='{self.resource_type}', date={self.gather_date}{kingdom_str}, amount={self.amount_gathered})>"
