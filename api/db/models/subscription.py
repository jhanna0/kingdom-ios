"""
Subscription Models
===================
Tracks subscriber status and customization options.

Tables:
1. Subscription - Subscription history (multiple rows per user)
2. UserPreferences - User customization preferences (colors stored directly as hex)
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..base import Base


class Subscription(Base):
    """Subscription history - one row per subscription period."""
    __tablename__ = "subscriptions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(String, nullable=False)
    original_transaction_id = Column(String, nullable=False)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    
    __table_args__ = (
        Index('idx_subscriptions_user_expires', 'user_id', 'expires_at'),
    )


class UserPreferences(Base):
    """User customization preferences (separate from auth data)."""
    __tablename__ = "user_preferences"
    
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    
    # Icon colors (hex values)
    icon_background_color = Column(String, nullable=True)  # hex e.g., '#6B21A8'
    icon_text_color = Column(String, nullable=True)        # hex
    
    # Card background color (hex)
    card_background_color = Column(String, nullable=True)  # hex
    
    # Selected title
    selected_title_achievement_id = Column(Integer, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="preferences")
