# Kingdom Skill Trees & Progression

## 📊 PLAYER SKILLS (5 Tiers Each)

All player skills start at Tier 1 and can be trained to Tier 5.

### ⚔️ Attack Power
**Purpose:** Offensive strength in coups and invasions

- **T1-T5:** Each tier increases combat damage
- **Training:** Purchase training contract, complete actions (2hr cooldown)

---

### 🛡️ Defense Power
**Purpose:** Defend against coups and invasions

- **T1-T5:** Each tier increases defensive strength
- **Training:** Purchase training contract, complete actions (2hr cooldown)

---

### 👑 Leadership
**Purpose:** Political power and rewards

- **T1:** Can vote on coups (base vote weight: 1)
- **T2:** +50% rewards from ruler distributions + vote weight: 1.2
- **T3:** Can **propose coups** + vote weight: 1.5
- **T4:** +100% rewards from ruler distributions + vote weight: 1.8
- **T5:** -50% coup cost (500g instead of 1000g) + vote weight: 2.0

---

### 🔨 Building Skill
**Purpose:** Construction rewards and city contribution superpowers.

- **T1:** Normal build action (2h cooldown), +0% coin reward
- **T2:** +10% coin reward for building actions
- **T3:** +20% coin reward; +1 daily "Assist" (instantly add 3 progress to a city contract)
- **T4:** +30% coin reward; 10% chance to instantly refund your build cooldown after contributing
- **T5:** +40% coin reward; 25% chance to double your work action progress when contributing to contracts
// too much but close

---

### 🧠 Intelligence
**Purpose:** Espionage, sabotage, and covert operations

- **T1:** 2% better at sabotage/patrol
- **T2:** 4% better at sabotage/patrol
- **T3:** 6% better at sabotage/patrol
- **T4:** 8% better at sabotage/patrol
- **T5:** 10% better at sabotage/patrol + **Unlock Vault Heist**
  - Vault Heist: Steal 10% of enemy vault (1000g cost, 7-day cooldown)

---

## 🏰 KINGDOM BUILDINGS (Ruler Upgrades)

All buildings have 5 tiers (T0 = unbuilt, T1-T5 = upgrades).

### Economic Buildings

#### ⛏️ Mine
**Purpose:** Unlocks material availability for purchase in the market

- **T0:** No materials available
- **T1:** Stone available for purchase (10g per unit)
- **T2:** Iron available for purchase (25g per unit)
- **T3:** Steel available for purchase (50g per unit)
- **T4:** Titanium available for purchase (100g per unit)
- **T5:** All materials available at 2x quantity per purchase per citizen

**Note:** Materials must be purchased by citizens using gold in the Market. The Mine only unlocks what materials exist in the kingdom's economy.

#### 🏪 Market
**Purpose:** Passive gold income + Material purchasing hub

- **T0:** 0 gold/day, no material purchases allowed
- **T1:** 15 gold/day, citizens can buy materials (1x quantity)
- **T2:** 35 gold/day, citizens can buy materials (1x quantity)
- **T3:** 65 gold/day, citizens can buy materials (1.5x quantity)
- **T4:** 100 gold/day, citizens can buy materials (1.5x quantity)
- **T5:** 150 gold/day, citizens can buy materials (2x quantity)

**Material Purchase System:**
- Citizens spend gold to buy materials unlocked by Mine level
- Market level determines purchase quantity multipliers
- Example: T1 Market + T2 Mine = can buy 5 iron for 25g each
- Example: T5 Market + T5 Mine = can buy 10 iron for 25g each (2x quantity)

#### 🌾 Farm
**Purpose:** Produces food that lets citizens complete city contracts faster

- **T0:** No bonus (city contracts = normal speed)
- **T1:** 5% faster contract completion for all citizens
- **T2:** 10% faster
- **T3:** 20% faster
- **T4:** 25% faster
- **T5:** 33% faster (contracts only require 2/3 as many actions)

---

### Defensive Buildings

#### 🏰 Walls
**Purpose:** Coup/invasion defense

- **T1-T5:** Each tier increases defensive strength in battles

#### 🔒 Vault
**Purpose:** Protect treasury from theft

- **T1-T5:** Each tier +5% detection chance for vault heists
  - T5 = +25% detection (very secure)

---

### Citizen Buffs

#### 📚 Education
**Purpose:** Reduce training time for all citizens

- **T0:** No bonus
- **T1:** Training 5% faster
- **T2:** Training 10% faster
- **T3:** Training 15% faster
- **T4:** Training 20% faster
- **T5:** Training 25% faster

**Example:** Player training Attack from T10 → T11
- Base: 6 actions required
- T5 Education: 6 × 0.75 = 4 actions required

---

## 🏠 PLAYER PROPERTIES (5 Tiers Each)

### 🏠 House
**Purpose:** Personal benefits and lifestyle improvements

- **T1:** 50% travel cost + instant travel to this kingdom
- **T2:** +5% faster actions when checked in here
- **T3:** +10% faster actions when checked in here
- **T4:** 50% tax reduction in this kingdom
- **T5:** 50% chance to survive conquest + retain property

### 🏢 Workshop
**Purpose:** Passive income + crafting speed

- **T1:** 10g/day
- **T2:** 25g/day + 10% faster crafting
- **T3:** 50g/day + 20% faster crafting
- **T4:** 100g/day + 30% faster crafting
- **T5:** 200g/day + 50% faster crafting
---

## ⭐ REPUTATION SYSTEM

**[TO BE DEFINED]**

Currently used for:
- Earned from completing contracts (+10), check-ins (+5), coups (+25-50)
- Required for buying property (50+ rep)
- Required for reward distributions (50+ rep)

**Needs rework:** What should reputation unlock/gate?

---

## 💰 PROGRESSION COSTS

### Training Costs
- Scales with total training purchases
- Formula: `base_cost × (1 + purchases × 0.1)`
- Prevents endless grinding

### Building Upgrade Costs
- Exponential scaling per tier
- Formula: `base × 2^(tier - 1)`

### Property Costs
- Scales with kingdom population
- Formula: `base × (1 + population / 50)`

