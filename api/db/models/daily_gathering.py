"""
Daily Gathering Limits - Track resources gathered per day
Prevents autoclicking abuse by capping resources at 200 * building level per day
"""
from sqlalchemy import Column, Integer, BigInteger, String, Date, ForeignKey, PrimaryKeyConstraint
from datetime import date

from ..base import Base


class DailyGathering(Base):
    """
    Tracks daily resource gathering per user per resource type.
    Resets at midnight UTC.
    
    Limit: 200 * hometown building level per resource per day
    - Wood limit = 200 * hometown lumbermill_level
    - Iron limit = 200 * hometown mine_level
    
    Composite primary key: (user_id, resource_type, gather_date)
    """
    __tablename__ = "daily_gathering"
    
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    resource_type = Column(String(16), nullable=False)  # 'wood' or 'iron'
    gather_date = Column(Date, nullable=False, default=date.today)
    
    # Amount gathered today
    amount_gathered = Column(Integer, default=0, nullable=False)
    
    # Composite primary key
    __table_args__ = (
        PrimaryKeyConstraint('user_id', 'resource_type', 'gather_date'),
    )
    
    def __repr__(self):
        return f"<DailyGathering(user_id={self.user_id}, resource='{self.resource_type}', date={self.gather_date}, amount={self.amount_gathered})>"
