"""
Market Service - Order matching engine for Grand Exchange
Implements FIFO order matching with price-time priority
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional, Tuple
from datetime import datetime

from db.models import MarketOrder, MarketTransaction, OrderType, OrderStatus, PlayerState, User
from schemas.market import ItemType


class MarketMatchingEngine:
    """
    Grand Exchange-style order matching engine
    
    Matching Rules:
    1. Price priority: Best prices match first (highest buy, lowest sell)
    2. Time priority (FIFO): Within same price, oldest orders match first
    3. Price improvement: Trades execute at the existing order's price
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def create_order(
        self,
        player_id: int,
        kingdom_id: str,
        order_type: OrderType,
        item_type: str,
        price_per_unit: int,
        quantity: int
    ) -> Tuple[Optional[MarketOrder], List[MarketTransaction]]:
        """
        Create a new order and attempt to match it immediately
        
        Returns:
            (order, transactions) - Order may be None if fully filled instantly
        """
        # Get player state
        player = self.db.query(User).filter(User.id == player_id).first()
        if not player or not player.player_state:
            raise ValueError("Player not found")
        
        state = player.player_state
        
        # Validate and lock resources
        if order_type == OrderType.BUY:
            total_cost = price_per_unit * quantity
            if state.gold < total_cost:
                raise ValueError(f"Not enough gold. Need {total_cost}g, have {state.gold}g")
            # Lock gold for buy order
            state.gold -= total_cost
        else:  # SELL
            current_amount = self._get_player_resource(state, item_type)
            if current_amount < quantity:
                raise ValueError(f"Not enough {item_type}. Need {quantity}, have {current_amount}")
            # Lock items for sell order
            self._modify_player_resource(state, item_type, -quantity)
        
        # Try to match against existing orders
        transactions = []
        remaining_quantity = quantity
        
        if order_type == OrderType.BUY:
            # Match against sell orders (lowest price first, then FIFO)
            matching_orders = self.db.query(MarketOrder).filter(
                and_(
                    MarketOrder.kingdom_id == kingdom_id,
                    MarketOrder.item_type == item_type,
                    MarketOrder.order_type == OrderType.SELL,
                    MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED]),
                    MarketOrder.price_per_unit <= price_per_unit  # Willing to pay this much
                )
            ).order_by(
                MarketOrder.price_per_unit.asc(),  # Lowest price first
                MarketOrder.created_at.asc()        # FIFO within price
            ).all()
            
            for sell_order in matching_orders:
                if remaining_quantity <= 0:
                    break
                
                # Match as much as possible
                match_quantity = min(remaining_quantity, sell_order.quantity_remaining)
                match_price = sell_order.price_per_unit  # Use existing order's price
                
                # Create transaction
                transaction = self._execute_trade(
                    buyer_id=player_id,
                    seller_id=sell_order.player_id,
                    buy_order_id=None,  # Will update after creating buy order
                    sell_order_id=sell_order.id,
                    kingdom_id=kingdom_id,
                    item_type=item_type,
                    quantity=match_quantity,
                    price_per_unit=match_price
                )
                transactions.append(transaction)
                
                # Update sell order
                sell_order.quantity_remaining -= match_quantity
                if sell_order.quantity_remaining == 0:
                    sell_order.status = OrderStatus.FILLED
                    sell_order.filled_at = datetime.utcnow()
                elif sell_order.quantity_remaining < sell_order.quantity_original:
                    sell_order.status = OrderStatus.PARTIALLY_FILLED
                
                remaining_quantity -= match_quantity
                
                # Refund buyer for price improvement
                price_diff = price_per_unit - match_price
                if price_diff > 0:
                    state.gold += price_diff * match_quantity
        
        else:  # SELL order
            # Match against buy orders (highest price first, then FIFO)
            matching_orders = self.db.query(MarketOrder).filter(
                and_(
                    MarketOrder.kingdom_id == kingdom_id,
                    MarketOrder.item_type == item_type,
                    MarketOrder.order_type == OrderType.BUY,
                    MarketOrder.status.in_([OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED]),
                    MarketOrder.price_per_unit >= price_per_unit  # Willing to accept this much
                )
            ).order_by(
                MarketOrder.price_per_unit.desc(),  # Highest price first
                MarketOrder.created_at.asc()         # FIFO within price
            ).all()
            
            for buy_order in matching_orders:
                if remaining_quantity <= 0:
                    break
                
                # Match as much as possible
                match_quantity = min(remaining_quantity, buy_order.quantity_remaining)
                match_price = buy_order.price_per_unit  # Use existing order's price
                
                # Create transaction
                transaction = self._execute_trade(
                    buyer_id=buy_order.player_id,
                    seller_id=player_id,
                    buy_order_id=buy_order.id,
                    sell_order_id=None,  # Will update after creating sell order
                    kingdom_id=kingdom_id,
                    item_type=item_type,
                    quantity=match_quantity,
                    price_per_unit=match_price
                )
                transactions.append(transaction)
                
                # Update buy order
                buy_order.quantity_remaining -= match_quantity
                if buy_order.quantity_remaining == 0:
                    buy_order.status = OrderStatus.FILLED
                    buy_order.filled_at = datetime.utcnow()
                elif buy_order.quantity_remaining < buy_order.quantity_original:
                    buy_order.status = OrderStatus.PARTIALLY_FILLED
                
                remaining_quantity -= match_quantity
                
                # Seller gets price improvement
                price_diff = match_price - price_per_unit
                if price_diff > 0:
                    state.gold += price_diff * match_quantity
        
        # Create order for remaining quantity (if any)
        order = None
        if remaining_quantity > 0:
            order = MarketOrder(
                player_id=player_id,
                kingdom_id=kingdom_id,
                order_type=order_type,
                item_type=item_type,
                price_per_unit=price_per_unit,
                quantity_remaining=remaining_quantity,
                quantity_original=quantity,
                status=OrderStatus.PARTIALLY_FILLED if transactions else OrderStatus.ACTIVE
            )
            self.db.add(order)
            self.db.flush()  # Get the order ID
            
            # Update transaction records with the new order ID
            for transaction in transactions:
                if order_type == OrderType.BUY:
                    transaction.buy_order_id = order.id
                else:
                    transaction.sell_order_id = order.id
        else:
            # Fully filled instantly - no order needed
            # But we need to create a dummy order for transaction records
            order = MarketOrder(
                player_id=player_id,
                kingdom_id=kingdom_id,
                order_type=order_type,
                item_type=item_type,
                price_per_unit=price_per_unit,
                quantity_remaining=0,
                quantity_original=quantity,
                status=OrderStatus.FILLED,
                filled_at=datetime.utcnow()
            )
            self.db.add(order)
            self.db.flush()
            
            # Update transaction records
            for transaction in transactions:
                if order_type == OrderType.BUY:
                    transaction.buy_order_id = order.id
                else:
                    transaction.sell_order_id = order.id
        
        self.db.commit()
        
        return (order if remaining_quantity > 0 else None, transactions)
    
    def cancel_order(self, order_id: int, player_id: int) -> MarketOrder:
        """
        Cancel an active order and refund locked resources
        """
        order = self.db.query(MarketOrder).filter(
            and_(
                MarketOrder.id == order_id,
                MarketOrder.player_id == player_id
            )
        ).first()
        
        if not order:
            raise ValueError("Order not found")
        
        if order.status not in [OrderStatus.ACTIVE, OrderStatus.PARTIALLY_FILLED]:
            raise ValueError("Order cannot be cancelled")
        
        # Get player state
        player = self.db.query(User).filter(User.id == player_id).first()
        if not player or not player.player_state:
            raise ValueError("Player not found")
        
        state = player.player_state
        
        # Refund locked resources
        if order.order_type == OrderType.BUY:
            # Refund locked gold
            refund_gold = order.price_per_unit * order.quantity_remaining
            state.gold += refund_gold
        else:  # SELL
            # Refund locked items
            self._modify_player_resource(state, order.item_type, order.quantity_remaining)
        
        # Update order status
        order.status = OrderStatus.CANCELLED
        order.filled_at = datetime.utcnow()
        
        self.db.commit()
        
        return order
    
    def _execute_trade(
        self,
        buyer_id: int,
        seller_id: int,
        buy_order_id: Optional[int],
        sell_order_id: Optional[int],
        kingdom_id: str,
        item_type: str,
        quantity: int,
        price_per_unit: int
    ) -> MarketTransaction:
        """Execute a trade between buyer and seller"""
        total_gold = quantity * price_per_unit
        
        # Get buyer and seller states
        buyer = self.db.query(User).filter(User.id == buyer_id).first()
        seller = self.db.query(User).filter(User.id == seller_id).first()
        
        if not buyer or not buyer.player_state or not seller or not seller.player_state:
            raise ValueError("Buyer or seller not found")
        
        buyer_state = buyer.player_state
        seller_state = seller.player_state
        
        # Transfer resources
        # Buyer receives items
        self._modify_player_resource(buyer_state, item_type, quantity)
        
        # Seller receives gold
        seller_state.gold += total_gold
        
        # Create transaction record
        transaction = MarketTransaction(
            kingdom_id=kingdom_id,
            item_type=item_type,
            buyer_id=buyer_id,
            seller_id=seller_id,
            buy_order_id=buy_order_id or 0,  # Temporary, will update
            sell_order_id=sell_order_id or 0,  # Temporary, will update
            quantity=quantity,
            price_per_unit=price_per_unit,
            total_gold=total_gold
        )
        self.db.add(transaction)
        
        return transaction
    
    def _get_player_resource(self, state: PlayerState, item_type: str) -> int:
        """Get player's current amount of a resource"""
        if item_type == "iron":
            return state.iron
        elif item_type == "steel":
            return state.steel
        elif item_type == "wood":
            return state.wood
        else:
            raise ValueError(f"Unknown item type: {item_type}")
    
    def _modify_player_resource(self, state: PlayerState, item_type: str, delta: int):
        """Modify player's resource amount"""
        if item_type == "iron":
            state.iron += delta
        elif item_type == "steel":
            state.steel += delta
        elif item_type == "wood":
            state.wood += delta
        else:
            raise ValueError(f"Unknown item type: {item_type}")

