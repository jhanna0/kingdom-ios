# New Achievements Proposal

This document proposes new achievement categories and specific achievements for review before implementation.

**Reward Philosophy**: Only gold rewards (no XP per existing system).

---

## 1. CRAFTING ACHIEVEMENTS

Track crafting equipment (weapons and armor) through the unified contract system.

### Items Crafted (Total)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `items_crafted` | 1 | 100 | 50 | Apprentice Smith I | Craft 100 items | `hammer.fill` |
| `items_crafted` | 2 | 500 | 200 | Apprentice Smith II | Craft 500 items | `hammer.fill` |
| `items_crafted` | 3 | 1000 | 500 | Journeyman Smith | Craft 1000 items | `hammer.fill` |
| `items_crafted` | 4 | 2500 | 1000 | Expert Smith | Craft 2500 items | `hammer.fill` |
| `items_crafted` | 5 | 5000 | 2000 | Master Smith | Craft 5000 items | `hammer.fill` |
| `items_crafted` | 6 | 10000 | 4000 | Veteran Smith | Craft 10000 items | `hammer.fill` |
| `items_crafted` | 7 | 25000 | 10000 | Legendary Smith | Craft 25000 items | `hammer.fill` |

### Weapons Crafted

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `weapons_crafted` | 1 | 25 | 50 | Blade Forger I | Craft 25 weapons | `axiom` |
| `weapons_crafted` | 2 | 50 | 100 | Blade Forger II | Craft 50 weapons | `axiom` |
| `weapons_crafted` | 3 | 100 | 200 | Blade Forger III | Craft 100 weapons | `axiom` |
| `weapons_crafted` | 4 | 250 | 500 | Blade Forger IV | Craft 250 weapons | `axiom` |
| `weapons_crafted` | 5 | 500 | 1000 | Blade Forger V | Craft 500 weapons | `axiom` |
| `weapons_crafted` | 6 | 1000 | 2500 | Blade Forger VI | Craft 1000 weapons | `axiom` |

### Armor Crafted

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `armor_crafted` | 1 | 25 | 50 | Armor Smith I | Craft 25 armor pieces | `shield.fill` |
| `armor_crafted` | 2 | 50 | 100 | Armor Smith II | Craft 50 armor pieces | `shield.fill` |
| `armor_crafted` | 3 | 100 | 200 | Armor Smith III | Craft 100 armor pieces | `shield.fill` |
| `armor_crafted` | 4 | 250 | 500 | Armor Smith IV | Craft 250 armor pieces | `shield.fill` |
| `armor_crafted` | 5 | 500 | 1000 | Armor Smith V | Craft 500 armor pieces | `shield.fill` |
| `armor_crafted` | 6 | 1000 | 2500 | Armor Smith VI | Craft 1000 armor pieces | `shield.fill` |

### Tier 5 Items (Rare)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `craft_tier_5_item` | 1 | 1 | 150 | Master Craftsman I | Craft 1 Tier 5 item | `star.fill` |
| `craft_tier_5_item` | 2 | 5 | 300 | Master Craftsman II | Craft 5 Tier 5 items | `star.fill` |
| `craft_tier_5_item` | 3 | 10 | 600 | Master Craftsman III | Craft 10 Tier 5 items | `star.fill` |
| `craft_tier_5_item` | 4 | 25 | 1500 | Master Craftsman IV | Craft 25 Tier 5 items | `star.fill` |
| `craft_tier_5_item` | 5 | 50 | 3000 | Master Craftsman V | Craft 50 Tier 5 items | `star.fill` |

---

## 2. FORTIFICATION ACHIEVEMENTS

Track sacrificing gear to fortify properties.

### Items Sacrificed

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `items_sacrificed` | 1 | 10 | 75 | Wall Builder I | Sacrifice 10 items to fortify | `brick.fill` |
| `items_sacrificed` | 2 | 25 | 150 | Wall Builder II | Sacrifice 25 items to fortify | `brick.fill` |
| `items_sacrificed` | 3 | 50 | 300 | Wall Builder III | Sacrifice 50 items to fortify | `brick.fill` |
| `items_sacrificed` | 4 | 100 | 600 | Wall Builder IV | Sacrifice 100 items to fortify | `brick.fill` |
| `items_sacrificed` | 5 | 250 | 1500 | Wall Builder V | Sacrifice 250 items to fortify | `brick.fill` |
| `items_sacrificed` | 6 | 500 | 3000 | Wall Builder VI | Sacrifice 500 items to fortify | `brick.fill` |

### Max Fortification

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `max_fortification` | 1 | 1 | 250 | Fortress Builder I | Reach 100% fortification on property | `building.columns.fill` |

## 3. RULER ACHIEVEMENTS

Track ruling kingdoms, empire building, and treasury.

### Days as Ruler (Cumulative)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `days_as_ruler` | 1 | 30 | 100 | New Monarch | Complete 1 full reign (30 days) | `crown.fill` |
| `days_as_ruler` | 2 | 90 | 250 | Established Ruler | Rule for 90 days total (3 months) | `crown.fill` |
| `days_as_ruler` | 3 | 180 | 500 | Veteran Ruler | Rule for 180 days total (6 months) | `crown.fill` |
| `days_as_ruler` | 4 | 365 | 1000 | Year King | Rule for 365 days total (1 year) | `crown.fill` |
| `days_as_ruler` | 5 | 730 | 2500 | Eternal Ruler | Rule for 730 days total (2 years) | `crown.fill` |

### Empire Size

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `empire_size` | 1 | 1 | 100 | First Crown | Become a ruler | `crown.fill` |
| `empire_size` | 2 | 2 | 500 | Dual Ruler | 2 kingdoms in empire | `map.fill` |
| `empire_size` | 3 | 3 | 1000 | Triple Crown | 3 kingdoms in empire | `map.fill` |
| `empire_size` | 4 | 5 | 2500 | Emperor | 5 kingdoms in empire | `map.fill` |
| `empire_size` | 5 | 7 | 5000 | High Emperor | 7 kingdoms in empire | `map.fill` |
| `empire_size` | 6 | 10 | 10000 | World Conqueror | 10 kingdoms in empire | `map.fill` |

### Treasury Collected (Taxes)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `treasury_collected` | 1 | 1000 | 50 | Tax Collector I | Collect 1,000g in taxes | `banknote.fill` |
| `treasury_collected` | 2 | 5000 | 100 | Tax Collector II | Collect 5,000g in taxes | `banknote.fill` |
| `treasury_collected` | 3 | 25000 | 250 | Tax Collector III | Collect 25,000g in taxes | `banknote.fill` |
| `treasury_collected` | 4 | 100000 | 500 | Tax Collector IV | Collect 100,000g in taxes | `banknote.fill` |
| `treasury_collected` | 5 | 500000 | 1000 | Tax Collector V | Collect 500,000g in taxes | `banknote.fill` |
| `treasury_collected` | 6 | 1000000 | 2500 | Master Treasurer | Collect 1,000,000g in taxes | `banknote.fill` |

---

## 4. COUP ACHIEVEMENTS

Track coup-related activities.

### Coups Initiated

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `coups_initiated` | 1 | 1 | 100 | Schemer I | Initiate 1 coup | `theatermasks.fill` |
| `coups_initiated` | 2 | 3 | 200 | Schemer II | Initiate 3 coups | `theatermasks.fill` |

### Successful Coups (Won)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `coups_won` | 1 | 1 | 150 | Usurper I | Win 1 coup | `bolt.fill` |
| `coups_won` | 2 | 3 | 300 | Usurper II | Win 3 coups | `bolt.fill` |
| `coups_won` | 3 | 5 | 600 | Usurper III | Win 5 coups | `bolt.fill` |
| `coups_won` | 4 | 10 | 1500 | Usurper IV | Win 10 coups | `bolt.fill` |
| `coups_won` | 5 | 25 | 3000 | Kingslayer | Win 25 coups | `bolt.fill` |


## 5. INVASION & BATTLE ACHIEVEMENTS

Track invasion and battle participation.

### Invasions Participated

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `invasions_participated` | 1 | 1 | 50 | Warrior I | Participate in 1 invasion | `figure.walk` |
| `invasions_participated` | 2 | 5 | 100 | Warrior II | Participate in 5 invasions | `figure.walk` |
| `invasions_participated` | 3 | 15 | 200 | Warrior III | Participate in 15 invasions | `figure.walk` |
| `invasions_participated` | 4 | 30 | 500 | Warrior IV | Participate in 30 invasions | `figure.walk` |
| `invasions_participated` | 5 | 50 | 1000 | Warrior V | Participate in 50 invasions | `figure.walk` |
| `invasions_participated` | 6 | 100 | 2500 | Veteran | Participate in 100 invasions | `figure.walk` |

### Invasions Won (Attacker)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `invasions_won_attack` | 1 | 1 | 150 | Conqueror I | Win 1 invasion as attacker | `flag.fill` |
| `invasions_won_attack` | 2 | 3 | 300 | Conqueror II | Win 3 invasions as attacker | `flag.fill` |
| `invasions_won_attack` | 3 | 10 | 600 | Conqueror III | Win 10 invasions as attacker | `flag.fill` |
| `invasions_won_attack` | 4 | 25 | 1500 | Conqueror IV | Win 25 invasions as attacker | `flag.fill` |

### Invasions Defended

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `invasions_won_defend` | 1 | 1 | 150 | Defender I | Defend 1 invasion successfully | `shield.checkered` |
| `invasions_won_defend` | 2 | 3 | 300 | Defender II | Defend 3 invasions successfully | `shield.checkered` |
| `invasions_won_defend` | 3 | 10 | 600 | Defender III | Defend 10 invasions successfully | `shield.checkered` |
| `invasions_won_defend` | 4 | 25 | 1500 | Defender IV | Defend 25 invasions successfully | `shield.checkered` |
| `invasions_won_defend` | 5 | 50 | 3000 | Legendary Defender | Defend 50 invasions successfully | `shield.checkered` |

## 6. PVP ACHIEVEMENTS

Track player-vs-player combat (duels).

### Duels Fought (Total)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `duels_fought` | 1 | 10 | 25 | Duelist I | Fight 10 duels | `figure.fencing` |
| `duels_fought` | 2 | 50 | 50 | Duelist II | Fight 50 duels | `figure.fencing` |
| `duels_fought` | 3 | 100 | 100 | Duelist III | Fight 100 duels | `figure.fencing` |
| `duels_fought` | 4 | 250 | 200 | Duelist IV | Fight 250 duels | `figure.fencing` |
| `duels_fought` | 5 | 500 | 500 | Duelist V | Fight 500 duels | `figure.fencing` |
| `duels_fought` | 6 | 1000 | 1000 | Duelist VI | Fight 1000 duels | `figure.fencing` |
| `duels_fought` | 7 | 2500 | 2500 | Arena Legend | Fight 2500 duels | `figure.fencing` |

### Duels Won

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `duels_won` | 1 | 5 | 25 | Victor I | Win 5 duels | `trophy.fill` |
| `duels_won` | 2 | 25 | 50 | Victor II | Win 25 duels | `trophy.fill` |
| `duels_won` | 3 | 50 | 100 | Victor III | Win 50 duels | `trophy.fill` |
| `duels_won` | 4 | 100 | 200 | Victor IV | Win 100 duels | `trophy.fill` |
| `duels_won` | 5 | 250 | 500 | Victor V | Win 250 duels | `trophy.fill` |
| `duels_won` | 6 | 500 | 1000 | Victor VI | Win 500 duels | `trophy.fill` |
| `duels_won` | 7 | 1000 | 2500 | Grand Champion | Win 1000 duels | `trophy.fill` |

### Unique Opponents Defeated

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `unique_opponents` | 1 | 10 | 50 | Rival Collector I | Defeat 10 different players | `person.badge.minus` |
| `unique_opponents` | 2 | 25 | 100 | Rival Collector II | Defeat 25 different players | `person.badge.minus` |
| `unique_opponents` | 3 | 50 | 200 | Rival Collector III | Defeat 50 different players | `person.badge.minus` |
| `unique_opponents` | 4 | 100 | 500 | Rival Collector IV | Defeat 100 different players | `person.badge.minus` |
| `unique_opponents` | 5 | 250 | 1000 | Rival Collector V | Defeat 250 different players | `person.badge.minus` |
| `unique_opponents` | 6 | 500 | 2500 | Champion of All | Defeat 500 different players | `person.badge.minus` |

---

## 7. INTELLIGENCE ACHIEVEMENTS

Track covert operations and infiltration outcomes.

### Operations Attempted

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `operations_attempted` | 1 | 10 | 25 | Spy I | Attempt 10 infiltrations | `eye.fill` |
| `operations_attempted` | 2 | 25 | 50 | Spy II | Attempt 25 infiltrations | `eye.fill` |
| `operations_attempted` | 3 | 50 | 100 | Spy III | Attempt 50 infiltrations | `eye.fill` |
| `operations_attempted` | 4 | 100 | 200 | Spy IV | Attempt 100 infiltrations | `eye.fill` |
| `operations_attempted` | 5 | 250 | 500 | Spy V | Attempt 250 infiltrations | `eye.fill` |
| `operations_attempted` | 6 | 500 | 1000 | Spy VI | Attempt 500 infiltrations | `eye.fill` |
| `operations_attempted` | 7 | 1000 | 2500 | Spymaster | Attempt 1000 infiltrations | `eye.fill` |

### Intel Gathered (Success)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `intel_gathered` | 1 | 5 | 50 | Intel Collector I | Gather intel 5 times | `doc.text.magnifyingglass` |
| `intel_gathered` | 2 | 15 | 100 | Intel Collector II | Gather intel 15 times | `doc.text.magnifyingglass` |
| `intel_gathered` | 3 | 30 | 200 | Intel Collector III | Gather intel 30 times | `doc.text.magnifyingglass` |
| `intel_gathered` | 4 | 75 | 500 | Intel Collector IV | Gather intel 75 times | `doc.text.magnifyingglass` |
| `intel_gathered` | 5 | 150 | 1000 | Intel Collector V | Gather intel 150 times | `doc.text.magnifyingglass` |
| `intel_gathered` | 6 | 300 | 2500 | Intelligence Director | Gather intel 300 times | `doc.text.magnifyingglass` |

### Sabotages Completed (Rare Outcome)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `sabotages_completed` | 1 | 1 | 150 | Saboteur I | Complete 1 sabotage | `wrench.and.screwdriver.fill` |
| `sabotages_completed` | 2 | 5 | 300 | Saboteur II | Complete 5 sabotages | `wrench.and.screwdriver.fill` |
| `sabotages_completed` | 3 | 10 | 600 | Saboteur III | Complete 10 sabotages | `wrench.and.screwdriver.fill` |
| `sabotages_completed` | 4 | 25 | 1500 | Saboteur IV | Complete 25 sabotages | `wrench.and.screwdriver.fill` |
| `sabotages_completed` | 5 | 50 | 3000 | Master Saboteur | Complete 50 sabotages | `wrench.and.screwdriver.fill` |

### Vault Heists (Very Rare Outcome)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `heists_completed` | 1 | 1 | 150 | Thief I | Complete 1 vault heist | `dollarsign.circle.fill` |
| `heists_completed` | 2 | 3 | 300 | Thief II | Complete 3 vault heists | `dollarsign.circle.fill` |
| `heists_completed` | 3 | 5 | 600 | Thief III | Complete 5 vault heists | `dollarsign.circle.fill` |
| `heists_completed` | 4 | 10 | 1500 | Thief IV | Complete 10 vault heists | `dollarsign.circle.fill` |
| `heists_completed` | 5 | 25 | 3000 | Master Thief | Complete 25 vault heists | `dollarsign.circle.fill` |

## 8. GARDENING ACHIEVEMENTS

Track garden activities, flowers, and harvests.

### Plants Grown (Total)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `plants_grown` | 1 | 25 | 25 | Gardener I | Grow 25 plants | `leaf.fill` |
| `plants_grown` | 2 | 100 | 50 | Gardener II | Grow 100 plants | `leaf.fill` |
| `plants_grown` | 3 | 250 | 100 | Gardener III | Grow 250 plants | `leaf.fill` |
| `plants_grown` | 4 | 500 | 200 | Gardener IV | Grow 500 plants | `leaf.fill` |
| `plants_grown` | 5 | 1000 | 500 | Gardener V | Grow 1000 plants | `leaf.fill` |
| `plants_grown` | 6 | 2500 | 1000 | Gardener VI | Grow 2500 plants | `leaf.fill` |
| `plants_grown` | 7 | 5000 | 2500 | Master Gardener | Grow 5000 plants | `leaf.fill` |

### Flowers Grown

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `flowers_grown` | 1 | 10 | 25 | Florist I | Grow 10 flowers | `camera.macro` |
| `flowers_grown` | 2 | 50 | 50 | Florist II | Grow 50 flowers | `camera.macro` |
| `flowers_grown` | 3 | 150 | 100 | Florist III | Grow 150 flowers | `camera.macro` |
| `flowers_grown` | 4 | 400 | 200 | Florist IV | Grow 400 flowers | `camera.macro` |
| `flowers_grown` | 5 | 1000 | 500 | Florist V | Grow 1000 flowers | `camera.macro` |
| `flowers_grown` | 6 | 2500 | 1000 | Master Florist | Grow 2500 flowers | `camera.macro` |

### Rare Flowers

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `rare_flowers_grown` | 1 | 1 | 100 | Rare Bloom I | Grow 1 rare flower | `sparkle` |
| `rare_flowers_grown` | 2 | 5 | 200 | Rare Bloom II | Grow 5 rare flowers | `sparkle` |
| `rare_flowers_grown` | 3 | 15 | 400 | Rare Bloom III | Grow 15 rare flowers | `sparkle` |
| `rare_flowers_grown` | 4 | 30 | 800 | Rare Bloom IV | Grow 30 rare flowers | `sparkle` |
| `rare_flowers_grown` | 5 | 50 | 1500 | Rare Bloom V | Grow 50 rare flowers | `sparkle` |
| `rare_flowers_grown` | 6 | 100 | 3000 | Legendary Botanist | Grow 100 rare flowers | `sparkle` |

### Wheat Harvested

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `wheat_harvested` | 1 | 50 | 25 | Farmer I | Harvest 50 wheat | `carrot.fill` |
| `wheat_harvested` | 2 | 200 | 50 | Farmer II | Harvest 200 wheat | `carrot.fill` |
| `wheat_harvested` | 3 | 500 | 100 | Farmer III | Harvest 500 wheat | `carrot.fill` |
| `wheat_harvested` | 4 | 1000 | 200 | Farmer IV | Harvest 1000 wheat | `carrot.fill` |
| `wheat_harvested` | 5 | 2500 | 500 | Farmer V | Harvest 2500 wheat | `carrot.fill` |
| `wheat_harvested` | 6 | 5000 | 1000 | Master Farmer | Harvest 5000 wheat | `carrot.fill` |

### Weeds Cleared

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `weeds_cleared` | 1 | 25 | 25 | Weed Puller I | Clear 25 weeds | `xmark.circle.fill` |
| `weeds_cleared` | 2 | 100 | 50 | Weed Puller II | Clear 100 weeds | `xmark.circle.fill` |
| `weeds_cleared` | 3 | 250 | 100 | Weed Puller III | Clear 250 weeds | `xmark.circle.fill` |
| `weeds_cleared` | 4 | 500 | 200 | Weed Puller IV | Clear 500 weeds | `xmark.circle.fill` |
| `weeds_cleared` | 5 | 1000 | 500 | Weed Puller V | Clear 1000 weeds | `xmark.circle.fill` |

### Flower Colors (Unique)

| Type | Tier | Target | Gold | Display Name | Description | Icon |
|------|------|--------|------|--------------|-------------|------|
| `flower_colors` | 1 | 3 | 100 | Color Collector I | Collect 3 different flower colors | `paintpalette.fill` |
| `flower_colors` | 2 | 6 | 250 | Color Collector II | Collect 6 different flower colors | `paintpalette.fill` |
| `flower_colors` | 3 | 10 | 500 | Rainbow Garden | Collect all 10 flower colors | `paintpalette.fill` |

---

## Summary of Achievement Counts

| Category | Achievement Types | Total Tiers |
|----------|-------------------|-------------|
| Crafting | 4 types | 24 tiers |
| Fortification | 3 types | 14 tiers |
| Ruler | 4 types | 24 tiers |
| Coup | 4 types | 21 tiers |
| Invasion & Battle | 4 types | 21 tiers |
| PVP | 4 types | 25 tiers |
| Intelligence | 5 types | 35 tiers |
| Gardening | 6 types | 34 tiers |
| **TOTAL** | **34 types** | **198 tiers** |

---

## Implementation Notes

1. **Display Order Ranges**:
   - Crafting: 400-499
   - Fortification: 500-549
   - Ruler: 550-599
   - Coup: 600-649
   - Invasion/Battle: 650-699
   - PVP: 700-799
   - Intelligence: 800-849
   - Gardening: 850-949

2. **Category Slugs**:
   - `crafting`, `fortification`, `ruler`, `coup`, `battle`, `pvp`, `intelligence`, `gardening`

3. **Backend Fixes Applied**:
   - `apply_kingdom_tax()` now increments `total_income_collected`
   - Ruler changes now update `total_reign_duration_hours` on `UserKingdom`

---

## Backend Data Architecture

### NEW STAT TABLES NEEDED (Migration: `add_achievement_stats.sql`)

| Table | Columns | Increment When |
|-------|---------|----------------|
| `player_combat_stats` | `coups_defended` | Defender wins coup |
| | `invasions_participated` | Player joins invasion |
| | `invasions_won_attack` | Attacker wins invasion |
| | `invasions_won_defend` | Defender wins invasion |
| `player_intelligence_stats` | `operations_attempted` | Any scout/intel action started |
| | `operations_succeeded` | Scout action succeeds |
| | `intel_gathered` | Intel outcome from scout |
| | `disruptions_caused` | Disruption outcome from scout |
| | `sabotages_completed` | Sabotage outcome from scout |
| | `heists_completed` | Heist outcome from scout (T5) |
| | `operations_prevented` | Defender catches infiltrator |
| `player_garden_stats` | `plants_grown` | Any plant harvested |
| | `flowers_grown` | Flower-type plant harvested |
| | `rare_flowers_grown` | Rare flower harvested |
| | `wheat_harvested` | Wheat harvested (count) |
| | `weeds_cleared` | Weed cleared from slot |
| | `flower_colors_collected` | TEXT[] - add new colors |
| `player_fortification_stats` | `items_sacrificed` | Item used for fortification |
| | `fortification_gained` | Total % gained |
| | `properties_survived` | Property survives invasion |

### COMPUTED FROM EXISTING TABLES (No new storage)

| Achievement Type | Source | Query |
|------------------|--------|-------|
| `items_crafted` | `player_items` | `COUNT(*) WHERE user_id = ?` |
| `weapons_crafted` | `player_items` | `COUNT(*) WHERE user_id = ? AND type = 'weapon'` |
| `armor_crafted` | `player_items` | `COUNT(*) WHERE user_id = ? AND type = 'armor'` |
| `craft_tier_5_item` | `player_items` | `COUNT(*) WHERE user_id = ? AND tier = 5` |
| `kingdoms_ruled` | `kingdom_history` | `COUNT(DISTINCT kingdom_id) WHERE ruler_id = ?` |
| `days_as_ruler` | `kingdom_history` | `SUM(ended_at - started_at)` in hours/24 |
| `empire_size` | `kingdoms` | `COUNT(*) WHERE ruler_id = ?` (live) |
| `coups_initiated` | `coup_events` | `COUNT(*) WHERE initiator_id = ?` |
| `coups_won` | `player_state` | Existing field |
| `coups_failed` | `player_state` | Existing field |
| `conspiracies_joined` | `coup_participants` | `COUNT(*) WHERE user_id = ?` |
| `invasions_declared` | `invasion_events` | `COUNT(*) WHERE initiator_id = ?` |
| `duel_wins` | `duel_stats` | Existing `wins` field |
| `duel_losses` | `duel_stats` | Existing `losses` field |
| `total_duels` | `duel_stats` | `wins + losses` |
| `duel_win_streak` | `duel_stats` | Existing `best_win_streak` field |
| `tax_collected` | `kingdoms` | Existing `total_income_collected` (NOW FIXED) |

### CODE CHANGES REQUIRED

| File | Change | Purpose |
|------|--------|---------|
| `api/routers/actions/tax_utils.py` | Increment `total_income_collected` | ✅ DONE |
| `api/routers/actions/tax_utils.py` | Add `update_ruler_reign_duration()` | ✅ DONE |
| `api/routers/coup.py` | Call reign duration update on ruler change | TODO |
| `api/routers/invasion.py` | Call reign duration update on ruler change | TODO |
| `api/routers/coup.py` | Increment `player_combat_stats.coups_defended` | TODO |
| `api/routers/invasion.py` | Increment `player_combat_stats` fields | TODO |
| `api/routers/actions/scout.py` | Increment `player_intelligence_stats` fields | TODO |
| `api/routers/garden.py` | Increment `player_garden_stats` fields | TODO |
| `api/routers/property.py` | Increment `player_fortification_stats` fields | TODO |

### EXISTING FIELDS STATUS

| Field | Location | Status |
|-------|----------|--------|
| `total_income_collected` | `Kingdom` | ✅ Fixed in `apply_kingdom_tax()` |
| `total_reign_duration_hours` | `UserKingdom` | ✅ Helper added, needs integration |
| `coups_won` | `player_state` | ✅ Already tracked |
| `coups_failed` | `player_state` | ✅ Already tracked |

