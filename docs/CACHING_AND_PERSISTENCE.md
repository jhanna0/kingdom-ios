# Caching and Persistence System

## Overview

The app now implements comprehensive caching and persistence to maintain game state between sessions. This is a **temporary solution** until the backend is implemented.

## Architecture

### 1. CacheManager (`CacheManager.swift`)
General-purpose file-based cache manager.

**Features:**
- Generic Codable object storage
- Cache expiration checking
- Cache size management
- Clear individual or all cached items

**Location:** `~/Library/Caches/KingdomCache/`

**TODO - Replace with Backend:**
- Not needed once backend handles data fetching/caching

---

### 2. MapCache (`MapCache.swift`)
Specialized cache for map data (kingdoms and GeoJSON).

**What it caches:**
- **Kingdoms by location**: Saves kingdoms for a specific coordinate + radius
  - Expires after: 24 hours
  - Used to avoid re-loading map data on every app launch
  
- **GeoJSON data**: Raw GeoJSON from URLs
  - Expires after: 7 days (geo boundaries rarely change)
  - Avoids re-downloading large GeoJSON files

**TODO - Replace with Backend:**
- `GET /kingdoms?lat=X&lon=Y&radius=Z` - Fetch kingdoms near location
- Backend should handle caching with proper ETags/Cache-Control headers

---

### 3. KingdomPersistence (`KingdomPersistence.swift`)
Handles persistent storage of kingdom **state** (upgrades, rulers, contracts, etc.).

**What it persists:**
- Kingdom ownership (who rules each kingdom)
- Building levels (walls, vault, mine, market)
- Treasury gold
- Active contracts and their progress
- Income history

**Key Feature: State Preservation**
When loading new kingdoms from GeoJSON, the app **merges** them with saved kingdoms to preserve state changes. This means:
- ✅ Upgrades you made are kept
- ✅ Contracts stay active
- ✅ Rulers remain in power
- ✅ New kingdoms can still be discovered

**TODO - Replace with Backend:**
- `GET /kingdoms` - Fetch all kingdoms with current state
- `PATCH /kingdoms/:id` - Update kingdom state (upgrades, etc.)
- `POST /kingdoms/:id/claim` - Claim a kingdom
- `GET /kingdoms/:id/contracts` - Fetch active contracts
- Backend becomes source of truth for all kingdom state

---

### 4. Player Persistence (`Player.swift`)
Uses `UserDefaults` to save player data.

**What it persists:**
- Player identity (ID, name)
- Stats (gold, level, XP, skills)
- Territory (kingdoms ruled)
- Contracts (active contract ID, completed count)
- Reputation (global + per-kingdom)
- Check-in status
- Cooldowns (coup attempts, daily check-ins)

**TODO - Replace with Backend:**
- `POST /auth/register` - Create player account
- `POST /auth/login` - Login (get player ID)
- `GET /players/:id` - Fetch player data
- `PATCH /players/:id` - Update player stats
- `POST /players/:id/checkin` - Check in to kingdom
- Backend validates all state changes (prevent cheating)

---

## How It Works

### App Launch Flow

```
1. MapViewModel.init()
   ├─ Player loads from UserDefaults (instant)
   └─ loadPersistedKingdoms() loads saved kingdoms (instant)
   
2. LocationManager gets user location
   └─ MapViewModel.updateUserLocation()
   
3. First location received
   └─ loadRealTowns()
       ├─ Check MapCache for kingdoms near location
       ├─ If cache hit: Load from cache (instant)
       ├─ If cache miss: Fetch from GeoJSON
       └─ Merge with persisted kingdoms (preserve state)
       
4. Kingdom state changes (upgrades, claims, etc.)
   └─ kingdoms array updated
       └─ didSet triggers saveKingdomsToStorage()
```

### State Preservation Strategy

When new kingdoms are loaded (from cache or network), they're **merged** with existing kingdoms:

```swift
for newKingdom in loadedKingdoms {
    if existingKingdom = find(by: name) {
        keep existingKingdom  // ✅ Preserves all state
    } else {
        add newKingdom       // 🆕 New discovery
    }
}
```

This ensures:
- Player upgrades persist
- Ruler claims persist  
- Active contracts continue
- New areas can still be explored

---

## Storage Locations

| Data | Location | Format |
|------|----------|--------|
| Player data | `UserDefaults` | Individual keys |
| Kingdom state | `~/Library/Caches/KingdomCache/kingdoms_local_state` | JSON |
| Map cache | `~/Library/Caches/KingdomCache/kingdoms_X_Y_Z` | JSON |
| GeoJSON cache | `~/Library/Caches/KingdomCache/geojson_HASH` | JSON |

---

## Cache Management

### Clear Cache Commands (for testing)

```swift
// Clear all cached data
CacheManager.shared.clearAll()

// Clear specific caches
MapCache.shared.clearKingdomsCache()
KingdomPersistence.shared.clearKingdoms()

// Check cache size
print(CacheManager.shared.formattedCacheSize())
```

### Cache Expiration

| Cache Type | Expiration | Reason |
|-----------|-----------|--------|
| Kingdoms by location | 24 hours | Daily updates reasonable |
| GeoJSON data | 7 days | Geo boundaries rarely change |
| Kingdom state | Never (until cleared) | Persistent game state |
| Player data | Never (until cleared) | Persistent character data |

---

## Backend Migration Plan

### Phase 1: Authentication
- Replace `Player.playerId` generation with backend auth
- Add login/register flow
- Store auth token for API calls

### Phase 2: Player Data Sync
- Replace `Player.saveToUserDefaults()` with `API.updatePlayer()`
- Replace `Player.loadFromUserDefaults()` with `API.fetchPlayer()`
- Keep UserDefaults as offline cache only

### Phase 3: Kingdom Data Sync
- Replace `KingdomPersistence` with API calls
- Backend becomes source of truth
- Local cache becomes read-only (for offline mode)

### Phase 4: Real-time Updates
- Add WebSocket/SSE for live updates
- Kingdom changes broadcast to all players
- Contract progress updates in real-time

### Phase 5: Multiplayer Validation
- Backend validates all state changes
- Prevent client-side cheating
- Server-authoritative game logic

---

## Known Limitations (Pre-Backend)

⚠️ **Current Issues:**

1. **No Sync Between Devices**
   - Data is local only
   - Can't share progress across devices

2. **No Multiplayer**
   - Other players aren't real
   - No real-time updates

3. **Easy to Cheat**
   - All game logic runs client-side
   - Can modify UserDefaults/cache files

4. **Data Loss Possible**
   - Clearing app data = lose everything
   - No backup/restore

5. **Stale Data**
   - Can't see other players' actions
   - Kingdom state only updates locally

✅ **What Works Well:**

1. **State Preservation**
   - Upgrades, claims, contracts persist
   - No data loss on app restart

2. **Performance**
   - Fast app launch (cached data)
   - Reduced network requests

3. **Offline Capable**
   - Can play without internet (after initial load)

---

## Testing

### Test Cache Behavior

```swift
// Test 1: App restart preserves state
1. Claim a kingdom
2. Upgrade a building
3. Close app
4. Reopen app
✅ Kingdom still claimed, building still upgraded

// Test 2: Cache expiration
1. Load kingdoms
2. Manually set cache timestamp to 25 hours ago
3. Reopen app
✅ Kingdoms reload from network

// Test 3: State merge
1. Have claimed kingdoms
2. Move to new location
3. Load new kingdoms
✅ Old kingdoms + new kingdoms both present
```

### Reset All Data (Clean Slate)

```swift
// In your code or debug console:
CacheManager.shared.clearAll()
KingdomPersistence.shared.clearKingdoms()
player.reset()
```

---

## File Summary

| File | Purpose | Backend Replacement |
|------|---------|---------------------|
| `CacheManager.swift` | Generic cache | HTTP caching layer |
| `MapCache.swift` | Map data cache | API response caching |
| `KingdomPersistence.swift` | Kingdom state | `GET/PATCH /kingdoms` |
| `Player.swift` (persistence) | Player data | `GET/PATCH /players/:id` |
| `MapViewModel.swift` (auto-save) | State management | API sync layer |

---

## Summary

✅ **What's Implemented:**
- Full local persistence of player and kingdom state
- Smart caching to reduce network requests
- State preservation across app restarts
- Merge strategy to keep state while discovering new areas

🔄 **What Needs Backend:**
- Authentication & account management
- True multiplayer (seeing other players' actions)
- Server-authoritative game logic
- Cross-device sync
- Anti-cheat validation

📝 **Bottom Line:**
You can now play the game, close the app, and come back without losing progress! Once backend is added, these local caching systems will become offline caches with the backend as the source of truth.





