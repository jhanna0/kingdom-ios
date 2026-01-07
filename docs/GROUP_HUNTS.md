# Group Hunts (Party Activity) — Very Brief README

## Goal
Create a **repeatable, social, real‑world “raid”** activity where a party runs a short hunt session. Each phase uses a **different player skill** (from `api/routers/tiers.py`) and each party member **rolls success/fail** to influence the outcome.

## Core Loop (5–7 minutes total)
**Party size:** 1–5 (solo allowed, harder).

### Phase 0 — Lobby (optional)
- Form/join hunt for your **current kingdom**.
- Party can start immediately or after a short countdown.

### Phase 1 — Track (Intelligence)
**Question:** “Do we find anything worth hunting?”
- Each member rolls **Track** using `intelligence`.
- Combine outcomes into `track_score`.

**Results**
- If `track_score` is low → **No trail** (hunt ends with tiny consolation reward or cooldown refund).
- If `track_score` is medium → **Small/medium game** likely.
- If `track_score` is high → **Big game** unlocked (boar/bear/moose possible).

### Phase 2 — Approach / Safety Setup (Defense)
**Question:** “Do we spook it / does anyone get hurt?”
- Each member rolls **Approach** using `defense`.
- Produce `safety_score` and `injury_risk`.

**Results**
- Low `safety_score` → higher chance of “spooked” (downgrades encounter) or “injury” (temporary debuff / longer hunt cooldown).

### Phase 3 — Coordinate (Leadership)
**Question:** “Do we execute cleanly as a team?”
- Each member rolls **Coordinate** using `leadership`.
- Generate a `coord_bonus` that boosts the next phase (hit chance / damage / reduces escape).

**Results**
- Low `coord_bonus` → more variance, higher escape chance.
- High `coord_bonus` → stable run, better odds at rare animals.

### Phase 4 — Engage (Attack + Defense, multiple rounds)
**Question:** “Do we land the kill before it escapes / someone gets hurt?”
- Run **N rounds** (ex: 2–4). Each round:
  - Everyone rolls **Attack** using `attack_power`.
  - Everyone rolls **Brace** using `defense_power`.
  - Outcome moves two values:
    - `progress_to_kill` (from attack successes, boosted by `coord_bonus`)
    - `danger` (reduced by defense successes; increased by failed defenses)

**Results**
- If `progress_to_kill` reaches threshold → **kill secured**
- If `danger` reaches threshold → **forced retreat** (no loot or reduced loot; possible injury)
- If time/rounds end with no kill → **escape** (reduced loot)

### Phase 5 — Loot / Blessing (Faith)
**Question:** “How good is the haul?”
- Each member rolls **Blessing** using `faith`.
- Convert to `loot_bonus` (small, additive/multiplicative).

**Rewards (simple v1)**
- **Gold** (always, scales by animal tier)
- **Meat** (optional as a number; can auto-convert to gold at a fixed rate for v1)
- **Rare drop roll** (optional): “pet” / “trophy” as a text-only collectible later

## Animals (real-only)
- Tier 0: squirrel / rabbit
- Tier 1: deer
- Tier 2: boar
- Tier 3: bear
- Tier 4: moose

Animal tier is primarily decided after **Track**, with modifiers from **Defense/Leadership** (spook/coordination) and performance in **Engage**.

## Fail States (keep it light)
- **No trail** (Track fail): ends early, tiny consolation
- **Spooked** (Approach fail): downgrade animal tier or increase escape odds
- **Escape** (Engage incomplete): reduced loot
- **Injury** (Approach/Engage danger): temporary debuff (e.g., -1 attack/defense for X minutes) or hunt-only cooldown penalty

## Why this is easy to ship (no new assets)
- UI can be text + SF Symbols + progress bars + timers.
- Backend is a small state machine: `lobby → track → approach → coordinate → engage(rounds) → loot → resolved`.

## Suggested Roll Sketch (keep tunable)
For a member with stat \(s\) (1–10), roll success with:
\[
p = clamp(0.15 + 0.08 \cdot s,\ 0.20,\ 0.90)
\]
Then:
- `track_score` = count(track successes)
- `safety_score` = count(defense successes)
- `coord_bonus` = count(leadership successes)
- Each Engage round adds:
  - `progress_to_kill += attack_successes + floor(coord_bonus/2)`
  - `danger += (party_size - defense_successes)`

That’s enough to prototype and iterate quickly.


