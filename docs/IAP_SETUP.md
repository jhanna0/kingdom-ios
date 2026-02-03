# In-App Purchases Setup

## Server-Driven Design

The store is **fully server-driven**. To add new products:

1. Add product to `PRODUCTS` dict in `api/routers/store.py`
2. Create matching product in App Store Connect
3. Deploy - iOS app will automatically show the new product

No iOS app update required for new products.

## Current Products

| Product ID | Name | Price | Contents |
|------------|------|-------|----------|
| `com.kingdom.starter_pack` | Starter Pack | $2.99 | 1,000 Gold + 1,000 Meat |
| `com.kingdom.book_pack_5` | Book Pack (5) | $3.99 | 5 Books |

**Books**: Non-tradeable item that reduces training/building cooldown by 1 hour per use.

## App Store Connect Setup

### 1. Create Products

1. Go to App Store Connect → Your App → Monetization → In-App Purchases
2. Create 3 **Consumable** products with the IDs above
3. Set prices and localized descriptions

### 2. Generate API Key (for server verification)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Users and Access → Keys → App Store Connect API (or "In-App Purchase" tab)
3. Click + to generate a new key with "In-App Purchase" access
4. Download the `.p8` file (only available once!)
5. Note the **Key ID** (shown in the table) and **Issuer ID** (shown at top of page)

If you can't find it, the server verification is optional - StoreKit 2 does client-side verification. You can skip the `APPLE_*` env vars and it will work in dev mode.

## Backend Setup

### Environment Variables

```bash
APPLE_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
APPLE_KEY_ID=XXXXXXXXXX
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
APPLE_BUNDLE_ID=com.kingdom.app
```

### Database Migration

```bash
psql $DATABASE_URL -f api/db/add_iap_purchases.sql
```

## API Endpoints

- `POST /store/redeem` - Redeem purchase, grant resources
- `GET /store/products` - List products
- `GET /store/history` - Purchase history
- `POST /store/use-book` - Use a book to reduce cooldown
- `GET /store/books` - Get book count

## Files

- `api/routers/store.py` - Store endpoints
- `api/db/models/purchase.py` - Purchase model
- `api/db/add_iap_purchases.sql` - Migration
- `api/routers/resources.py` - Book resource definition
- `ios/.../Services/StoreService.swift` - StoreKit 2 client
- `ios/.../Views/Store/StoreView.swift` - Store UI
