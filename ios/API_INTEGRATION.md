# Kingdom iOS App - API Integration

## ✅ Setup Complete!

Your iOS app now has a fully integrated API service that connects to your local backend.

---

## 📱 How to Use

### 1. Update the IP Address

Open `KingdomAPIService.swift` and update the IP address:

```swift
private let baseURL = "http://192.168.1.13:8000"  // Change to your Mac's IP
```

**To find your Mac's IP:** Run `ipconfig getifaddr en0` in Terminal

---

### 2. Start the API Server

On your Mac:

```bash
cd /Users/jad/Desktop/kingdom
docker-compose up -d
```

---

### 3. Test in the App

1. **Run the iOS app** on your iPhone (connected to same WiFi as Mac)
2. **Look for the green/gray dot** in the top-right of the HUD
   - 🟢 Green = Connected to API
   - ⚪ Gray = Not connected
3. **Tap the dot** to open the API Debug panel
4. **Test the endpoints** using the debug buttons

---

## 🎯 Features Integrated

### API Service (`KingdomAPIService.swift`)

Located in: `/Services/KingdomAPIService.swift`

**Available Methods:**
- `testConnection()` - Check API health
- `createPlayer()` - Create player on server
- `getPlayer()` - Fetch player data
- `updatePlayer()` - Sync player changes
- `createKingdom()` - Create kingdom on server
- `getKingdom()` - Fetch kingdom data
- `checkIn()` - Check-in with rewards
- `syncPlayer()` - Smart sync (create or update)
- `syncKingdom()` - Smart sync for kingdoms

### MapViewModel Integration

The `MapViewModel` now includes:
- `@Published var apiService` - Access to API service
- `syncPlayerToAPI()` - Sync player to backend
- `syncKingdomToAPI()` - Sync kingdom to backend
- `checkInWithAPI()` - Check-in with server rewards
- `testAPIConnection()` - Test connectivity

### UI Components

**API Debug View** (`/Views/Components/APIDebugView.swift`)
- Interactive testing panel
- Connection status indicator
- Quick test buttons for all endpoints
- Direct link to API docs

**Map View** - Added green/gray status dot in HUD
**Player HUD** - Can show API status and open debug panel

---

## 🔄 How to Sync Data

### Automatic Syncing (Coming Soon)

You can add automatic syncing by calling these methods at appropriate times:

```swift
// After player claims a kingdom
func claimKingdom() -> Bool {
    let success = // ... existing code
    if success {
        syncKingdomToAPI(kingdom)  // Sync to backend
    }
    return success
}

// When player data changes significantly
func addGold(_ amount: Int) {
    gold += amount
    syncPlayerToAPI()  // Sync to backend
}
```

### Manual Syncing

Use the API Debug view to manually test and sync:
1. Tap the status dot in the HUD
2. Use "Create Test Player" or "Create Test Kingdom"
3. Check "List All Players" to verify

---

## 🚀 Next Steps

### 1. Add Auto-Sync

Currently syncing is manual. Add calls to `syncPlayerToAPI()` and `syncKingdomToAPI()` after important actions:
- Kingdom claiming
- Building upgrades
- Check-ins
- Gold/XP changes

### 2. Load from Server on Launch

In `MapViewModel.init()`, add:

```swift
Task {
    do {
        // Try to load player from server
        let apiPlayer = try await apiService.getPlayer(id: player.playerId)
        player.gold = apiPlayer.gold
        player.level = apiPlayer.level
        // ... update other fields
    } catch {
        // Player doesn't exist yet, will sync on first action
        print("Player not on server yet")
    }
}
```

### 3. Real-time Multiplayer

When you're ready for multiplayer:
- Replace the in-memory storage in `api/main.py` with PostgreSQL queries
- Add WebSocket support for real-time updates
- Implement player location tracking
- Add kingdom player lists

### 4. Production Deployment

When ready to deploy:
- Update `baseURL` to your production server
- Add authentication (JWT tokens)
- Implement proper error handling
- Add retry logic for failed requests

---

## 📁 File Structure

```
/Services/
  - KingdomAPIService.swift          ← API service (NEW)
  - LocationManager.swift             ← Existing
  - KingdomPersistence.swift          ← Existing (will be replaced by API)
  - ...

/Views/Components/
  - APIDebugView.swift                ← Debug panel (NEW)
  - ...

/ViewModels/
  - MapViewModel.swift                ← Updated with API integration
```

---

## 🐛 Troubleshooting

### Can't Connect to API

1. **Check WiFi**: iPhone and Mac must be on same network
2. **Check IP**: Run `ipconfig getifaddr en0` and update `KingdomAPIService.swift`
3. **Check server**: Run `docker-compose ps` to verify containers are running
4. **Check firewall**: System Preferences → Security & Privacy → Firewall
5. **Test locally**: `curl http://localhost:8000` on your Mac

### API Returns Errors

1. **Check logs**: `docker-compose logs -f api`
2. **Restart API**: `docker-compose restart api`
3. **Check database**: `docker-compose ps` (db should be "healthy")

### Green Dot Never Appears

1. The dot shows in the top-right of the HUD (next to "Traveling")
2. It appears after the first connection test (1-2 seconds after app launch)
3. If gray, tap it to open debug panel and click "Test"

---

## 💡 Tips

1. **Keep Docker running** while developing - the API will automatically restart when you edit `api/main.py`
2. **Use the debug panel** to test endpoints before integrating them
3. **Check the API docs** at http://localhost:8000/docs for interactive testing
4. **Monitor logs** with `docker-compose logs -f api` to see what's happening

---

## 🎮 Current State

✅ **Working:**
- Local API server running
- iOS app can connect
- Debug panel for testing
- Basic CRUD for players and kingdoms
- Check-in endpoint with rewards

⏳ **Coming Soon:**
- Automatic syncing
- Load from server on launch
- Real-time multiplayer
- Production deployment

---

## Questions?

Check the main `API_SETUP.md` in the project root for server-side documentation.




