# Coup & Invasion Mechanics - Design Document

## Overview

This document clarifies the distinction between **internal coups** (changing leadership within a city) and **external invasions** (conquering a city for another kingdom).

---

## 1. COUP MECHANICS (Internal Power Struggle)

### Current System Issues
- ✅ Secret conspiracy system works well
- ⚠️ **Problem**: Coup initiator automatically becomes ruler - no reputation check
- ⚠️ **Problem**: Doesn't ensure the new ruler is trusted/reputable

### Improved Coup System

#### Phase 1-3: Conspiracy (Unchanged)
- Initiate secretly
- Invite conspirators
- Risk of snitching
- Recruit your army

#### Phase 4: Execute - COMBAT TIME! (NEW)
When coup is executed, it becomes a **pure attack vs defense battle**:

```
1. Coup initiator executes the coup
2. All checked-in players can pick a side:
   - Join the ATTACKERS (support coup)
   - Join the DEFENDERS (support ruler)
   - 2-hour voting/recruitment window
3. After 2 hours, BATTLE RESOLVES automatically
4. Attack vs Defense combat (just like invasions!)
```

**Battle Formula:**
```swift
// Attacker strength
let attackerStrength = attackers.reduce(0) { $0 + $1.attackPower }

// Defender strength  
let defenderStrength = defenders.reduce(0) { $0 + $1.defensePower }

// Add wall defense
let wallDefense = kingdom.wallLevel * 5

let totalDefense = defenderStrength + wallDefense

// Attackers need 25% advantage
if attackerStrength > totalDefense * 1.25 {
    // COUP SUCCEEDS - initiator becomes ruler
    return .coupSuccess
} else {
    // COUP FAILS - all attackers exposed
    return .coupFailed
}
```

**Victory/Defeat:**

**If Coup Succeeds:**
```swift
// Coup initiator becomes ruler
kingdom.setRuler(playerId: coup.initiatorId, playerName: coup.initiatorName)

// Initiator gets rewards
initiator.gold += 1000
initiator.reputation += 50
initiator.recordCoupAttempt(success: true)

// Defenders get nothing (they lost)
// Old ruler loses the kingdom
```

**If Coup Fails (HARSH PUNISHMENT):**
```swift
// All attackers suffer HARSH penalties (tried to overthrow ruler!)
for attacker in attackers {
    // 1. Lose 50% of their gold (seized by ruler)
    let goldLost = attacker.gold / 2
    attacker.gold -= goldLost
    ruler.gold += goldLost
    
    // 2. MAJOR reputation loss (-100 rep)
    attacker.reputation -= 100  // Traitor!
    attacker.kingdomReputation[kingdomId] -= 100
    
    // 3. Lose 2 points from each combat stat (beaten/wounded)  
    attacker.attackPower = max(1, attacker.attackPower - 2)
    attacker.defensePower = max(1, attacker.defensePower - 2)
    
    // 4. Publicly exposed as traitor
    attacker.recordCoupAttempt(success: false)
}

// Defenders get rewards
for defender in defenders {
    defender.gold += 200
    defender.reputation += 30
}

// Ruler gets all seized gold + bonus
ruler.gold += (total seized from attackers)
ruler.reputation += 50

// Ruler can optionally execute attackers (not automatic)
```

**Why This Is Better:**
- ✅ Attack and Defense stats actually matter in coups
- ✅ Same combat system as invasions (consistent)
- ✅ Gives defenders a chance to rally
- ✅ Makes walls useful for internal defense too
- ✅ High-attack players are valuable for coups
- ✅ High-defense players are valuable for defending ruler
- ✅ Pure PvP combat
- ✅ **HUGE consequences for failed coups** (think before you attack!)

#### Requirements to Start Coup
```swift
// Minimum requirements
- 300+ reputation in target city (Notable tier)
- 50 gold cost to initiate
- Must be checked in
- 24h cooldown between coup attempts
- Cannot be dead
```

**Strategic Implications:**
- Want to rule? Start the coup AND have high attack
- Train attack power to be a coup leader
- Train defense power to defend your ruler
- Walls help defend against internal coups too
- 2-hour window creates dramatic tension
- Players must choose sides publicly

---

## 2. INVASION MECHANICS (External Conquest)

### What is an Invasion?
An **invasion** is when players from **Kingdom A** (the attackers) try to conquer a city currently ruled by **Kingdom B** (the defenders). Unlike coups (internal), invasions are:
- Cross-kingdom warfare
- About territorial expansion
- Requires physical presence at the target city
- Defenders can actively resist

### Core Design

#### Invasion Requirements

**For Attackers:**
```
1. Minimum 3 attackers from SAME kingdom
2. All must be checked in to TARGET city
3. Target city must be NEIGHBORING (within 10km of any city in attacker's kingdom)
4. Costs 100 gold per attacker (shared cost)
5. Must declare invasion - gives defenders 2 hours to respond
```

**Kingdom Membership:**
A player belongs to the kingdom of:
- Any city they currently rule, OR
- The city where they have highest reputation (if not a ruler)

#### Phase 1: Declaration (2 Hour Warning)

```python
def declare_invasion(attacker_ids: List[str], target_city: str) -> bool:
    """
    Declare invasion of target city
    - Creates public event visible to ALL
    - Starts 2-hour countdown
    - Defenders can rally during this time
    """
    # Validate attackers
    for attacker_id in attacker_ids:
        - Must be checked in to target city
        - Must all be from same kingdom
        - Must have 100g each
    
    # Check neighboring requirement
    if not is_neighboring(attacker_kingdom, target_city):
        return False, "Target city not neighboring your kingdom"
    
    # Deduct gold from all attackers
    total_cost = 100 * len(attacker_ids)
    
    # Create invasion event
    create_invasion_timer(target_city, attacker_ids, 2_hours)
    
    # PUBLIC BROADCAST (everyone in target city sees this)
    broadcast_to_city(target_city, {
        'type': 'invasion_declared',
        'attackers': [names...],
        'attacking_kingdom': attacker_kingdom_name,
        'time_until_battle': 2_hours,
        'attacker_count': len(attacker_ids)
    })
    
    return True
```

**Why 2-hour warning?**
- Gives defenders time to organize
- Makes invasions require coordination
- Creates tension and excitement
- Prevents instant offline snipes

#### Phase 2: Defender Rally (2 Hours)

During the 2-hour window:

**Defenders Can:**
- Check in to the city to join defense
- Call allies from other cities  
- Request help from liege lord/vassals
- Form counter-attack plans

**That's it. Pure PvP.**

- No emergency gold spending
- No mercenaries
- No shortcuts
- If you didn't build walls, train citizens, and maintain an active population, you lose
- Preparation > Panic spending

#### Phase 3: Battle Resolution

After 2 hours, battle automatically resolves:

**Combat Formula:**
```python
# Calculate attack strength
attacker_strength = sum([
    player.attack_power 
    for player_id in attackers 
    if player.is_checked_in(2_hours) and player.current_city == target_city
])

# Calculate defense strength
defender_strength = sum([
    player.defense_power 
    for player_id in defenders 
    if player.is_checked_in(2_hours) and player.current_city == target_city
])

# Add wall defenders (each wall level = 5 defense power)
wall_defense = city.wall_level * 5

# Total defense (no mercenaries - pure PvP)
total_defense = defender_strength + wall_defense

# Determine winner
if attacker_strength > total_defense * 1.25:
    # Attackers win - need 25% advantage due to defender bonus
    return invasion_succeeds()
else:
    return invasion_fails()
```

**Why 25% advantage needed?**
- Defenders have home advantage
- Walls provide protection
- Makes invasions require real strength
- Prevents easy conquests

#### Phase 4: Victory/Defeat

**If Invasion Succeeds:**
```python
def invasion_succeeds():
    # 1. City changes ownership
    old_kingdom = city.kingdom
    new_kingdom = attackers_kingdom
    attacking_ruler = get_ruler_of_kingdom(new_kingdom)
    
    city.kingdom = new_kingdom
    
    # 2. Attacking kingdom's ruler takes control
    city.ruler_id = attacking_ruler.player_id
    city.ruler_name = attacking_ruler.name
    attacking_ruler.add_fief(city.name)
    
    # 3. Loot treasury (vault protection applies)
    vault_protection = city.get_vault_protection()
    lootable = city.treasury * (1.0 - vault_protection)
    
    # Split loot among attackers
    loot_per_attacker = lootable // len(attackers)
    for attacker in attackers:
        attacker.gold += loot_per_attacker
        attacker.reputation += 50  # Big reputation boost
    
    # 4. Wall damage
    city.wall_level = max(0, city.wall_level - 2)  # Walls damaged
    
    # 5. Old ruler loses the city
    old_ruler.remove_fief(city.name)
    
    # 6. Public event
    broadcast_to_all({
        'type': 'invasion_success',
        'city': city.name,
        'old_kingdom': old_kingdom.name,
        'new_kingdom': new_kingdom.name,
        'new_ruler': attacking_ruler.name,
        'attackers': [names...],
        'loot': lootable
    })
    
    # 7. Attacking ruler now controls multiple cities - EMPIRE BUILDING!
```

**If Invasion Fails:**
```python
def invasion_fails():
    # 1. All attackers PUNISHED (lost battle)
    for attacker in attackers:
        # Already lost 100g (paid upfront)
        
        # Reputation hit (-50 rep, failed military campaign)
        attacker.reputation -= 50
        
        # Wounded - lose 1 attack power for 24h (temporary debuff)
        attacker.attack_debuff = 1  # -1 attack for 24h
        attacker.debuff_expires = datetime.now() + timedelta(hours=24)
    
    # 2. Defenders get rewards
    for defender in defenders:
        defender.gold += 100  # From attacker payment
        defender.reputation += 30
    
    # 3. Ruler gets BIG reward
    ruler.gold += 200
    ruler.reputation += 50
    
    # 4. Public event
    broadcast_to_all({
        'type': 'invasion_failed',
        'city': city.name,
        'defenders': [names...],
        'attackers': [names...],
        'message': 'Invasion repelled!'
    })
    
    # 5. Attackers get 24h invasion cooldown + wounded debuff
```

---

## 3. KEY DIFFERENCES: Coup vs Invasion

| Aspect | Coup | Invasion |
|--------|------|----------|
| **Who** | Same kingdom (internal) | Different kingdoms (external) |
| **Goal** | Change leadership | Conquer territory |
| **Warning** | Secret until executed, then 2h voting | 2-hour public warning |
| **Success Metric** | Attack > Defense * 1.25 | Attack > Defense * 1.25 |
| **Result** | Coup initiator becomes ruler | Attacking ruler takes control |
| **Stats Used** | Attack vs Defense power | Attack vs Defense power |
| **Cost** | 50g (leader only) | 100g per attacker |
| **Walls** | Each level = 2 defenders | Each level = 5 defense power |

---

## 4. DEFENDING AGAINST INVASIONS

### Active Defense Options

#### Option 1: Be Present
- Most important: be checked in when battle resolves
- Each defender adds their defense_power
- Rally your citizens!

#### Option 2: Build Walls
```
Wall Level 1: +5 defense (cost: ~200g to build)
Wall Level 2: +10 defense (cost: ~500g)
Wall Level 3: +15 defense (cost: ~1000g)
Wall Level 4: +20 defense (cost: ~2000g)
Wall Level 5: +25 defense (cost: ~4000g)
```

#### Option 3: Train Defense
- Spend gold to increase defense_power stat
- Higher defense = more valuable in battles

#### Option 4: Call Vassals/Allies
- Vassals obligated to help their liege
- Failure to help = reputation penalty
- Success = reputation bonus

#### Option 5: Build Vault
- Won't prevent invasion
- But protects treasury from looting
```
Vault Level 1: 20% treasury protected
Vault Level 2: 40% protected
Vault Level 3: 60% protected  
Vault Level 4: 80% protected (max)
```

---

## 5. STRATEGIC IMPLICATIONS

### For Attackers

**When to Invade:**
- Target has low walls
- Target has few active players
- Your kingdom has strong attack-focused players
- Target city is valuable (high treasury, good location)

**Invasion Strategy:**
- Recruit high-attack players
- Coordinate check-in timing
- Choose targets wisely (neighboring only)
- Be willing to lose 100g if failed

**Risk vs Reward:**
- **Success**: Expand kingdom, gain loot, huge reputation
- **Failure**: Lose 100g, 24h cooldown, reputation hit

### For Defenders

**Prevention:**
- Build walls early
- Keep citizens active (daily check-ins)
- Train defense stats
- Maintain treasury for emergency mercenaries
- Form strong alliances

**During Invasion:**
- Rally all citizens immediately (2-hour window)
- Call vassals and allies
- High-defense players are MVP
- No shortcuts - must have prepared

**If Conquered:**
- City changes kingdoms
- Attacking kingdom's ruler now controls it (empire building!)
- Original citizens can attempt coup to reclaim
- Or join the new kingdom

---

## 6. NEIGHBORING REQUIREMENT

### What is "Neighboring"?

```python
def is_neighboring(attacker_kingdom: Kingdom, target_city: str) -> bool:
    """
    Two cities are neighbors if:
    1. Within 10km of each other, OR
    2. Share a border (polygons touch)
    """
    
    # Get all cities in attacker's kingdom
    attacker_cities = get_kingdom_cities(attacker_kingdom)
    
    for city in attacker_cities:
        distance = calculate_distance(city, target_city)
        if distance <= 10_000:  # 10km in meters
            return True
        
        if polygons_touch(city.boundary, target_city.boundary):
            return True
    
    return False
```

**Why neighboring requirement?**
- Prevents random distant invasions
- Creates natural expansion patterns
- Encourages border conflicts
- Makes geography matter

**Strategic Implications:**
- Kingdoms grow organically from starting cities
- Border cities are most vulnerable
- Creates natural "frontiers"
- Encourages defensive depth (buffer cities)

---

## 7. EMPIRE BUILDING

After successful invasion, the **attacking kingdom's ruler** automatically takes control:

```python
def get_ruler_of_kingdom(kingdom_id: str) -> Player:
    """
    Get the ruler of a kingdom (the player who controls it)
    
    For now, this is the player who rules the "capital" city
    (the first city founded in that kingdom)
    
    Future: Could have election/succession mechanics
    """
    capital_city = get_kingdom_capital(kingdom_id)
    return get_player(capital_city.ruler_id)
```

**Multi-City Rulers:**
- One player can rule multiple cities
- Each conquered city adds to their empire
- More cities = more power but harder to defend all
- Creates natural empire expansion gameplay

**Examples:**
```
Alice rules "Kingstown" (capital of Kingdom A)
Alice's forces invade "Enemyville" (Kingdom B city)
Invasion succeeds
→ Alice now rules BOTH Kingstown and Enemyville
→ Both cities are in Kingdom A
→ Alice is emperor of Kingdom A with 2 cities
```

**Strategic Implications:**
- Powerful rulers can build empires
- But must defend multiple cities simultaneously
- Can't be everywhere at once
- Creates opportunities for counter-attacks while ruler is busy
- Vassals become more important for multi-city rulers

---

## 8. IMPLEMENTATION CHECKLIST

### Backend (Python)

- [ ] Update `execute_coup()` - initiator becomes ruler (already works!)
- [ ] Add `declare_invasion()` function
- [ ] Add invasion timer system (2-hour countdown)
- [ ] Add `resolve_invasion()` battle calculation
- [ ] Add `is_neighboring()` check
- [ ] Add multi-city ruler support (one player rules multiple cities)
- [ ] Add invasion cooldown tracking
- [ ] Update attack/defense stat usage
- [ ] Add kingdom membership logic
- [ ] Remove any mercenary/emergency spending systems

### Frontend (iOS)

- [ ] Show invasion countdown timer
- [ ] Show defender rally UI
- [ ] Show neighboring kingdoms on map
- [ ] Show "Declare Invasion" button for neighboring cities
- [ ] Show defense/attack stats prominently
- [ ] Show mercenary hiring UI for rulers
- [ ] Show empire view (all cities a ruler controls)
- [ ] Push notifications for invasion warnings
- [ ] Show battle results screen

### Database

- [ ] Add `kingdom_id` to cities table
- [ ] Add `invasion_events` table
- [ ] Add `invasion_cooldowns` table
- [ ] Support players with multiple `fiefs_ruled`

---

## 9. BALANCE CONSIDERATIONS

### Attack vs Defense Balance

**Attack-focused players:**
- Good for invasions
- Good for aggressive coups
- Offensive builds

**Defense-focused players:**
- Good for defending cities
- Good for preventing coups
- Defensive builds

**Leadership-focused players:**
- Good for coup voting weight
- Good for vassalage system
- Political builds

**Balanced builds:**
- Jack of all trades
- Most flexible
- Recommended for solo players

### Gold Economy

**Invasion costs:**
- 100g per attacker - significant but not prohibitive
- Success returns ~200-500g in loot (profit!)
- Failure loses the 100g (risk!)

**Defense costs:**
- Walls: 200-4000g depending on level
- Training defense stats: Ongoing investment
- Must be done BEFORE invasion declared (no shortcuts)

**Strategic choice:**
- Offensive kingdoms: Low walls, high attack stats
- Defensive kingdoms: High walls, high defense stats
- Balanced kingdoms: Mix of both

---

## 10. EXAMPLE SCENARIOS

### Scenario 1: Successful Invasion

```
Kingdom A (Attackers): "Iron Legion"
- 5 players with avg 10 attack = 50 attack power
- Paid 500g total to declare invasion

Kingdom B (Defenders): "Peaceful Realm" 
- City: "Harmonyville"
- Ruler: Alice
- 2 players with avg 8 defense = 16 defense power
- Wall level 2 = +10 defense
- Total defense = 26

2 hours pass...

Battle Resolution:
- Attacker strength: 50
- Defender strength: 26
- Attacker needs: 26 * 1.25 = 32.5
- Result: 50 > 32.5 → ATTACKERS WIN!

Outcome:
- Harmonyville joins Iron Legion kingdom
- Alice loses rulership
- City becomes unclaimed
- Attackers split 300g treasury (60g each)
- Walls reduced to level 0
- All attackers gain +50 reputation
- Alice and defenders gain nothing (loss)
- Iron Legion can now invade cities neighboring Harmonyville!
```

### Scenario 2: Failed Invasion

```
Kingdom A (Attackers): "War Hawks"
- 3 players with avg 8 attack = 24 attack power
- Paid 300g total

Kingdom B (Defenders): "Fortified Realm"
- City: "Stronghold"
- Ruler: Bob
- 4 players with avg 7 defense = 28 defense power
- Wall level 4 = +20 defense
- Total defense = 48

2 hours pass...

Battle Resolution:
- Attacker strength: 24
- Defender strength: 48
- Attacker needs: 48 * 1.25 = 60
- Result: 24 < 60 → DEFENDERS WIN!

Outcome:
- Stronghold remains in Fortified Realm
- Attackers lose 300g (paid upfront)
- Each defender gets 75g (from attacker payment)
- Bob gets extra 200g + 50 rep
- All defenders get +30 reputation
- Attackers get 24h invasion cooldown
- Attackers learned: don't attack fortified cities!
```

### Scenario 3: Coup Combat Example

```
Kingdom: "Kingstown"
Current Ruler: Alice (tyrant)

Bob initiates coup:
- Bob has 300 rep (can propose coup)
- Bob pays 50g
- Coup goes PUBLIC with 2-hour voting window

Players choose sides:

ATTACKERS (Support Bob):
- Bob: 12 attack
- Charlie: 10 attack  
- Dave: 8 attack
Total Attack: 30

DEFENDERS (Support Alice):
- Alice: 5 defense
- Eve: 7 defense
- Frank: 6 defense
Total Defense: 18
+ Wall Level 2: +10 defense
= Total Defense: 28

2 hours pass... BATTLE!

Combat Resolution:
- Attacker strength: 30
- Defender strength: 28
- Attackers need: 28 * 1.25 = 35
- Result: 30 < 35 → COUP FAILS!

Outcome:
- Alice remains ruler
- All attackers HARSHLY punished:
  - Bob loses 50% gold (had 500g → loses 250g)
  - Charlie loses 50% gold (had 300g → loses 150g)
  - Dave loses 50% gold (had 400g → loses 200g)
  - Alice gets 600g total from seized gold
  - All lose 100 reputation in Kingstown (traitors!)
  - All lose 2 attack and 2 defense (beaten)
  - Bob: 12→10 attack, Charlie: 10→8 attack, Dave: 8→6 attack
- Publicly exposed as traitors
- Alice can execute them if she wants (optional)
- Defenders (Alice, Eve, Frank) each get +200g, +30 rep
```

**Why attackers lost:**
- Didn't have enough attack power
- Walls made the difference
- Should have recruited more high-attack players

### Scenario 4: Empire Building

```
Alice rules "Kingstown" (capital of Iron Legion kingdom)
Alice's stats: 15 attack, 8 defense

Alice declares invasion of "Bordertown" (Peaceful Realm kingdom)
- Brings 4 allies (total 5 attackers)
- Total attack: 70
- Cost: 500g total

Bordertown defense:
- 2 defenders with 25 defense total
- Wall level 2 = +10 defense  
- Total defense: 35

Battle Resolution:
- Attack: 70
- Defense needed: 70 * 1.25 = 87.5
- Actual defense: 35
- Result: INVASION SUCCEEDS!

Outcome:
- Bordertown joins Iron Legion kingdom
- Alice now rules BOTH Kingstown AND Bordertown
- Alice is building an empire!
- Old Bordertown ruler loses everything
- Bordertown citizens can coup to reclaim or join Iron Legion

Strategic situation:
- Alice must now defend 2 cities
- Can't be in both places at once
- Vulnerable to counter-invasion in Kingstown
- Needs strong vassals to help defend
- More cities = more power but more risk
```

---

## Summary

**Coups**: Internal power struggles where initiator becomes ruler

**Invasions**: External conquest requiring attack/defense combat with 2-hour warning

**Key Balance**: 
- Coups = social/political (who you trust)
- Invasions = military (who's stronger)
- Both require strategic coordination
- Geography matters (neighboring requirement)
- Gold economy balances both systems

This creates a rich strategic layer where kingdoms can grow through military might OR political intrigue!

