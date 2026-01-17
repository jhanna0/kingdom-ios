"""
Player Items - Equipment and inventory
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey, Index
from datetime import datetime

from ..base import Base


class PlayerItem(Base):
    """
    Player inventory items (weapons, armor, etc.)
    Replaces player_state.inventory, equipped_weapon, equipped_armor JSONB columns
    """
    __tablename__ = "player_items"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Item definition
    item_id = Column(String(64), nullable=True)  # "fur_armor", "hunting_bow" - nullable for legacy items
    type = Column(String(32), nullable=False)  # 'weapon', 'armor'
    tier = Column(Integer, nullable=False, default=1)
    
    # Stats
    attack_bonus = Column(Integer, default=0)
    defense_bonus = Column(Integer, default=0)
    
    # Equipment state
    is_equipped = Column(Boolean, default=False, index=True)
    
    # Metadata
    crafted_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    
    # Indexes
    __table_args__ = (
        Index('idx_player_items_user', 'user_id'),
        Index('idx_player_items_user_equipped', 'user_id', 'is_equipped'),
        Index('idx_player_items_user_type', 'user_id', 'type'),
    )
    
    def __repr__(self):
        equipped = " (equipped)" if self.is_equipped else ""
        return f"<PlayerItem(id={self.id}, type='{self.type}', tier={self.tier}{equipped})>"

