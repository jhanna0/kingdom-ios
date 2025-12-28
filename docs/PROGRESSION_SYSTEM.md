# Character Progression & Gold Economy

## Overview
Kingdom uses a **Gold + Reputation** progression system inspired by Eve Online. Players earn gold from activities and must make strategic choices about how to spend it.

---

## Core Currencies

### 💰 Gold (Spendable)
- Primary currency earned from all activities
- Used for: training, XP purchases, coups, properties, etc.
- **Strategic Resource**: Forces choices between immediate power vs long-term investments

### ⭐ Reputation (Permanent, Public)
- Earned through contributions to kingdoms
- **Cannot be bought with gold** (prevents pay-to-win)
- Permanent and publicly visible (like Eve Online standings)
- Gates access to political power (voting, coups)

---

## Earning Rewards

### Contracts (Main Income)
- **Gold**: Payment set by ruler (varies by contract)
- **Reputation**: +10 per contract completed
- **Where**: In current kingdom only

### Daily Check-In
- **Gold**: +50g
- **Reputation**: +5
- **Requirement**: Once per day, must be physically present

### Successful Coup
- **Gold**: +1000g (massive reward)
- **Reputation**: +50 (huge boost)

### Defend Against Coup
- **Gold**: +200g
- **Reputation**: +25

---

## Reputation Tiers

### Stranger (0-49 rep)
- 🔓 Accept contracts
- 🔒 Everything else locked

### Resident (50-149 rep)
- 🔓 Buy property
- 🔒 Can't vote yet

### Citizen (150-299 rep)
- 🔓 **Vote on coups**
- 🔒 Can't propose coups

### Notable (300-499 rep)
- 🔓 **Propose coups**
- Vote weight: 1x + leadership

### Champion (500-999 rep)
- 🔓 All abilities
- **Vote weight: 2x + leadership**

### Legendary (1000+ rep)
- 🔓 All abilities
- **Vote weight: 3x + leadership**

---

## Character Progression

### Leveling System
```
Level 1 → 2: 100 XP
Level 2 → 3: 200 XP
Level 3 → 4: 400 XP
Level 4 → 5: 800 XP
(Exponential: 100 * 2^(level-1))
```

**Level Up Rewards:**
- +3 Skill Points (free stat increases)
- +50g bonus gold

### Getting Experience
**XP is NOT earned automatically** - you must purchase it with gold!

```
Purchase XP:
- Small: 10 XP for 100g
- Medium: 50 XP for 500g
- Large: 100 XP for 1000g

Rate: 10 gold = 1 XP
```

**Strategic Choice**: Invest in character growth vs other opportunities

---

## Combat Stats

### ⚔️ Attack Power
- Increases offensive strength in coups
- Higher attack = better coup success chance

### 🛡️ Defense Power
- Helps defend your kingdom against coups
- Higher defense = harder to overthrow

### 👑 Leadership
- Bonus to your vote weight in coups
- Helps recruit allies (future feature)

---

## Training (Spending Gold)

### Two Paths to Power

#### Path 1: Buy XP → Level Up → Free Skill Points
```
Example:
1. Spend 1000g to buy 100 XP
2. Level up (gain 3 skill points)
3. Use skill points to increase any stat (FREE)

Cost: Efficient long-term
Speed: Slower (need to level up)
```

#### Path 2: Direct Stat Training (Instant but Expensive)
```
Training Cost Formula: 100 * (stat_level^1.5)

Examples:
- Attack 1→2: 100g
- Attack 2→3: 282g
- Attack 5→6: 559g
- Attack 10→11: 1,581g

Cost: Gets expensive quickly
Speed: Instant power boost
```

---

## Strategic Choices

### Early Game
Focus on **reputation** to unlock voting/coups
- Accept every contract you can
- Check in daily
- Build rep in one kingdom first

### Mid Game
Choose your path:
1. **Power Player**: Buy XP, level up, get strong for coups
2. **Property Baron**: Save gold, buy properties for passive income
3. **Balanced**: Mix of both

### Late Game
Once you have rep + power:
- Attempt coups (300+ rep required)
- Vote in political decisions (vote weight = tier + leadership)
- Defend your kingdom

---

## Coup System (Reputation-Gated)

### Proposing a Coup
**Requirements:**
- 300+ reputation in that kingdom
- Must be checked in
- Pays gold to initiate

### Voting on Coups
**Requirements:**
- 150+ reputation in that kingdom
- Must be checked in during voting period

**Vote Weight:**
```
Base weight = Reputation tier multiplier (1x/2x/3x)
+ Leadership stat
```

### Example Vote Weights
```
Citizen (150 rep) + 2 leadership = 3 votes
Notable (300 rep) + 5 leadership = 6 votes
Champion (500 rep) + 10 leadership = 20 votes
Legendary (1000 rep) + 10 leadership = 30 votes
```

---

## Gold Management Tips

### Save For:
- **Coups**: Need gold to initiate (TBD cost)
- **Properties**: 1000-5000g for passive income
- **Emergency training**: Quick power boost before important coup

### Spend On:
- **XP purchases**: Best long-term value
- **Direct training**: When you need power NOW
- **Skill points**: Most efficient (free after leveling)

### Don't:
- Waste gold on unnecessary early training
- Forget to check in daily (free 50g)
- Ignore reputation (gates everything important)

---

## Future Features (Planned)

### Properties
- Buy income-generating buildings in kingdoms
- Requires 50+ reputation
- Generates passive gold over time

### Equipment
- Weapons: Boost attack
- Armor: Boost defense
- Banners: Boost leadership

### Specializations
- Warrior: Bonus attack
- Merchant: Bonus gold from contracts
- Diplomat: Bonus leadership
- Engineer: Buildings complete faster

---

## Summary

**Gold + Reputation** system creates meaningful choices:
- Earn gold from activities
- Earn reputation from contributions (can't buy)
- Choose how to spend gold strategically
- Reputation gates political power
- Power comes from investment, not automatic rewards

This prevents:
- Mindless grinding
- Pay-to-win reputation
- Automatic progression without choices

And encourages:
- Strategic resource management
- Long-term planning
- Kingdom loyalty (reputation is per-kingdom)
- Active participation in community



