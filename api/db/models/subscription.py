"""
Subscription Models
===================
Tracks subscriber status and theme customization options.

Tables:
1. SubscriberTheme - Server-driven theme definitions (colors, names)
2. Subscription - Subscription history (multiple rows per user)
3. UserPreferences - User customization preferences
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..base import Base


class SubscriberTheme(Base):
    """Server-driven theme definitions."""
    __tablename__ = "subscriber_themes"
    
    id = Column(String, primary_key=True)  # e.g., 'royal_purple'
    display_name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    background_color = Column(String, nullable=False)  # hex e.g., '#6B21A8'
    text_color = Column(String, nullable=False)
    icon_background_color = Column(String, nullable=False)


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
    subscriber_theme_id = Column(String, ForeignKey("subscriber_themes.id", ondelete="SET NULL"), nullable=True)
    selected_title_achievement_id = Column(Integer, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="preferences")
    theme = relationship("SubscriberTheme")
