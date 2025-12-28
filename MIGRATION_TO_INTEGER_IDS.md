# Migration: UUID Strings → PostgreSQL Auto-Increment Integers

## Summary

Changed user IDs from UUID strings (`"a1b2c3d4-..."`) to PostgreSQL auto-incrementing integers (`1, 2, 3, ...`).

## Why?

- **Cleaner**: Sequential integers are easier to work with
- **Efficient**: Smaller index size, faster joins
- **Conventional**: Standard database practice
- **Backend-controlled**: PostgreSQL generates IDs, not the application

## Changes Made

### Backend (Python/FastAPI)

**Models Updated:**
- `User.id`: `String` → `BigInteger` (auto-increment)
- `PlayerState.user_id`: `String` → `BigInteger` (foreign key)
- `Kingdom.ruler_id`: `String` → `BigInteger` (foreign key)
- `UserKingdom.user_id`: `String` → `BigInteger` (foreign key)
- `Contract.created_by`: `String` → `BigInteger` (foreign key)

**Service Functions:**
- `create_user_with_apple()`: Removed UUID generation, PostgreSQL auto-generates ID
- All `user_id` parameters changed from `str` → `int`

**Auth Flow (Already Correct):**
```python
# Routes get user from JWT token automatically
@router.post("/kingdoms")
def create_kingdom(
    current_user: User = Depends(get_current_user),  # From JWT!
    db: Session = Depends(get_db)
):
    # Just use current_user.id - no need to pass it around
    kingdom.ruler_id = current_user.id
```

### Frontend (iOS/Swift)

**Models Updated:**
- `Player.playerId`: `String` → `Int`
- `Kingdom.rulerId`: `String?` → `Int?`
- `UserData.id`: `String` → `Int`
- All API models: `ruler_id` changed to `Int?`

**Initialization:**
- `MapViewModel` fetches user from backend on init
- Sets `player.playerId` to backend's integer ID
- Syncs kingdoms based on integer comparison

## Database Migration

**Run this SQL to migrate your database:**

```bash
cd api/db
psql -U your_user -d kingdom_db -f migrate_to_integer_ids.sql
```

**⚠️ WARNING:** This migration **deletes all existing data**. Only run on development/fresh databases.

## How It Works Now

### User Creation Flow:
1. User signs in with Apple → Backend receives Apple ID
2. Backend creates `User` record (PostgreSQL auto-generates ID: `1, 2, 3...`)
3. Backend returns JWT with `user_id` in payload
4. Frontend receives JWT and stores it

### Kingdom Claiming Flow:
1. Frontend sends request with JWT token in header
2. Backend extracts `user_id` from JWT via `get_current_user` dependency
3. Backend sets `kingdom.ruler_id = current_user.id` (integer)
4. Frontend fetches kingdoms, compares `kingdom.rulerId == player.playerId` (both integers)

### Comparison Example:
```swift
// iOS
if kingdom.rulerId == player.playerId {  // 42 == 42 ✅
    // Show crown icon
}
```

```python
# Backend
if kingdom.ruler_id == current_user.id:  # 42 == 42 ✅
    # User is ruler
```

## Testing Checklist

After migration:

- [ ] Sign in with Apple creates user with integer ID
- [ ] Claim kingdom sets ruler_id correctly
- [ ] Kingdom shows you as ruler in UI
- [ ] "My Kingdoms" view shows claimed kingdoms
- [ ] Crown icon appears in player HUD
- [ ] Kingdom comparisons work (`rulerId == playerId`)

## Rollback

If needed, revert to UUID strings:
1. Restore database backup
2. Git revert the commits
3. Rebuild iOS app

## Files Changed

**Backend:**
- `api/db/models/user.py`
- `api/db/models/player_state.py`
- `api/db/models/kingdom.py`
- `api/db/models/contract.py`
- `api/services/auth_service.py`
- `api/db/migrate_to_integer_ids.sql` (new)

**Frontend:**
- `ios/.../Models/Player.swift`
- `ios/.../Models/Kingdom.swift`
- `ios/.../Services/AuthManager.swift`
- `ios/.../Services/API/Models/KingdomModels.swift`
- `ios/.../ViewModels/MapViewModel.swift`

