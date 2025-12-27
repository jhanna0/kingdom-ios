# Kingdom iOS App

SwiftUI + MapKit implementation of the Kingdom GPS social power game.

## Quick Start

1. Open Xcode
2. Create a new iOS App project:
   - Product Name: `KingdomApp`
   - Interface: `SwiftUI`
   - Language: `Swift`
   
3. Replace the default files with these:
   - `KingdomApp.swift`
   - `ContentView.swift`
   - Create folders and add:
     - `Models/Kingdom.swift`
     - `Models/SampleData.swift`
     - `Views/MapView.swift`
     - `ViewModels/MapViewModel.swift`

4. Add `Info.plist` to your project (for location permissions)

5. **IMPORTANT:** Edit `Models/SampleData.swift` and change `defaultCenter` to your location:
   ```swift
   static let defaultCenter = CLLocationCoordinate2D(
       latitude: YOUR_LATITUDE,  // e.g., 34.0522
       longitude: YOUR_LONGITUDE // e.g., -118.2437
   )
   ```

6. Run on a real device (simulator works but won't show your real location as easily)

## What You'll See

- **Map View**: Shows 8 kingdoms around your area
- **Colored Territories**: Each kingdom has a hexagonal territory with unique color
- **Kingdom Markers**: Castle icons showing kingdom centers
- **Tap to View**: Tap any kingdom to see:
  - Ruler name
  - Treasury gold
  - Wall level (defenders)
  - Vault level (protection)
  - Checked-in players

## Project Structure

```
KingdomApp/
├── KingdomApp.swift          # App entry point
├── ContentView.swift         # Root view
├── Models/
│   ├── Kingdom.swift         # Kingdom + Territory data models
│   └── SampleData.swift      # Generate sample kingdoms (EDIT YOUR LOCATION HERE)
├── Views/
│   └── MapView.swift         # Main map UI with territories
└── ViewModels/
    └── MapViewModel.swift    # Map state management
```

## Features Implemented

✅ MapKit integration  
✅ Territory visualization (hexagonal borders)  
✅ Multiple kingdoms with unique colors  
✅ Kingdom info display  
✅ User location tracking  
✅ Interactive map controls  

## Next Steps

- [ ] Add check-in functionality (geofencing)
- [ ] Add room-based chat
- [ ] Add coup mechanics
- [ ] Add construction contracts
- [ ] Connect to backend API
- [ ] Add push notifications
- [ ] Add player list view

## Technical Notes

- Uses SwiftUI for modern iOS development
- MapKit for all map functionality
- Hexagonal territories for game-like appearance
- Color-coded kingdoms for easy differentiation
- Sample data generates 8 kingdoms in a grid pattern

## Customization

**Change Territory Shape:**
In `Models/SampleData.swift`, change:
```swift
let territory = Territory.hexagonal(center: center, radiusMeters: radius)
```
to:
```swift
let territory = Territory.circular(center: center, radiusMeters: radius)
```

**Change Kingdom Count/Names:**
Edit the `kingdomData` array in `SampleData.generateKingdoms()`

**Change Colors:**
Edit `KingdomColor` enum in `Models/Kingdom.swift`


