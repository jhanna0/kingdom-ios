# Science Discovery (Technology Research) — Very Brief README

## Goal
Create a **repeatable, social, real‑world “research session”** activity where a party runs a short discovery run and earns rewards. Each phase uses an existing player skill (see `api/routers/tiers.py`) and each party member rolls success/fail to influence the outcome.

This is the “equivalent” of `docs/GROUP_HUNTS.md`, but themed around **science discovery + technology**.

---

## Core Loop (5–7 minutes total)
**Party size:** 1–5 (solo allowed, harder).

### Phase 0 — Setup (optional)
- Form/join a research party for your **current kingdom**.
- Choose a **Research Focus** (simple v1): `Materials`, `Medicine`, `Engineering`, `Navigation`, `Agriculture`.
- Optional flavor: pick a “site type” (future) via OSM tags (library/museum/university/etc).

### Phase 1 — Observe (Intelligence)
**Question:** “Do we notice something interesting or useful?”
- Each member rolls **Observe** using `intelligence`.
- Combine outcomes into `signal_score`.

**Results**
- Low `signal_score` → **No lead** (session ends early with small consolation reward / reduced cooldown).
- Medium → **Minor lead** (common discoveries).
- High → **Strong lead** (rare discoveries / higher tier tech possible).

### Phase 2 — Hypothesis (Science)
**Question:** “Do we form a correct model quickly?”
- Each member rolls **Hypothesis** using `science`.
- Produce `model_score` (quality of the proposed explanation).

**Results**
- Low `model_score` → experiments are less efficient (more “wasted” attempts).
- High `model_score` → boosts breakthrough progress and reduces failure risk in Phase 3.

### Phase 3 — Prototype / Experiment (Building)
**Question:** “Can we build/run the test without it falling apart?”
- Each member rolls **Prototype** using `building_skill`.
- Produce `stability_score` and `break_risk`.

**Results**
- Low `stability_score` → higher chance of “equipment break / contamination” (temporary penalty or reduced rewards).
- High `stability_score` → smoother run, enables bigger breakthroughs.

### Phase 4 — Analyze (Science + Intelligence, multiple rounds)
**Question:** “Do we turn the results into a real breakthrough before time runs out?”
- Run **N rounds** (ex: 2–4). Each round:
  - Everyone rolls **Analyze** using `science`.
  - Everyone rolls **Sanity Check** using `intelligence`.
  - Outcome moves two values:
    - `breakthrough += analyze_successes + floor(model_score/2)`
    - `error += (party_size - sanity_successes)` (misreads, bad data, false positives)

**Results**
- If `breakthrough` reaches threshold → **discovery made**
- If `error` reaches threshold → **false conclusion** (reduced rewards; possible “setback” debuff)
- If rounds end with no breakthrough → **inconclusive** (reduced rewards)

### Phase 5 — Publish / Apply (Philosophy or Leadership)
**Question:** “Do we share it well enough to matter?”
- Each member rolls **Publish** using `philosophy` (preferred) *or* `leadership` (fallback).
- Convert to `impact_bonus`.

**Results**
- Low `impact_bonus` → discovery is “niche”: mostly personal rewards.
- High `impact_bonus` → discovery spreads: bonus **reputation** and (future) kingdom-wide unlock progress.

---

## Discoveries (simple v1)
Treat discoveries as **text-only collectibles** (no assets required) with a tier and focus. Example output:
- `Materials I — Improved Steel Temper`
- `Agriculture II — Soil Rotation Notes`
- `Navigation III — Landmark Triangulation Method`

**Technology framing:** each discovery can later map to a “Tech” that unlocks a perk (crafting discount, build speed, travel fee reduction, etc.).

---

## Rewards (simple v1)
- **Gold** (always): scales with discovery tier.
- **XP** (optional): small amount to support leveling.
- **Reputation** (optional): small, mainly from Phase 5.
- **Temporary buff** (optional): e.g. “+10% crafting speed for 30 minutes” (later system).

---

## Fail States (keep it light)
- **No lead** (Observe fail): ends early, tiny consolation
- **Setback** (Prototype fail): reduced rewards; possible short debuff (e.g., -1 building for 10 minutes)
- **False conclusion** (Analyze error threshold): reduced rewards, longer cooldown
- **Inconclusive** (time/rounds end): reduced rewards

---

## Why this is easy to ship (no new assets)
- UI can be text + SF Symbols + progress bars + timers.
- Backend is a small state machine:
  - `lobby → observe → hypothesis → prototype → analyze(rounds) → publish → resolved`

---

## Suggested Roll Sketch (keep tunable)
For a member with stat \(s\) (0–10), roll success with:
\[
p = clamp(0.15 + 0.08 \cdot s,\ 0.20,\ 0.90)
\]

Then:
- `signal_score` = count(intelligence successes)
- `model_score` = count(science successes)
- `stability_score` = count(building successes)
- Each Analyze round adds:
  - `breakthrough += science_successes + floor(model_score/2)`
  - `error += (party_size - intelligence_successes)`

That’s enough to prototype and iterate quickly.


