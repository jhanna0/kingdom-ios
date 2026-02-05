"""
Purchase Model
==============
Tracks in-app purchases from the App Store.

Stores transaction info to:
1. Prevent duplicate redemptions
2. Enable refund handling
3. Provide purchase history for support
"""
from sqlalchemy import Column, Integer, BigInteger, String, Float, DateTime, Boolean, ForeignKey, Index
from sqlalchemy.sql import func
from ..base import Base


class Purchase(Base):
    """
    In-app purchase record.
    
    Each row represents a completed App Store transaction.
    The transaction_id is unique and used to prevent duplicate redemptions.
    """
    __tablename__ = "purchases"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # App Store transaction info
    product_id = Column(String, nullable=False)  # e.g., "com.kingdom.starter_pack"
    transaction_id = Column(String, unique=True, nullable=False, index=True)  # Apple's transaction ID
    original_transaction_id = Column(String, nullable=True)  # For subscription renewals
    
    # Purchase details
    price_usd = Column(Float, nullable=True)  # Price at time of purchase
    currency = Column(String(3), nullable=True)  # ISO currency code
    
    # Resources granted
    gold_granted = Column(Integer, default=0)
    meat_granted = Column(Integer, default=0)
    books_granted = Column(Integer, default=0)
    
    # Verification
    environment = Column(String, default="Production")  # "Production" or "Sandbox"
    verified_with_apple = Column(Boolean, default=False)
    verification_error = Column(String, nullable=True)
    
    # Status
    status = Column(String, default="completed")  # "completed", "refunded", "disputed"
    refunded_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    purchased_at = Column(DateTime(timezone=True), nullable=False)  # When user made purchase
    created_at = Column(DateTime(timezone=True), server_default=func.now())  # When we recorded it
    
    # Indexes for common queries
    __table_args__ = (
        Index('idx_purchases_user_product', 'user_id', 'product_id'),
        Index('idx_purchases_status', 'status'),
    )
