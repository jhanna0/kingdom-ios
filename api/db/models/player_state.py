"""
PlayerState model - Core game state (post-migration)
Columns removed by unified_migration.sql have been moved to:
- action_cooldowns (last_*_action columns)
- player_items (equipment & inventory)
- unified_contracts (training/crafting/property contracts)
- Computed from other tables (coups_won, total_conquests, etc.)
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, Boolean, ForeignKey
from datetime import datetime

from ..base import Base


class PlayerState(Base):
    """
    Player game state - core attributes only
    See unified_migration.sql and SCHEMA_REFACTOR_PLAN.md for details
    """
    __tablename__ = "player_state"
    
    # Primary key and user reference
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False, index=True)
    
    # Territory
    hometown_kingdom_id = Column(String, nullable=True, index=True)
    current_kingdom_id = Column(String, nullable=True)
    
    # Resources
    gold = Column(Integer, default=100)
    iron = Column(Integer, default=0)
    steel = Column(Integer, default=0)
    
    # Progression
    level = Column(Integer, default=1)
    experience = Column(Integer, default=0)
    skill_points = Column(Integer, default=0)
    
    # Stats
    attack_power = Column(Integer, default=1)
    defense_power = Column(Integer, default=1)
    leadership = Column(Integer, default=1)
    building_skill = Column(Integer, default=1)
    intelligence = Column(Integer, default=1)
    
    # Combat debuff (temporary)
    attack_debuff = Column(Integer, default=0)
    debuff_expires_at = Column(DateTime, nullable=True)
    
    # Status
    is_alive = Column(Boolean, default=True)
    
    # One-time flags
    has_claimed_starting_city = Column(Boolean, default=False)
    
    # Training cost scaling (can't compute this easily)
    total_training_purchases = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<PlayerState(user_id='{self.user_id}', level={self.level}, gold={self.gold})>"

