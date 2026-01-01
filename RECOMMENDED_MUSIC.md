# Recommended Tracks for That Skyrim Vibe 🎵

## Ready-to-Use Tracks (Free & Legal!)

### 🏔️ For That "Whiterun Spawn" Ambient Feel

#### 1. **"Ancient Tales" by Adrian von Ziegler**
- **Where:** YouTube → Download via YouTube Audio Library
- **Vibe:** Peaceful Nordic ambience with lute and flute
- **Duration:** ~4 minutes
- **Perfect for:** Main exploration/background music
- **Link:** Search "Adrian von Ziegler Ancient Tales" on YouTube

#### 2. **"Tavern Music - Medieval" from Pixabay**
- **Where:** https://pixabay.com/music/
- **Search:** "medieval tavern"
- **Vibe:** Warm, welcoming, medieval atmosphere
- **Perfect for:** When player is in their kingdom/town
- **License:** Free, no attribution required

#### 3. **"Thatched Villagers" by Kevin MacLeod**
- **Where:** https://incompetech.com
- **Vibe:** Gentle, pastoral medieval life
- **Duration:** 3:34
- **Perfect for:** Peaceful gameplay moments
- **License:** Free with attribution (credit Kevin MacLeod)

#### 4. **"Frozen Star" by Kevin MacLeod**
- **Where:** https://incompetech.com
- **Vibe:** Cold, atmospheric, Nordic
- **Duration:** 2:36
- **Perfect for:** Outdoor exploration
- **License:** Free with attribution

#### 5. **"Celtic Impulse" by Kevin MacLeod**
- **Where:** https://incompetech.com
- **Vibe:** Mysterious, Celtic atmosphere
- **Duration:** 2:36
- **Perfect for:** Discovery/scouting moments
- **License:** Free with attribution

### ⚔️ For Battle/Action Moments

#### 1. **"Epic Battle" from Pixabay**
- **Where:** https://pixabay.com/music/
- **Search:** "epic battle medieval"
- **Vibe:** Intense, action-packed
- **Perfect for:** Invasion battles, raids
- **License:** Free, no attribution

#### 2. **"Achilles" by Kevin MacLeod**
- **Where:** https://incompetech.com
- **Vibe:** Epic, dramatic battle music
- **Perfect for:** Major conflicts
- **License:** Free with attribution

### 🏰 For Kingdom Management

#### 1. **"Meditation" from Purple Planet**
- **Where:** https://www.purple-planet.com
- **Vibe:** Calm, thoughtful
- **Perfect for:** Building, managing kingdom
- **License:** Free for non-commercial

## Quick Start: Single Track Setup

If you want to start simple, I recommend:

**"Thatched Villagers" by Kevin MacLeod**

1. Go to: https://incompetech.com/music/royalty-free/music.html
2. Search: "Thatched Villagers"
3. Download the MP3
4. Rename to: `ambient_background.mp3`
5. Add to Xcode (see MUSIC_SETUP.md)
6. Done! ✅

**Attribution:** Just add to your app's credits/about section:
```
Music: "Thatched Villagers" by Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
```

## Pro Setup: Multiple Tracks

Create different moods:

### Files to Add:
- `ambient_exploration.mp3` - Peaceful exploration (use "Ancient Tales")
- `ambient_town.mp3` - When in your kingdom (use "Thatched Villagers")
- `ambient_battle.mp3` - During conflicts (use "Achilles")
- `ambient_travel.mp3` - When traveling (use "Celtic Impulse")

### Code to Switch Tracks:

In your `MusicService.swift`, add:

```swift
enum MusicTrack: String {
    case exploration = "ambient_exploration.mp3"
    case town = "ambient_town.mp3"
    case battle = "ambient_battle.mp3"
    case travel = "ambient_travel.mp3"
    
    var volume: Float {
        switch self {
        case .exploration: return 0.25
        case .town: return 0.3
        case .battle: return 0.4
        case .travel: return 0.25
        }
    }
}

func playTrack(_ track: MusicTrack) {
    playBackgroundMusic(filename: track.rawValue, volume: track.volume)
}
```

Then use it anywhere:
```swift
// When entering your kingdom
musicService.playTrack(.town)

// When starting a battle
musicService.playTrack(.battle)

// When exploring
musicService.playTrack(.exploration)
```

## Skyrim-Specific Alternatives

If you want music that sounds VERY close to Skyrim:

### YouTube Channels (Download via converter, check licensing)
1. **Adrian von Ziegler** - Nordic/Celtic ambience
2. **Peter Gundry** - Medieval fantasy
3. **BrunuhVille** - Celtic/Fantasy
4. **Secession Studios** - Cinematic fantasy

### Note on YouTube Downloads
- Check each video's description for licensing
- Many artists allow free use with attribution
- Consider supporting them on Patreon if you use their music!

## Attribution Template

If using music that requires attribution, add this to your app's About/Credits screen:

```
🎵 Music Credits:

Background Music:
"[Track Name]" by [Artist Name]
Licensed under Creative Commons: By Attribution 4.0
[artist-website.com]

For more information: creativecommons.org/licenses/by/4.0
```

## File Size Tips

- Keep music files under 5 MB each for faster app load
- Use MP3 format at 128-192 kbps (good quality, small size)
- For ambient music, 128 kbps is usually fine
- For battle music, use 192 kbps for better quality

## My Top Pick for Your Game

**Start with "Ancient Tales" or "Thatched Villagers"**

Both give that perfect "peaceful medieval kingdom" vibe that Whiterun has. They're calming enough to loop for hours without getting annoying, but interesting enough to set the mood.

Download, add to Xcode, and you're good to go! 🎵⚔️



