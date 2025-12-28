# Sabotage & Espionage System

## Overview
Players can sabotage enemy kingdoms to gain tactical advantages. Detection is handled through an active patrol system where defenders must check in to guard their city.

---

## Sabotage Mechanics

### Requirements
- Building skill level 4+ unlocks sabotage ability
- Must be checked into target kingdom (physically present)
- Once per day per player (daily action limit)
- Costs 300g to attempt (always paid upfront)

### Sabotage Targets
1. **Walls** - Mark as damaged, requires repair contract
2. **Mine** - Mark as damaged, requires repair contract
3. **Market** - Mark as damaged, requires repair contract
4. **Vault** - Mark as damaged, requires repair contract
5. **Active Contract** - Delay completion by X hours (TBD)

### Sabotage Effects

**Damaged Buildings:**
- Building marked with `isDamaged: true` flag
- Produces at 0% efficiency while damaged
- Walls provide 0 defense while damaged
- Visual indicator: "🔥 DAMAGED" status in UI
- Cannot be upgraded while damaged
- Must be repaired before functioning

**Repair Process:**
- Ruler creates repair contract (similar to upgrade contracts)
- Repair cost: ~50% of building's upgrade cost
- Repair time: ~25% of upgrade time
- Once repaired, building functions normally

---

## Detection System (Patrol-Based)

### Patrol Mechanics
- Players with building skill 4+ can "Check In on Patrol"
- Patrol duration: 10 minutes
- Reward: +5 reputation per completed patrol
- Catch reward: +50 reputation + bounty gold

### Detection Formula
When sabotage is attempted:

```
For each active patrol (independent rolls):
    Base detection: 0.5%
    City size scaling: baseDetection / sqrt(totalActivePlayersInCity)
    Saboteur skill reduction: -0.05% per building skill level above 3
    
    Adjusted chance = max(0.001%, 
        (0.5% / sqrt(cityPopulation)) - (saboteurSkill - 3) × 0.05%)
    
    If random() < adjustedChance:
        CAUGHT by this patrol
        break
```

**Example Scaling:**

*Small city (25 active players):*
- Detection per patrol: 0.5% / 5 = 0.1%
- 5 patrols vs skill 4: ~5% total catch chance
- 10 patrols vs skill 4: ~10% total catch chance

*Medium city (100 active players):*
- Detection per patrol: 0.5% / 10 = 0.05%
- 20 patrols vs skill 4: ~10% total catch chance
- 50 patrols vs skill 4: ~22% total catch chance

*Large city (1000 active players):*
- Detection per patrol: 0.5% / 31.6 = 0.016%
- 50 patrols vs skill 4: ~8% total catch chance
- 200 patrols vs skill 4: ~28% total catch chance

*Huge city (10,000 active players):*
- Detection per patrol: 0.5% / 100 = 0.005%
- 100 patrols vs skill 4: ~5% total catch chance
- 500 patrols vs skill 10: ~18% total catch chance (skilled spies critical in big cities)

### Success vs. Getting Caught

**If Sabotage Succeeds:**
1. Target building/contract marked as damaged
2. Saboteur gains rewards:
   - +100 gold
   - +50 reputation in their HOME kingdom
3. No one knows who did it (anonymous)
4. Defender kingdom sees: "🔥 [Building] has been sabotaged!"

**If Caught:**
1. Saboteur added to kingdom's `bannedPlayers` set
2. Saboteur loses 200 reputation in that kingdom
3. Saboteur loses the 300g paid (no refund)
4. Patrol who caught them gets reward:
   - +50 reputation in their kingdom
   - +150 gold bounty (from kingdom treasury as reward)
5. Sabotage attempt fails (no damage)
6. Public announcement: "[Saboteur name] caught attempting sabotage by [Patrol name]!"

### Ban Enforcement
```swift
struct Kingdom {
    var bannedPlayers: Set<String> = []
    
    func canCheckIn(playerId: String) -> Bool {
        return !bannedPlayers.contains(playerId)
    }
}
```

Banned players:
- Cannot check in to kingdom
- Cannot participate in coups/invasions/contracts
- Cannot vote or perform any kingdom actions
- Ruler can manually unban (remove from set)

---

## Strategic Gameplay

### For Attackers
- Send high-skill saboteurs to enemy kingdoms
- Scout patrol schedules (attack during low-patrol hours like 3am)
- Sabotage walls before invasion - makes them 0% effective until repaired
- Sabotage mine/market to hurt enemy economy
- Risk: Getting caught = permanent exile from that kingdom
- Reward: Gold + reputation in home kingdom

### For Defenders
- Coordinate patrol schedules to cover peak hours (24/7 coverage)
- More active patrols = higher detection
- Reward patrol duty to encourage participation (pay citizens to patrol)
- Large active populations = naturally safer
- Prioritize repairing critical buildings (walls first if invasion threat)
- Monitor kingdom for sudden damage alerts
- Keep treasury reserves for emergency repairs

### Scaling
- Big cities (1000+ players, 100+ patrols) = very safe
- Small cities (10 players, 2-3 patrols) = vulnerable
- Naturally balanced by population size
- Skilled saboteurs can evade better

---

## Implementation Notes

### Data Models
```swift
// Player.swift
@Published var buildingSkill: Int = 1
@Published var lastSpyAction: Date?

// Kingdom.swift
var bannedPlayers: Set<String> = []

// Building damage tracking
var wallsDamaged: Bool = false
var mineDamaged: Bool = false
var marketDamaged: Bool = false
var vaultDamaged: Bool = false

// Patrol tracking
struct Patrol {
    let playerId: String
    let playerName: String
    let startTime: Date
    let expiresAt: Date  // startTime + 10 minutes
}

var activePatrols: [Patrol] = []

// Contract types
enum ContractType: String {
    case upgrade
    case repair  // New: for repairing sabotaged buildings
}

struct Contract {
    // ... existing fields ...
    let contractType: ContractType  // upgrade or repair
}
```

### Key Functions
- `attemptSabotage(target:)` - Execute sabotage with detection rolls
- `checkInOnPatrol()` - Start 10-minute patrol shift
- `getActivePatrols()` - Query patrols from last 10 minutes
- `banPlayer(_ playerId:)` - Add to banned set
- `unbanPlayer(_ playerId:)` - Remove from banned set (ruler only)
- `createRepairContract(building:)` - Create contract to repair damaged building (ruler only)
- `getBuildingEfficiency(building:)` - Returns 0% if damaged, 100% if working
- `getDamageStatus()` - Returns list of damaged buildings for UI display

---

## UI/UX for Kingdoms

### Damage Indicators
- Kingdom info shows damaged buildings with 🔥 icon
- "Walls: Level 3 🔥 DAMAGED - 0% effective"
- "Mine: Level 4 🔥 DAMAGED - No production"
- Red warning badge on kingdom marker

### Repair Contracts
- Appear in contract list as "REPAIR: [Building Name]"
- Cost: ~50% of upgrade cost
- Time: ~25% of upgrade time
- Priority display (show above upgrade contracts)
- Can't create upgrade contract while building is damaged

### Activity Feed
- "⚠️ Your Walls have been sabotaged!"
- "🎉 [Patrol Name] caught [Saboteur Name] attempting sabotage!"
- "✅ Walls repaired and fully operational"

---

## Balance Considerations

- Detection chance scales with defender activity (natural)
- Skilled saboteurs harder to catch (investment pays off)
- Sabotage once-per-day prevents spam
- Gold cost prevents casual griefing
- Patrol rewards encourage active defense
- Ban system provides consequence without permanent damage
- Damage stops building function (0% efficiency) - real tactical impact
- Repair costs time + gold - defenders must invest to fix
- Saboteurs rewarded with gold + home kingdom reputation
- Patrol catching saboteur gets bounty - makes patrol duty valuable
- Big cities harder to sabotage but not impossible
- Small cities vulnerable - encourages active population growth

