# Conquered Citizens & Kingdom Loyalty

## The Problem

When a city is conquered:
```
Kingdom A rules "Bordertown"
→ Kingdom B invades and conquers "Bordertown"
→ "Bordertown" now belongs to Kingdom B
→ Old Kingdom A citizens are still there
→ Can they immediately coup and take it back? 🤔
```

If yes → invasions are pointless (immediate recoup)
If no → how do we prevent it?

---

## The Solution: Kingdom-Based Reputation

**Core Rule: You need 300+ reputation in the CURRENT kingdom to start a coup**

### How It Works

```swift
// Coup requirement check
func canProposeCoup(inKingdom currentKingdomId: String) -> Bool {
    let repInCurrentKingdom = getKingdomReputation(currentKingdomId)
    return repInCurrentKingdom >= 300  // Must have rep in THIS kingdom
}

// When city is conquered
city.kingdomId = attackingKingdomId  // City changes kingdoms

// Old citizens still have their old kingdom rep
// But have 0 rep in the NEW kingdom
// Therefore can't start coups!
```

### Example Timeline

```
DAY 1: Normal Rule
- "Bordertown" belongs to Kingdom A
- Bob: 350 rep in Kingdom A ✅
- Bob CAN start coups in Bordertown

DAY 2: Invasion!
- Kingdom B invades Bordertown
- Kingdom B wins
- Bordertown now belongs to Kingdom B

DAY 3: Aftermath
- Bob still has 350 rep in Kingdom A
- Bob has 0 rep in Kingdom B ❌
- Bob CANNOT start coup (needs 300 rep in Kingdom B)
- Bob is effectively "occupied"

DAY 4-30: Integration Period
- Bob does contracts in Bordertown (+10 rep each)
- Bob checks in daily (+5 rep each)
- After ~20 contracts, Bob has 300 rep in Kingdom B
- Bob can NOW start coups in Bordertown ✅
```

---

## Strategic Options for Conquered Citizens

### Option 1: Accept New Rule (Integration)
```
Build reputation in new kingdom:
- Accept contracts from new ruler
- Check in daily
- Participate in new kingdom's defense
- Eventually earn 300 rep → can coup if you want

Timeline: ~3-4 weeks of active play
```

**Pros:**
- Peaceful transition
- Can eventually gain power
- New opportunities

**Cons:**
- Slow process
- Working for "the enemy"
- May feel like betrayal

### Option 2: Leave (Emigration)
```
Move to another city in your original kingdom:
- Check in to a Kingdom A city
- Keep your Kingdom A reputation
- Can coup there if you have enough rep
- Stay loyal to your original kingdom

Immediate effect
```

**Pros:**
- Keep your loyalty
- Immediate action
- Stay with your kingdom

**Cons:**
- Lose your home city
- Have to rebuild elsewhere
- No revenge

### Option 3: Wait for Liberation (Resistance)
```
Stay in occupied city but wait:
- Don't build rep in new kingdom (resistance)
- Wait for Kingdom A to invade BACK
- Help defend when invasion comes
- Reclaim your city through military means

Timeline: Depends on Kingdom A's military power
```

**Pros:**
- Stay loyal
- Can help in liberation
- Dramatic story

**Cons:**
- Passive waiting
- No guarantee of liberation
- Under enemy rule

### Option 4: Build Rep to Coup Back (Long Game)
```
Play the long game:
- Pretend to integrate
- Build 300 rep in new kingdom
- Then start coup to take it back!
- Become ruler yourself (not give back to old kingdom)

Timeline: 3-4 weeks, then coup
```

**Pros:**
- Strategic deception
- Can become ruler yourself
- Revenge feels good

**Cons:**
- Betrays both kingdoms
- Takes time
- Coup can fail (harsh penalties)

---

## Strategic Implications for Rulers

### For Conquering Rulers (Kingdom B)

**Immediate Concerns:**
```
You conquered the city, but:
- Old citizens (Kingdom A) can't coup yet (0 rep)
- But they CAN defend against YOUR citizens' coups
- And they can help if Kingdom A invades back
```

**Defense Strategy:**
```
1. Bring loyal citizens to conquered city
   - Your Kingdom B citizens have rep in Kingdom B
   - They can defend against coups
   - They are your occupation force

2. Build loyalty in occupied population
   - Offer good contracts
   - Don't be a tyrant
   - Encourage integration

3. Build walls
   - Protect against Kingdom A re-invasion
   - Walls help defend against internal coups too

4. Watch for Kingdom A counter-invasion
   - They WILL try to take it back
   - Keep defenders ready
```

### For Defending Rulers (Kingdom A - Lost City)

**Immediate Concerns:**
```
You lost the city, but:
- Your citizens are still there
- They're loyal but can't coup (no rep in Kingdom B)
- You need to take it back militarily
```

**Reconquest Strategy:**
```
1. Plan counter-invasion
   - Gather forces from other Kingdom A cities
   - High attack power team
   - 100g per attacker

2. Strike while defenses are weak
   - Right after conquest, walls are damaged
   - Before Kingdom B brings reinforcements
   - 2-hour window to organize

3. Rally your old citizens
   - They can help defend during YOUR invasion
   - They want their city back
   - Coordination is key

4. Long-term: Border warfare
   - Keep trying to reconquer
   - Weaken Kingdom B's other cities
   - Strategic military campaign
```

---

## Kingdom Membership & Loyalty

### Who Belongs to Which Kingdom?

```swift
func getPlayerKingdom(player: Player) -> Kingdom? {
    // Option 1: Player rules a city - that's their kingdom
    if let ruledCity = player.fiefsRuled.first {
        return getKingdom(ofCity: ruledCity)
    }
    
    // Option 2: Player has highest rep in a specific kingdom
    if let maxKingdom = player.kingdomReputation.max(by: { $0.value < $1.value }) {
        return getKingdom(byId: maxKingdom.key)
    }
    
    // Option 3: Player's current check-in location
    if let currentKingdom = player.currentKingdom {
        return getKingdom(byId: currentKingdom)
    }
    
    // No kingdom affiliation
    return nil
}
```

### Loyalty Tracking

```swift
struct Player {
    // Track reputation in each kingdom
    var kingdomReputation: [String: Int] = [:]  // kingdomId -> reputation
    
    // Player's "home" kingdom (highest rep)
    var homeKingdom: String? {
        return kingdomReputation.max(by: { $0.value < $1.value })?.key
    }
    
    // Check loyalty to a specific kingdom
    func getLoyaltyTier(toKingdom kingdomId: String) -> String {
        let rep = getKingdomReputation(kingdomId)
        
        if rep >= 1000 { return "Legendary Citizen" }
        if rep >= 500 { return "Champion" }
        if rep >= 300 { return "Notable" }
        if rep >= 150 { return "Citizen" }
        if rep >= 50 { return "Resident" }
        return "Stranger"
    }
}
```

---

## Occupation Dynamics

### Fresh Conquest (First 24 Hours)

```
City just conquered:
- Old citizens: Confused, can't coup
- New ruler: Vulnerable, needs reinforcements
- Walls: Damaged (-2 levels)
- Treasury: Partially looted

HIGH RISK PERIOD for conqueror
```

### Occupation Period (Week 1-4)

```
Integration happening:
- Some old citizens building rep (integrating)
- Some old citizens left (emigrated)
- Some waiting for liberation (resistance)
- New ruler bringing loyal citizens
- Walls being rebuilt

STABILIZATION PERIOD
```

### Integrated City (Month 2+)

```
New normal:
- Many old citizens now have rep in new kingdom
- City feels like part of new kingdom
- Old kingdom loyalty fading
- Can defend against old kingdom invasions

STABLE OCCUPATION
```

---

## Preventing Exploits

### Exploit: "Fake Conquest"
```
Problem: Kingdom A "invades" its own city to reset something

Solution: Can't invade cities in your own kingdom
- Neighboring check prevents this
- Invasions are external only
```

### Exploit: "Instant Recoup"
```
Problem: Old citizens immediately coup after conquest

Solution: Need 300 rep in CURRENT kingdom
- Old citizens have 0 rep in new kingdom
- Can't coup immediately
- Must invade back militarily
```

### Exploit: "Reputation Transfer"
```
Problem: Transfer rep between kingdoms somehow

Solution: Kingdom reputation is SEPARATE
- Rep in Kingdom A ≠ Rep in Kingdom B
- Each kingdom tracks separately
- No transfer mechanism
```

### Exploit: "Rapid Integration"
```
Problem: Conqueror gives tons of contracts to old citizens

Solution: Natural rate limiting
- Contracts take time to complete
- Can't spam 30 contracts instantly
- ~10 rep per contract = slow growth
```

---

## UI/UX Considerations

### Player Profile Screen

```
Player: Bob
Home Kingdom: Kingdom A (350 rep - Notable)

Kingdom Reputation:
- Kingdom A: 350 rep ⭐ (Notable)
- Kingdom B: 0 rep (Stranger)
- Kingdom C: 125 rep (Resident)

Currently in: Bordertown (Kingdom B territory)

Status: Cannot start coups here (need 300 rep in Kingdom B)
```

### Conquered City Screen

```
🏰 Bordertown
Ruler: Alice (Kingdom B)
Formerly: Kingdom A territory

Your Status:
- You are a Kingdom A citizen (350 rep)
- You have 0 rep in Kingdom B
- You cannot start coups here yet

Options:
→ Build reputation in Kingdom B (integrate)
→ Leave to Kingdom A city (emigrate)
→ Wait for Kingdom A liberation (resist)

Kingdom A reconquest attempts: 2 failed
```

### Coup Attempt Screen

```
⚠️ Cannot Start Coup

You need 300+ reputation in Kingdom B to start a coup.

Your reputation:
- Kingdom B: 0 rep (Stranger)
- Need: 300 rep (Notable)

How to gain reputation:
→ Complete contracts (+10 rep each)
→ Daily check-ins (+5 rep each)
→ Defend against invasions (+30 rep)

Estimated time: ~3-4 weeks
```

---

## Real-World Example Flow

### The Story of Bob

```
WEEK 1: Happy Citizen
- Bob lives in Bordertown (Kingdom A)
- Bob has 350 rep in Kingdom A
- Bob is a Notable citizen
- Life is good

WEEK 2: The Invasion
- Kingdom B invades Bordertown
- Bob joins defense (Kingdom A defender)
- Defense fails
- Bordertown now belongs to Kingdom B
- Bob is now "occupied"

WEEK 3: The Choice
- Bob tries to start coup → BLOCKED (need 300 rep in Kingdom B)
- Bob has 3 options:

Option A: Leave (Emigration)
- Bob checks in to Capital City (Kingdom A)
- Bob keeps his 350 rep in Kingdom A
- Bob can coup there if he wants
- But he lost his home

Option B: Wait (Resistance)  
- Bob stays in Bordertown
- Bob doesn't build rep in Kingdom B (passive resistance)
- Bob waits for Kingdom A to invade back
- Bob will help defend during liberation

Option C: Integrate (Long Game)
- Bob does contracts for new ruler Alice
- Bob slowly builds rep in Kingdom B
- After 30 contracts: Bob has 300 rep in Kingdom B
- Bob starts coup and takes Bordertown for himself!
- (Betrays both kingdoms)

Bob chooses Option B: Wait for liberation

WEEK 4: The Liberation
- Kingdom A invades Bordertown
- Bob joins as ATTACKER (helping his old kingdom)
- Kingdom A wins!
- Bordertown returns to Kingdom A
- Bob's home is free again!
```

---

## Summary

**Key Mechanic:**
- Need 300+ rep in CURRENT kingdom to start coups
- Conquered citizens have 0 rep in new kingdom
- Can't immediately coup back
- Must invade militarily to reconquer

**Why This Works:**
- ✅ Prevents instant recoup exploit
- ✅ Makes invasions meaningful
- ✅ Creates occupation dynamics
- ✅ Encourages military reconquest
- ✅ Allows integration path
- ✅ Creates interesting citizen choices
- ✅ Rewards kingdom loyalty

**Strategic Depth:**
- Conquered cities take time to stabilize
- Old citizens must choose paths
- Conquering rulers need loyal citizens
- Border warfare becomes important
- Kingdom loyalty actually matters

---

*In Kingdom, loyalty is earned through reputation, not just declared!* 🏰⚔️


