"""
Market Router - Grand Exchange style player-to-player trading
"""
from fastapi import APIRouter, HTTPException, Depends, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, desc
from typing import List, Optional
from datetime import datetime, timedelta
from collections import defaultdict

from db import get_db, User, Kingdom, MarketOrder, MarketTransaction, OrderType, OrderStatus, PlayerInventory
from routers.auth import get_current_user
from schemas.market import (
    CreateOrderRequest, CreateOrderResult, MarketOrderResponse, MarketTransactionResponse,
    OrderBook, OrderBookEntry, PriceHistory, PriceHistoryEntry, PlayerOrdersResponse,
    CancelOrderResult, MarketInfoResponse, AvailableItemsResponse
)
from routers.resources import RESOURCES
from services.market_service import MarketMatchingEngine


router = APIRouter(prefix="/market", tags=["market"])


def get_market_commodities(kingdom: Kingdom) -> List[str]:
    """
    Get building-gated market commodities (iron, steel, wood).
    These are the main items shown as tabs on the market page.
    """
    items = []
    
    if kingdom.mine_level >= 2:
        items.append("iron")
    if kingdom.mine_level >= 3:
        items.append("steel")
    
    has_lumbermill = hasattr(kingdom, 'lumbermill_level') and kingdom.lumbermill_level >= 1
    has_farm = kingdom.farm_level >= 1
    if has_lumbermill or has_farm:
        items.append("wood")
    
    return items


def get_all_tradeable_items(kingdom: Kingdom) -> List[str]:
    """
    Get ALL items that can be traded (for Create Order page).
    Includes market commodities + inventory items like meat/sinew.
    """
    items = get_market_commodities(kingdom)
    
    # Add inventory items (consumables, crafting materials)
    for item_id, config in RESOURCES.items():
        if not config.get("is_tradeable", True):
            continue
        if config.get("storage_type") == "inventory" and item_id not in items:
            items.append(item_id)
    
    return items


@router.post("/orders", response_model=CreateOrderResult)
def create_order(
    request: CreateOrderRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new buy or sell order
    
    - Attempts instant matching with existing orders
    - Uses price-time priority (FIFO within price level)
    - Provides price improvement when possible
    - Orders are scoped to your current kingdom
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Check if player is in a kingdom
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom to trade"
        )
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if market exists
    if kingdom.market_level < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This kingdom has no market. The ruler must build a market first."
        )
    
    # Check if player can use this market
    # By default, you can only use the market in your HOME kingdom
    # Merchant skill tier 3+ unlocks using markets in foreign kingdoms
    is_home_kingdom = state.hometown_kingdom_id == state.current_kingdom_id
    merchant_level = getattr(state, 'merchant', 0)
    
    if not is_home_kingdom and merchant_level < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can only use the market in your home kingdom. Merchant skill tier 3 unlocks foreign market access."
        )
    
    # Validate item exists in RESOURCES config
    if request.item_type not in RESOURCES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown item type: '{request.item_type}'"
        )
    
    # Check if item is available for trading (includes meat, sinew, etc.)
    tradeable_items = get_all_tradeable_items(kingdom)
    if request.item_type not in tradeable_items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Item '{request.item_type}' not available for trading in this kingdom"
        )
    
    # Check buy order limit (20 per item type)
    if request.order_type == OrderType.BUY:
        active_buy_orders_count = db.query(func.count(MarketOrder.id)).filter(
            and_(
                MarketOrder.player_id == current_user.id,
                MarketOrder.item_type == request.item_type,
                MarketOrder.order_type == OrderType.BUY,
                MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED])
            )
        ).scalar() or 0
        
        if active_buy_orders_count >= 20:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You have reached the maximum of 20 active buy orders for {request.item_type}. Cancel some orders first."
            )
    
    # TODO: Check merchant skill for cross-kingdom trading
    # For now, all trades are kingdom-scoped
    
    # Create order using matching engine
    engine = MarketMatchingEngine(db)
    
    try:
        order, transactions = engine.create_order(
            player_id=current_user.id,
            kingdom_id=state.current_kingdom_id,
            order_type=request.order_type,
            item_type=request.item_type,
            price_per_unit=request.price_per_unit,
            quantity=request.quantity
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    # Calculate results
    total_quantity_filled = sum(t.quantity for t in transactions)
    total_gold_exchanged = sum(t.total_gold for t in transactions)
    fully_filled = total_quantity_filled == request.quantity
    partially_filled = 0 < total_quantity_filled < request.quantity
    quantity_remaining = request.quantity - total_quantity_filled
    
    return CreateOrderResult(
        order_created=order is not None,
        order=MarketOrderResponse.from_orm(order) if order else None,
        instant_matches=[MarketTransactionResponse.from_orm(t) for t in transactions],
        total_quantity_filled=total_quantity_filled,
        total_gold_exchanged=total_gold_exchanged,
        fully_filled=fully_filled,
        partially_filled=partially_filled,
        quantity_remaining=quantity_remaining
    )


@router.get("/orders/{order_id}", response_model=MarketOrderResponse)
def get_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get details of a specific order"""
    order = db.query(MarketOrder).filter(MarketOrder.id == order_id).first()
    
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )
    
    # Only allow viewing own orders (or make public for transparency?)
    # For now, making it public for market transparency
    
    return MarketOrderResponse.from_orm(order)


@router.delete("/orders/{order_id}", response_model=CancelOrderResult)
def cancel_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Cancel an active order
    
    - Refunds locked resources (gold for buy orders, items for sell orders)
    - Can only cancel your own orders
    - Cannot cancel already filled orders
    """
    engine = MarketMatchingEngine(db)
    
    try:
        order = engine.cancel_order(order_id, current_user.id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    refunded_items = None
    refunded_gold = None
    
    if order.order_type == OrderType.SELL:
        refunded_items = order.quantity_remaining
    else:
        refunded_gold = order.price_per_unit * order.quantity_remaining
    
    return CancelOrderResult(
        success=True,
        message=f"Order cancelled successfully",
        order_id=order_id,
        refunded_items=refunded_items,
        refunded_gold=refunded_gold
    )


@router.get("/orderbook/{item_type}", response_model=OrderBook)
def get_order_book(
    item_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get the current order book for an item
    
    Shows aggregated buy and sell orders by price level
    """
    state = current_user.player_state
    if not state or not state.current_kingdom_id:
            raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    kingdom_id = state.current_kingdom_id
    
    # Get active buy orders (group by price)
    buy_orders_query = db.query(
        MarketOrder.price_per_unit,
        func.sum(MarketOrder.quantity_remaining).label('total_quantity'),
        func.count(MarketOrder.id).label('num_orders')
    ).filter(
        and_(
            MarketOrder.kingdom_id == kingdom_id,
            MarketOrder.item_type == item_type,
            MarketOrder.order_type == OrderType.BUY,
            MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED])
        )
    ).group_by(MarketOrder.price_per_unit).order_by(desc(MarketOrder.price_per_unit)).all()
    
    # Get active sell orders (group by price)
    sell_orders_query = db.query(
        MarketOrder.price_per_unit,
        func.sum(MarketOrder.quantity_remaining).label('total_quantity'),
        func.count(MarketOrder.id).label('num_orders')
    ).filter(
        and_(
            MarketOrder.kingdom_id == kingdom_id,
            MarketOrder.item_type == item_type,
            MarketOrder.order_type == OrderType.SELL,
            MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED])
        )
    ).group_by(MarketOrder.price_per_unit).order_by(MarketOrder.price_per_unit.asc()).all()
    
    buy_orders = [
        OrderBookEntry(
            price_per_unit=price,
            total_quantity=int(quantity),
            num_orders=int(count)
        )
        for price, quantity, count in buy_orders_query
    ]
    
    sell_orders = [
        OrderBookEntry(
            price_per_unit=price,
            total_quantity=int(quantity),
            num_orders=int(count)
        )
        for price, quantity, count in sell_orders_query
    ]
    
    highest_buy = buy_orders[0].price_per_unit if buy_orders else None
    lowest_sell = sell_orders[0].price_per_unit if sell_orders else None
    spread = (lowest_sell - highest_buy) if (highest_buy and lowest_sell) else None
    
    return OrderBook(
        item_type=item_type,
        kingdom_id=kingdom_id,
        buy_orders=buy_orders,
        sell_orders=sell_orders,
        highest_buy_offer=highest_buy,
        lowest_sell_offer=lowest_sell,
        spread=spread
    )


@router.get("/history/{item_type}", response_model=PriceHistory)
def get_price_history(
    item_type: str,
    hours: int = Query(default=24, ge=1, le=168),  # 1 hour to 1 week
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get price history for an item
    
    Shows recent completed transactions with statistics
    """
    state = current_user.player_state
    if not state or not state.current_kingdom_id:
            raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    kingdom_id = state.current_kingdom_id
    cutoff_time = datetime.utcnow() - timedelta(hours=hours)
    
    # Get recent transactions
    transactions = db.query(MarketTransaction).filter(
        and_(
            MarketTransaction.kingdom_id == kingdom_id,
            MarketTransaction.item_type == item_type,
            MarketTransaction.created_at >= cutoff_time
        )
    ).order_by(MarketTransaction.created_at.desc()).limit(500).all()
    
    if not transactions:
        return PriceHistory(
            item_type=item_type,
            kingdom_id=kingdom_id,
            transactions=[],
            average_price=None,
            min_price=None,
            max_price=None,
            total_volume=0
        )
    
    # Build history entries
    history_entries = [
        PriceHistoryEntry(
            timestamp=t.created_at,
            price=t.price_per_unit,
            quantity=t.quantity
        )
        for t in transactions
    ]
    
    # Calculate statistics
    prices = [t.price_per_unit for t in transactions]
    quantities = [t.quantity for t in transactions]
    
    # Weighted average price
    total_value = sum(t.total_gold for t in transactions)
    total_quantity = sum(quantities)
    avg_price = total_value / total_quantity if total_quantity > 0 else None
    
    return PriceHistory(
        item_type=item_type,
        kingdom_id=kingdom_id,
        transactions=history_entries,
        average_price=avg_price,
        min_price=min(prices),
        max_price=max(prices),
        total_volume=total_quantity
    )


@router.get("/my-orders", response_model=PlayerOrdersResponse)
def get_my_orders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all your orders and recent transactions
    
    Includes:
    - Active orders (can be cancelled)
    - Recently filled orders
    - Recent transactions you participated in
    """
    # Get active orders
    active_orders = db.query(MarketOrder).filter(
        and_(
            MarketOrder.player_id == current_user.id,
            MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED])
        )
    ).order_by(MarketOrder.created_at.desc()).all()
    
    # Get recently filled orders (last 7 days)
    cutoff_time = datetime.utcnow() - timedelta(days=7)
    filled_orders = db.query(MarketOrder).filter(
        and_(
            MarketOrder.player_id == current_user.id,
            MarketOrder.status.in_([OrderStatus.FILLED, OrderStatus.CANCELLED]),
            MarketOrder.filled_at >= cutoff_time
        )
    ).order_by(MarketOrder.filled_at.desc()).limit(50).all()
    
    # Get recent transactions
    recent_transactions = db.query(MarketTransaction).filter(
        and_(
            or_(
                MarketTransaction.buyer_id == current_user.id,
                MarketTransaction.seller_id == current_user.id
            ),
            MarketTransaction.created_at >= cutoff_time
        )
    ).order_by(MarketTransaction.created_at.desc()).limit(50).all()
    
    return PlayerOrdersResponse(
        active_orders=[MarketOrderResponse.from_orm(o) for o in active_orders],
        recent_filled=[MarketOrderResponse.from_orm(o) for o in filled_orders],
        recent_transactions=[MarketTransactionResponse.from_orm(t) for t in recent_transactions]
    )


@router.get("/info", response_model=MarketInfoResponse)
def get_market_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get general market information for your current kingdom
    
    Shows:
    - Kingdom market details
    - Available items for trading (ALL tradeable items, not just what player owns)
    - Your resources/inventory (for sell quantity limits)
    - Market activity stats
    """
    state = current_user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    if not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if player can access this market
    is_home_kingdom = state.hometown_kingdom_id == state.current_kingdom_id
    merchant_level = getattr(state, 'merchant', 0)
    can_access_market = is_home_kingdom or merchant_level >= 3
    
    # Get ALL tradeable items (commodities + inventory items like meat/sinew)
    # Users can BUY anything tradeable, SELL only what they own
    available_items = get_all_tradeable_items(kingdom) if can_access_market else []
    
    # Generate message based on access
    message = None
    if not can_access_market:
        message = "You can only use the market in your home kingdom. Train Merchant to tier 3 to unlock foreign market access."
    elif not available_items:
        message = "No items available for trading yet."
    
    # Count active orders
    total_active_orders = db.query(func.count(MarketOrder.id)).filter(
        and_(
            MarketOrder.kingdom_id == kingdom.id,
            MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED])
        )
    ).scalar()
    
    # Count transactions in last 24 hours
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    total_transactions_24h = db.query(func.count(MarketTransaction.id)).filter(
        and_(
            MarketTransaction.kingdom_id == kingdom.id,
            MarketTransaction.created_at >= cutoff_time
        )
    ).scalar()
    
    # Build player resources from both column storage and inventory
    # This tells the frontend how much the player can SELL of each item
    player_resources = {}
    for item_id, config in RESOURCES.items():
        if config.get("storage_type") == "column":
            value = getattr(state, item_id, 0)
            # Handle float gold - convert to int for display
            player_resources[item_id] = int(value) if isinstance(value, float) else value
        else:
            inv = db.query(PlayerInventory).filter(
                PlayerInventory.user_id == current_user.id,
                PlayerInventory.item_id == item_id
            ).first()
            player_resources[item_id] = inv.quantity if inv else 0
    
    return MarketInfoResponse(
        kingdom_id=kingdom.id,
        kingdom_name=kingdom.name,
        market_level=kingdom.market_level,
        player_id=current_user.id,
        can_access_market=can_access_market,
        available_items=available_items,
        message=message,
        player_gold=int(state.gold) if isinstance(state.gold, float) else state.gold,
        player_resources=player_resources,
        total_active_orders=total_active_orders or 0,
        total_transactions_24h=total_transactions_24h or 0
    )


@router.get("/recent-trades", response_model=List[MarketTransactionResponse])
def get_recent_trades(
    item_type: Optional[str] = None,
    limit: int = Query(default=50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get recent market trades in your kingdom
    
    Useful for seeing market activity and current prices
    """
    state = current_user.player_state
    if not state or not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    query = db.query(MarketTransaction).filter(
        MarketTransaction.kingdom_id == state.current_kingdom_id
    )
    
    if item_type:
        query = query.filter(MarketTransaction.item_type == item_type)
    
    transactions = query.order_by(
        MarketTransaction.created_at.desc()
    ).limit(limit).all()
    
    return [MarketTransactionResponse.from_orm(t) for t in transactions]


@router.get("/available-items", response_model=AvailableItemsResponse)
def get_available_items_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all items available for trading with full config.
    Frontend should use this to render market UI dynamically - NO HARDCODING!
    """
    state = current_user.player_state
    if not state or not state.current_kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must be checked into a kingdom"
        )
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == state.current_kingdom_id).first()
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Get ALL tradeable items (commodities + inventory items like meat/sinew)
    tradeable_item_ids = get_all_tradeable_items(kingdom)
    
    items = []
    for item_id in tradeable_item_ids:
        config = RESOURCES.get(item_id, {})
        items.append({
            "id": item_id,
            "display_name": config.get("display_name", item_id),
            "icon": config.get("icon", "questionmark"),
            "color": config.get("color", "gray"),
            "description": config.get("description", ""),
            "category": config.get("category", "unknown"),
        })
    
    return AvailableItemsResponse(items=items)
