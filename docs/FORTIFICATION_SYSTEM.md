# Fortification System (Property Gear Sink)

## Purpose
Weapons/armor are currently permanent and risk becoming a one-time craft. This system introduces an **item sink** by allowing players to **sacrifice crafted equipment** to build a **Fortification %** on each property.

Fortification is designed to:
- Be **available daily** (even if battles are rare)
- Create value for **low-tier** equipment (e.g., T1 swords)
- Integrate cleanly with the existing **property + contracts + `player_items`** architecture

---

## Player-facing rules (requirements)
1. **Unlock**: After a property becomes a **House (tier ≥ 2)**, a **Fortification bar** appears (in addition to Garden).
2. **Interface**: Players can open a UI to **sacrifice crafted weapons/armor**.
3. **RNG gain**: Each sacrificed weapon/armor rolls a **random % increase** to Fortification based on the item's tier.
4. **Safety**: Users **cannot sacrifice their last weapon** or **their last armor**.
5. **Meaning**: Fortification is a **% chance the property is protected** when the kingdom is conquered (via **coup or invasion**). Unprotected properties **lose 1 tier**.
6. **Decay**: Fortification decays by **1% per day** (but never below base).
7. **T5 Bonus**: Estate (T5) properties have **50% base fortification** that does not decay. Sacrificed gear stacks on top.

---

## Data model

### `properties` table
Add fields to `api/db/models/property.py` and create a migration:
- `fortification_percent` (INTEGER, not null, default 0)
- `fortification_last_decay_at` (TIMESTAMP, nullable)

**Notes**
- Keep `fortification_percent` clamped to `[0, 100]`.
- Use `fortification_last_decay_at` to support **lazy decay** (no cron required).

---

## Core mechanics

### A) Lazy decay (no scheduler required)
Fortification decay is applied whenever a property is read or modified by property/fortify logic.

Pseudo:
- If `fortification_last_decay_at` is null -> set to `now` (no decay applied this call).
- Else:
  - `days_elapsed = floor((now - last_decay_at) / 24h)`
  - `base = 50 if tier == 5 else 0`
  - `fortification_percent = max(base, fortification_percent - days_elapsed * 1)`
  - `fortification_last_decay_at = last_decay_at + days_elapsed * 24h`

Apply lazy decay in:
- `GET /properties/status`
- `POST /properties/{property_id}/fortify` (before rolling/capping)
- Any conquest-resolution hook that reads `fortification_percent`

### B) RNG gain from sacrificed gear
When sacrificing a `PlayerItem`, roll a percent gain in a tier-based range.

Recommended starting ranges (tunable, wider ranges reduce RNG frustration):
- Tier 1: `+3..+8%`
- Tier 2: `+6..+12%`
- Tier 3: `+10..+18%`
- Tier 4: `+15..+25%`
- Tier 5: `+20..+35%`

Then:
- `fortification_percent = min(100, fortification_percent + gain_roll)`
- Consume the gear (delete the `player_items` row).

### C) "Can't sacrifice last of weapon/armor"
Interpretation (strict, simple):
- If the sacrificed item is a **weapon**: player must still own **>= 1 other weapon** after the sacrifice.
- If the sacrificed item is an **armor**: player must still own **>= 1 other armor** after the sacrifice.

Implementation:
- Before deletion, count remaining items of that type:
  - `count_weapon = count(player_items where user_id = X and type = 'weapon')`
  - `count_armor = count(player_items where user_id = X and type = 'armor')`
- Block if count is 1 for that type.

Additional simplification (recommended v1):
- Disallow sacrificing **equipped** items (`is_equipped = true`).

---

## API changes

### 1) Extend property status
Update `GET /properties/status` (`api/routers/property.py`) to include fortification info per property.

Suggested response fields per property:
- `fortification_unlocked`: boolean (`tier >= 2`)
- `fortification`: object (only if unlocked)
  - `percent`: int (0..100)
  - `base_percent`: int (50 for T5, 0 otherwise)
  - `decays_per_day`: 1

### 2) Fortify endpoint (sacrifice gear)
Add endpoint to `api/routers/property.py`:

`POST /properties/{property_id}/fortify`

Request:
```json
{ "player_item_id": 12345 }
```

Validation:
- Property exists and is owned by current user
- Property tier >= 2
- `PlayerItem` exists, belongs to user
- `PlayerItem.type` in `{ "weapon", "armor" }`
- Not equipped (recommended v1)
- Not last-of-type rule passes

Behavior:
- Apply lazy decay
- Roll fortification gain based on item tier
- Clamp to 100
- Delete `PlayerItem`
- Persist changes

Response:
```json
{
  "success": true,
  "fortification_before": 34,
  "fortification_gain": 14,
  "fortification_after": 48
}
```

### 3) UI list of sacrificeable items
To render a sacrifice picker, the client needs a list of items that are eligible to sacrifice.

Options:
- **Option A (recommended)**: add a lightweight endpoint:
  - `GET /properties/{property_id}/fortify/options`
  - returns eligible unequipped items + their tier/type + expected range
- **Option B**: reuse `GET /equipment` and filter client-side (less server work, but client must implement last-of-type rules consistently).

---

## Conquest hook (where fortification is used)

Current battle resolution in `api/routers/battles.py` changes ruler/empire/treasury but does not touch properties.

Add a property-protection step when a **coup or invasion is resolved with attacker victory** (kingdom is conquered):

For each property in the conquered kingdom:
1. Apply lazy decay.
2. Compute `p = fortification_percent / 100`.
3. Roll `protected = random() < p`.
4. If protected -> no damage, property survives intact.
5. If not protected -> apply property damage:
   - `tier = max(1, tier - 1)` (minimum Land, T1)
   - Note: If a T5 Estate is downgraded to T4, it loses its 50% base fortification bonus.
   - Optional: reduce fortification by 25% after the roll (weakened but not reset).

**Why tier damage instead of deletion**
- Keeps the system understandable and avoids catastrophic loss
- Still creates strong value in fortification (preventing downgrade)
- Downgraded properties lose benefits AND require expensive re-upgrades

**Coup vs Invasion behavior**
- Both trigger the same property protection roll
- This gives property owners a reason to care about kingdom politics
- Fortification protects your investment regardless of how the kingdom falls

---

## UX / balance notes

### Why T1 swords stay valuable
Even with only one basic weapon/armor recipe, low-tier crafts become a reusable sink input:
- cheap crafts -> small fortification gains -> meaningful protection over time

### Cap and decay
- Cap at 100% prevents infinite stacking.
- 1% per day decay prevents "set and forget forever".
- T5 base of 50% rewards long-term property investment.

### T5 Estate synergy
The 50% base fortification for T5 properties:
- Replaces the old "50% survive conquest" benefit with something more interactive
- Rewards players who invested heavily in upgrading properties
- Still allows stacking via gear sacrifice for players who want guaranteed protection
- Creates a decision: maintain fortification above 50%, or let it decay to base and accept the risk?

### What if the kingdom is never conquered?
If conquests are rare (by design), fortification still functions as:
- A **preparation mechanic** (players can choose to maintain it or not)
- A **gold/material sink** via crafting and sacrifice
- A **reason to keep crafting** even with good equipped gear

---

## Implementation checklist (server)
- [ ] Add DB fields + migration for `properties.fortification_percent`, `properties.fortification_last_decay_at`.
- [ ] Add `apply_fortification_decay(property, now)` helper in `api/routers/property.py` (or a shared util).
- [ ] Extend `GET /properties/status` to return current fortification data (after decay).
- [ ] Add `POST /properties/{property_id}/fortify`:
  - validate
  - decay
  - roll gain
  - delete item
  - persist
- [ ] Add conquest resolution hook in `api/routers/battles.py` (attacker victory path for both coups and invasions) to apply property protection roll and downgrade if unprotected.
- [ ] Update T5 Estate benefit description (replace "50% survive conquest" with "50% base fortification").
