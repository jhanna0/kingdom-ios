"""
Daily Gathering Limits - Track resources gathered per day per kingdom
Prevents autoclicking abuse by capping resources at 200 * building level per day

With building permits, players can gather in multiple kingdoms:
- Hometown: uses hometown building level for limits
- Foreign kingdoms (with permit or allied): uses hometown level for limits, tracked separately
"""
from sqlalchemy import Column, Integer, BigInteger, String, Date, ForeignKey, PrimaryKeyConstraint, Index
from datetime import date

from ..base import Base


class DailyGathering(Base):
    """
    Tracks daily resource gathering per user per resource type PER KINGDOM.
    Resets at midnight UTC.
    
    Limit: 200 * HOMETOWN building level per resource per day per kingdom
    - Your limit is always based on YOUR hometown's building level
    - But you can gather that amount at EACH kingdom you have access to
    
    Example: Hometown has L3 lumbermill (600/day limit)
    - Can gather 600 wood at hometown
    - Can gather 600 wood at each allied kingdom (separate pool)
    - Can gather 600 wood at each kingdom with permit (separate pool)
    
    Composite primary key: (user_id, resource_type, gather_date, kingdom_id)
    """
    __tablename__ = "daily_gathering"
    
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    resource_type = Column(String(16), nullable=False)  # 'wood', 'iron', 'stone'
    gather_date = Column(Date, nullable=False, default=date.today)
    
    # Which kingdom this gathering was done in (NULL = legacy data from before permits)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=True)
    
    # Amount gathered today at this kingdom
    amount_gathered = Column(Integer, default=0, nullable=False)
    
    # Composite primary key - now includes kingdom_id
    # Note: kingdom_id is nullable for backward compatibility with existing data
    __table_args__ = (
        PrimaryKeyConstraint('user_id', 'resource_type', 'gather_date'),
        Index('idx_daily_gathering_kingdom', 'user_id', 'kingdom_id', 'resource_type', 'gather_date'),
    )
    
    def __repr__(self):
        kingdom_str = f", kingdom='{self.kingdom_id}'" if self.kingdom_id else ""
        return f"<DailyGathering(user_id={self.user_id}, resource='{self.resource_type}', date={self.gather_date}{kingdom_str}, amount={self.amount_gathered})>"
