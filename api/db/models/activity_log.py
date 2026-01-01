"""
Player Activity Log - Track all player actions for feed display
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class PlayerActivityLog(Base):
    """
    Comprehensive activity log for all player actions
    Used to build activity feeds for friends/self
    """
    __tablename__ = "player_activity_log"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Activity classification
    action_type = Column(String, nullable=False, index=True)  # travel, checkin, build, vote, train, etc.
    action_category = Column(String, nullable=False, index=True)  # kingdom, combat, economy, social
    
    # Core details
    description = Column(String, nullable=False)  # Human-readable description
    kingdom_id = Column(String, nullable=True, index=True)  # Related kingdom if any
    kingdom_name = Column(String, nullable=True)
    
    # Quantitative data
    amount = Column(Integer, nullable=True)  # Gold spent/earned, XP gained, etc.
    
    # Extended details (flexible JSON)
    # Examples:
    # - Travel: {from_kingdom, to_kingdom, fee_paid, free_reason}
    # - Vote: {coup_id, side, kingdom_id}
    # - Build: {contract_id, building_type, actions_contributed}
    # - Train: {stat_type, cost, new_level}
    details = Column(JSONB, default=dict)
    
    # Visibility control
    visibility = Column(String, default='friends', nullable=False)  # 'public', 'friends', 'private'
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<PlayerActivityLog(user_id={self.user_id}, action_type='{self.action_type}', created_at={self.created_at})>"


# Composite indexes for common queries
Index('idx_activity_user_created', PlayerActivityLog.user_id, PlayerActivityLog.created_at.desc())
Index('idx_activity_kingdom_created', PlayerActivityLog.kingdom_id, PlayerActivityLog.created_at.desc())
Index('idx_activity_type_created', PlayerActivityLog.action_type, PlayerActivityLog.created_at.desc())

