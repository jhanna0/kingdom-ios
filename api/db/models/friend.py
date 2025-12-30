from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Index
from sqlalchemy.sql import func
from ..base import Base


class Friend(Base):
    __tablename__ = "friends"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # User who sent the friend request
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # User who received the friend request
    friend_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Status: 'pending', 'accepted', 'rejected', 'blocked'
    status = Column(String, nullable=False, default='pending')
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Index for quick lookups
    __table_args__ = (
        Index('idx_user_friend', 'user_id', 'friend_user_id'),
        Index('idx_friend_status', 'status'),
    )

