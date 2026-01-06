"""
Market Order models - Grand Exchange style order book system
"""
from sqlalchemy import Column, String, DateTime, Integer, BigInteger, Boolean, ForeignKey, Enum as SQLEnum
from datetime import datetime
import enum

from ..base import Base


class OrderType(str, enum.Enum):
    """Order type - buy or sell"""
    BUY = "buy"
    SELL = "sell"


class OrderStatus(str, enum.Enum):
    """Order status"""
    ACTIVE = "active"          # Order is in the order book
    FILLED = "filled"          # Order completely filled
    PARTIALLY_FILLED = "partially_filled"  # Some quantity filled
    CANCELLED = "cancelled"    # Cancelled by player


class MarketOrder(Base):
    """
    Market order in the order book
    Players can place buy/sell orders for resources
    """
    __tablename__ = "market_orders"
    
    # Primary key
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Order details
    player_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    kingdom_id = Column(String, nullable=False, index=True)  # Kingdom-scoped market
    
    # Order type and item
    order_type = Column(SQLEnum(OrderType), nullable=False, index=True)
    item_type = Column(String, nullable=False, index=True)  # "iron", "steel", "wood", etc.
    
    # Pricing and quantity
    price_per_unit = Column(Integer, nullable=False, index=True)  # Gold per unit
    quantity_remaining = Column(Integer, nullable=False)  # Units left to fill
    quantity_original = Column(Integer, nullable=False)   # Original order size
    
    # Status
    status = Column(SQLEnum(OrderStatus), nullable=False, default=OrderStatus.ACTIVE, index=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    filled_at = Column(DateTime, nullable=True)  # When fully filled or cancelled
    
    def __repr__(self):
        return f"<MarketOrder(id={self.id}, {self.order_type.value} {self.quantity_remaining}/{self.quantity_original} {self.item_type} @ {self.price_per_unit}g)>"


class MarketTransaction(Base):
    """
    Completed market transaction history
    Records all trades that occur
    """
    __tablename__ = "market_transactions"
    
    # Primary key
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Transaction details
    kingdom_id = Column(String, nullable=False, index=True)
    item_type = Column(String, nullable=False, index=True)
    
    # Parties involved
    buyer_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    seller_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # Orders that matched
    buy_order_id = Column(Integer, ForeignKey("market_orders.id"), nullable=False)
    sell_order_id = Column(Integer, ForeignKey("market_orders.id"), nullable=False)
    
    # Transaction details
    quantity = Column(Integer, nullable=False)
    price_per_unit = Column(Integer, nullable=False)  # Actual price traded at
    total_gold = Column(Integer, nullable=False)      # quantity * price_per_unit
    
    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<MarketTransaction(id={self.id}, {self.quantity} {self.item_type} @ {self.price_per_unit}g, total={self.total_gold}g)>"

