# Kingdom iOS - Clean Setup Guide

## ✅ Project Structure (CLEANED UP)

```
ios/
├── KingdomApp/
│   ├── KingdomApp.xcodeproj/     ← OPEN THIS IN XCODE
│   └── KingdomApp/                ← Source files
│       ├── Assets.xcassets/
│       ├── KingdomAppApp.swift
│       ├── ContentView.swift
│       ├── MapView.swift          ← Main map UI
│       ├── MapViewModel.swift     ← Map state
│       ├── Kingdom.swift          ← Data models
│       └── SampleData.swift       ← Kingdom generator
└── SETUP.md                       ← This file
```

## ✅ All Files Are Properly Referenced

All Swift files are correctly added to the Xcode project and will compile.

## 🚀 To Run the App

### 1. Open Xcode Project
```bash
open /Users/jad/Desktop/kingdom/ios/KingdomApp/KingdomApp/KingdomApp.xcodeproj
```

### 2. Add Location Permissions (REQUIRED)

**In Xcode:**
1. Click on the **KingdomApp** project (blue icon at top of sidebar)
2. Select **KingdomApp** target
3. Go to **Info** tab
4. Under "Custom iOS Target Properties", click the **+** button
5. Add these two entries:

| Key | Value |
|-----|-------|
| `Privacy - Location When In Use Usage Description` | `Kingdom needs your location to show nearby cities and enable check-ins.` |
| `Privacy - Location Always and When In Use Usage Description` | `Kingdom needs your location to notify you when you enter city boundaries.` |

### 3. Change Location (Optional but Recommended)

Edit `SampleData.swift` line 8 to your location:
```swift
static let defaultCenter = CLLocationCoordinate2D(
    latitude: YOUR_LATITUDE,  
    longitude: YOUR_LONGITUDE
)
```

Find your coordinates: https://www.latlong.net/

### 4. Build & Run
- Connect your iPhone or use simulator
- Click **Play** button (▶️) in Xcode
- Allow location permissions when prompted

## 🗺️ What You Should See

- **Map with 8 colored hexagonal kingdoms**
- **Castle markers** at kingdom centers
- **Tap any kingdom** to see ruler info, treasury, walls, etc.
- **Your blue dot** showing your location

## 🐛 Troubleshooting

**Still seeing "Hello World"?**
- Make sure ContentView.swift has `MapView()` not the default code
- Clean build: Cmd+Shift+K then rebuild

**Map not showing?**
- Check location permissions were added (step 2 above)
- Make sure you're running on device/simulator with location enabled

**Build errors?**
- All files should already be in the project
- Try Clean Build Folder: Cmd+Shift+K

## 📱 File Overview

| File | Purpose |
|------|---------|
| `KingdomAppApp.swift` | App entry point |
| `ContentView.swift` | Root view (shows MapView) |
| `MapView.swift` | Main map UI with territories |
| `MapViewModel.swift` | Map state management |
| `Kingdom.swift` | Kingdom & Territory data models |
| `SampleData.swift` | Generates sample kingdoms |

## ✅ Status
- [x] Project structure cleaned
- [x] All files properly referenced
- [x] No duplicate folders
- [x] No linter errors
- [x] Ready to build

**Just add location permissions (step 2) and you're good to go!**


