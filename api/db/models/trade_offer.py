"""
TradeOffer model - Player-to-player trading system

Requires Merchant skill tier 1 for both sender and receiver.
Supports:
- Item offers with optional gold price (can be 0 for gifts)
- Pure gold gifts (send money to friends)
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, ForeignKey, Index, Enum as SQLEnum
from sqlalchemy.sql import func
from enum import Enum
from ..base import Base


class TradeOfferStatus(str, Enum):
    """Status of a trade offer"""
    PENDING = "pending"      # Waiting for recipient to respond
    ACCEPTED = "accepted"    # Recipient accepted, items/gold exchanged
    DECLINED = "declined"    # Recipient declined
    CANCELLED = "cancelled"  # Sender cancelled before response
    EXPIRED = "expired"      # Offer expired (after 24 hours)


class TradeOffer(Base):
    """
    Player-to-player trade offer.
    
    Two types of offers:
    1. Item offer: Sender offers an item, recipient pays gold_price (can be 0)
    2. Gold gift: Sender sends gold_amount to recipient (no item involved)
    """
    __tablename__ = "trade_offers"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Players involved (must be friends, both with Merchant 1+)
    sender_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    recipient_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Offer type: "item" or "gold"
    offer_type = Column(String, nullable=False, default="item")
    
    # For item offers: what item is being offered
    item_type = Column(String, nullable=True)  # e.g., "iron", "steel", "wood", "meat"
    item_quantity = Column(Integer, nullable=True, default=1)
    
    # Gold component:
    # - For item offers: price the recipient must pay (0 = gift)
    # - For gold gifts: amount being sent
    gold_amount = Column(Integer, nullable=False, default=0)
    
    # Status
    status = Column(String, nullable=False, default=TradeOfferStatus.PENDING.value)
    
    # Optional message from sender
    message = Column(String, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    responded_at = Column(DateTime(timezone=True), nullable=True)  # When accepted/declined
    
    # Indexes
    __table_args__ = (
        Index('idx_trade_sender_status', 'sender_id', 'status'),
        Index('idx_trade_recipient_status', 'recipient_id', 'status'),
    )
