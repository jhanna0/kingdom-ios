# Music Setup Guide 🎵

## What I've Added

I've implemented a complete music system for your game with:

1. **MusicService.swift** - Handles all background music and sound effects
2. **MusicSettingsView.swift** - A settings panel where users can toggle music/SFX
3. **Integration** - Music controls in your HUD (music note icon next to the API status dot)

The music will:
- Start automatically when the app launches
- Loop continuously in the background
- Remember user preferences (if they turn it off)
- Fade in/out smoothly
- Mix with other audio (like phone calls, podcasts, etc.)

## Getting Skyrim-Style Music (Royalty-Free!)

Since we can't use actual Skyrim music due to copyright, here are great alternatives that sound very similar:

### Option 1: Free Music Archive (Best for Skyrim-like ambience)
**URL:** https://freemusicarchive.org

Search for:
- "medieval ambient"
- "fantasy ambient"
- "nordic ambient"
- "tavern music"

**Recommended Artists:**
- Adrian von Ziegler (YouTube: Nordic/Celtic ambience)
- Peter Gundry (YouTube: Medieval/Fantasy music)
- BrunuhVille (YouTube: Epic Celtic/Fantasy)

### Option 2: Incompetech (Royalty-Free, Attribution Required)
**URL:** https://incompetech.com

Search genres:
- "Ambient" 
- "World"

Good tracks:
- "Frozen Star"
- "Misty Mountain"
- "Thatched Villagers"

### Option 3: Pixabay Music (Totally Free, No Attribution)
**URL:** https://pixabay.com/music

Search for:
- "medieval"
- "fantasy"
- "ambient"

### Option 4: YouTube Audio Library (Free)
**URL:** https://studio.youtube.com/channel/UC.../music

Filter by:
- Genre: Ambient/Cinematic
- Mood: Calm/Dark/Inspirational

### Option 5: Purple Planet Music (Free for Non-Commercial)
**URL:** https://www.purple-planet.com

Great atmospheric tracks in the "Fantasy" and "Ambient" categories.

## How to Add Music to Your App

### Step 1: Download Your Music

1. Download music in `.mp3` or `.m4a` format
2. Keep file sizes reasonable (2-5 MB for background music)
3. Rename to something simple like: `ambient_background.mp3`

### Step 2: Add to Xcode

1. Open your project in Xcode
2. In the Project Navigator, right-click on the `KingdomApp` folder
3. Select **"Add Files to KingdomApp..."**
4. Select your music files
5. **IMPORTANT:** Make sure to check:
   - ✅ "Copy items if needed"
   - ✅ "Add to targets: KingdomApp"

### Step 3: Verify the File

1. Click on your music file in Xcode
2. In the right panel, check the "Target Membership"
3. Make sure `KingdomApp` is checked

### Step 4: Update the Filename (if needed)

In `KingdomAppApp.swift`, I set it to play `ambient_background.mp3`:

```swift
musicService.playBackgroundMusic(filename: "ambient_background.mp3", volume: 0.25)
```

If you name your file something else, update this line!

## Multiple Music Tracks

You can add different music for different situations:

```swift
// In MusicService, add these helper methods:
func playExplorationMusic() {
    playBackgroundMusic(filename: "ambient_exploration.mp3", volume: 0.25)
}

func playBattleMusic() {
    playBackgroundMusic(filename: "ambient_battle.mp3", volume: 0.4)
}

func playTownMusic() {
    playBackgroundMusic(filename: "ambient_town.mp3", volume: 0.3)
}
```

Then call them from anywhere in your app:
```swift
@EnvironmentObject var musicService: MusicService

// When entering battle
musicService.playBattleMusic()

// When in town
musicService.playTownMusic()
```

## Adding Sound Effects

You can add sound effects for actions:

```swift
// In your action completion handlers:
musicService.playSoundEffect(filename: "sword_clash.mp3", volume: 0.5)
musicService.playSoundEffect(filename: "coins.mp3", volume: 0.6)
musicService.playSoundEffect(filename: "level_up.mp3", volume: 0.7)
```

Great places to get free sound effects:
- **Freesound.org** (requires account, free)
- **Zapsplat.com** (requires account, free)
- **Mixkit.co** (no account needed)

## Testing Your Music

1. Build and run the app
2. You should hear music start immediately
3. Tap the music note icon in the HUD (top right) to open settings
4. Toggle music on/off to test

## Troubleshooting

### "Could not find music file"
- Check the filename matches exactly (including extension)
- Verify the file is in the Xcode project
- Check Target Membership is enabled

### Music not playing
- Check device volume isn't muted
- Check the silent switch on your phone
- Try increasing the volume parameter (0.0 to 1.0)

### Music sounds too loud/quiet
Change the volume in `KingdomAppApp.swift`:
```swift
musicService.playBackgroundMusic(filename: "ambient_background.mp3", volume: 0.15) // Quieter
```

## My Recommendations

For that **Whiterun ambient** feel, look for:
- **Slow, atmospheric tracks** (not epic battle music)
- **Nordic/Celtic instruments** (lute, fiddle, flute)
- **Nature sounds mixed in** (wind, birds)
- **3-10 minutes long** (so it doesn't loop too obviously)

Check out Adrian von Ziegler's "Moonsong" or "Ancient Tales" on YouTube - they're perfect and free to use with attribution!

## Current Music Controls

Your users can now:
- ✅ Toggle music on/off (persists across app restarts)
- ✅ Toggle sound effects on/off separately
- ✅ Access settings via the music note icon in the HUD
- ✅ Music plays automatically on app launch
- ✅ Music loops seamlessly

Enjoy your medieval soundtrack! 🎵⚔️👑



