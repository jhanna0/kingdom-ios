"""
Market schemas - Grand Exchange style order book
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class OrderType(str, Enum):
    """Order type"""
    BUY = "buy"
    SELL = "sell"


class OrderStatus(str, Enum):
    """Order status"""
    ACTIVE = "active"
    FILLED = "filled"
    PARTIALLY_FILLED = "partially_filled"
    CANCELLED = "cancelled"


class ItemType(str, Enum):
    """Tradeable items"""
    IRON = "iron"
    STEEL = "steel"
    WOOD = "wood"
    # Future: stone, titanium, food, etc.


class CreateOrderRequest(BaseModel):
    """Request to create a new market order"""
    order_type: OrderType
    item_type: ItemType
    price_per_unit: int = Field(gt=0, description="Gold per unit")
    quantity: int = Field(gt=0, description="Number of units")


class MarketOrderResponse(BaseModel):
    """Response for a market order"""
    id: int
    player_id: int
    kingdom_id: str
    order_type: OrderType
    item_type: ItemType
    price_per_unit: int
    quantity_remaining: int
    quantity_original: int
    status: OrderStatus
    created_at: datetime
    updated_at: datetime
    filled_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class MarketTransactionResponse(BaseModel):
    """Response for a completed transaction"""
    id: int
    kingdom_id: str
    item_type: ItemType
    buyer_id: int
    seller_id: int
    quantity: int
    price_per_unit: int
    total_gold: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class OrderBookEntry(BaseModel):
    """Single entry in the order book"""
    price_per_unit: int
    total_quantity: int  # Sum of all orders at this price
    num_orders: int      # Number of orders at this price


class OrderBook(BaseModel):
    """Current order book for an item"""
    item_type: ItemType
    kingdom_id: str
    
    # Buy orders (highest price first)
    buy_orders: List[OrderBookEntry]
    
    # Sell orders (lowest price first)
    sell_orders: List[OrderBookEntry]
    
    # Best prices
    highest_buy_offer: Optional[int] = None
    lowest_sell_offer: Optional[int] = None
    
    # Spread
    spread: Optional[int] = None  # Difference between best buy and sell


class PriceHistoryEntry(BaseModel):
    """Price history data point"""
    timestamp: datetime
    price: int
    quantity: int


class PriceHistory(BaseModel):
    """Price history for an item"""
    item_type: ItemType
    kingdom_id: str
    transactions: List[PriceHistoryEntry]
    
    # Statistics
    average_price: Optional[float] = None
    min_price: Optional[int] = None
    max_price: Optional[int] = None
    total_volume: int = 0


class CreateOrderResult(BaseModel):
    """Result of creating an order (may include instant matches)"""
    order_created: bool
    order: Optional[MarketOrderResponse] = None
    
    # Instant matching results
    instant_matches: List[MarketTransactionResponse] = []
    total_quantity_filled: int = 0
    total_gold_exchanged: int = 0
    
    # Final status
    fully_filled: bool
    partially_filled: bool
    quantity_remaining: int = 0


class CancelOrderResult(BaseModel):
    """Result of cancelling an order"""
    success: bool
    message: str
    order_id: int
    refunded_items: Optional[int] = None  # For sell orders
    refunded_gold: Optional[int] = None   # For buy orders


class PlayerOrdersResponse(BaseModel):
    """Player's active and recent orders"""
    active_orders: List[MarketOrderResponse]
    recent_filled: List[MarketOrderResponse]
    recent_transactions: List[MarketTransactionResponse]


class MarketInfoResponse(BaseModel):
    """General market information"""
    kingdom_id: str
    kingdom_name: str
    market_level: int
    
    # Available items (based on kingdom buildings)
    available_items: List[ItemType]
    message: Optional[str] = None  # Message to display when no items available
    
    # Player resources
    player_gold: int
    player_resources: dict  # {item_type: quantity}
    
    # Market activity
    total_active_orders: int
    total_transactions_24h: int

