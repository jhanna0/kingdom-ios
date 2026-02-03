"""
Unified Contract system - All contracts (training, crafting, property, buildings)
"""
from sqlalchemy import Column, String, Integer, BigInteger, Float, DateTime, ForeignKey, Index
from sqlalchemy.orm import relationship
from datetime import datetime

from ..base import Base


class UnifiedContract(Base):
    """
    Unified contract for all work-based progression:
    - Training (attack, defense, leadership, building, intelligence)
    - Crafting (weapon, armor)
    - Property upgrades
    - Kingdom buildings (wall, vault, mine, market, farm, education)
    """
    __tablename__ = "unified_contracts"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    # Ownership - either user OR kingdom (not both)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=True, index=True)
    kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=True, index=True)
    
    # What's being built/trained
    category = Column(String(32), nullable=False)  # 'kingdom_building', 'personal_property', 'personal_training', 'personal_crafting'
    type = Column(String(32), nullable=False)  # 'attack', 'weapon', 'wall', 'property', etc.
    tier = Column(Integer, nullable=True)  # Level/tier if applicable
    target_id = Column(String(128), nullable=True)  # Property ID, etc. if needed
    option_id = Column(String(64), nullable=True)  # Which room at this tier (e.g., 'workshop', 'kitchen')
    
    # Requirements
    actions_required = Column(Integer, nullable=False, default=1)
    
    # Cost paid (denormalized for history)
    # OLD SYSTEM: gold_paid > 0 means player paid upfront, actions are free
    gold_paid = Column(Integer, default=0)
    iron_paid = Column(Integer, default=0)
    steel_paid = Column(Integer, default=0)
    wood_paid = Column(Integer, default=0)
    
    # NEW SYSTEM: gold_per_action > 0 means player pays per action (+ tax on top)
    # Backwards compat: if gold_paid > 0 and gold_per_action = 0, actions are free
    gold_per_action = Column(Float, default=0.0)
    
    # Reward pool (for kingdom contracts)
    reward_pool = Column(Integer, default=0)
    action_reward = Column(Integer, default=0)  # Gold per action (ruler-set for kingdom contracts)
    
    # Metadata
    kingdom_name = Column(String(256), nullable=True)  # Denormalized for display
    
    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    contributions = relationship("ContractContribution", back_populates="contract", cascade="all, delete-orphan")
    
    # Indexes for queries filtering on completion
    __table_args__ = (
        Index('idx_unified_contracts_user_completed', 'user_id', 'completed_at'),
        Index('idx_unified_contracts_kingdom_completed', 'kingdom_id', 'completed_at'),
        Index('idx_unified_contracts_category_completed', 'category', 'completed_at'),
    )
    
    @property
    def actions_completed(self) -> int:
        """Count of contributions = actions completed"""
        return len(self.contributions) if self.contributions else 0
    
    @property
    def is_complete(self) -> bool:
        """Check if contract is complete"""
        return self.actions_completed >= self.actions_required
    
    @property
    def progress_percent(self) -> int:
        """Progress as percentage"""
        if self.actions_required == 0:
            return 100
        return min(100, int((self.actions_completed / self.actions_required) * 100))
    
    def __repr__(self):
        status = "completed" if self.completed_at else "active"
        return f"<UnifiedContract(id={self.id}, type='{self.type}', {status})>"


class ContractContribution(Base):
    """
    Each action performed on a contract.
    One row = one action.
    """
    __tablename__ = "contract_contributions"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    contract_id = Column(BigInteger, ForeignKey("unified_contracts.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    
    # When the action was performed
    performed_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    
    # Rewards earned for this action (denormalized)
    gold_earned = Column(Integer, default=0)
    xp_earned = Column(Integer, default=0)
    
    # Relationships
    contract = relationship("UnifiedContract", back_populates="contributions")
    
    # Indexes
    __table_args__ = (
        Index('idx_contributions_contract', 'contract_id'),
        Index('idx_contributions_user', 'user_id'),
        Index('idx_contributions_user_time', 'user_id', 'performed_at'),
    )
    
    def __repr__(self):
        return f"<ContractContribution(contract_id={self.contract_id}, user_id={self.user_id})>"

