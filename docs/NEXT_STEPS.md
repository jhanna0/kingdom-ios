# Next Steps - Xcode Integration

## ⚠️ Important: Add New Files to Xcode

You need to add these 3 new Swift files to your Xcode project:

1. **CacheManager.swift**
2. **MapCache.swift**
3. **KingdomPersistence.swift**

### How to Add Them:

1. Open Xcode project: `/Users/jad/Desktop/kingdom/ios/KingdomApp/KingdomApp/KingdomApp.xcodeproj`

2. In Xcode, right-click on the `KingdomApp` folder (yellow folder icon)

3. Select **"Add Files to KingdomApp..."**

4. Navigate to and select:
   - `CacheManager.swift`
   - `MapCache.swift`
   - `KingdomPersistence.swift`

5. Make sure:
   - ✅ **"Copy items if needed"** is UNCHECKED (files already in place)
   - ✅ **"Add to targets"** has `KingdomApp` checked
   - ✅ **"Create groups"** is selected

6. Click **"Add"**

### Verify It Works:

After adding the files, build the project (⌘+B):
- ✅ Should build successfully with no errors
- ✅ All persistence features will be active

---

## What You Get

Once the files are added, your app will:

### 🎯 Persist Everything Between Sessions

- ✅ **Player Data**: Gold, level, XP, skills, kingdoms ruled
- ✅ **Kingdom State**: Rulers, upgrades, treasury, contracts
- ✅ **Progress**: Active contracts, check-ins, reputation

### 🚀 Faster Performance

- ✅ **Map Caching**: GeoJSON cached for 7 days
- ✅ **Kingdom Caching**: Loaded kingdoms cached for 24 hours
- ✅ **Instant Launch**: Saved state loads immediately

### 🔄 Smart State Merging

- ✅ **Preserves Progress**: Upgrades and claims survive app restarts
- ✅ **Allows Exploration**: New kingdoms can still be discovered
- ✅ **No Conflicts**: Existing kingdoms take priority over fresh loads

---

## Test It Out

1. **Add files to Xcode** (see above)
2. **Build and run** (⌘+R)
3. **Play the game**:
   - Claim a kingdom
   - Upgrade a building
   - Create a contract
4. **Close the app completely**
5. **Reopen the app**
6. **Verify**: Everything should be exactly as you left it! 🎉

---

## Troubleshooting

### If Build Fails:

1. Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
2. Make sure all 3 files are in target membership
3. Check file paths are correct in Xcode navigator

### If Data Doesn't Persist:

1. Check logs for "💾 Saved" messages
2. Verify files are in target (appear blue, not red, in Xcode)
3. Try: `CacheManager.shared.clearAll()` to reset and test fresh

### Reset Everything (for testing):

In your code or debug console:
```swift
CacheManager.shared.clearAll()
KingdomPersistence.shared.clearKingdoms()
viewModel.player.reset()
```

---

## Backend Migration Notes

All persistence code includes `// TODO:` comments marking what needs backend replacement:

### Player Endpoints Needed:
- `POST /auth/register` - Create account
- `POST /auth/login` - Login
- `GET /players/:id` - Fetch player data
- `PATCH /players/:id` - Update stats

### Kingdom Endpoints Needed:
- `GET /kingdoms?lat=X&lon=Y&radius=Z` - Fetch nearby kingdoms
- `PATCH /kingdoms/:id` - Update kingdom state
- `POST /kingdoms/:id/claim` - Claim kingdom
- `GET /kingdoms/:id/contracts` - Fetch contracts

### Contract Endpoints Needed:
- `POST /contracts` - Create contract
- `POST /contracts/:id/accept` - Accept contract
- `DELETE /contracts/:id/leave` - Leave contract

---

## Documentation

Full details in:
- `docs/CACHING_AND_PERSISTENCE.md` - Complete system documentation
- `docs/PERSISTENCE_SUMMARY.md` - Quick overview
- `docs/NEXT_STEPS.md` - This file

---

**Ready to test!** Just add the files to Xcode and run! 🚀





