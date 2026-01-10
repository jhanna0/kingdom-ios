# Coup v2 (Brief Spec)

Goal: **Internal leadership change** inside a kingdom, designed for **multiplayer-only** async play. Coup resolution is **player-driven RNG rolls** (hunting-style), where **player stats affect odds**. **No simulated combat**.

## Eligibility + Rate Limits
- **Who can start**: A citizen with sufficient **local reputation** + **leadership tier**.
- **Starter cooldown**: **1 coup start per player per 30 days**.
- **Kingdom throttle**: **max 1 coup per kingdom per 7 days** (and no overlapping coups).

## Phases (Fixed Timers)
### Phase 1 — Pledge (12 hours)
- All **citizens of the kingdom** get **one pledge**:
  - **Claimant** (yay) = supports the coup initiator as next ruler
  - **Crown** (nay) = supports the current ruler
- UI shows the claimant’s credentials (rep/leadership/combat stats/etc).
- At end of 12h: sides lock; no switching.

### Phase 2 — Battle (12 hours)
Battle is a shared “tug-of-war” state (momentum/morale/bar).
- Players on each side can perform **battle rolls** on a cooldown.
- Each roll updates the shared battle state and is visible to all participants.
- **Stats affect roll odds and/or impact** (like hunting):
  - Claimant side: primarily **attack power** (optionally leadership for coordination)
  - Crown side: primarily **defense power** (optionally ruler legitimacy bonus)
- Battle ends when:
  - A side’s bar hits zero, **or**
  - The 12h timer expires (resolve based on current bar).

### Phase 3 — Resolution
- If **Claimant** wins: initiator becomes ruler.
- If **Crown** wins: current ruler remains.
- Rewards/penalties can be tuned later; keep them meaningful but avoid “one misclick ruins you”.

## Required Notifications (High Level)
- **Coup started**: broadcast to kingdom citizens (optional initiator message).
- **Pledge reminder**: if you haven’t pledged and pledge time is running out.
- **Battle started**: sides locked; battle rolls now available.
- **Coup resolved**: outcome + ruler change.

## API Shape (Conceptual Only)
- `POST /coups/initiate` (starts pledge phase)
- `POST /coups/{id}/pledge` (one-time pledge: claimant/crown)
- `POST /coups/{id}/battle/roll` (cooldown-limited; returns roll result + updated battle state)
- `POST /coups/{id}/resolve` (finalize when battle ends / timer expires)
- `GET /coups/{id}` (status + timers + counts + battle bar)

losers lose 50% gold, -2 skills (min 0), gold is distributed to winners