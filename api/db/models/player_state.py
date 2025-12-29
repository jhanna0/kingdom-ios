"""
PlayerState model - All game state separate from auth/account
"""
from sqlalchemy import Column, String, Float, DateTime, Integer, BigInteger, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from ..base import Base


class PlayerState(Base):
    """
    Player game state - separate from User authentication
    This keeps auth data clean and allows for better game state management
    """
    __tablename__ = "player_state"
    
    # Primary key and user reference
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False, index=True)
    
    # Kingdom & Territory
    hometown_kingdom_id = Column(String, nullable=True, index=True)
    origin_kingdom_id = Column(String, nullable=True)  # First kingdom where they got 300+ rep
    home_kingdom_id = Column(String, nullable=True)    # Kingdom they check in most
    current_kingdom_id = Column(String, nullable=True) # Current kingdom they're in
    fiefs_ruled = Column(JSONB, default=list)  # List of kingdom IDs they rule
    
    # Core Stats
    gold = Column(Integer, default=100)
    level = Column(Integer, default=1)
    experience = Column(Integer, default=0)
    skill_points = Column(Integer, default=0)
    
    # Combat Stats
    attack_power = Column(Integer, default=1)
    defense_power = Column(Integer, default=1)
    leadership = Column(Integer, default=1)
    building_skill = Column(Integer, default=1)
    intelligence = Column(Integer, default=1)  # Improves sabotage/patrol efficiency
    
    # Combat Debuffs
    attack_debuff = Column(Integer, default=0)
    debuff_expires_at = Column(DateTime, nullable=True)
    
    # Reputation
    reputation = Column(Integer, default=0)  # Global reputation
    honor = Column(Integer, default=100)  # 0-100 scale
    kingdom_reputation = Column(JSONB, default=dict)  # {kingdom_id: rep_value}
    
    # Check-in tracking
    check_in_history = Column(JSONB, default=dict)  # {kingdom_id: count}
    last_check_in = Column(DateTime, nullable=True)
    last_check_in_lat = Column(Float, nullable=True)
    last_check_in_lon = Column(Float, nullable=True)
    last_daily_check_in = Column(DateTime, nullable=True)
    
    # Activity tracking
    total_checkins = Column(Integer, default=0)
    total_conquests = Column(Integer, default=0)
    kingdoms_ruled = Column(Integer, default=0)
    coups_won = Column(Integer, default=0)
    coups_failed = Column(Integer, default=0)
    times_executed = Column(Integer, default=0)
    executions_ordered = Column(Integer, default=0)
    last_coup_attempt = Column(DateTime, nullable=True)
    
    # Contract & Work tracking
    contracts_completed = Column(Integer, default=0)
    total_work_contributed = Column(Integer, default=0)
    total_training_purchases = Column(Integer, default=0)  # Global training counter for cost scaling
    
    # Resources
    iron = Column(Integer, default=0)
    steel = Column(Integer, default=0)
    
    # Daily Action Tracking
    last_mining_action = Column(DateTime, nullable=True)
    last_crafting_action = Column(DateTime, nullable=True)
    last_building_action = Column(DateTime, nullable=True)
    last_spy_action = Column(DateTime, nullable=True)
    
    # Action System (cooldown-based)
    last_work_action = Column(DateTime, nullable=True)
    last_patrol_action = Column(DateTime, nullable=True)
    last_sabotage_action = Column(DateTime, nullable=True)
    last_scout_action = Column(DateTime, nullable=True)
    patrol_expires_at = Column(DateTime, nullable=True)  # When current patrol ends
    
    # Training Actions (cooldown-based)
    last_training_action = Column(DateTime, nullable=True)
    
    # Active Training Contracts (JSONB array)
    # Each contract: {id, type, actions_required, actions_completed, created_at, cost_paid}
    training_contracts = Column(JSONB, default=list)
    
    # Equipment (stored as JSONB)
    equipped_weapon = Column(JSONB, nullable=True)
    equipped_armor = Column(JSONB, nullable=True)
    equipped_shield = Column(JSONB, nullable=True)
    inventory = Column(JSONB, default=list)
    crafting_queue = Column(JSONB, default=list)
    crafting_progress = Column(JSONB, default=dict)
    
    # Properties owned
    properties = Column(JSONB, default=list)
    
    # Rewards tracking
    total_rewards_received = Column(Integer, default=0)
    last_reward_received = Column(DateTime, nullable=True)
    last_reward_amount = Column(Integer, default=0)
    
    # Status
    is_alive = Column(Boolean, default=True)
    is_ruler = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Extensible game data
    game_data = Column(JSONB, nullable=True, default=dict)
    
    def __repr__(self):
        return f"<PlayerState(user_id='{self.user_id}', level={self.level}, gold={self.gold})>"

