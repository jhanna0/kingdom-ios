# Duel Attack Style System

## Core Principle: Frontend is a DUMB RENDERER

**ALL game logic, calculations, and style definitions live on the backend.**

The frontend:
- Displays what the server sends
- Never calculates odds, modifiers, or outcomes
- Gets style definitions (name, icon, description, effects) from `/duels/config`
- Shows exactly what the server tells it to show

If we want to change a style's effect from +5% to +8%, we change it on the backend ONLY.

---

## Architecture: WebSocket vs API Response

**Critical design principle for event handling:**

1. **WebSocket broadcasts the SAME event to BOTH players simultaneously.**
   - Used for real-time sync and triggering UI events (popups, animations)
   - When a round resolves, DUEL_ROUND_RESOLVED is sent to both players

2. **API response returns current game state for the caller ONLY.**
   - Used for state sync after actions
   - Used for reconnect scenarios (catch up on missed state)
   - Does NOT trigger popups (to avoid duplication)

3. **Frontend does NO deduplication logic.**
   - WebSocket events → trigger popups/animations
   - API responses → update state only
   - This prevents Player A from seeing duplicate popups (API + WebSocket)

**Example flow when Player A triggers round resolution:**
```
Player A clicks SUBMIT
    ↓
API processes, detects both submitted, resolves round
    ↓
API broadcasts WebSocket DUEL_ROUND_RESOLVED to Player A
API broadcasts WebSocket DUEL_ROUND_RESOLVED to Player B
API returns response to Player A (with round_resolved: true)
    ↓
Player A receives:
  - API response → updates match state (NO popup)
  - WebSocket event → shows popup
Player B receives:
  - WebSocket event → shows popup
    ↓
Result: Both players see exactly ONE popup
```

---

## The 6 Attack Styles (Exact Specification)

**All hit chance modifiers are MULTIPLICATIVE** - fair across all stat levels.
A -20% penalty costs the same relative amount whether you have 30% or 70% base hit.

### Balanced (default)
- No modifiers.

### Aggressive (attack-forward)
- **Rolls:** +1 roll this round (still capped by your existing cap)
- **Hit chance:** ×0.80 (20% less accurate - swinging wild)
- **Effect:** more chances to spike, but each swing is riskier.

### Precise (anti-miss)
- **Hit chance:** ×1.20 (20% more accurate - careful aim)
- **Crit rate:** ×0.50 (50% fewer crits - not swinging for the fences)
- **Effect:** fewer "all miss" rounds, but fewer crits too.

### Power (leadership-forward)
- **If you win the round:** push multiplier ×1.25
- **If you lose:** opponent push multiplier ×1.20 (you left yourself open)
- **Effect:** higher drama; leadership already scales push, this amplifies it.

### Guard (defense-forward)
- **Opponent hit chance:** ×0.80 (opponent is 20% less accurate)
- **Your rolls:** -1 roll (min 1)
- **Effect:** reduces opponent spike potential; you trade offense.

### Feint (bluff, but still "numbers")
- **If both sides' best outcome tier ties** (hit vs hit, crit vs crit, miss vs miss): you win the tiebreak. if both have, still a draw
- **Effect:** gives you a reason to "predict" the opponent's choice without inventing new systems.

---

## Round Flow (End-to-End)

### Phase 1: Style Selection (10 seconds)
```
Round starts
    ↓
Both players see style picker (styles from server config)
    ↓
Player A picks "Aggressive" → POST /duels/{id}/lock-style
Player B picks "Guard" → POST /duels/{id}/lock-style
    ↓
Server calculates COMBINED effects (MULTIPLICATIVE):
  - A's hit chance: base × 0.80 (aggressive) × 0.80 (B's guard) = base × 0.64
  - A's rolls: base + 1 (aggressive)
  - B's hit chance: base × 1.0 (no self-modifier)
  - B's rolls: base - 1 (guard)
    ↓
Timer expires OR both locked → Style phase ends
```

### Phase 2: Swing Phase (Player Controls Each Swing)

ANIMATION SHOWS EACH CHOSEN STYLE, EFFECTS ARE APPLIED TO PROBABILITY BAR (MISSING)
(ADD CARD CHIPS TO SHOW EACH CHOSEN STYLE)
```
Player A clicks SWING → POST /duels/{id}/swing
    ↓
Server generates ONE roll with A's modified odds
Server returns: { outcome: "miss", value: 73.2 }
    ↓
Frontend displays the roll result
    ↓
Player A sees: "Roll 1: MISS" 
Player A has 2 swings remaining (because +1 from Aggressive)
    ↓
Player A clicks SWING again → gets "HIT"
Player A clicks SWING again → gets "MISS"
    ↓
Player A clicks STOP (or uses all swings)
Server records A's LAST roll: HIT (swinging again would REPLACE this!)
    ↓
Player A waits for B to finish
```

### Phase 3: Resolution & Reveal
```
Both players submitted
    ↓
Server compares best outcomes:
  - A's best: HIT
  - B's best: HIT
  - TIE! Check feint...
  - Neither has feint → No push (parried)
    ↓
Server broadcasts REVEAL to both:
{
  "challenger_style": "aggressive",
  "opponent_style": "guard",
  "challenger_best": "hit",
  "opponent_best": "hit",
  "winner": null,
  "push": 0,
  "feint_winner": null
}
    ↓
Frontend shows reveal screen with both styles and outcomes
```

---

## UI Requirements (Frontend)

### Style Selection Card
Server sends style config:
```json
{
  "attack_styles": [
    {
      "id": "aggressive",
      "name": "Aggressive",
      "icon": "flame.fill",
      "description": "+1 roll, -20% hit chance",
      "hit_chance_mod": -20,
      "roll_bonus": 1
    },
    {
      "id": "guard",
      "name": "Guard",
      "icon": "shield.fill",
      "description": "-1 roll, opponent -20% hit chance",
      "roll_bonus": -1,
      "opponent_hit_mod": -20
    }
  ]
}
```

Frontend displays:
- Style name and icon (from server)
- Effects on SELF (green/red indicators)
- Effects on OPPONENT (show these clearly!)
- Timer countdown

### Active Style Display (After Locking)
Show:
- Your locked style with its effects
- Whether opponent has locked (not WHICH style yet)
- Modified probability bar reflecting YOUR style + opponent's style (if known)

### Probability Bar
Must show MODIFIED odds from server:
```
Base: 65% hit → With Aggressive (×0.80) + Enemy Guard (×0.80) → 41.6% hit
```
Server sends the final calculated odds. Frontend just displays them.

### Swing Phase UI

**Button Layout: ALWAYS 50/50 side-by-side**
```
┌─────────────────────────────────────────┐
│  [    SWING    ]  [    SUBMIT    ]     │
│   (3 left)          (Lock HIT)          │
└─────────────────────────────────────────┘
```

- **SWING button** - always visible (left side, 50%)
  - Enabled when can swing, disabled otherwise
  - Shows swings remaining or "Done" when exhausted
  
- **SUBMIT button** - always visible (right side, 50%)
  - Enabled after at least 1 swing, disabled before
  - Shows "Lock [CURRENT]" (e.g. "Lock HIT") or "Swing first" when disabled
  - **KEY DECISION**: Swinging again REPLACES your current roll - risk vs reward!

- **Forfeit button** - in top-right header (flag icon)
  - NOT in the bottom button area
  - Prevents accidental taps when buttons shift

**Why this layout?**
- Buttons never appear/disappear causing layout shift
- User can't accidentally tap SUBMIT when SWING button expands
- Clear, predictable interaction pattern

### Reveal Screen
Show:
- Your style (icon + name)
- Opponent's style (icon + name)  
- Your final roll (what you stopped with)
- Opponent's final roll
- Winner indicator
- Push amount (with style multipliers applied)
- If feint won a tie, show "FEINT WINS TIE!"

---

## Backend API Changes

### Modified Endpoints

#### POST /duels/{id}/swing
Does ONE swing, returns one result:
```json
{
  "roll_number": 2,
  "value": 45.3,
  "outcome": "hit",
  "swings_used": 2,
  "swings_remaining": 1,
  "best_outcome": "hit",
  "can_stop": true
}
```

#### POST /duels/{id}/stop
Locks in your CURRENT roll (your last swing result), waits for opponent:
```json
{
  "submitted": true,
  "best_outcome": "hit",
  "waiting_for_opponent": true
}
```

#### GET /duels/{id} (match state)
Returns modified odds based on BOTH styles:
```json
{
  "your_hit_chance": 52,
  "your_crit_chance": 8,
  "your_miss_chance": 40,
  "your_max_swings": 4,
  "opponent_style_locked": true,
  "style_effects_applied": {
    "your_style": "aggressive",
    "hit_mod": -5,
    "roll_mod": +1,
    "opponent_guard_effect": -8
  }
}
```

---

## Database Fields

### duel_matches table
```sql
-- Style tracking
style_lock_expires_at TIMESTAMP
challenger_style VARCHAR(20)
opponent_style VARCHAR(20)
challenger_style_locked_at TIMESTAMP
opponent_style_locked_at TIMESTAMP

-- Per-swing tracking (existing)
turn_swings_used INTEGER
turn_max_swings INTEGER
turn_best_outcome VARCHAR(20)
turn_best_push FLOAT
turn_rolls JSONB
```

---

## Key Implementation Notes

1. **Style effects are MUTUAL** - Guard affects your OPPONENT's hit chance, not yours
2. **Odds calculated on server** - Frontend never does math
3. **One swing at a time** - User controls when to stop
4. **Last roll counts** - Swinging again REPLACES your current roll (press your luck!)
5. **Reveal shows everything** - Both styles, both outcomes, winner, push amount
