# Intelligence System: Covert Incidents + Probability Bar

A **multi-player espionage system** using hunt-style probability bar mechanics.

---

## How It Works (Two-Phase System)

### Phase 1: Initial Success Roll

When a player attempts an infiltration operation:

1. **Calculate success chance** based on:
   - Attacker's **Intelligence Tier** (higher = better base chance)
   - Enemy **Patrol Count** (more patrols = penalty to success)

2. **Roll for success**:
   - If **FAIL**: Operation fails entirely. Attacker loses gold + cooldown but gets nothing.
   - If **SUCCESS**: Proceed to Phase 2 (incident triggers).

#### Initial Success Formula

```
success_chance = BASE_SUCCESS[intelligence_tier] - (active_patrols × PATROL_PENALTY)
```

Clamped to `[5%, 70%]` (always some chance, never trivial).

**Base Success by Tier:**
| Tier | Base Chance |
|------|-------------|
| T1   | 20%         |
| T2   | 28%         |
| T3   | 36%         |
| T4   | 44%         |
| T5   | 52%         |
| T6   | 58%         |
| T7   | 64%         |

**Patrol Penalty:** -6% per active patrol

**Examples:**
- T1 vs 0 patrols: 20% success
- T1 vs 3 patrols: 20% - 18% = 5% (floor)
- T3 vs 2 patrols: 36% - 12% = 24% success
- T5 vs 3 patrols: 52% - 18% = 34% success
- T5 vs 0 patrols: 52% success

### Phase 2: Tug-of-War Incident (If Phase 1 Succeeds)

Once the initial roll succeeds, a **Covert Incident** is created:

1. Both sides are notified
2. Players can **join** and **roll** to shift the probability bar
3. When resolved, a **master roll** picks the final outcome

---

## Core Concepts

### Covert Incident (Event)

An incident is keyed by:
- **attacker_kingdom_id**
- **defender_kingdom_id**

Rules:
- **At most 1 active incident** per (attacker → defender) pair
- A defender kingdom can have **multiple simultaneous incidents**, one per attacking kingdom

### The Probability Bar (Same Pattern as Hunting)

Each incident has a **slot table** ("bar"). Available outcomes depend on attacker's intelligence tier:

**T1 (base):**
```
prevent: 60          # Defender wins
intel: 40            # Attacker gets intelligence
```

**T3 (adds disruption):**
```
prevent: 50
intel: 30
disruption: 20       # Attacker causes temp debuff
```

**T5 (adds sabotage & heist):**
```
prevent: 40
intel: 22
disruption: 18
contract_sabotage: 12  # Attacker delays contract
vault_heist: 8         # Attacker steals gold
```

### Shifting the Bar

Participants roll during the incident window:

- **Attacker success**: shift slots *toward attacker outcomes* (pulls from `prevent`)
- **Defender success**: shift slots *toward `prevent`* (pulls from attacker outcomes)
- **Critical success**: apply 2x shift

This creates the tug-of-war:
- Defenders grow the "prevent" section
- Attackers grow the outcome sections

### Resolution: Master Roll

When the incident ends (timer or manually resolved):
1. One master roll across the bar
2. The roll "lands" on an outcome based on current probabilities
3. Apply the result

---

## Outcomes

### `prevent` (Defender Win)
- Operation fails at the last moment
- Defenders receive reputation/gold rewards for participation
- Attacker already paid cost + cooldown (risk for attempting)

### `intel` (Attacker Win, T1+)
- Create/update `KingdomIntelligence` snapshot for defender kingdom
- Snapshot is shared with attacker kingdom, expires after 48 hours

### `disruption` (Attacker Win, T3+)
- Temporary debuff on defender kingdom (e.g., +10% cooldowns)
- Duration: 30 minutes

### `contract_sabotage` (Attacker Win, T5+)
- Add 5% more actions required to defender's active contract
- Cooldown: Can only sabotage same kingdom once per 6 hours

### `vault_heist` (Attacker Win, T5+)
- Steal 10% of defender kingdom's vault (min 500g if available)
- High risk, high reward

---

## What Patrol Does

Patrol has **one job**: make the initial success roll harder.

- Each active patrol reduces attacker's success chance by 6%
- Patrols do NOT affect the tug-of-war phase or outcome probabilities
- This keeps the system simple and patrol meaningful

**No patrols = easier to infiltrate initially**
**Many patrols = hard to even start the operation**

---

## What Intelligence Tier Does

Intelligence tier affects **two things**:

1. **Initial Success Chance**: Higher tier = better base chance to succeed at Phase 1
2. **Available Outcomes**: Higher tier unlocks more powerful outcomes (disruption, sabotage, heist)

---

## API Endpoints

- `POST /incidents/trigger` - Attempt infiltration (pays gold, rolls initial success)
- `POST /incidents/{id}/join` - Join an existing incident
- `POST /incidents/{id}/roll` - Execute a roll to shift the bar
- `POST /incidents/{id}/resolve` - Resolve with master roll
- `GET /incidents/{id}` - Get incident status
- `GET /incidents/config` - Get tunable config values
