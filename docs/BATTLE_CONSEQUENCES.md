# Battle Consequences - Risks & Rewards

## 💀 Failed Coup (HARSH PUNISHMENT)

When attackers lose a coup, they face **BRUTAL consequences**:

### Penalties for ALL Attackers
```swift
// 1. GOLD SEIZURE - Lose 50% of your gold!
let goldLost = player.gold / 2
player.gold -= goldLost
ruler.gold += goldLost  // Ruler takes it

// 2. REPUTATION DESTROYED - Marked as traitor
player.reputation -= 100
player.kingdomReputation[kingdom] -= 100

// 3. STAT LOSS - Beaten and weakened (PERMANENT)
player.attackPower -= 2  // Can't go below 1
player.defensePower -= 2  // Can't go below 1

// 4. PUBLICLY EXPOSED - Everyone knows you're a traitor
```

### Example
```
Bob tries to coup Alice
Bob has: 500g, 12 attack, 10 defense, 350 reputation

Coup FAILS

Bob loses:
- 250g (50% seized by Alice)
- 100 reputation (now 250 rep - lost Notable status!)
- 2 attack (now 10 attack)
- 2 defense (now 8 defense)
- Public shaming (everyone sees he's a traitor)
- Alice can execute him (optional)
```

### Why So Harsh?
- **You tried to overthrow the ruler!**
- This isn't a game - it's treason
- Makes coups HIGH RISK, HIGH REWARD
- Forces players to be strategic, not impulsive
- Successful coups are genuinely impressive

---

## ⚔️ Failed Invasion (Battle Wounds)

When attackers lose an invasion, they suffer **battle wounds**:

### Penalties for ALL Attackers
```swift
// 1. GOLD LOST - Already paid 100g upfront (lost)
// Can't get it back

// 2. REPUTATION HIT - Failed military campaign
player.reputation -= 50

// 3. WOUNDED - Temporary attack debuff
player.attackDebuff = 1  // -1 attack power
player.debuffExpires = Date() + 24 hours

// Effective attack during debuff:
let effectiveAttack = player.attackPower - player.attackDebuff
```

### Example
```
Alice invades Bordertown with 4 allies
Each paid: 100g (500g total)
Alice has: 15 attack, 1000 reputation

Invasion FAILS

Alice loses:
- 100g (paid upfront, can't recover)
- 50 reputation (now 950 rep)
- Temporarily wounded: 15 attack → 14 attack for 24 hours
- Can't invade again for 24 hours (cooldown)

All 4 allies suffer same penalties
```

### Why Wounds?
- Lost battle = wounded soldiers
- Temporary (24h) so not permanent damage
- But still hurts - can't attack again effectively
- Defenders get rewarded for good defense

---

## 🎖️ Defender Rewards

### Successful Coup Defense
```swift
// For each defender
player.gold += 200
player.reputation += 30

// For the ruler
ruler.gold += (all seized gold from attackers)
ruler.reputation += 50

// Ruler can execute attackers (optional)
```

### Successful Invasion Defense
```swift
// For each defender  
player.gold += 100  // From attacker payments
player.reputation += 30

// For the ruler
ruler.gold += 200
ruler.reputation += 50
```

---

## 📊 Risk vs Reward Comparison

### Coups (Internal Power Struggle)

| Outcome | Initiator | Other Attackers | Defenders |
|---------|-----------|-----------------|-----------|
| **Win** | Become ruler, +1000g, +50 rep | Nothing | Nothing |
| **Lose** | -50% gold, -100 rep, -2/-2 stats | -50% gold, -100 rep, -2/-2 stats | +200g, +30 rep |

**Risk Level: EXTREME**
- Initiator gets HUGE reward if they win
- But BRUTAL punishment if they lose
- All conspirators share the pain

### Invasions (External Conquest)

| Outcome | Attackers | Defending Ruler | Defenders |
|---------|-----------|-----------------|-----------|
| **Win** | Split loot, +50 rep, ruler gains city | Loses city | Nothing |
| **Lose** | -100g, -50 rep, -1 attack (24h) | +200g, +50 rep | +100g, +30 rep |

**Risk Level: HIGH**
- Good rewards for winning (conquer city!)
- Moderate punishment for losing (temporary debuff)
- Less harsh than coups

---

## 🎯 Strategic Implications

### For Coup Leaders
**High Risk, High Reward:**
- Don't start a coup unless you're CONFIDENT
- Recruit high-attack players
- Make sure you outnumber defenders
- Check wall levels (add defense to defenders)
- One failed coup can RUIN you financially and stat-wise

### For Coup Conspirators
**Think Before Joining:**
- Are you willing to lose 50% of your gold?
- Can you afford -2 attack/-2 defense permanently?
- Do you trust the leader?
- Is the reward worth the risk?

### For Invasion Leaders
**Moderate Risk, Big Reward:**
- Less risky than coups (no permanent stat loss)
- But still expensive (100g per attacker)
- Temporary debuff if you lose
- Great for empire building if you win

### For Defenders
**Always Worth It:**
- No risk - you're defending your home
- Good gold rewards
- Reputation boost
- Protect your kingdom/ruler

---

## 🔥 The Psychology

### Why Harsh Coup Penalties Work

**1. Makes Coups Rare & Meaningful**
- Not just random spam
- Each coup is a BIG DEAL
- Creates dramatic moments

**2. Rewards Successful Conspirators**
- If you pull off a coup, you EARNED it
- Overcoming harsh penalties makes victory sweeter
- Separates skilled players from impulsive ones

**3. Creates Trust Dynamics**
- Conspirators must REALLY trust the leader
- Won't join just anyone's coup
- Builds meaningful alliances

**4. Ruler Deterrent**
- Bad rulers risk coups
- But attackers risk EVERYTHING
- Creates interesting balance

### Why Invasion Penalties Are Lighter

**1. External Warfare**
- Not treason - it's war
- Should be encouraged for expansion
- Part of normal gameplay

**2. Already Expensive**
- 100g per attacker upfront
- That's already significant
- Don't need to be TOO punishing

**3. Temporary Debuff**
- Still hurts (wounded in battle)
- But recovers in 24h
- Allows for strategy (can't chain-attack)

---

## 💡 Player Advice

### When to Start a Coup
✅ **Good Time:**
- You have 400+ attack power coalition
- Walls are level 0-1 (low defense)
- Few defenders online
- You have 1000+ gold to risk
- High confidence

❌ **Bad Time:**
- Walls are level 4-5
- Lots of defenders online
- You only have 200g
- Low attack power allies
- Impulsive decision

### When to Join a Coup
✅ **Join If:**
- You trust the leader completely
- You can afford to lose 50% gold
- You have backup gold/stats
- The coalition is strong
- Worth the risk for you

❌ **Don't Join If:**
- You just met the leader
- You need that gold
- You can't afford stat loss
- Coalition looks weak
- Not confident in victory

### When to Invade
✅ **Good Time:**
- Target has low walls
- Target has few active players
- Your team has high attack
- You can afford 100g
- Neighboring kingdom

❌ **Bad Time:**
- Target has level 5 walls
- Target has active defense force
- Low attack power team
- Not confident
- Can't afford temporary debuff

---

## 🎮 In-Game UI Ideas

### Coup Warning Screen
```
⚠️ WARNING: STARTING A COUP ⚠️

If you LOSE this coup, you will:
• Lose 50% of your gold (250g)
• Lose 100 reputation
• Lose 2 attack power (12 → 10)
• Lose 2 defense power (10 → 8)
• Be exposed as a traitor
• Possible execution

This is PERMANENT and IRREVERSIBLE.

Are you SURE you want to proceed?

[Cancel] [I Accept The Risk]
```

### Failed Coup Results Screen
```
💀 COUP FAILED 💀

Your conspiracy has been crushed!

PENALTIES:
❌ -250g (seized by ruler)
❌ -100 reputation (traitor!)
❌ -2 attack power
❌ -2 defense power

You are now a marked traitor.
The ruler may execute you.

[Accept Fate]
```

### Failed Invasion Results Screen
```
⚔️ INVASION FAILED ⚔️

Your forces have been repelled!

CASUALTIES:
❌ -100g (lost in battle)
❌ -50 reputation
🩹 -1 attack (wounded, recovers in 24h)
⏱️ Cannot invade for 24 hours

Your soldiers need time to recover.

[Retreat]
```

---

## Summary

**Coups:**
- EXTREME risk, EXTREME reward
- Permanent stat loss if you fail
- Makes coups rare and meaningful
- High-stakes political drama

**Invasions:**
- HIGH risk, BIG reward
- Temporary debuff if you fail
- Encourages territorial warfare
- Empire building gameplay

**Both:**
- No shortcuts or bailouts
- Pure PvP consequences
- Strategic depth
- Think before you attack!

---

*Remember: In Kingdom, actions have REAL consequences. Choose your battles wisely!* 🏰⚔️





