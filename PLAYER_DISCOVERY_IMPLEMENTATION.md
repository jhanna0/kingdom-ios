# Player Discovery & Social Features Implementation

## Overview

Added comprehensive player discovery and social features to make the game feel more alive and multiplayer-focused. Players can now see who's in their kingdom, what they're doing, and view detailed profiles of other players.

## What Was Added

### 🎯 Backend API (Python/FastAPI)

#### New Endpoints (`/api/routers/players.py`)

1. **GET `/players/in-kingdom/{kingdom_id}`**
   - Lists all players currently in a specific kingdom
   - Shows their current activity (working, patrolling, training, crafting, etc.)
   - Indicates who's online (active in last 5 minutes)
   - Highlights the ruler with a crown
   - Returns: `PlayersInKingdomResponse`

2. **GET `/players/active`**
   - Gets recently active players (logged in within last hour)
   - Optional `kingdom_id` filter
   - Sorted by most recent activity
   - Returns: `ActivePlayersResponse`

3. **GET `/players/{user_id}/profile`**
   - Public profile for any player
   - Shows stats, equipment, achievements, current activity
   - Does NOT expose private data (gold, resources)
   - Returns: `PlayerPublicProfile`

#### Activity Detection System

The backend automatically detects what players are doing:
- **Patrolling** - If patrol is active
- **Training** - If training contract in progress
- **Crafting** - If crafting contract in progress
- **Working** - If worked in last 2 minutes
- **Scouting** - If scouted in last 2 minutes
- **Sabotage** - If sabotaged in last 2 minutes
- **Idle** - Default state

#### New Schemas (`/api/schemas/player.py`)

- `PlayerActivity` - Current activity with type, details, expiration
- `PlayerEquipment` - Weapon and armor data
- `PlayerPublicProfile` - Full public profile
- `PlayerInKingdom` - Condensed info for lists
- `PlayersInKingdomResponse` - Kingdom player list response
- `ActivePlayersResponse` - Active players response

### 📱 iOS Client (Swift/SwiftUI)

#### New Models (`PlayerDiscoveryModels.swift`)

- `PlayerActivity` - With display helpers (icon, color, text)
- `PlayerEquipmentData` - Equipment info
- `PlayerPublicProfile` - Full profile model
- `PlayerInKingdom` - List item model
- Response models for API calls

#### New API Methods (`PlayerAPI.swift`)

```swift
func getPlayersInKingdom(_ kingdomId: String) async throws -> PlayersInKingdomResponse
func getActivePlayers(kingdomId: String?, limit: Int) async throws -> ActivePlayersResponse
func getPlayerProfile(userId: Int) async throws -> PlayerPublicProfile
```

#### Refactored Components

Created reusable UI components from `CharacterSheetView`:

1. **`ProfileHeaderCard`** - Name, level, XP bar
   - Can hide XP bar for other players
   - Reusable across own profile and others

2. **`ReputationStatsCard`** - Reputation tier, abilities
   - Optional honor display
   - Can hide detailed abilities for other players

3. **`CombatStatsCard`** - Attack, defense, leadership, building, intelligence
   - Shows equipment bonuses
   - Optional interactive mode (for training)
   - Non-interactive for viewing others

4. **`EquipmentStatsCard`** - Weapon and armor display
   - Shows tier and bonuses
   - Optional interactive mode (for crafting)
   - Non-interactive for viewing others

#### New Views

1. **`PlayersListView`**
   - Shows all players in your current kingdom
   - Real-time activity indicators
   - Online/offline status (green dot)
   - Ruler highlighted with crown
   - Stats preview (attack, defense)
   - Tap any player to view their profile
   - Pull to refresh

2. **`PlayerProfileView`**
   - Full public profile for any player
   - Uses refactored components
   - Shows location and current activity
   - Combat stats and equipment
   - Achievements (kingdoms ruled, coups won, etc.)
   - Clean, parchment-themed medieval UI

3. **`PlayerRowCard`**
   - Compact player card for lists
   - Avatar circle with first initial
   - Online indicator
   - Activity icon and text
   - Stats preview
   - Ruler crown badge

#### UI Integration

- Added **Players button** to `MapHUD` (purple icon with 3 people)
- Opens `PlayersListView` as a sheet
- Positioned between Properties and Activity buttons
- Consistent with existing medieval theme

## Features

### 🎮 Player Discovery

**See who's around:**
- View all players in your kingdom
- See who's online right now
- Check what everyone is doing
- Identify the ruler at a glance

**Activity Tracking:**
- 🔨 Working on construction
- 🚶 Patrolling the kingdom
- 💪 Training skills
- ⚒️ Crafting equipment
- 👁️ Gathering intelligence
- ⚠️ Sabotaging enemies
- ⭕ Idle

### 👤 Player Profiles

**View detailed profiles:**
- Level and reputation tier
- Combat stats (attack, defense, leadership, building, intelligence)
- Equipped weapon and armor
- Current location and activity
- Achievements:
  - Kingdoms ruled
  - Coups won
  - Total check-ins
  - Contracts completed
  - Total conquests

**Privacy:**
- Only public data is shown
- No access to gold, resources, or private info
- Can't see training/crafting costs

### 🎨 UI/UX

**Medieval Theme:**
- Parchment backgrounds
- Gold accents
- Medieval icons
- Consistent with existing design

**Smooth Experience:**
- Loading states
- Error handling with retry
- Pull to refresh
- Haptic feedback
- Smooth animations

## Benefits

### For Players

1. **Social Connection** - See who else is playing
2. **Competition** - Compare stats with others
3. **Strategy** - Scout potential allies/enemies
4. **Engagement** - Game feels more alive and multiplayer

### For Game Design

1. **Transparency** - Players can see kingdom activity
2. **Community** - Encourages player interaction
3. **Rivalry** - Natural competition emerges
4. **Retention** - Social features increase engagement

## Technical Details

### Performance

- **Efficient queries** - Only fetches necessary data
- **Online detection** - Based on last login (5 min threshold)
- **Activity caching** - Uses existing player state data
- **Pagination ready** - Limit parameter for scaling

### Security

- **Authentication required** - All endpoints protected
- **Public data only** - No sensitive info exposed
- **Rate limiting ready** - Can add if needed

### Scalability

- **Database indexed** - Fast lookups by kingdom_id
- **Efficient joins** - Minimal query overhead
- **Ready for caching** - Can add Redis if needed

## Usage

### As a Player

1. **Open the map**
2. **Tap the Players button** (purple icon with 3 people)
3. **See all players** in your current kingdom
4. **Tap any player** to view their full profile
5. **Compare stats** and see what they're doing

### As a Developer

**Backend:**
```python
# Get players in a kingdom
GET /players/in-kingdom/boston-ma

# Get active players globally
GET /players/active?limit=50

# Get active players in specific kingdom
GET /players/active?kingdom_id=boston-ma&limit=50

# Get player profile
GET /players/123/profile
```

**iOS:**
```swift
// Get players in kingdom
let players = try await KingdomAPIService.shared.player.getPlayersInKingdom("boston-ma")

// Get player profile
let profile = try await KingdomAPIService.shared.player.getPlayerProfile(userId: 123)

// Show players list
PlayersListView(player: player)

// Show player profile
PlayerProfileView(userId: 123)
```

## Future Enhancements

### Potential Additions

1. **Friend System** - Add/remove friends
2. **Direct Messages** - Private chat between players
3. **Player Search** - Search by name
4. **Leaderboards** - Top players by stat
5. **Activity Feed** - Real-time activity stream
6. **Player Badges** - Achievements and titles
7. **Block/Report** - Moderation tools
8. **Online Notifications** - "Player X is online"
9. **Last Seen** - "Active 2 hours ago"
10. **Player Alliances** - Formal player groups

### Easy Wins

- Add player count to kingdom info sheet
- Show online players on map (dots?)
- Add "Recently Played With" section
- Show mutual kingdoms/properties

## Files Changed/Added

### Backend
- ✅ `api/routers/players.py` - New router
- ✅ `api/schemas/player.py` - New schemas
- ✅ `api/main.py` - Register router
- ✅ `api/routers/__init__.py` - Export router
- ✅ `api/schemas/__init__.py` - Export schemas

### iOS
- ✅ `Services/API/Models/PlayerDiscoveryModels.swift` - New models
- ✅ `Services/API/PlayerAPI.swift` - New methods
- ✅ `Views/Players/PlayersListView.swift` - New view
- ✅ `Views/Players/PlayerProfileView.swift` - New view
- ✅ `Views/Character/Components/ProfileHeaderCard.swift` - New component
- ✅ `Views/Character/Components/ReputationStatsCard.swift` - New component
- ✅ `Views/Character/Components/CombatStatsCard.swift` - New component
- ✅ `Views/Character/Components/EquipmentStatsCard.swift` - New component
- ✅ `Views/Character/CharacterSheetView.swift` - Refactored to use components
- ✅ `Views/Components/MapHUD.swift` - Added Players button
- ✅ `Views/Map/MapView.swift` - Wire up Players sheet

## Testing

### Backend Testing

```bash
# Test player list endpoint
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/players/in-kingdom/boston-ma

# Test player profile
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/players/123/profile

# Test active players
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/players/active?limit=10
```

### iOS Testing

1. Run the app
2. Check in to a kingdom
3. Tap the Players button (purple icon)
4. Verify player list loads
5. Tap a player to view profile
6. Verify stats and equipment display correctly
7. Test with multiple players in same kingdom

## Summary

This implementation adds crucial social features that make the multiplayer aspect of the game visible and engaging. Players can now:

- **Discover** other players in their kingdom
- **See** what everyone is doing in real-time
- **Compare** stats and equipment
- **Connect** with the community

The refactored components make the codebase cleaner and more maintainable, while the new views provide a polished, medieval-themed experience consistent with the rest of the game.

**Result:** The game now feels like a living, breathing multiplayer world! 🎮👥

