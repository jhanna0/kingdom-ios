# Invasion System - Design Questions & Decisions

## Core Architecture Questions

### 1. Kingdom vs City Structure 🏰

**Current State:**
- Each city IS its own kingdom (kingdom_id = city name)
- No concept of multi-city kingdoms/empires yet
- Player can rule multiple cities (via `fiefs_ruled` array)

**Question: How should invasions work?**

#### Option A: City-to-City (Simple)
```
- Invasions are between individual cities
- "Kingdom" = single city
- A player's "kingdom" = all cities they rule collectively
- Neighboring = any city within 10km of any city the attacker rules
```

**Pros:**
- Simpler implementation
- Works with current schema
- Each city maintains independence
- Natural empire building (collect cities)

**Cons:**
- Less "kingdom warfare" feel
- No faction/alliance system built-in

#### Option B: Multi-City Kingdoms (Complex)
```
- Add new "Empire" or "Faction" concept
- Multiple cities can belong to one kingdom/faction
- Invasions are faction vs faction
- Need new empire_id column and management system
```

**Pros:**
- More strategic depth
- True kingdom warfare
- Natural alliances

**Cons:**
- Major schema changes
- Complex governance (who controls the faction?)
- Harder to implement

**RECOMMENDATION: Option A (City-to-City)**
- Start simple, can expand later
- Current schema supports it
- Player's "kingdom power" = sum of all cities they rule

---

### 2. Player Kingdom Membership 👥

**Question: Which "kingdom" does a player belong to for invasion purposes?**

#### Proposed Rules:
```python
def get_player_kingdom(player: PlayerState) -> List[str]:
    """
    A player belongs to the kingdom(s) of:
    1. Any city they currently rule (fiefs_ruled)
    2. OR their hometown_kingdom_id if they don't rule any
    
    This determines which cities they can attack FROM
    """
    if player.fiefs_ruled and len(player.fiefs_ruled) > 0:
        return player.fiefs_ruled  # All cities they rule
    elif player.hometown_kingdom_id:
        return [player.hometown_kingdom_id]  # Their home city
    else:
        return []  # Nomad - cannot initiate invasions
```

**Invasion Rules:**
```python
# To declare invasion:
# - Attacker must rule at least 1 city (have fiefs_ruled)
# - Target city must be within 10km of ANY city attacker rules
# - Min 3 attackers from players who have same city in their fiefs_ruled
```

**Defending:**
```python
# Anyone checked in to target city can defend
# Regardless of whether they rule it or just live there
```

---

### 3. Multi-City Rulers 👑

**Current Support:**
- `PlayerState.fiefs_ruled` = List of kingdom IDs player rules
- `PlayerState.kingdoms_ruled` = Count of cities ruled
- Already tracks multiple cities per player!

**Question: When you invade, which of your cities is the "attacking kingdom"?**

#### Proposed Solution:
```python
# Invasion initiator specifies which of their ruled cities is leading the attack
POST /invasions/declare
{
    "attacking_from_kingdom_id": "cityA",  # One of initiator's fiefs_ruled
    "target_kingdom_id": "cityB",
    "attacker_player_ids": [1, 2, 3, 4]
}

# Neighboring check:
# target_city must be within 10km of attacking_from_kingdom_id
```

**Why this matters:**
- Geography! You can only invade neighbors
- If you rule 3 cities, you can invade from any of them
- But each city can only invade its neighbors
- Creates strategic positioning

---

### 4. Victory Outcome 🎉

**Question: When invasion succeeds, what happens to the conquered city?**

#### Proposed Rules:
```python
def apply_invasion_victory(invasion, target_kingdom):
    # Get the invasion initiator (must be a ruler)
    initiator = get_player(invasion.initiator_id)
    
    # Initiator adds this city to their empire
    initiator.fiefs_ruled.append(target_kingdom.id)
    initiator.kingdoms_ruled += 1
    initiator.total_conquests += 1
    
    # Update the target kingdom's ruler
    old_ruler = get_player(target_kingdom.ruler_id)
    if old_ruler:
        old_ruler.fiefs_ruled.remove(target_kingdom.id)
        old_ruler.kingdoms_ruled -= 1
    
    target_kingdom.ruler_id = initiator.id
    
    # Loot treasury
    lootable = calculate_lootable_treasury(target_kingdom)
    split_among_attackers(lootable, invasion.attackers)
    
    # Damage walls
    target_kingdom.wall_level = max(0, target_kingdom.wall_level - 2)
```

**Result:**
- Initiator now rules N+1 cities
- All their cities are independent (no "merged kingdom")
- They must defend all cities separately
- Empire building mechanic!

---

## Implementation Plan

### Phase 1: Database Schema ✅
```sql
CREATE TABLE invasion_events (
    id SERIAL PRIMARY KEY,
    
    -- Geography
    attacking_from_kingdom_id VARCHAR NOT NULL,  -- Which city is attacking
    target_kingdom_id VARCHAR NOT NULL,          -- Which city is being invaded
    
    -- Leadership
    initiator_id BIGINT NOT NULL REFERENCES users(id),
    initiator_name VARCHAR NOT NULL,
    
    -- Status
    status VARCHAR NOT NULL DEFAULT 'declared',  -- 'declared', 'resolved'
    
    -- Timing
    declared_at TIMESTAMP NOT NULL DEFAULT NOW(),
    battle_time TIMESTAMP NOT NULL,  -- When battle will resolve (2h from declared_at)
    resolved_at TIMESTAMP,
    
    -- Participants
    attackers JSONB DEFAULT '[]'::jsonb,  -- List of player IDs
    defenders JSONB DEFAULT '[]'::jsonb,  -- List of player IDs
    
    -- Combat Results (after resolution)
    attacker_victory BOOLEAN,
    attacker_strength INTEGER,
    defender_strength INTEGER,
    total_defense_with_walls INTEGER,
    loot_distributed INTEGER,
    
    -- Cost
    cost_per_attacker INTEGER DEFAULT 100,
    total_cost_paid INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_invasion_target ON invasion_events(target_kingdom_id);
CREATE INDEX idx_invasion_status ON invasion_events(status);
CREATE INDEX idx_invasion_battle_time ON invasion_events(battle_time);
```

### Phase 2: API Endpoints
```
POST   /invasions/declare          - Declare invasion (initiator + 2-4 allies)
POST   /invasions/{id}/join        - Join as defender
GET    /invasions/active           - List active invasions
GET    /invasions/{id}             - Get invasion details
POST   /invasions/{id}/resolve     - Manually resolve
POST   /invasions/auto-resolve     - Background job
```

### Phase 3: Combat Resolution
```python
# Similar to coups but WITH WALLS
attacker_strength = sum(attacker.attack_power for each attacker)
defender_strength = sum(defender.defense_power for each defender)
wall_defense = target_kingdom.wall_level * 5
total_defense = defender_strength + wall_defense

required_attack = total_defense * 1.25

if attacker_strength > required_attack:
    invasion_succeeds()
else:
    invasion_fails()
```

---

## Key Differences: Coups vs Invasions

| Aspect | Coup | Invasion |
|--------|------|----------|
| **Scope** | Internal (same city) | External (city-to-city) |
| **Warning** | Instant public vote | 2-hour declaration warning |
| **Initiator Requirement** | 300+ rep, checked in | Must rule a city |
| **Participant Requirement** | Checked in to city | Attackers: from initiator's cities<br>Defenders: checked in to target |
| **Walls** | NO walls | YES walls (+5 def per level) |
| **Geography** | N/A | Must be neighboring (10km) |
| **Cost** | 50g (initiator only) | 100g per attacker |
| **Victory** | Initiator becomes ruler | Initiator adds city to empire |
| **Failure Penalty** | HARSH (lose everything) | Medium (100g lost, -50 rep, 24h debuff) |

---

## Next Steps

1. ✅ **Finalize design decisions** (this doc)
2. 🔨 **Create database migration** for invasion_events table
3. 🔨 **Create InvasionEvent model** in `api/db/models/invasion.py`
4. 🔨 **Create invasion schemas** in `api/schemas/invasion.py`
5. 🔨 **Implement API router** in `api/routers/invasions.py`
6. 🔨 **Add neighboring check** helper function
7. 🔨 **Implement combat resolution** logic
8. 🔨 **Test backend** with curl/Postman
9. 🎨 **Build iOS UI** for declaring/joining invasions
10. 🎮 **Playtest & balance**

---

## Open Questions / Needs Decision

### Critical:
1. ✅ **Are invasions city-to-city or kingdom-to-kingdom?**
   - **Decision: City-to-city (each city is independent)**

2. ⚠️ **Can multiple players initiate together, or does one player initiate and others join?**
   - Option A: One initiator, others join within declaration window
   - Option B: Multiple players declare together upfront (min 3)
   - **Recommendation: Option A (more flexible, like coups)**

3. ⚠️ **Who can join as attacker?**
   - Only players who rule cities in initiator's "empire"?
   - OR anyone checked in to the attacking city?
   - OR anyone who has high rep in attacking city?
   - **Recommendation: Anyone checked in to the attacking city (inclusive)**

### Balance:
4. ⚠️ **Cost per attacker: 100g too much/little?**
5. ⚠️ **2-hour warning too short/long?**
6. ⚠️ **Should vault protect against invasion looting?** (doc says yes)
7. ⚠️ **Wall damage on success: 2 levels or more?**

---

## Summary

**Proposed Simple Model:**
- Each city is independent
- Players can rule multiple cities (already supported)
- Invasions are city A → city B
- Must be neighboring (10km)
- Initiator must rule attacking city
- Anyone checked in can defend
- Victory = initiator adds city to their empire
- All cities remain independent (no merging)

This works with current schema and is easy to understand!

**Ready to implement?** Let me know if you want to change any of these decisions!



