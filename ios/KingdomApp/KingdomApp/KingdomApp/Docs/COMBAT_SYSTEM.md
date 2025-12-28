# Combat System - Coups & Invasions

**Key Difference:**
- **Coups**: Internal rebellion - NO WALLS (already inside)
- **Invasions**: External siege - WALLS MATTER (attacking from outside)

---

## Coups (Internal Power Struggle)

### Flow
1. Player initiates coup (50g, needs 300+ rep in CURRENT kingdom)
2. Goes PUBLIC - 2 hour voting period
3. All active players in kingdom pick side: Attackers or Defenders
4. Battle resolves: `attackPower vs defensePower` (NO WALLS)
5. Attackers need 25% advantage to win

### Combat
```swift
attackerStrength = Σ attackers.attackPower
defenderStrength = Σ defenders.defensePower
// NO WALLS - internal rebellion

if attackerStrength > defenderStrength × 1.25 {
    // Attackers win - initiator becomes ruler
} else {
    // Defenders win - attackers punished
}
```

### Outcomes

**Attackers Win:**
- Initiator becomes ruler, +1000g, +50 rep
- **Old ruler's fate:** Coin flip based on % defender support
  - Support % = defenders / (attackers + defenders)
  - If flee succeeds: Ruler escapes with everything intact
  - If flee fails: Ruler loses EVERYTHING (all gold, -5 all stats, -200 rep)
- Old ruler gets "Couped Ruler" badge (permanent)

**Attackers Lose (HARSH):**
- Lose 100% gold (ruler takes it)
- Lose 100 reputation (traitor!)
- Lose ALL attack + defense stats (executed)
- Get "Traitor" badge (permanent shame)
- Publicly exposed

### Ruler Flee Mechanic
```
Example: 5 attackers, 5 defenders
Attackers win coup
Ruler flee chance = 5/10 = 50%
Roll: 0.43 → ESCAPED! ✅
Roll: 0.67 → CAPTURED! ❌ (lose everything)
```

---

## Invasions (External Conquest)

### Flow

**Phase 1: Ruler Declares War (Recruitment Period)**
```
1. Ruler declares intention to invade neighboring kingdom
2. Opens recruitment
3. Players must VISIT TARGET kingdom to sign up
4. Must be physically there (location-based)
5. Each signup pays 100g upfront
6. Minimum 10 signups required to launch
```

**Phase 2: Ruler Launches Attack (2-Hour Warning)**
```
1. Ruler decides to launch (once 10+ signups)
2. Goes PUBLIC to target kingdom - 2 hour warning
3. Target kingdom sees: "Kingdom A is invading in 2 hours!"
4. Defenders can check in and organize
```

**Phase 3: Battle**
```swift
attackerStrength = Σ attackers.attackPower
defenderStrength = Σ defenders.defensePower + (wallLevel × 5)

if attackerStrength > defenderStrength × 1.25 {
    // Attackers win - ruler takes city
}
```

### Why This Works
- **Physical presence required**: Must visit target city to sign up
- Ruler controls WHEN to invade (once enough signups)
- Target sees enemy forces gathering in their city (dramatic!)
- Can see army size before committing to launch
- Target gets 2-hour warning once launched
- Attackers already in position when battle starts

### Example Timeline
```
Day 1, 10am: Ruler declares intention to invade Bordertown
→ Recruitment opens

Day 1, 2pm: 5 attackers visit Bordertown, sign up (100g each)
→ Bordertown citizens see: "5 enemy forces gathering"
→ Not enough yet (need 10)

Day 1, 6pm: 8 attackers now in Bordertown
→ Still waiting for more

Day 2, 9am: 12 attackers have joined in Bordertown!
→ Can launch now

Ruler decides to launch:
→ 2-hour warning starts NOW
→ "12 attackers launching invasion! 2 hours!"

Day 2, 11am: Battle resolves
→ 12 attackers (already there) vs defenders + walls
```

### Outcomes

**Attackers Win:**
- Attacking ruler gains control of city (empire building!)
- **All attackers split treasury loot equally** (100g signup fee returned + share of treasury)
  - Example: Treasury has 5,000g, 10 attackers → 500g each
- **Empire bonus unlocked**: Each kingdom in empire adds +10% to ALL kingdom earnings
  - 2 kingdoms = 120% income per kingdom
  - 3 kingdoms = 130% income per kingdom
  - 5 kingdoms = 150% income per kingdom
- Walls damaged (-2 levels)
- Production damaged (mine -2 levels)
- +50 rep each (in their HOME kingdom, not conquered)

**Attackers Lose:**
- Lose 100g each (already paid)
- Lose 50 reputation
- -1 attack for 24h (wounded)
- 24h invasion cooldown
- Defenders get +100g, +30 rep each

---

## Key Mechanics

### Reputation & Coups
**Critical:** Need 300+ rep in CURRENT kingdom to start coup

**Why it matters:**
```
Bordertown (Kingdom A) gets conquered by Kingdom B
→ City now belongs to Kingdom B
→ Old citizens have 0 rep in Kingdom B
→ They CAN'T coup immediately (need 300 rep)
→ Must either:
  - Integrate (build rep over 3-4 weeks)
  - Leave (emigrate to Kingdom A city)
  - Wait for Kingdom A to invade back
```

**Prevents instant recoup exploit**
**Requires strong kingdom to hold conquered cities**

### Player Origin & Home
**Tracks where players are really from:**

```swift
struct Player {
    var originKingdomId: String?     // First kingdom they got 300+ rep in
    var homeKingdomId: String?       // Kingdom they check in to most
    var checkInHistory: [String: Int] // kingdomId -> total check-ins
    
    func getTrueKingdom() -> String? {
        // If they rule a city, that's their kingdom
        // Otherwise, their home (most check-ins)
    }
}
```

Shows coup leader's REAL allegiance (not just current location)

### Stats That Matter
- **Attack Power**: Offense in both coups and invasions
- **Defense Power**: Defense in both coups and invasions
- **Walls**: Only for INVASIONS (external attacks) - each level = +5 defense
- **Vault**: Protects % of treasury from looting (doesn't affect combat)

### Daily Action Limits
**Every action can only be done ONCE per day:**
- Mine resources (one collection per day)
- Work on crafting (one progress per day)
- Contribute to building upgrades (one contribution per day)
- Must be physically at kingdom location to perform actions

**Why no walls for coups?**
- Coups are INTERNAL rebellions
- Rebels are already inside the city
- Walls defend against external armies, not internal uprisings

### Empire Building
- One ruler can control multiple cities
- Conquered city → attacking ruler takes it
- Must defend all cities simultaneously
- Needs loyal citizens to occupy conquered territory

**Empire Income Bonus (Multiplicative):**
```
Each additional kingdom = +10% to ALL kingdoms in empire

1 kingdom:  100% income (base)
2 kingdoms: 120% income per kingdom (240% total)
3 kingdoms: 130% income per kingdom (390% total)
4 kingdoms: 140% income per kingdom (560% total)
5 kingdoms: 150% income per kingdom (750% total)
```

**Why subjects help conquer:**
- Immediate: Split enemy treasury (500g+ each)
- Long-term: Empire bonus means MORE income from reward distribution
- Status: +50 rep for conquest veterans

### Ruler Powers
**Tax Rates:**
- Ruler sets tax rate on mined resources (e.g., 10% of all iron/steel mined)
- Goes to kingdom treasury
- Too high = subjects leave or rebel

**Daily Quests:**
- Ruler can issue kingdom-wide objectives
- Examples: "Mine 100 total iron this week", "Craft 5 weapons", "Check in 7 days straight"
- Rewards paid from treasury (ruler's choice)
- Keeps subjects engaged and working toward kingdom goals

---

## Risk vs Reward

| Event | Cost | Win | Lose |
|-------|------|-----|------|
| **Coup (Attacker)** | 50g | Become ruler, +1000g, +50 rep | ALL gold, ALL stats, -100 rep, "Traitor" badge |
| **Coup (Ruler)** | - | Keep power | Flee % = defenders/(total). Fail = lose ALL, "Couped" badge |
| **Invasion (Sign up)** | 100g | Split treasury loot (500g+ each), +50 rep, empire +10% income bonus | -100g, -50 rep, -1 attack (24h) |

---

## Implementation (Swift)

**Files:**
- `Player.swift` - Has `attackPower`, `defensePower`, debuff tracking, origin/home tracking
- `Kingdom.swift` - Has `wallLevel`, `vaultLevel`, `treasuryGold`
- `CombatSystem.swift` - Combat resolution logic

**Key Structs:**
```swift
struct CoupEvent {
    let initiatorId: String
    let votingEndTime: Date  // 2 hours
    var attackers: [String]
    var defenders: [String]
}

struct InvasionEvent {
    let recruitmentStartTime: Date
    var signups: [String]  // Must be checked in to target
    var isLaunched: Bool
    var launchTime: Date?
    var rallyEndTime: Date?  // 2 hours after launch
    var defenders: [String]
}

class CombatResolver {
    static func resolveCoup(...) -> CoupResult
    static func resolveInvasion(...) -> InvasionResult
}
```

---

## Summary

- **Coups**: Internal, EXTREME risk (lose everything), initiator becomes ruler
- **Invasions**: External, HIGH risk (temp debuff), attacking ruler takes city
- **Both**: Pure PvP, attack vs defense, 2-hour warning, 25% advantage needed
- **Reputation**: Prevents instant recoup, requires integration or military reconquest
- **Strong Kingdoms**: Need loyal citizens to hold conquered territory
- **Empire Building**: One ruler can control multiple cities, each adds +10% income to ALL kingdoms
- **Subject Benefits**: Split treasury loot (500g+ each), empire income bonus, +50 rep for conquest

*For equipment, resources, and crafting: See EQUIPMENT_RESOURCES.md*
