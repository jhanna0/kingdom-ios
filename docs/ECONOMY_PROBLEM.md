# Gold Economy Problem

## Current Gold Flow

### Faucets (gold enters)
- Farming: 10g per 10min
- Hunting: 1-12g per 30min (equal to meat earned)
- Kingdom contract work: paid from treasury (ruler sets rate)
- Science minigame: small amounts

### Sinks (gold exits)
- Training: 100 × 1.4^(total_skill_points) — exponential, uncapped
- Property: 500g to 4000g per tier
- Equipment crafting: 100g to 3000g per tier
- Scout/coups/other actions: various costs

### Circulation (gold moves player-to-player)
- Market: exists but underused
- Trades: exist but rare
- Treasury → contracts → workers: works but depends on active rulers

## The Problem

Players earn ~100g/hour. Training costs scale exponentially. Players spend all gold on training immediately. No gold left for market activity. Economy is stagnant.

## Why Standard Fixes Don't Work

| Fix | Problem |
|-----|---------|
| More gold income | Players just save it for training |
| Gold sinks to treasury | Sits there unless rulers create contracts |
| Reduce training costs | Accounts max too fast |
| Training costs resources | Changes core progression |
| Recurring costs (upkeep) | Feels punishing |

## Core Tension

- Want accounts to be maxable (long-term goal)
- Want gold to circulate (active economy)
- Want progression to be slow (not instant max)
- Training is the primary gold sink
- Training is also the primary progression

These goals conflict. Need a design solution that balances all of them.

## Solution V1: Pay-As-You-Go & Base Cost + Tax

We have refactored the economy to address the liquidity problem while maintaining necessary sinks.

**Status: IMPLEMENTED** (branch: per-action-gold)

### 1. Pay-As-You-Go (Liquidity)
Instead of huge upfront costs (e.g., 5000g to start training), players now pay per action (e.g., 15g per click).
- **Benefit:** Players can start training immediately without hoarding.
- **Benefit:** Gold leaves the economy steadily rather than in lumps.
- **Implementation:** `UnifiedContract` now tracks `cost_per_action`. `gold_paid` tracks total paid over time.

### 2. Base Cost + Tax (Sink vs. Circulation)
We implemented a "Tax on Top" model to balance inflation control with kingdom funding.
- **Old Model:** Split payment (70% burned, 30% tax). Manipulatable by Kings.
- **New Model:**
    - **Base Cost (CPA):** 100% BURNED (Destroyed). This is the deflationary sink.
    - **Tax:** Added ON TOP of Base Cost (e.g., Base 15g + 10% Tax = Player pays 16.5g).
    - **Result:** King gets 1.5g. 15g is destroyed.
- **Benefit:** The King cannot "refund" the sink. The Base Cost is always lost to the void.
- **Benefit:** Active players constantly generate tax revenue for the King without needing market transactions.

### 3. Decoupled Scaling (Tuning)
We separated the formulas for "Time Cost" and "Gold Cost" to allow independent tuning.
- **Time Sink (`calculate_training_actions_required`):** Determines how long training takes. Currently exponential.
- **Gold Sink (`calculate_training_gold_per_action`):** Determines gold drained per click. Linear: `10 + 2 * TotalSkillPoints`.

### 4. Dynamic Cost Configuration
All costs are now defined in single-source-of-truth config files. Frontend reads these dynamically.

#### Config Locations:
- `api/routers/tiers.py` - TRAINING_CONFIG, PROPERTY_TIERS, EQUIPMENT_TIERS, BUILDING_TYPES
- `api/routers/actions/action_config.py` - ACTION_TYPES with costs, COST_MODELS

#### Cost Models:
| Model | Description | Example |
|-------|-------------|---------|
| `none` | Free action | Patrol, Farm |
| `fixed_gold` | Flat gold cost | Scout (100g) |
| `per_action_gold` | Gold per action (burn + tax) | Training |
| `per_action_resources` | Resources per action | Building work |
| `upfront_gold_per_action_resources` | Gold upfront + resources per action | Property upgrades |
| `upfront_all` | All costs upfront | Crafting |

#### API Endpoints for Cost Calculation:
- `GET /tiers/costs/training?total_skill_points=X&tax_rate=Y`
- `GET /tiers/costs/property/{tier}?building_skill=X`
- `GET /tiers/costs/equipment/{tier}`
- `GET /tiers/costs/building/{type}/{tier}?population=X`

#### Implementation Files Changed:
- `api/db/models/unified_contract.py` - Added `cost_per_action` column
- `api/routers/actions/training.py` - Pay-As-You-Go logic for purchase/work
- `api/routers/tiers.py` - TRAINING_CONFIG, cost calculation endpoints
- `api/routers/actions/action_config.py` - ACTION_TYPES with costs structure
- `api/db/add_cost_per_action.sql` - Database migration

### 4. Property & Construction
- Property upgrades and land purchases also use the Pay-As-You-Go model.
- **No upfront gold cost** to start construction/upgrades
- `gold_per_action` defined in `PROPERTY_TIERS` (burned + tax on top)
- Resources (wood, iron) still consumed per action

#### Property Tier Gold Per Action:
| Tier | Name | Gold/Action |
|------|------|-------------|
| 1 | Land | 15g |
| 2 | House | 20g |
| 3 | Workshop | 25g |
| 4 | Beautiful Property | 35g |
| 5 | Defensive Walls | 50g |

#### Files Changed for Property Pay-As-You-Go:
- `api/routers/tiers.py` - Added `gold_per_action` to PROPERTY_TIERS, PROPERTY_CONFIG
- `api/routers/property.py` - Removed upfront gold, stores cost_per_action
- `api/routers/actions/contracts.py` - work_on_property_upgrade charges gold per action

---

we will be adding skill tiers that allow early levels of tiers to be worked on, BUT, there will be a total skill point factor too (number of actions). this will make early levels possible, but only give playesr the ability to max 1-2 levels easily 