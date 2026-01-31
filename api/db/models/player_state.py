"""
PlayerState model - Core game state (post-migration)

Moved to other tables:
- action_cooldowns: All cooldowns (last_*_action, last_coup_attempt, etc.)
- player_items: Equipment (weapons, armor)
- player_inventory: Stackable items (meat, sinew, iron, steel, wood, stone, etc.)
- unified_contracts: Training/crafting/building contracts
- user_kingdoms: Per-kingdom reputation and check-in counts

NOTE: As of the inventory refactor, ALL resources except gold are stored in player_inventory.
Gold remains here because it needs float precision for tax calculations.

TODO: These columns should be computed on read, not stored:
- kingdoms_ruled, total_conquests, coups_won, coups_failed, total_checkins
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, Boolean, ForeignKey, Float
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
    
    # Currency - gold remains as column because it needs float precision for tax calculations
    # All other resources (iron, steel, wood, stone, etc.) are in player_inventory table
    gold = Column(Float, default=100.0)
    
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
    # total_checkins: REMOVED - computed from user_kingdoms.checkins_count
    total_conquests = Column(Integer, default=0)
    kingdoms_ruled = Column(Integer, default=0)
    coups_won = Column(Integer, default=0)
    coups_failed = Column(Integer, default=0)
    times_executed = Column(Integer, default=0)
    executions_ordered = Column(Integer, default=0)
    
    # Hunting Permit (for visiting hunters)
    hunting_permit_kingdom_id = Column(String, nullable=True)  # Kingdom where permit is valid
    hunting_permit_expires_at = Column(DateTime, nullable=True)  # When permit expires
    
    # Current Activity Status (for friend list - avoids N+1 queries)
    # Simple text like "Training attack 3/5", "Foraging", "Fishing", etc.
    current_activity_status = Column(String, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    last_notifications_viewed = Column(DateTime, nullable=True)  # For notification "unread" badge
    
    def __repr__(self):
        return f"<PlayerState(user_id='{self.user_id}', level={self.level}, gold={self.gold})>"

