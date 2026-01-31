"""
Market Service - Order matching engine for Grand Exchange
Implements FIFO order matching with price-time priority

TODO: CROSS-KINGDOM TRADING (Not yet implemented!)
=====================================
Currently ALL trades are scoped to the player's current kingdom.

Cross-kingdom trading should work based on:

1. MARKET BUILDING TIER (kingdom where the order is placed):
   - Tier 1: Intrakingdom only (same kingdom)
   - Tier 3: Trade with ALLIED kingdoms
   - Tier 5: Trade with ANY neighboring kingdom

2. MERCHANT SKILL (player skill):
   - Tier 3: "Ability to buy and sell to markets of other kingdoms"
   - This allows the PLAYER to access foreign kingdom markets
   - Should go by player's CURRENT kingdom location

Implementation notes:
- When placing order: Check if player can access that kingdom's market
- When matching: Consider orders from accessible kingdoms based on market tier
- Player with Merchant 3+ can use markets in kingdoms they're visiting
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional, Tuple
from datetime import datetime

from db.models import MarketOrder, MarketTransaction, OrderType, OrderStatus, PlayerState, User, PlayerInventory, Kingdom
from routers.resources import RESOURCES


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
        if order_type == OrderType.buy:
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
        
        # Create the order FIRST (so we have an ID for transactions)
        order = MarketOrder(
            player_id=player_id,
            kingdom_id=kingdom_id,
            order_type=order_type,
            item_type=item_type,
            price_per_unit=price_per_unit,
            quantity_remaining=quantity,
            quantity_original=quantity,
            status=OrderStatus.active
        )
        self.db.add(order)
        self.db.flush()  # Get the order ID
        
        # Now try to match against existing orders
        transactions = []
        remaining_quantity = quantity
        
        if order_type == OrderType.buy:
            # Match against sell orders (lowest price first, then FIFO)
            matching_orders = self.db.query(MarketOrder).filter(
                and_(
                    MarketOrder.kingdom_id == kingdom_id,
                    MarketOrder.item_type == item_type,
                    MarketOrder.order_type == OrderType.sell,
                    MarketOrder.status.in_([OrderStatus.active, OrderStatus.partially_filled]),
                    MarketOrder.price_per_unit <= price_per_unit,  # Willing to pay this much
                    MarketOrder.id != order.id  # Don't match with self
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
                
                # Create transaction with both order IDs
                transaction = self._execute_trade(
                    buyer_id=player_id,
                    seller_id=sell_order.player_id,
                    buy_order_id=order.id,
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
                    sell_order.status = OrderStatus.filled
                    sell_order.filled_at = datetime.utcnow()
                elif sell_order.quantity_remaining < sell_order.quantity_original:
                    sell_order.status = OrderStatus.partially_filled
                
                remaining_quantity -= match_quantity
                
                # Handle price difference (buyer bid higher than seller's ask)
                price_diff = price_per_unit - match_price
                if price_diff > 0:
                    diff_gold = price_diff * match_quantity
                    buyer_merchant_level = getattr(state, 'merchant', 0)
                    
                    if buyer_merchant_level >= 2:
                        # Merchant T2: Buyer keeps the excess
                        state.gold += diff_gold
                    else:
                        # No perk: Excess goes to kingdom treasury
                        kingdom = self.db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
                        if kingdom:
                            kingdom.treasury_gold += diff_gold
        
        else:  # SELL order
            # Match against buy orders (highest price first, then FIFO)
            matching_orders = self.db.query(MarketOrder).filter(
                and_(
                    MarketOrder.kingdom_id == kingdom_id,
                    MarketOrder.item_type == item_type,
                    MarketOrder.order_type == OrderType.buy,
                    MarketOrder.status.in_([OrderStatus.active, OrderStatus.partially_filled]),
                    MarketOrder.price_per_unit >= price_per_unit,  # Willing to accept this much
                    MarketOrder.id != order.id  # Don't match with self
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
                
                # Create transaction with both order IDs
                transaction = self._execute_trade(
                    buyer_id=buy_order.player_id,
                    seller_id=player_id,
                    buy_order_id=buy_order.id,
                    sell_order_id=order.id,
                    kingdom_id=kingdom_id,
                    item_type=item_type,
                    quantity=match_quantity,
                    price_per_unit=match_price
                )
                transactions.append(transaction)
                
                # Update buy order
                buy_order.quantity_remaining -= match_quantity
                if buy_order.quantity_remaining == 0:
                    buy_order.status = OrderStatus.filled
                    buy_order.filled_at = datetime.utcnow()
                elif buy_order.quantity_remaining < buy_order.quantity_original:
                    buy_order.status = OrderStatus.partially_filled
                
                remaining_quantity -= match_quantity
                
                # Handle price difference (buyer paid more than seller asked)
                price_diff = match_price - price_per_unit
                if price_diff > 0:
                    diff_gold = price_diff * match_quantity
                    seller_merchant_level = getattr(state, 'merchant', 0)
                    
                    # Get the buyer's merchant level to check T2
                    buyer_user = self.db.query(User).filter(User.id == buy_order.player_id).first()
                    buyer_merchant_level = 0
                    if buyer_user and buyer_user.player_state:
                        buyer_merchant_level = getattr(buyer_user.player_state, 'merchant', 0)
                    
                    if buyer_merchant_level >= 2:
                        # Buyer has T2: They get the refund (already locked gold is returned)
                        # The buyer's gold was already locked when they placed the order
                        # So we need to refund them the difference
                        buyer_user.player_state.gold += diff_gold
                    elif seller_merchant_level >= 4:
                        # Seller has T4 (and buyer doesn't have T2): Seller gets the bonus
                        state.gold += diff_gold
                    else:
                        # Neither has the perk: Goes to kingdom treasury
                        kingdom = self.db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
                        if kingdom:
                            kingdom.treasury_gold += diff_gold
        
        # Update our order's remaining quantity and status
        order.quantity_remaining = remaining_quantity
        if remaining_quantity == 0:
            order.status = OrderStatus.filled
            order.filled_at = datetime.utcnow()
        elif remaining_quantity < quantity:
            order.status = OrderStatus.partially_filled
        
        self.db.commit()
        
        # Return None for order if fully filled (no active order remaining)
        return (order if remaining_quantity > 0 else order, transactions)
    
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
        
        if order.status not in [OrderStatus.active, OrderStatus.partially_filled]:
            raise ValueError("Order cannot be cancelled")
        
        # Get player state
        player = self.db.query(User).filter(User.id == player_id).first()
        if not player or not player.player_state:
            raise ValueError("Player not found")
        
        state = player.player_state
        
        # Refund locked resources
        if order.order_type == OrderType.buy:
            # Refund locked gold
            refund_gold = order.price_per_unit * order.quantity_remaining
            state.gold += refund_gold
        else:  # SELL
            # Refund locked items
            self._modify_player_resource(state, order.item_type, order.quantity_remaining)
        
        # Update order status
        order.status = OrderStatus.cancelled
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
        
        # Get kingdom for taxes
        kingdom = self.db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
        
        # Transfer resources
        # Buyer receives items
        self._modify_player_resource(buyer_state, item_type, quantity)
        
        # Apply tax to seller's income
        # Tax goes to the kingdom where the trade happens
        tax_rate = kingdom.tax_rate if kingdom else 0
        
        # Check for Merchant T5: 50% reduced taxes
        seller_merchant_level = getattr(seller_state, 'merchant', 0)
        if seller_merchant_level >= 5:
            tax_rate = tax_rate // 2  # 50% reduced taxes
        
        tax_amount = int(total_gold * tax_rate / 100)
        net_gold = total_gold - tax_amount
        
        # Seller receives gold after tax
        seller_state.gold += net_gold
        
        # Kingdom treasury receives tax
        if kingdom and tax_amount > 0:
            kingdom.treasury_gold += tax_amount
        
        # Create transaction record
        # Note: order_id fields are nullable to allow creating transaction before order exists
        transaction = MarketTransaction(
            kingdom_id=kingdom_id,
            item_type=item_type,
            buyer_id=buyer_id,
            seller_id=seller_id,
            buy_order_id=buy_order_id,
            sell_order_id=sell_order_id,
            quantity=quantity,
            price_per_unit=price_per_unit,
            total_gold=total_gold  # Store gross amount, tax is applied separately
        )
        self.db.add(transaction)
        
        return transaction
    
    def _get_player_resource(self, state: PlayerState, item_type: str) -> int:
        """Get player's current amount of a resource.
        
        Uses storage_type from RESOURCES config:
        - "column": Only gold (needs float precision for taxes)
        - "inventory": All other resources (iron, steel, wood, stone, meat, etc.)
        """
        config = RESOURCES.get(item_type)
        if not config:
            raise ValueError(f"Unknown item type: {item_type}")
        
        if config.get("storage_type") == "column":
            # Gold is stored as column (needs float precision for tax math)
            return getattr(state, item_type, 0)
        else:
            # All other resources use inventory table
            inv = self.db.query(PlayerInventory).filter(
                PlayerInventory.user_id == state.user_id,
                PlayerInventory.item_id == item_type
            ).first()
            return inv.quantity if inv else 0
    
    def _modify_player_resource(self, state: PlayerState, item_type: str, delta: int):
        """Modify player's resource amount.
        
        Uses storage_type from RESOURCES config:
        - "column": Only gold (needs float precision for taxes)
        - "inventory": All other resources (iron, steel, wood, stone, meat, etc.)
        """
        config = RESOURCES.get(item_type)
        if not config:
            raise ValueError(f"Unknown item type: {item_type}")
        
        if config.get("storage_type") == "column":
            # Gold is stored as column (needs float precision for tax math)
            current = getattr(state, item_type, 0)
            setattr(state, item_type, current + delta)
        else:
            # All other resources use inventory table
            inv = self.db.query(PlayerInventory).filter(
                PlayerInventory.user_id == state.user_id,
                PlayerInventory.item_id == item_type
            ).first()
            
            if inv:
                inv.quantity += delta
                if inv.quantity <= 0:
                    self.db.delete(inv)
            elif delta > 0:
                # Create new inventory row
                inv = PlayerInventory(
                    user_id=state.user_id,
                    item_id=item_type,
                    quantity=delta
                )
                self.db.add(inv)

