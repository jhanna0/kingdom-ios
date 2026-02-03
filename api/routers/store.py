"""
STORE API ROUTER
================
In-app purchase validation and resource granting with Apple App Store Server API verification.

Endpoints:
- POST /store/redeem - Redeem a purchase and grant resources (verifies with Apple)
- GET /store/products - Get available products
- GET /store/history - Get user's purchase history

Security:
- All purchases are verified with Apple's App Store Server API
- Transaction IDs are stored to prevent duplicate redemptions
- Supports sandbox testing in development
"""

import os
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from jose import jwt

from db import get_db
from db.models import User, PlayerState, PlayerInventory, Purchase
from routers.auth import get_current_user
import config

router = APIRouter(prefix="/store", tags=["store"])


# ============================================================
# APPLE APP STORE CONFIGURATION
# ============================================================

# App Store Server API credentials (from App Store Connect)
APPLE_ISSUER_ID = os.getenv("APPLE_ISSUER_ID")  # Your team's issuer ID
APPLE_KEY_ID = os.getenv("APPLE_KEY_ID")  # API key ID
APPLE_PRIVATE_KEY = os.getenv("APPLE_PRIVATE_KEY", "").replace("\\n", "\n")  # .p8 key contents
APPLE_BUNDLE_ID = os.getenv("APPLE_BUNDLE_ID", "com.kingdom.app")

# App Store Server API endpoints
APPLE_PRODUCTION_URL = "https://api.storekit.itunes.apple.com"
APPLE_SANDBOX_URL = "https://api.storekit-sandbox.itunes.apple.com"


# ============================================================
# PRODUCT CONFIGURATION
# ============================================================

PRODUCTS = {
    "com.kingdom.starter_pack": {
        "name": "Starter Pack",
        "gold": 1000,
        "meat": 1000,
        "price_usd": 1.99,
        "icon": "crown.fill",
        "color": "imperialGold",
    },
    "com.kingdom.book_pack_5": {
        "name": "Book Pack (5)",
        "books": 5,
        "price_usd": 3.99,
        "icon": "book.fill",
        "color": "buttonPrimary",
    },
    # Uncomment when added to App Store Connect:
    # "com.kingdom.book_pack_15": {
    #     "name": "Book Pack (15)",
    #     "books": 15,
    #     "price_usd": 4.99,
    #     "icon": "books.vertical.fill",
    #     "color": "buttonPrimary",
    # },
    # Future products:
    # "com.kingdom.mega_pack": {
    #     "name": "Mega Pack", 
    #     "gold": 5000,
    #     "meat": 5000,
    #     "price_usd": 19.99,
    #     "icon": "crown.fill",
    #     "color": "imperialGold",
    # },
}


# ============================================================
# BOOK CONFIGURATION
# ============================================================

# Slots that can use books (excludes farm, patrol, and battle-related)
BOOK_ELIGIBLE_SLOTS = ["personal", "building", "crafting"]

# Action types that CANNOT use books (farming, patrolling, fighting)
BOOK_INELIGIBLE_ACTIONS = ["farm", "patrol", "view_coup", "view_invasion", "view_battle", "spectate_battle"]


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class RedeemRequest(BaseModel):
    product_id: str
    transaction_id: str
    original_transaction_id: Optional[str] = None


class RedeemResponse(BaseModel):
    success: bool
    message: Optional[str] = None
    display_message: Optional[str] = None  # Ready-to-display message for UI (server-driven)
    gold_granted: int = 0
    meat_granted: int = 0
    books_granted: int = 0
    new_gold_total: int = 0
    new_meat_total: int = 0
    new_book_total: int = 0


class UseBookRequest(BaseModel):
    slot: str  # "personal" (training), "building", or "crafting"
    action_type: Optional[str] = None  # Optional: specific action type for validation


class UseBookResponse(BaseModel):
    success: bool
    message: str
    books_remaining: int
    cooldown_reduced_minutes: int
    new_cooldown_seconds: int  # Seconds remaining after reduction


class PurchaseHistoryItem(BaseModel):
    product_id: str
    product_name: str
    gold_granted: int
    meat_granted: int
    purchased_at: str
    status: str


# ============================================================
# APPLE APP STORE SERVER API
# ============================================================

def generate_apple_jwt() -> str:
    """
    Generate a JWT for authenticating with Apple's App Store Server API.
    
    See: https://developer.apple.com/documentation/appstoreserverapi/generating_tokens_for_api_requests
    """
    if not all([APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY]):
        raise ValueError("Apple App Store credentials not configured")
    
    now = int(time.time())
    
    payload = {
        "iss": APPLE_ISSUER_ID,
        "iat": now,
        "exp": now + 3600,  # 1 hour expiry
        "aud": "appstoreconnect-v1",
        "bid": APPLE_BUNDLE_ID,
    }
    
    headers = {
        "alg": "ES256",
        "kid": APPLE_KEY_ID,
        "typ": "JWT",
    }
    
    return jwt.encode(payload, APPLE_PRIVATE_KEY, algorithm="ES256", headers=headers)


async def verify_transaction_with_apple(transaction_id: str, use_sandbox: bool = False) -> dict:
    """
    Verify a transaction with Apple's App Store Server API.
    
    Returns transaction info if valid, raises exception if invalid.
    """
    base_url = APPLE_SANDBOX_URL if use_sandbox else APPLE_PRODUCTION_URL
    url = f"{base_url}/inApps/v1/transactions/{transaction_id}"
    
    try:
        token = generate_apple_jwt()
    except ValueError as e:
        print(f"⚠️ Apple credentials not configured: {e}")
        # In dev mode, allow unverified purchases
        if config.DEV_MODE:
            return {"dev_mode": True, "verified": False}
        raise HTTPException(status_code=500, detail="Store not configured")
    
    async with httpx.AsyncClient() as client:
        response = await client.get(
            url,
            headers={"Authorization": f"Bearer {token}"}
        )
    
    if response.status_code == 404:
        # Transaction not found - try sandbox if we tried production
        if not use_sandbox:
            return await verify_transaction_with_apple(transaction_id, use_sandbox=True)
        raise HTTPException(status_code=400, detail="Transaction not found")
    
    if response.status_code != 200:
        print(f"❌ Apple API error: {response.status_code} - {response.text}")
        raise HTTPException(status_code=400, detail="Failed to verify transaction with Apple")
    
    data = response.json()
    
    # The response contains a JWS-signed transaction
    # For full security, you should verify this JWS, but the API response itself is trusted
    return {
        "verified": True,
        "environment": "Sandbox" if use_sandbox else "Production",
        "data": data,
    }


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_player_inventory_item(db: Session, user_id: int, item_id: str) -> int:
    """Get player's current amount of an item from inventory."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).first()
    return inv.quantity if inv else 0


def get_player_meat(db: Session, user_id: int) -> int:
    """Get player's current meat amount from inventory."""
    return get_player_inventory_item(db, user_id, "meat")


def get_player_books(db: Session, user_id: int) -> int:
    """Get player's current book count from inventory."""
    return get_player_inventory_item(db, user_id, "book")


def add_inventory_item(db: Session, user_id: int, item_id: str, amount: int):
    """Add an item to player's inventory."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == user_id,
        PlayerInventory.item_id == item_id
    ).first()
    
    if inv:
        inv.quantity += amount
        if inv.quantity <= 0:
            db.delete(inv)
    elif amount > 0:
        inv = PlayerInventory(
            user_id=user_id,
            item_id=item_id,
            quantity=amount
        )
        db.add(inv)


def add_meat(db: Session, user_id: int, amount: int):
    """Add meat to player's inventory."""
    add_inventory_item(db, user_id, "meat", amount)


def add_books(db: Session, user_id: int, amount: int):
    """Add books to player's inventory."""
    add_inventory_item(db, user_id, "book", amount)


# ============================================================
# ENDPOINTS
# ============================================================

@router.post("/redeem", response_model=RedeemResponse)
async def redeem_purchase(
    request: RedeemRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Redeem an in-app purchase and grant resources to the player.
    
    Flow:
    1. Check if transaction already redeemed (prevent duplicates)
    2. Verify transaction with Apple's App Store Server API
    3. Grant resources to player
    4. Record purchase in database
    """
    
    # 1. Validate product exists
    product = PRODUCTS.get(request.product_id)
    if not product:
        raise HTTPException(status_code=400, detail=f"Unknown product: {request.product_id}")
    
    # 2. Check for duplicate redemption
    existing = db.query(Purchase).filter(
        Purchase.transaction_id == request.transaction_id
    ).first()
    
    if existing:
        if existing.user_id == current_user.id:
            # Same user trying to redeem again - just return success
            return RedeemResponse(
                success=True,
                message="Purchase already redeemed",
                gold_granted=0,
                meat_granted=0,
                new_gold_total=int(db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first().gold or 0),
                new_meat_total=get_player_meat(db, current_user.id)
            )
        else:
            # Different user trying to use same transaction - fraud attempt
            print(f"🚨 FRAUD ALERT: User {current_user.id} tried to redeem transaction {request.transaction_id} owned by user {existing.user_id}")
            raise HTTPException(status_code=400, detail="Invalid transaction")
    
    # 3. Get player state
    state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # 4. Verify with Apple (or trust client in dev mode)
    verification_error = None
    verified_with_apple = False
    environment = "Production"
    
    try:
        verification = await verify_transaction_with_apple(request.transaction_id)
        verified_with_apple = verification.get("verified", False)
        environment = verification.get("environment", "Production")
        
        if verification.get("dev_mode"):
            print(f"⚠️ DEV MODE: Skipping Apple verification for transaction {request.transaction_id}")
    except HTTPException:
        raise
    except Exception as e:
        verification_error = str(e)
        print(f"❌ Apple verification failed: {e}")
        
        # In dev mode, allow purchases without verification
        if not config.DEV_MODE:
            raise HTTPException(status_code=400, detail="Failed to verify purchase")
    
    # 5. Set purchase date
    purchase_date = datetime.now(timezone.utc)
    
    # 6. Grant resources
    gold_amount = product.get("gold", 0)
    meat_amount = product.get("meat", 0)
    book_amount = product.get("books", 0)
    
    if gold_amount > 0:
        state.gold = (state.gold or 0) + gold_amount
    if meat_amount > 0:
        add_meat(db, current_user.id, meat_amount)
    if book_amount > 0:
        add_books(db, current_user.id, book_amount)
    
    # 7. Record purchase
    purchase = Purchase(
        user_id=current_user.id,
        product_id=request.product_id,
        transaction_id=request.transaction_id,
        original_transaction_id=request.original_transaction_id,
        price_usd=product["price_usd"],
        gold_granted=gold_amount,
        meat_granted=meat_amount,
        books_granted=book_amount,
        environment=environment,
        verified_with_apple=verified_with_apple,
        verification_error=verification_error,
        purchased_at=purchase_date,
    )
    db.add(purchase)
    db.commit()
    
    # 8. Get new totals
    new_gold = int(state.gold)
    new_meat = get_player_meat(db, current_user.id)
    new_books = get_player_books(db, current_user.id)
    
    print(f"💰 Purchase redeemed! User {current_user.id} ({current_user.display_name})")
    print(f"   Product: {product['name']} (${product['price_usd']})")
    if gold_amount > 0:
        print(f"   Gold: +{gold_amount} (total: {new_gold})")
    if meat_amount > 0:
        print(f"   Meat: +{meat_amount} (total: {new_meat})")
    if book_amount > 0:
        print(f"   Books: +{book_amount} (total: {new_books})")
    print(f"   Verified: {verified_with_apple} ({environment})")
    
    # Build display message for UI (server-driven)
    from routers.resources import RESOURCES
    items = []
    if gold_amount > 0:
        gold_name = RESOURCES.get("gold", {}).get("display_name", "Gold")
        items.append(f"{gold_amount:,} {gold_name}")
    if meat_amount > 0:
        meat_name = RESOURCES.get("meat", {}).get("display_name", "Meat")
        items.append(f"{meat_amount:,} {meat_name}")
    if book_amount > 0:
        book_name = RESOURCES.get("book", {}).get("display_name", "Book")
        if book_amount > 1:
            book_name += "s"
        items.append(f"{book_amount} {book_name}")
    
    display_message = f"Added {' and '.join(items)}!" if items else "Purchase complete!"
    
    return RedeemResponse(
        success=True,
        message=f"Successfully redeemed {product['name']}!",
        display_message=display_message,
        gold_granted=gold_amount,
        meat_granted=meat_amount,
        books_granted=book_amount,
        new_gold_total=new_gold,
        new_meat_total=new_meat,
        new_book_total=new_books
    )


@router.get("/products")
async def get_products():
    """
    Get available products and their details.
    
    Note: The iOS app gets product info from the App Store directly,
    but this endpoint is useful for:
    - Web clients
    - Debugging
    - Verifying product configuration
    """
    return {
        "products": [
            {
                "id": product_id,
                "name": cfg["name"],
                "gold": cfg.get("gold", 0),
                "meat": cfg.get("meat", 0),
                "books": cfg.get("books", 0),
                "price_usd": cfg["price_usd"],
                "icon": cfg.get("icon", "bag.fill"),
                "color": cfg.get("color", "royalBlue"),
            }
            for product_id, cfg in PRODUCTS.items()
        ]
    }


@router.get("/history", response_model=List[PurchaseHistoryItem])
async def get_purchase_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get the current user's purchase history.
    """
    purchases = db.query(Purchase).filter(
        Purchase.user_id == current_user.id
    ).order_by(Purchase.purchased_at.desc()).limit(50).all()
    
    return [
        PurchaseHistoryItem(
            product_id=p.product_id,
            product_name=PRODUCTS.get(p.product_id, {}).get("name", "Unknown"),
            gold_granted=p.gold_granted,
            meat_granted=p.meat_granted,
            purchased_at=p.purchased_at.isoformat() if p.purchased_at else "",
            status=p.status,
        )
        for p in purchases
    ]


@router.post("/use-book", response_model=UseBookResponse)
async def use_book(
    request: UseBookRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Use a book to skip or reduce a cooldown. Effect is server-driven from resources.py.
    
    Books can be used on:
    - "personal" slot (training)
    - "building" slot (work, property_upgrade)
    - "crafting" slot
    
    Books CANNOT be used on:
    - farm (economy slot)
    - patrol (security slot)
    - battle-related actions (view_coup, view_invasion, etc.)
    
    Effect is determined by resources.py book config:
    - effect="skip_cooldown" (or cooldown_reduction_minutes=None): Clears entire cooldown
    - effect="reduce_cooldown" with cooldown_reduction_minutes=X: Reduces by X minutes
    """
    from datetime import timedelta
    from db.models import ActionCooldown
    from routers.actions.action_config import ACTION_SLOTS
    
    # Validate slot - books can only be used on certain slots
    if request.slot not in BOOK_ELIGIBLE_SLOTS:
        raise HTTPException(
            status_code=400, 
            detail=f"Books cannot be used on {request.slot}. Eligible slots: {', '.join(BOOK_ELIGIBLE_SLOTS)}"
        )
    
    # Validate action_type if provided - some actions can't use books even if in eligible slot
    if request.action_type and request.action_type in BOOK_INELIGIBLE_ACTIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Books cannot be used on {request.action_type}."
        )
    
    # Check if player has books
    book_count = get_player_books(db, current_user.id)
    if book_count <= 0:
        raise HTTPException(status_code=400, detail="No books available")
    
    # Get ALL action types in this slot - we need to clear ALL of them
    actions_in_slot = [action for action, slot in ACTION_SLOTS.items() if slot == request.slot]
    
    if not actions_in_slot:
        raise HTTPException(status_code=400, detail=f"No actions in slot: {request.slot}")
    
    # Find ALL cooldowns in the slot
    all_cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type.in_(actions_in_slot)
    ).all()
    
    if not all_cooldowns:
        raise HTTPException(status_code=400, detail="No active cooldown to skip")
    
    # Check if ANY cooldown in the slot has time remaining
    now = datetime.utcnow()
    has_active_cooldown = False
    
    for cd in all_cooldowns:
        if cd.last_performed:
            # Use a generous 3 hour check - if performed within 3 hours, consider it active
            elapsed = (now - cd.last_performed).total_seconds()
            if elapsed < 3 * 60 * 60:  # 3 hours
                has_active_cooldown = True
                break
    
    if not has_active_cooldown:
        return UseBookResponse(
            success=True,
            message="Cooldown already ready - no book needed!",
            books_remaining=book_count,
            cooldown_reduced_minutes=0,
            new_cooldown_seconds=0
        )
    
    # Get book config to determine effect
    from routers.resources import RESOURCES
    book_config = RESOURCES.get("book", {})
    effect = book_config.get("effect", "skip_cooldown")
    reduction_minutes = book_config.get("cooldown_reduction_minutes")
    
    if effect == "skip_cooldown" or reduction_minutes is None:
        # SKIP ENTIRE SLOT COOLDOWN - clear ALL cooldowns in the slot
        for cd in all_cooldowns:
            cd.last_performed = now - timedelta(days=7)
        cooldown_skipped = True
        new_remaining = 0
        message = f"Used 1 book to skip {request.slot} cooldown!"
    else:
        # REDUCE COOLDOWN - reduce all cooldowns in slot
        for cd in all_cooldowns:
            if cd.last_performed:
                cd.last_performed = cd.last_performed - timedelta(minutes=reduction_minutes)
        cooldown_skipped = False
        new_remaining = 0  # We don't calculate this for reduce mode
        message = f"Used 1 book to reduce {request.slot} cooldown by {reduction_minutes} minutes!"
    
    # Deduct the book
    add_books(db, current_user.id, -1)
    
    db.commit()
    
    books_remaining = get_player_books(db, current_user.id)
    
    print(f"📚 Book used! User {current_user.id} {'skipped' if cooldown_skipped else 'reduced'} {request.slot} cooldown")
    print(f"   Books remaining: {books_remaining}")
    print(f"   Cooldowns cleared: {len(all_cooldowns)}")
    
    return UseBookResponse(
        success=True,
        message=message,
        books_remaining=books_remaining,
        cooldown_reduced_minutes=reduction_minutes or 0,
        new_cooldown_seconds=int(new_remaining)
    )


@router.get("/books")
async def get_book_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get the current user's book count."""
    return {
        "books": get_player_books(db, current_user.id)
    }


class BookInfoResponse(BaseModel):
    """Book information for the cooldown skip popup."""
    books_owned: int
    description: str
    effect: str  # "skip_cooldown" or "reduce_cooldown"
    effect_description: str  # Human-readable effect for button/UI
    cooldown_reduction_minutes: Optional[int] = None  # None if skip_cooldown
    eligible_slots: List[str]
    can_purchase: bool
    purchase_product_id: Optional[str] = None


@router.get("/book-info", response_model=BookInfoResponse)
async def get_book_info(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get book information for the cooldown skip popup.
    
    All book behavior is server-driven so we can change it without app updates:
    - effect: "skip_cooldown" clears entire cooldown, "reduce_cooldown" reduces by X minutes
    - effect_description: Human-readable text for the button/UI
    - description: Full description of what books do
    """
    from routers.resources import RESOURCES
    
    book_config = RESOURCES.get("book", {})
    book_count = get_player_books(db, current_user.id)
    
    effect = book_config.get("effect", "skip_cooldown")
    reduction_minutes = book_config.get("cooldown_reduction_minutes")
    
    # Generate effect description based on current config
    if effect == "skip_cooldown" or reduction_minutes is None:
        effect_description = "Skip cooldown"
    else:
        if reduction_minutes >= 60:
            hours = reduction_minutes // 60
            effect_description = f"Skip {hours} hour{'s' if hours > 1 else ''}"
        else:
            effect_description = f"Skip {reduction_minutes} minutes"
    
    return BookInfoResponse(
        books_owned=book_count,
        description=book_config.get("description", "A tome of knowledge. Skip your current cooldown!"),
        effect=effect,
        effect_description=effect_description,
        cooldown_reduction_minutes=reduction_minutes,
        eligible_slots=BOOK_ELIGIBLE_SLOTS,
        can_purchase=True,
        purchase_product_id="com.kingdom.book_pack_5"
    )


# ============================================================
# WEBHOOK FOR APPLE SERVER NOTIFICATIONS (FUTURE)
# ============================================================
# Apple can send server-to-server notifications for:
# - Refunds
# - Subscription renewals
# - Subscription cancellations
#
# To enable this:
# 1. Configure the URL in App Store Connect
# 2. Add endpoint: POST /store/webhook/apple
# 3. Verify the JWS signature
# 4. Handle the notification type (REFUND, etc.)
#
# @router.post("/webhook/apple")
# async def apple_webhook(request: Request, db: Session = Depends(get_db)):
#     body = await request.body()
#     # Verify JWS signature
#     # Handle notification
#     pass
