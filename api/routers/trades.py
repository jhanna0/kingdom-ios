"""
Player-to-Player Trading System

Requirements:
- Both sender and recipient must have Merchant skill tier 1+
- Both players must be friends (accepted friendship)

Trade Types:
1. Item Offer: Send an item with optional gold price (0 = gift)
2. Gold Gift: Send gold directly to a friend

Flow:
1. Sender creates offer -> recipient gets notification
2. Recipient accepts/declines
3. On accept: resources exchanged atomically on backend
4. Both players get notifications of outcome
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from typing import List, Optional
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel

from db.base import get_db
from db import User, PlayerState, Friend, TradeOffer, TradeOfferStatus, PlayerInventory, Kingdom
from routers.auth import get_current_user
from routers.resources import RESOURCES
from routers.actions.utils import format_datetime_iso
from routers.actions.tax_utils import apply_kingdom_tax
from websocket.broadcast import notify_user


router = APIRouter(prefix="/trades", tags=["trades"])


# ===== Constants =====

TRADE_OFFER_EXPIRY_HOURS = 24  # Offers expire after 24 hours
MERCHANT_SKILL_REQUIRED = 1    # Minimum merchant skill to trade


# ===== Schemas =====

class CreateTradeOfferRequest(BaseModel):
    """Request to create a new trade offer"""
    recipient_id: int                     # Friend's user ID
    offer_type: str = "item"              # "item" or "gold"
    item_type: Optional[str] = None       # e.g., "iron", "wood", "meat"
    item_quantity: Optional[int] = 1      # How many items to offer
    gold_amount: int = 0                  # Price (for items) or amount (for gold gifts)
    message: Optional[str] = None         # Optional message


class TradeOfferResponse(BaseModel):
    """Trade offer details for API response"""
    id: int
    sender_id: int
    sender_name: str
    recipient_id: int
    recipient_name: str
    offer_type: str
    item_type: Optional[str]
    item_display_name: Optional[str]
    item_icon: Optional[str]
    item_quantity: Optional[int]
    gold_amount: int
    status: str
    message: Optional[str]
    created_at: str
    expires_at: str
    is_incoming: bool  # True if current user is recipient


class TradeListResponse(BaseModel):
    """List of trade offers"""
    success: bool
    incoming: List[TradeOfferResponse]   # Offers received (pending)
    outgoing: List[TradeOfferResponse]   # Offers sent (pending)
    history: List[TradeOfferResponse]    # Recent completed/declined offers


class TradeActionResponse(BaseModel):
    """Response for trade actions (accept, decline, cancel)"""
    success: bool
    message: str
    gold_exchanged: Optional[int] = None
    item_exchanged: Optional[str] = None
    item_quantity: Optional[int] = None


# ===== Helper Functions =====

def get_player_state(db: Session, user: User) -> PlayerState:
    """Get player state for a user"""
    state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    return state


def check_merchant_skill(state: PlayerState, min_level: int = MERCHANT_SKILL_REQUIRED) -> bool:
    """Check if player has required merchant skill"""
    merchant_level = getattr(state, 'merchant', 0)
    return merchant_level >= min_level


def are_friends(db: Session, user_id_1: int, user_id_2: int) -> bool:
    """Check if two users are friends (accepted friendship)"""
    friendship = db.query(Friend).filter(
        or_(
            and_(Friend.user_id == user_id_1, Friend.friend_user_id == user_id_2),
            and_(Friend.user_id == user_id_2, Friend.friend_user_id == user_id_1)
        ),
        Friend.status == 'accepted'
    ).first()
    return friendship is not None


def get_player_resource_amount(db: Session, state: PlayerState, item_type: str) -> int:
    """Get how much of a resource a player has"""
    config = RESOURCES.get(item_type)
    if not config:
        return 0
    
    if config.get("storage_type") == "column":
        # Legacy column storage (gold, iron, steel, wood)
        return int(getattr(state, item_type, 0))
    else:
        # Inventory table storage (meat, sinew, etc.)
        inv = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == state.user_id,
            PlayerInventory.item_id == item_type
        ).first()
        return inv.quantity if inv else 0


def modify_player_resource(db: Session, state: PlayerState, item_type: str, delta: int):
    """Modify player's resource amount"""
    config = RESOURCES.get(item_type)
    if not config:
        raise ValueError(f"Unknown item type: {item_type}")
    
    if config.get("storage_type") == "column":
        # Legacy column storage
        current = getattr(state, item_type, 0)
        setattr(state, item_type, current + delta)
    else:
        # Inventory table storage
        inv = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == state.user_id,
            PlayerInventory.item_id == item_type
        ).first()
        
        if inv:
            inv.quantity += delta
            if inv.quantity <= 0:
                db.delete(inv)
        elif delta > 0:
            inv = PlayerInventory(
                user_id=state.user_id,
                item_id=item_type,
                quantity=delta
            )
            db.add(inv)


def trade_offer_to_response(
    db: Session, 
    offer: TradeOffer, 
    current_user_id: int
) -> TradeOfferResponse:
    """Convert TradeOffer to API response"""
    sender = db.query(User).filter(User.id == offer.sender_id).first()
    recipient = db.query(User).filter(User.id == offer.recipient_id).first()
    
    # Get item display info
    item_display_name = None
    item_icon = None
    if offer.item_type:
        resource_config = RESOURCES.get(offer.item_type, {})
        item_display_name = resource_config.get("display_name", offer.item_type.capitalize())
        item_icon = resource_config.get("icon", "cube.fill")
    
    # Calculate expiry time
    expires_at = offer.created_at + timedelta(hours=TRADE_OFFER_EXPIRY_HOURS)
    
    return TradeOfferResponse(
        id=offer.id,
        sender_id=offer.sender_id,
        sender_name=sender.display_name if sender else "Unknown",
        recipient_id=offer.recipient_id,
        recipient_name=recipient.display_name if recipient else "Unknown",
        offer_type=offer.offer_type,
        item_type=offer.item_type,
        item_display_name=item_display_name,
        item_icon=item_icon,
        item_quantity=offer.item_quantity,
        gold_amount=offer.gold_amount,
        status=offer.status,
        message=offer.message,
        created_at=format_datetime_iso(offer.created_at),
        expires_at=format_datetime_iso(expires_at),
        is_incoming=offer.recipient_id == current_user_id
    )


def send_trade_notification(
    user_id: int,
    event_type: str,
    offer: TradeOffer,
    sender_name: str,
    recipient_name: str,
    extra_data: dict = None
):
    """Send a real-time notification about a trade"""
    data = {
        "offer_id": offer.id,
        "offer_type": offer.offer_type,
        "sender_id": offer.sender_id,
        "sender_name": sender_name,
        "recipient_id": offer.recipient_id,
        "recipient_name": recipient_name,
    }
    
    if offer.item_type:
        resource_config = RESOURCES.get(offer.item_type, {})
        data["item_type"] = offer.item_type
        data["item_display_name"] = resource_config.get("display_name", offer.item_type.capitalize())
        data["item_icon"] = resource_config.get("icon", "cube.fill")
        data["item_quantity"] = offer.item_quantity
    
    data["gold_amount"] = offer.gold_amount
    
    if extra_data:
        data.update(extra_data)
    
    notify_user(str(user_id), event_type, data)


# ===== API Endpoints =====

@router.get("/list", response_model=TradeListResponse)
def list_trade_offers(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all trade offers for the current user.
    Returns incoming (pending), outgoing (pending), and recent history.
    """
    user_id = current_user.id
    
    # Check if user has merchant skill (required to see trades)
    # COMMENTED OUT: Allow viewing trades even without merchant skill (for message injection workaround)
    # state = get_player_state(db, current_user)
    # if not check_merchant_skill(state):
    #     raise HTTPException(
    #         status_code=403,
    #         detail="Merchant skill tier 1 required for trading. Train your Merchant skill!"
    #     )
    
    # Expire old pending offers and return escrow
    expire_threshold = datetime.now(timezone.utc) - timedelta(hours=TRADE_OFFER_EXPIRY_HOURS)
    expired_offers = db.query(TradeOffer).filter(
        TradeOffer.status == TradeOfferStatus.PENDING.value,
        TradeOffer.created_at < expire_threshold
    ).all()
    
    for offer in expired_offers:
        # Return escrowed items/gold to sender
        sender_state = db.query(PlayerState).filter(PlayerState.user_id == offer.sender_id).first()
        if sender_state:
            if offer.offer_type == "item" and offer.item_type:
                modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
            elif offer.offer_type == "gold":
                sender_state.gold += offer.gold_amount
        
        offer.status = TradeOfferStatus.EXPIRED.value
    
    db.commit()
    
    # Get incoming pending offers
    incoming = db.query(TradeOffer).filter(
        TradeOffer.recipient_id == user_id,
        TradeOffer.status == TradeOfferStatus.PENDING.value
    ).order_by(TradeOffer.created_at.desc()).all()
    
    # Get outgoing pending offers
    outgoing = db.query(TradeOffer).filter(
        TradeOffer.sender_id == user_id,
        TradeOffer.status == TradeOfferStatus.PENDING.value
    ).order_by(TradeOffer.created_at.desc()).all()
    
    # Get recent history (last 20)
    history = db.query(TradeOffer).filter(
        or_(TradeOffer.sender_id == user_id, TradeOffer.recipient_id == user_id),
        TradeOffer.status != TradeOfferStatus.PENDING.value
    ).order_by(TradeOffer.updated_at.desc()).limit(20).all()
    
    return TradeListResponse(
        success=True,
        incoming=[trade_offer_to_response(db, o, user_id) for o in incoming],
        outgoing=[trade_offer_to_response(db, o, user_id) for o in outgoing],
        history=[trade_offer_to_response(db, o, user_id) for o in history]
    )


@router.get("/pending-count")
def get_pending_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get count of pending incoming trade offers (for badge display)"""
    # COMMENTED OUT: Allow viewing count even without merchant skill
    # state = get_player_state(db, current_user)
    # if not check_merchant_skill(state):
    #     return {"count": 0, "has_merchant_skill": False}
    
    # Expire old offers first (return escrow)
    expire_threshold = datetime.now(timezone.utc) - timedelta(hours=TRADE_OFFER_EXPIRY_HOURS)
    expired_offers = db.query(TradeOffer).filter(
        TradeOffer.status == TradeOfferStatus.PENDING.value,
        TradeOffer.created_at < expire_threshold
    ).all()
    
    for offer in expired_offers:
        sender_state = db.query(PlayerState).filter(PlayerState.user_id == offer.sender_id).first()
        if sender_state:
            if offer.offer_type == "item" and offer.item_type:
                modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
            elif offer.offer_type == "gold":
                sender_state.gold += offer.gold_amount
        offer.status = TradeOfferStatus.EXPIRED.value
    
    db.commit()
    
    count = db.query(TradeOffer).filter(
        TradeOffer.recipient_id == current_user.id,
        TradeOffer.status == TradeOfferStatus.PENDING.value
    ).count()
    
    # Always return True for has_merchant_skill since we're not checking it anymore
    return {"count": count, "has_merchant_skill": True}


@router.post("/create", response_model=TradeActionResponse)
def create_trade_offer(
    request: CreateTradeOfferRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new trade offer to a friend.
    
    Requirements:
    - Both sender and recipient must have Merchant skill tier 1+
    - Players must be friends
    - Sender must have the items/gold to offer
    """
    sender_state = get_player_state(db, current_user)
    
    # Check sender has merchant skill
    if not check_merchant_skill(sender_state):
        raise HTTPException(
            status_code=403,
            detail="Merchant skill tier 1 required to create trade offers. Train your Merchant skill!"
        )
    
    # Get recipient
    recipient = db.query(User).filter(User.id == request.recipient_id).first()
    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")
    
    # Check they're friends
    if not are_friends(db, current_user.id, request.recipient_id):
        raise HTTPException(status_code=403, detail="You can only trade with friends")
    
    # Check no pending trade already exists between these players (either direction)
    existing_pending = db.query(TradeOffer).filter(
        TradeOffer.status == TradeOfferStatus.PENDING.value,
        or_(
            and_(TradeOffer.sender_id == current_user.id, TradeOffer.recipient_id == request.recipient_id),
            and_(TradeOffer.sender_id == request.recipient_id, TradeOffer.recipient_id == current_user.id)
        )
    ).first()
    
    if existing_pending:
        raise HTTPException(
            status_code=400,
            detail="There's already a pending trade between you and this player. Wait for it to be resolved first."
        )
    
    # Check recipient has merchant skill
    recipient_state = db.query(PlayerState).filter(
        PlayerState.user_id == request.recipient_id
    ).first()
    if not recipient_state or not check_merchant_skill(recipient_state):
        raise HTTPException(
            status_code=403,
            detail=f"{recipient.display_name} doesn't have Merchant skill tier 1. They need to train it to trade!"
        )
    
    # Validate offer
    if request.offer_type == "item":
        # Validate item type
        if not request.item_type:
            raise HTTPException(status_code=400, detail="Item type required for item offers")
        
        if request.item_type not in RESOURCES:
            raise HTTPException(status_code=400, detail=f"Unknown item type: {request.item_type}")
        
        resource_config = RESOURCES.get(request.item_type, {})
        if not resource_config.get("is_tradeable", True):
            raise HTTPException(status_code=400, detail=f"Cannot trade {request.item_type}")
        
        # Check sender has the items
        quantity = request.item_quantity or 1
        if quantity < 1:
            raise HTTPException(status_code=400, detail="Quantity must be at least 1")
        
        sender_amount = get_player_resource_amount(db, sender_state, request.item_type)
        if sender_amount < quantity:
            item_name = resource_config.get("display_name", request.item_type)
            raise HTTPException(
                status_code=400,
                detail=f"You don't have enough {item_name}. You have {sender_amount}, need {quantity}."
            )
        
        # Gold price can be 0 (gift) or positive
        if request.gold_amount < 0:
            raise HTTPException(status_code=400, detail="Gold price cannot be negative")
        
    elif request.offer_type == "gold":
        # Gold gift - sender sends gold to recipient
        if request.gold_amount <= 0:
            raise HTTPException(status_code=400, detail="Gold amount must be positive for gold gifts")
        
        # Check sender has enough gold
        sender_gold = int(sender_state.gold)
        if sender_gold < request.gold_amount:
            raise HTTPException(
                status_code=400,
                detail=f"You don't have enough gold. You have {sender_gold}, trying to send {request.gold_amount}."
            )
    else:
        raise HTTPException(status_code=400, detail="Invalid offer type. Must be 'item' or 'gold'")
    
    # ESCROW: Deduct items/gold from sender NOW (return if declined/cancelled)
    if request.offer_type == "item":
        # Hold the items in escrow
        modify_player_resource(db, sender_state, request.item_type, -request.item_quantity)
    else:  # gold gift
        # Hold the gold in escrow
        sender_state.gold -= request.gold_amount
    
    # Create the offer
    offer = TradeOffer(
        sender_id=current_user.id,
        recipient_id=request.recipient_id,
        offer_type=request.offer_type,
        item_type=request.item_type if request.offer_type == "item" else None,
        item_quantity=request.item_quantity if request.offer_type == "item" else None,
        gold_amount=request.gold_amount,
        message=request.message,
        status=TradeOfferStatus.PENDING.value
    )
    
    db.add(offer)
    db.commit()
    db.refresh(offer)
    
    # Send notification to recipient
    send_trade_notification(
        user_id=request.recipient_id,
        event_type="trade_offer_received",
        offer=offer,
        sender_name=current_user.display_name,
        recipient_name=recipient.display_name
    )
    
    # Build response message
    if request.offer_type == "item":
        item_name = RESOURCES.get(request.item_type, {}).get("display_name", request.item_type)
        if request.gold_amount > 0:
            msg = f"Offered {request.item_quantity} {item_name} for {request.gold_amount}g to {recipient.display_name}"
        else:
            msg = f"Offered {request.item_quantity} {item_name} as a gift to {recipient.display_name}"
    else:
        msg = f"Offered {request.gold_amount}g to {recipient.display_name}"

    return TradeActionResponse(success=True, message=msg)


@router.post("/{offer_id}/accept", response_model=TradeActionResponse)
def accept_trade_offer(
    offer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Accept a trade offer. Exchanges items/gold atomically.
    """
    offer = db.query(TradeOffer).filter(TradeOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Trade offer not found")
    
    # Must be the recipient
    if offer.recipient_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the recipient can accept this offer")
    
    # Must be pending
    if offer.status != TradeOfferStatus.PENDING.value:
        raise HTTPException(status_code=400, detail=f"Offer is no longer pending (status: {offer.status})")
    
    # Check if expired - return escrow if so
    if offer.created_at < datetime.now(timezone.utc) - timedelta(hours=TRADE_OFFER_EXPIRY_HOURS):
        # Return escrow to sender
        if sender_state:
            if offer.offer_type == "item" and offer.item_type:
                modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
            elif offer.offer_type == "gold":
                sender_state.gold += offer.gold_amount
        
        offer.status = TradeOfferStatus.EXPIRED.value
        db.commit()
        raise HTTPException(status_code=400, detail="Offer has expired")
    
    # Get states
    recipient_state = get_player_state(db, current_user)
    sender = db.query(User).filter(User.id == offer.sender_id).first()
    sender_state = db.query(PlayerState).filter(PlayerState.user_id == offer.sender_id).first()
    
    if not sender or not sender_state:
        raise HTTPException(status_code=404, detail="Sender no longer exists")
    
    # Validate both still have merchant skill
    # COMMENTED OUT: Allow accepting trades even without merchant skill (already validated at creation)
    # if not check_merchant_skill(recipient_state):
    #     raise HTTPException(status_code=403, detail="You no longer have Merchant skill tier 1")
    # if not check_merchant_skill(sender_state):
    #     raise HTTPException(status_code=403, detail="Sender no longer has Merchant skill tier 1")
    
    # Items/gold are already held in escrow from sender when offer was created
    # Now we just need to transfer to recipient
    
    if offer.offer_type == "item":
        # Check recipient has enough gold (if not a gift)
        if offer.gold_amount > 0:
            recipient_gold = int(recipient_state.gold)
            if recipient_gold < offer.gold_amount:
                raise HTTPException(
                    status_code=400,
                    detail=f"You don't have enough gold. Need {offer.gold_amount}g, you have {recipient_gold}g."
                )
        
        # Execute the trade
        # 1. Items already deducted from sender (escrow) - give to recipient
        modify_player_resource(db, recipient_state, offer.item_type, offer.item_quantity)
        
        # 2. Transfer gold payment from recipient to sender (if any) - with tax
        tax_amount = 0
        tax_rate = 0
        net_gold_to_sender = 0
        if offer.gold_amount > 0:
            recipient_state.gold -= offer.gold_amount
            
            # Apply kingdom tax to gold the sender receives (goes to sender's hometown)
            # Tax is paid by the person receiving the gold
            if sender_state.hometown_kingdom_id:
                net_gold_to_sender, tax_amount, tax_rate = apply_kingdom_tax(
                    db=db,
                    kingdom_id=sender_state.hometown_kingdom_id,
                    player_state=sender_state,
                    gross_income=float(offer.gold_amount)
                )
            else:
                # No hometown, no tax
                net_gold_to_sender = float(offer.gold_amount)
            
            sender_state.gold += net_gold_to_sender
        
        item_name = RESOURCES.get(offer.item_type, {}).get("display_name", offer.item_type)
        if offer.gold_amount > 0:
            if tax_amount > 0:
                msg = f"Received {offer.item_quantity} {item_name} for {offer.gold_amount}g (seller received {int(net_gold_to_sender)}g after {tax_rate}% tax)"
            else:
                msg = f"Received {offer.item_quantity} {item_name} for {offer.gold_amount}g"
        else:
            msg = f"Received {offer.item_quantity} {item_name} as a gift"
        
    else:  # gold gift
        # Gold already deducted from sender (escrow) - give to recipient
        recipient_state.gold += offer.gold_amount
        
        msg = f"Received {offer.gold_amount}g from {sender.display_name}"
        item_name = None
    
    # Mark as accepted
    offer.status = TradeOfferStatus.ACCEPTED.value
    offer.responded_at = datetime.now(timezone.utc)
    db.commit()
    
    # Notify sender that offer was accepted
    send_trade_notification(
        user_id=offer.sender_id,
        event_type="trade_offer_accepted",
        offer=offer,
        sender_name=sender.display_name,
        recipient_name=current_user.display_name
    )
    
    return TradeActionResponse(
        success=True,
        message=msg,
        gold_exchanged=offer.gold_amount if offer.gold_amount > 0 else None,
        item_exchanged=offer.item_type,
        item_quantity=offer.item_quantity
    )


@router.post("/{offer_id}/decline", response_model=TradeActionResponse)
def decline_trade_offer(
    offer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Decline a trade offer. Returns escrowed items/gold to sender."""
    offer = db.query(TradeOffer).filter(TradeOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Trade offer not found")
    
    # Must be the recipient
    if offer.recipient_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the recipient can decline this offer")
    
    # Must be pending
    if offer.status != TradeOfferStatus.PENDING.value:
        raise HTTPException(status_code=400, detail=f"Offer is no longer pending (status: {offer.status})")
    
    # Get sender state to return escrow
    sender = db.query(User).filter(User.id == offer.sender_id).first()
    sender_state = db.query(PlayerState).filter(PlayerState.user_id == offer.sender_id).first()
    
    # Return escrowed items/gold to sender
    if sender_state:
        if offer.offer_type == "item" and offer.item_type:
            modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
        elif offer.offer_type == "gold":
            sender_state.gold += offer.gold_amount
    
    # Mark as declined
    offer.status = TradeOfferStatus.DECLINED.value
    offer.responded_at = datetime.now(timezone.utc)
    db.commit()
    
    # Notify sender
    send_trade_notification(
        user_id=offer.sender_id,
        event_type="trade_offer_declined",
        offer=offer,
        sender_name=sender.display_name if sender else "Unknown",
        recipient_name=current_user.display_name
    )
    
    return TradeActionResponse(success=True, message="Trade offer declined")


@router.post("/{offer_id}/cancel", response_model=TradeActionResponse)
def cancel_trade_offer(
    offer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a trade offer you sent. Returns escrowed items/gold."""
    offer = db.query(TradeOffer).filter(TradeOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Trade offer not found")
    
    # Must be the sender
    if offer.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the sender can cancel this offer")
    
    # Must be pending
    if offer.status != TradeOfferStatus.PENDING.value:
        raise HTTPException(status_code=400, detail=f"Offer is no longer pending (status: {offer.status})")
    
    # Return escrowed items/gold to sender
    sender_state = get_player_state(db, current_user)
    if offer.offer_type == "item" and offer.item_type:
        modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
    elif offer.offer_type == "gold":
        sender_state.gold += offer.gold_amount
    
    # Mark as cancelled
    offer.status = TradeOfferStatus.CANCELLED.value
    offer.responded_at = datetime.now(timezone.utc)
    db.commit()
    
    return TradeActionResponse(success=True, message="Trade offer cancelled")


@router.get("/tradeable-items")
def get_tradeable_items(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get list of items the player can trade (has at least 1 of).
    Returns item info with quantities.
    """
    state = get_player_state(db, current_user)
    
    # COMMENTED OUT: Allow viewing tradeable items even without merchant skill
    # if not check_merchant_skill(state):
    #     raise HTTPException(
    #         status_code=403,
    #         detail="Merchant skill tier 1 required for trading"
    #     )
    
    tradeable = []
    
    for item_id, config in RESOURCES.items():
        # Skip non-tradeable items (like gold)
        if not config.get("is_tradeable", True):
            continue
        
        amount = get_player_resource_amount(db, state, item_id)
        if amount > 0:
            tradeable.append({
                "item_id": item_id,
                "display_name": config.get("display_name", item_id.capitalize()),
                "icon": config.get("icon", "cube.fill"),
                "color": config.get("color", "gray"),
                "quantity": amount
            })
    
    # Also include current gold for gold gifts
    gold = int(state.gold)
    
    return {
        "success": True,
        "items": tradeable,
        "gold": gold
    }
