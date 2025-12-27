# Getting Real Town Boundaries with GeoJSON

Your app now supports loading **REAL town/city boundaries** from GeoJSON files!

## 📥 Download Boundary Data

### Option 1: geoBoundaries (Recommended)
Visit: https://www.geoboundaries.org/globalDownloads.html

**For towns/cities**, download **ADM2 (Municipalities)**:
- Format: GeoJSON (easiest to use)
- Choose your country
- File will be named like: `geoBoundaries-USA-ADM2.geojson`

**Example downloads:**
- USA Municipalities: https://github.com/wmgeolab/geoBoundaries/raw/main/releaseData/gbOpen/USA/ADM2/geoBoundaries-USA-ADM2.geojson
- UK Districts: Similar pattern for other countries

### Administrative Levels:
- **ADM0**: Countries (too large)
- **ADM1**: States/Provinces (good for large areas)
- **ADM2**: Municipalities/Counties ✅ **Perfect for towns!**

## 🔧 How to Add to Your App

### 1. Download the GeoJSON file for your area
```bash
# Example: Download USA municipalities
curl -o municipalities.geojson \
  "https://github.com/wmgeolab/geoBoundaries/raw/main/releaseData/gbOpen/USA/ADM2/geoBoundaries-USA-ADM2.geojson"
```

### 2. Add to Xcode Project
1. In Xcode, right-click on "KingdomApp" folder
2. Select **"Add Files to KingdomApp..."**
3. Select your `municipalities.geojson` file
4. Make sure **"Copy items if needed"** is checked
5. Make sure your target is checked
6. Click **Add**

### 3. Add GeoJSONLoader.swift to Project
The file is already created at:
- `/Users/jad/Desktop/kingdom/ios/KingdomApp/KingdomApp/KingdomApp/GeoJSONLoader.swift`

Add it to Xcode:
1. Right-click "KingdomApp" folder
2. **"Add Files to KingdomApp..."**
3. Select `GeoJSONLoader.swift`
4. Click Add

### 4. Rebuild and Run
- Clean: **Cmd+Shift+K**
- Run: **Cmd+R**

## 🎯 What You'll See

Instead of circles, you'll see **ACTUAL town boundaries** as irregular polygons matching real municipal borders!

## 📝 Filtering to Your Area

The GeoJSON file contains ALL municipalities in a country. To filter to just your local area:

Edit `MapViewModel.swift` and add filtering:

```swift
// Filter kingdoms to only those near user
let nearbyKingdoms = foundKingdoms.filter { kingdom in
    let distance = SampleData.distanceBetween(location, kingdom.territory.center)
    return distance < 50000 // Within 50km
}
kingdoms = nearbyKingdoms
```

## 🌍 Alternative Sources

### OpenStreetMap (More detailed)
- Use Overpass API to query specific regions
- More current data
- Requires API calls

### US Census Bureau (USA only)
- https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html
- Very detailed municipal boundaries
- Free for USA

## 🔍 GeoJSON Structure

geoBoundaries files typically have this structure:
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "shapeName": "San Francisco",
        "shapeGroup": "USA",
        "shapeType": "ADM2"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[lon, lat], [lon, lat], ...]]
      }
    }
  ]
}
```

The `GeoJSONLoader` parses this automatically and creates Kingdom territories with real boundaries!

## ✅ Benefits

- ✅ Real town/city shapes (not circles!)
- ✅ Accurate boundaries
- ✅ Works offline (bundled in app)
- ✅ Free and open data
- ✅ Covers entire world

## 🚀 Next Steps

1. Download GeoJSON for your area
2. Add to Xcode project
3. Add GeoJSONLoader.swift to project
4. Rebuild
5. See real town boundaries! 🎉


