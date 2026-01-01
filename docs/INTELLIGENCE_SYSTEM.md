# Intelligence & Military Strength System

## Overview

The intelligence system transforms the map view from a static display into a strategic information warfare layer. Players can now:

1. **See their own kingdom's military strength** (always visible)
2. **Scout enemy kingdoms** to gather intelligence
3. **Make informed decisions** about attacks and defenses

---

## 🎯 Key Features

### 1. Military Strength Display

Every kingdom shows:
- **Walls** - Always visible (can be seen from outside)
- **Attack Power** - Total combat strength (if own kingdom or scouted)
- **Defense Power** - Total defensive strength (if own kingdom or scouted)
- **Active Citizens** - Players checked in within 24h
- **Population** - Total citizens

### 2. Intelligence Levels

Intelligence skill determines what info you can gather:

| Level | Info Revealed |
|-------|---------------|
| **T3** | Population estimate, active citizens |
| **T4** | + Patrol strength indicator |
| **T5** | + Total attack/defense power |
| **T6** | + Top 5 strongest players |
| **T7+** | + All building levels |

### 3. Intelligence Gathering

**Requirements:**
- Intelligence level 3+
- 500 gold (always paid upfront)
- Must be checked into target kingdom
- 24-hour cooldown
- Cannot target own kingdom

**Success Chance:**
```
Base: 40%
+ Intelligence bonus: +8% per level
- Patrol penalty: -5% per active patrol
- Vault penalty: -3% per vault level

Range: 10% - 90%
```

**On Success:**
- Reveal military stats (based on your intelligence level)
- Intel shared with your home kingdom (all citizens see it)
- Intel expires after 7 days
- +50 reputation in home kingdom

**On Failure (Caught):**
- Lose 500g
- Lose 200 reputation in target kingdom
- Temporarily banned (future: 48 hours)
- No intel gained

---

## 🎮 Gameplay Flow

### As an Attacker

1. **Scout the target** - Check neighboring kingdoms
2. **Gather intelligence** - Send scouts to get military stats
3. **Analyze strength** - Compare your attack vs their defense
4. **Plan the attack** - "We need 75 more attack to guarantee victory"
5. **Recruit allies** - Share intel with your kingdom
6. **Launch assault** - Once you have enough power

### As a Defender

1. **Monitor your strength** - Check your military stats regularly
2. **Run patrols** - Increase detection chance for enemy scouts
3. **Build walls** - Visible deterrent + actual defense
4. **Upgrade vault** - Makes it harder for spies to succeed
5. **Stay active** - More active citizens = more defense

---

## 📊 Database Schema

### `kingdom_intelligence` Table

```sql
CREATE TABLE kingdom_intelligence (
    id SERIAL PRIMARY KEY,
    kingdom_id VARCHAR NOT NULL,           -- Target kingdom
    gatherer_id INTEGER NOT NULL,          -- Who gathered this intel
    gatherer_kingdom_id VARCHAR NOT NULL,  -- Gatherer's home kingdom
    gatherer_name VARCHAR NOT NULL,
    
    -- Intelligence data (snapshot)
    wall_level INTEGER NOT NULL,
    total_attack_power INTEGER NOT NULL,
    total_defense_power INTEGER NOT NULL,
    active_citizen_count INTEGER NOT NULL,
    population_estimate INTEGER NOT NULL,
    treasury_estimate INTEGER,
    building_levels JSONB,
    top_players JSONB,
    
    -- Metadata
    intelligence_level INTEGER NOT NULL,
    gathered_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,         -- Intel expires after 7 days
    
    UNIQUE(kingdom_id, gatherer_kingdom_id)  -- One intel per kingdom pair
);
```

### `player_state` Table Update

```sql
ALTER TABLE player_state 
ADD COLUMN last_intelligence_action TIMESTAMP;
```

---

## 🔌 API Endpoints

### GET `/intelligence/military-strength/{kingdom_id}`

Get military strength information for a kingdom.

**Response (Own Kingdom):**
```json
{
  "kingdom_id": "ashford",
  "kingdom_name": "Ashford",
  "wall_level": 3,
  "total_attack": 150,
  "total_defense": 120,
  "total_defense_with_walls": 135,
  "active_citizens": 25,
  "population": 30,
  "is_own_kingdom": true,
  "has_intel": false
}
```

**Response (Enemy Kingdom with Intel):**
```json
{
  "kingdom_id": "bordertown",
  "kingdom_name": "Bordertown",
  "wall_level": 2,
  "total_attack": 80,
  "total_defense": 60,
  "total_defense_with_walls": 70,
  "active_citizens": 15,
  "population": 20,
  "is_own_kingdom": false,
  "has_intel": true,
  "intel_level": 5,
  "intel_age_days": 2,
  "gathered_by": "Alice"
}
```

**Response (Enemy Kingdom, No Intel):**
```json
{
  "kingdom_id": "stronghold",
  "kingdom_name": "Stronghold",
  "wall_level": 4,
  "is_own_kingdom": false,
  "has_intel": false
}
```

### POST `/intelligence/gather/{kingdom_id}`

Gather intelligence on an enemy kingdom.

**Success Response:**
```json
{
  "success": true,
  "caught": false,
  "message": "Successfully gathered intelligence on Bordertown!",
  "cost_paid": 500,
  "reputation_gained": 50,
  "detection_chance": 35.0,
  "intel_expires_in_days": 7,
  "intel_level": 5,
  "intel_data": {
    "wall_level": 2,
    "total_attack": 80,
    "total_defense": 60,
    "active_citizens": 15,
    "population": 20
  }
}
```

**Caught Response:**
```json
{
  "success": false,
  "caught": true,
  "message": "Caught gathering intelligence! Lost 500g and 200 reputation.",
  "cost_paid": 500,
  "reputation_lost": 200,
  "detection_chance": 45.0
}
```

---

## 📱 iOS Implementation

### New Models

**`Intelligence.swift`:**
- `MilitaryStrengthResponse` - API response
- `MilitaryStrength` - UI display model
- `GatherIntelligenceResponse` - Scout action result

### New API Methods

**`IntelligenceAPI.swift`:**
- `getMilitaryStrength(kingdomId:)` - Fetch military info
- `gatherIntelligence(kingdomId:)` - Scout enemy kingdom

### New UI Components

**`MilitaryStrengthCard.swift`:**
- Shows military strength for own kingdoms
- Shows scouted intelligence for enemy kingdoms
- Shows "gather intelligence" button for unscouted enemies
- Displays intel age and warning when expiring
- Shows combat assessment ("We could win!")

### Updated Views

**`KingdomDetailView.swift`:**
- Now shows `MilitaryStrengthCard` for every kingdom
- Automatically loads military strength when opened
- Handles intelligence gathering action

**`MapViewModel.swift`:**
- Caches military strength data: `militaryStrengthCache`
- `fetchMilitaryStrength(kingdomId:)` - Load strength info
- `gatherIntelligence(kingdomId:)` - Scout action

---

## 🎨 UI/UX Features

### Own Kingdom Display

```
┌─────────────────────────────────────┐
│ 🛡️ Military Strength               │
├─────────────────────────────────────┤
│ 🏛️ Walls       Level 3 (+15 defense)│
│ ⚡ Total Attack           150       │
│ 🛡️ Total Defense          135       │
│ 👥 Active Citizens         25       │
└─────────────────────────────────────┘
```

### Enemy Kingdom (No Intel)

```
┌─────────────────────────────────────┐
│ 👁️ Intelligence Report              │
├─────────────────────────────────────┤
│ 🏛️ Walls              Level 2       │
│                                     │
│        🚫 Intelligence Unknown       │
│                                     │
│   Send a scout to gather info       │
│                                     │
│  [🔭 Gather Intelligence (500g)]    │
│                                     │
│ Requirements:                       │
│ ✓ Intelligence level 3+             │
│ ✓ 500 gold                         │
│ ✗ Must check into Bordertown       │
└─────────────────────────────────────┘
```

### Enemy Kingdom (With Intel)

```
┌─────────────────────────────────────┐
│ 👁️ Intelligence Report   2 days ago │
├─────────────────────────────────────┤
│ 🔎 Intel by Alice                   │
│                                     │
│ 🏛️ Walls              Level 2       │
│ 👥 Population             ~20       │
│ 👤 Active Citizens         15       │
│ ⚡ Attack Power            80       │
│ 🛡️ Total Defense          70       │
│                                     │
│ ✅ We could win an attack!          │
│                                     │
│  [🔄 Update Intel (500g)]           │
└─────────────────────────────────────┘
```

---

## 🎲 Strategic Implications

### Information Asymmetry

- **Fog of War**: You don't know enemy strength by default
- **Scouting Value**: Intelligence gathering becomes essential
- **Counter-Intelligence**: Patrols catch enemy scouts
- **Intel Decay**: Must re-scout every 7 days

### Risk vs Reward

**Scouting:**
- Low risk (10-90% detection based on situation)
- High reward (crucial battle info)
- Cheap (500g per attempt)
- Team benefit (entire kingdom sees intel)

**Being Scouted:**
- Patrols increase detection
- Vaults provide security bonus
- Catching scouts grants reputation
- Walls always visible (deterrent)

### Attack Planning

Before: *"Let's just attack!"*  
After: *"Their defense is 70, we have 150 attack. We need 88 to win (70 × 1.25). We have 62 more than needed. High chance of success!"*

---

## 🚀 Setup Instructions

### 1. Run Database Migration

```bash
cd api
psql -U your_username -d kingdom_db -f db/add_kingdom_intelligence.sql
```

### 2. Restart Backend

```bash
cd api
uvicorn main:app --reload
```

### 3. Test API

```bash
# Get military strength (own kingdom)
curl http://localhost:8000/intelligence/military-strength/YOUR_KINGDOM_ID \
  -H "Authorization: Bearer YOUR_TOKEN"

# Gather intelligence (enemy kingdom)
curl -X POST http://localhost:8000/intelligence/gather/ENEMY_KINGDOM_ID \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. Build iOS App

The new files should be automatically detected by Xcode:
- `Models/Intelligence.swift`
- `Services/API/IntelligenceAPI.swift`
- `Views/Kingdom/MilitaryStrengthCard.swift`

If not, add them manually to your Xcode project.

---

## 🔮 Future Enhancements

### Phase 1 (Current)
- ✅ Military strength display
- ✅ Intelligence gathering
- ✅ Intel sharing with kingdom
- ✅ Patrol-based detection

### Phase 2 (Next)
- [ ] Temporary ban system (48h after being caught)
- [ ] Push notifications when caught scouting
- [ ] Intel feed (see all recent intel in kingdom)
- [ ] Spy counter (track how many times you've scouted)

### Phase 3 (Advanced)
- [ ] Counter-intelligence actions
- [ ] Fake intelligence (plant false info)
- [ ] Assassination attempts (remove ruler temporarily)
- [ ] Spy networks (coordinate with other spies)
- [ ] Information marketplace (sell intel to other kingdoms)

---

## 📈 Balance Considerations

### Detection Rates

Current formula provides:
- **High-level spy + no patrols + weak vault**: ~10-20% detection
- **Medium spy + some patrols + medium vault**: ~40-50% detection
- **Low-level spy + many patrols + strong vault**: ~70-80% detection

### Cost vs Benefit

- **500g cost** - Affordable but not trivial
- **24h cooldown** - Prevents spam but allows planning
- **7-day expiry** - Forces periodic re-scouting
- **+50 rep reward** - Encourages scouting for your kingdom

### Patrol Effectiveness

- Each patrol: -5% detection chance for enemy scouts
- 10 patrols = -50% detection (very effective)
- Encourages active defense
- Patrol duration: 10 minutes

---

## 🎉 Result

The map view is now **strategically useful**! Players can:

1. **Know their strength** - See own kingdom's military power
2. **Scout enemies** - Gather intel on potential targets
3. **Make decisions** - "Can we win this fight?"
4. **Coordinate attacks** - Share intel with kingdom
5. **Defend intelligently** - Run patrols to catch scouts

This creates the **information warfare layer** needed before implementing coups and invasions!



