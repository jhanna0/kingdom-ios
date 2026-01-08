"""
PlayerState model - Core game state (post-migration)

Moved to other tables:
- action_cooldowns: All cooldowns (last_*_action, last_coup_attempt, etc.)
- player_items: Equipment (weapons, armor)
- player_inventory: Stackable items (meat, sinew, etc.)
- unified_contracts: Training/crafting/building contracts
- user_kingdoms: Per-kingdom reputation and check-in counts

TODO: These columns should be computed on read, not stored:
- kingdoms_ruled, total_conquests, coups_won, coups_failed, total_checkins
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, Boolean, ForeignKey
from datetime import datetime

from ..base import Base


class PlayerState(Base):
    """
    Player game state - core attributes only
    See cleanup_player_state.sql for migration details
    """
    __tablename__ = "player_state"
    
    # Primary key and user reference
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False, index=True)
    
    # Territory
    hometown_kingdom_id = Column(String, nullable=True, index=True)
    current_kingdom_id = Column(String, nullable=True)
    
    # Resources (legacy columns - new items use player_inventory table!)
    gold = Column(Integer, default=100)
    iron = Column(Integer, default=0)
    steel = Column(Integer, default=0)
    wood = Column(Integer, default=0)
    
    # Progression
    level = Column(Integer, default=1)
    experience = Column(Integer, default=0)
    skill_points = Column(Integer, default=0)
    
    # Stats (T0 to T5)
    attack_power = Column(Integer, default=0)
    defense_power = Column(Integer, default=0)
    leadership = Column(Integer, default=0)
    building_skill = Column(Integer, default=0)
    intelligence = Column(Integer, default=0)
    science = Column(Integer, default=0)
    faith = Column(Integer, default=0)
    philosophy = Column(Integer, default=0)
    merchant = Column(Integer, default=0)
    
    # Combat debuff (temporary)
    attack_debuff = Column(Integer, default=0)
    debuff_expires_at = Column(DateTime, nullable=True)
    
    # Honor
    honor = Column(Integer, default=100)
    
    # Status
    is_alive = Column(Boolean, default=True)
    
    # One-time flags
    has_claimed_starting_city = Column(Boolean, default=False)
    
    # Training cost scaling
    total_training_purchases = Column(Integer, default=0)
    
    # Activity counters (TODO: should be computed from other tables)
    contracts_completed = Column(Integer, default=0)
    total_work_contributed = Column(Integer, default=0)
    total_checkins = Column(Integer, default=0)
    total_conquests = Column(Integer, default=0)
    kingdoms_ruled = Column(Integer, default=0)
    coups_won = Column(Integer, default=0)
    coups_failed = Column(Integer, default=0)
    times_executed = Column(Integer, default=0)
    executions_ordered = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<PlayerState(user_id='{self.user_id}', level={self.level}, gold={self.gold})>"

