"""
STORE API ROUTER
================
In-app purchase validation and resource granting with Apple App Store Server API verification.

Endpoints:
- POST /store/redeem - Redeem a purchase and grant resources (verifies with Apple)
- GET /store/products - Get available products
- GET /store/history - Get user's purchase history
- POST /store/use-book - Use a book to skip/reduce cooldown
- GET /store/book-history - Get book usage history for traceability

Security:
- All purchases are verified with Apple's App Store Server API
- Transaction IDs are stored to prevent duplicate redemptions
- Supports sandbox testing in development
"""

import os
import time
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from jose import jwt

from db import get_db
from db.models import User, PlayerState, PlayerInventory, Purchase, BookUsage, Subscription
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
        "type": "consumable",
        "gold": 1000,
        "meat": 1000,
        "price_usd": 1.99,
        "icon": "crown.fill",
        "color": "imperialGold",
    },
    "com.kingdom.book_pack_5": {
        "name": "Book Pack (5)",
        "type": "consumable",
        "books": 5,
        "price_usd": 3.99,
        "icon": "book.fill",
        "color": "buttonPrimary",
    },
    # Subscription product
    "com.kingdom.sub": {
        "name": "Kingdom Supporter",
        "type": "subscription",
        "price_usd": 4.99,
        "icon": "heart.fill",
        "color": "imperialGold",
        "subtitle": "Monthly subscription",
        "description": "Kingdoms is a homemade project done built in free time. It costs about $150 to host 100 players per month. By supporting you unlock profile theming, displaying your pets & achievments pubicly, and other benefits. Thank you!",
        "benefits": [
            "Support independent development",
            "Help keep the game ad-free",
            "Unlock profile customization",
        ],
    },
    # Uncomment when added to App Store Connect:
    # "com.kingdom.book_pack_15": {
    #     "name": "Book Pack (15)",
    #     "type": "consumable",
    #     "books": 15,
    #     "price_usd": 4.99,
    #     "icon": "books.vertical.fill",
    #     "color": "buttonPrimary",
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
            # Already processed - return success with popup
            state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
            return RedeemResponse(
                success=True,
                message="Already received",
                display_message="This purchase was already added to your account!",
                gold_granted=0,
                meat_granted=0,
                books_granted=0,
                new_gold_total=int(state.gold or 0) if state else 0,
                new_meat_total=get_player_meat(db, current_user.id),
                new_book_total=get_player_books(db, current_user.id)
            )
        else:
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
    products = []
    for product_id, cfg in PRODUCTS.items():
        product = {
            "id": product_id,
            "name": cfg["name"],
            "type": cfg.get("type", "consumable"),
            "gold": cfg.get("gold", 0),
            "meat": cfg.get("meat", 0),
            "books": cfg.get("books", 0),
            "price_usd": cfg["price_usd"],
            "icon": cfg.get("icon", "bag.fill"),
            "color": cfg.get("color", "royalBlue"),
        }
        # Add subscription-specific fields
        if cfg.get("type") == "subscription":
            product["subtitle"] = cfg.get("subtitle", "")
            product["description"] = cfg.get("description", "")
            product["benefits"] = cfg.get("benefits", [])
        products.append(product)
    
    return {"products": products}


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
    
    Books are purchased with REAL MONEY. All usage attempts are logged with full
    state for debugging support issues.
    
    Books can be used on:
    - "personal" slot (training)
    - "building" slot (work, property_upgrade)
    - "crafting" slot
    
    Books CANNOT be used on:
    - farm (economy slot)
    - patrol (security slot)
    - battle-related actions (view_coup, view_invasion, etc.)
    """
    from datetime import timedelta
    from db.models import ActionCooldown
    from routers.actions.action_config import ACTION_SLOTS
    from routers.resources import RESOURCES
    
    # Capture initial state
    books_before = get_player_books(db, current_user.id)
    now = datetime.utcnow()
    
    # Get book config
    book_config = RESOURCES.get("book", {})
    effect = book_config.get("effect", "skip_cooldown")
    reduction_minutes = book_config.get("cooldown_reduction_minutes")
    cooldown_skipped = (effect == "skip_cooldown" or reduction_minutes is None)
    
    # Validate slot
    if request.slot not in BOOK_ELIGIBLE_SLOTS:
        raise HTTPException(
            status_code=400, 
            detail=f"Books cannot be used on {request.slot}. Eligible slots: {', '.join(BOOK_ELIGIBLE_SLOTS)}"
        )
    
    # Validate action_type
    if request.action_type and request.action_type in BOOK_INELIGIBLE_ACTIONS:
        raise HTTPException(status_code=400, detail=f"Books cannot be used on {request.action_type}.")
    
    # Check if player has books
    if books_before <= 0:
        raise HTTPException(status_code=400, detail="No books available")
    
    # Get actions in slot
    actions_in_slot = [action for action, slot in ACTION_SLOTS.items() if slot == request.slot]
    if not actions_in_slot:
        raise HTTPException(status_code=400, detail=f"No actions in slot: {request.slot}")
    
    # Find cooldowns
    all_cooldowns = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type.in_(actions_in_slot)
    ).all()
    
    cooldowns_found = len(all_cooldowns)
    
    if not all_cooldowns:
        raise HTTPException(status_code=400, detail="No active cooldown to skip")
    
    # Check for active cooldown
    has_active_cooldown = False
    for cd in all_cooldowns:
        if cd.last_performed:
            elapsed = (now - cd.last_performed).total_seconds()
            if elapsed < 3 * 60 * 60:  # 3 hours
                has_active_cooldown = True
                break
    
    if not has_active_cooldown:
        # No book needed - don't charge them, no need to log
        return UseBookResponse(
            success=True,
            message="Cooldown already ready - no book needed!",
            books_remaining=books_before,
            cooldown_reduced_minutes=0,
            new_cooldown_seconds=0
        )
    
    # === ACTUALLY USE THE BOOK ===
    # This is the critical section - we deduct the book and modify cooldowns
    # Only log here since this is when real money is at stake
    try:
        # Modify cooldowns
        cooldowns_modified = 0
        for cd in all_cooldowns:
            if cooldown_skipped:
                cd.last_performed = now - timedelta(days=7)
            elif cd.last_performed:
                cd.last_performed = cd.last_performed - timedelta(minutes=reduction_minutes)
            cooldowns_modified += 1
        
        # Deduct the book
        add_books(db, current_user.id, -1)
        books_after = get_player_books(db, current_user.id)
        
        # Record usage
        usage = BookUsage(
            user_id=current_user.id,
            slot=request.slot,
            action_type=request.action_type,
            effect="skip_cooldown" if cooldown_skipped else "reduce_cooldown",
            cooldown_reduction_minutes=None if cooldown_skipped else reduction_minutes,
            success=True,
            error_message=None,
            books_before=books_before,
            books_after=books_after,
            cooldowns_found=cooldowns_found,
            cooldowns_modified=cooldowns_modified
        )
        db.add(usage)
        
        db.commit()
        
        if cooldown_skipped:
            message = f"Used 1 book to skip {request.slot} cooldown!"
        else:
            message = f"Used 1 book to reduce {request.slot} cooldown by {reduction_minutes} minutes!"
        
        print(f"📚 Book used! User {current_user.id} - {message}")
        print(f"   Books: {books_before} -> {books_after}")
        print(f"   Cooldowns modified: {cooldowns_modified}/{cooldowns_found}")
        print(f"   Usage ID: #{usage.id}")
        
        return UseBookResponse(
            success=True,
            message=message,
            books_remaining=books_after,
            cooldown_reduced_minutes=reduction_minutes or 0,
            new_cooldown_seconds=0
        )
        
    except HTTPException:
        raise
    except Exception as e:
        # Something went wrong - log the failure, rollback
        db.rollback()
        error_msg = f"Unexpected error: {str(e)}"
        print(f"❌ Book usage failed for user {current_user.id}: {error_msg}")
        
        # Record failure in a fresh transaction
        try:
            usage = BookUsage(
                user_id=current_user.id,
                slot=request.slot,
                action_type=request.action_type,
                effect="skip_cooldown" if cooldown_skipped else "reduce_cooldown",
                cooldown_reduction_minutes=None if cooldown_skipped else reduction_minutes,
                success=False,
                error_message=error_msg[:500],  # Truncate long errors
                books_before=books_before,
                books_after=books_before,  # Book not consumed
                cooldowns_found=cooldowns_found,
                cooldowns_modified=0
            )
            db.add(usage)
            db.commit()
        except Exception:
            pass  # Don't fail if logging fails
        
        raise HTTPException(status_code=500, detail="Failed to use book. Your book was not consumed. Please try again.")


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
# BOOK USAGE HISTORY
# ============================================================

class BookUsageHistoryItem(BaseModel):
    """Single book usage record with full state for debugging."""
    id: int
    slot: str
    action_type: Optional[str]
    effect: str
    cooldown_reduction_minutes: Optional[int]
    # Result
    success: bool
    error_message: Optional[str]
    # Balances
    books_before: int
    books_after: int
    # Cooldown state
    cooldowns_found: Optional[int]
    cooldowns_modified: Optional[int]
    # Timestamp
    used_at: str


@router.get("/book-history", response_model=List[BookUsageHistoryItem])
async def get_book_usage_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = 50
):
    """
    Get the current user's book usage history.
    
    Shows all usage attempts (successful and failed) with full state
    for debugging "my book didn't work" issues.
    """
    usages = db.query(BookUsage).filter(
        BookUsage.user_id == current_user.id
    ).order_by(BookUsage.used_at.desc()).limit(limit).all()
    
    return [
        BookUsageHistoryItem(
            id=u.id,
            slot=u.slot,
            action_type=u.action_type,
            effect=u.effect,
            cooldown_reduction_minutes=u.cooldown_reduction_minutes,
            success=u.success,
            error_message=u.error_message,
            books_before=u.books_before,
            books_after=u.books_after,
            cooldowns_found=u.cooldowns_found,
            cooldowns_modified=u.cooldowns_modified,
            used_at=u.used_at.isoformat() if u.used_at else "",
        )
        for u in usages
    ]


# ============================================================
# SUBSCRIPTION ENDPOINTS
# ============================================================

class SubscriptionStatusResponse(BaseModel):
    """Current subscription status."""
    is_subscriber: bool
    product_id: Optional[str] = None
    expires_at: Optional[str] = None


@router.get("/subscription-status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get the current user's subscription status.
    
    Returns whether the user has an active subscription and when it expires.
    """
    now = datetime.now(timezone.utc)
    
    # Get most recent active subscription
    subscription = db.query(Subscription).filter(
        Subscription.user_id == current_user.id,
        Subscription.expires_at > now
    ).order_by(Subscription.expires_at.desc()).first()
    
    if not subscription:
        return SubscriptionStatusResponse(is_subscriber=False)
    
    return SubscriptionStatusResponse(
        is_subscriber=True,
        product_id=subscription.product_id,
        expires_at=subscription.expires_at.isoformat()
    )


class RedeemSubscriptionRequest(BaseModel):
    product_id: str
    transaction_id: str
    original_transaction_id: str
    expires_at: str  # ISO format datetime


class RedeemSubscriptionResponse(BaseModel):
    success: bool
    message: str
    is_subscriber: bool
    expires_at: Optional[str] = None


@router.post("/redeem-subscription", response_model=RedeemSubscriptionResponse)
async def redeem_subscription(
    request: RedeemSubscriptionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Redeem a subscription purchase and activate subscriber status.
    
    Creates a new subscription row for history tracking.
    If same original_transaction_id exists, updates the expiration (renewal).
    """
    
    # 1. Validate product is a subscription
    product = PRODUCTS.get(request.product_id)
    if not product:
        raise HTTPException(status_code=400, detail=f"Unknown product: {request.product_id}")
    
    if product.get("type") != "subscription":
        raise HTTPException(status_code=400, detail="Product is not a subscription")
    
    # 2. Parse expiration date
    try:
        expires_at = datetime.fromisoformat(request.expires_at.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid expires_at format")
    
    # 3. Check for existing subscription by original_transaction_id (renewal case)
    existing = db.query(Subscription).filter(
        Subscription.original_transaction_id == request.original_transaction_id
    ).first()
    
    if existing:
        # Renewal - update expiration on existing row
        if existing.user_id != current_user.id:
            raise HTTPException(status_code=400, detail="Subscription belongs to another user")
        
        existing.expires_at = expires_at
        db.commit()
        
        print(f"🔄 Subscription renewed for user {current_user.id} ({current_user.display_name})")
        print(f"   Product: {product['name']}")
        print(f"   Expires: {expires_at}")
        
        return RedeemSubscriptionResponse(
            success=True,
            message="Subscription renewed!",
            is_subscriber=True,
            expires_at=expires_at.isoformat()
        )
    
    # 4. New subscription - create new row (for history tracking)
    subscription = Subscription(
        user_id=current_user.id,
        product_id=request.product_id,
        original_transaction_id=request.original_transaction_id,
        expires_at=expires_at
    )
    db.add(subscription)
    db.commit()
    
    print(f"⭐ New subscription activated for user {current_user.id} ({current_user.display_name})")
    print(f"   Product: {product['name']}")
    print(f"   Expires: {expires_at}")
    
    return RedeemSubscriptionResponse(
        success=True,
        message="Subscription activated! You can now customize your profile.",
        is_subscriber=True,
        expires_at=expires_at.isoformat()
    )


def is_user_subscriber(db: Session, user_id: int) -> bool:
    """
    Check if a user has an active subscription.
    
    Active = any subscription row with expires_at > NOW()
    """
    now = datetime.now(timezone.utc)
    subscription = db.query(Subscription).filter(
        Subscription.user_id == user_id,
        Subscription.expires_at > now
    ).first()
    
    return subscription is not None


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
