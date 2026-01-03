"""
Action Cooldowns - Track when actions were last performed
"""
from sqlalchemy import Column, String, BigInteger, DateTime, ForeignKey, PrimaryKeyConstraint
from datetime import datetime

from ..base import Base


class ActionCooldown(Base):
    """
    Tracks cooldowns for player actions.
    Replaces all the last_*_action timestamp columns in player_state.
    
    Composite primary key: (user_id, action_type)
    """
    __tablename__ = "action_cooldowns"
    
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    action_type = Column(String(32), nullable=False)  # 'farm', 'work', 'patrol', 'scout', 'sabotage', 'training', 'crafting', 'intelligence', 'coup'
    
    # When the action was last performed
    last_performed = Column(DateTime, nullable=False, default=datetime.utcnow)
    
    # For duration-based actions (like patrol)
    expires_at = Column(DateTime, nullable=True)
    
    # Composite primary key
    __table_args__ = (
        PrimaryKeyConstraint('user_id', 'action_type'),
    )
    
    def __repr__(self):
        return f"<ActionCooldown(user_id={self.user_id}, action_type='{self.action_type}')>"

