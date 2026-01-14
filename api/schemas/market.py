"""
Market schemas - Grand Exchange style order book
"""
from pydantic import BaseModel, Field, field_serializer
from typing import Optional, List
from datetime import datetime
from enum import Enum


def serialize_datetime_with_z(dt: Optional[datetime]) -> Optional[str]:
    """Serialize datetime to ISO8601 string with Z suffix for iOS compatibility"""
    if dt is None:
        return None
    # Strip microseconds - Swift's .iso8601 decoder can't parse them
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        # Naive datetime - assume UTC and add Z
        return iso_str + 'Z'
    return iso_str


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


# ItemType is now a simple string validated against RESOURCES config
# No more hardcoded enum! Frontend fetches available items from /market/available-items
ItemType = str  # Validated against routers.resources.RESOURCES at runtime


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
    
    @field_serializer('created_at', 'updated_at', 'filled_at')
    @classmethod
    def serialize_dt(cls, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


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
    
    @field_serializer('created_at')
    @classmethod
    def serialize_dt(cls, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


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
    
    @field_serializer('timestamp')
    @classmethod
    def serialize_dt(cls, dt: Optional[datetime]) -> Optional[str]:
        return serialize_datetime_with_z(dt)


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
    
    # Market access - requires home kingdom OR Merchant tier 3+
    can_access_market: bool = True
    
    # Available items (based on kingdom buildings)
    available_items: List[str]  # List of item_ids from resources.RESOURCES
    message: Optional[str] = None  # Message to display when no access or no items
    
    # Player resources
    player_gold: int
    player_resources: dict  # {item_type: quantity}
    
    # Market activity
    total_active_orders: int
    total_transactions_24h: int


class AvailableItemsResponse(BaseModel):
    """List of items available for trading with full config"""
    items: List[dict]  # Each item has: id, display_name, icon, color, description, category

