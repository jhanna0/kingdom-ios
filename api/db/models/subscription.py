"""
Subscription Models
===================
Tracks subscriber status and customization options.

Tables:
1. Subscription - Subscription history (multiple rows per user)
2. UserPreferences - User customization preferences (style presets)
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
    
    # Style presets (IDs like 'royal_purple', 'ocean_blue')
    icon_style = Column(String, nullable=True)
    card_style = Column(String, nullable=True)
    
    # Selected title
    selected_title_achievement_id = Column(Integer, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="preferences")


# =============================================================================
# STYLE PRESETS - defined here, sent to frontend
# =============================================================================

STYLE_PRESETS = {
    # Royal / Luxury
    "royal_purple": {"background": "#4C1D95", "text": "#F5D742", "name": "Royal Purple"},
    "imperial_gold": {"background": "#78350F", "text": "#FCD34D", "name": "Imperial Gold"},
    
    # Nature
    "forest": {"background": "#14532D", "text": "#BBF7D0", "name": "Forest"},
    "ocean": {"background": "#0C4A6E", "text": "#BAE6FD", "name": "Ocean"},
    "sunset": {"background": "#7C2D12", "text": "#FED7AA", "name": "Sunset"},
    
    # Bold
    "crimson": {"background": "#7F1D1D", "text": "#FECACA", "name": "Crimson"},
    "midnight": {"background": "#1E1B4B", "text": "#C7D2FE", "name": "Midnight"},
    "obsidian": {"background": "#18181B", "text": "#E4E4E7", "name": "Obsidian"},
    
    # Vibrant
    "emerald": {"background": "#047857", "text": "#FFFFFF", "name": "Emerald"},
    "sapphire": {"background": "#1D4ED8", "text": "#FFFFFF", "name": "Sapphire"},
    "ruby": {"background": "#B91C1C", "text": "#FFFFFF", "name": "Ruby"},
    "amethyst": {"background": "#7E22CE", "text": "#FFFFFF", "name": "Amethyst"},
    
    # Neutral
    "slate": {"background": "#334155", "text": "#F1F5F9", "name": "Slate"},
    "bronze": {"background": "#92400E", "text": "#FEF3C7", "name": "Bronze"},
    "steel": {"background": "#3F3F46", "text": "#FAFAFA", "name": "Steel"},
}

def get_style_colors(style_id: str) -> dict:
    """Get background and text colors for a style preset."""
    return STYLE_PRESETS.get(style_id, {"background": None, "text": None, "name": None})
