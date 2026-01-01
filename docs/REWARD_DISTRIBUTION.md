# Reward Distribution System

## Overview
Rulers can distribute % of kingdom income to subjects based on reputation and skills.

## Merit Score Formula
```
Merit = (reputation × 1.0) + (skillTotal × 0.5)
Share = (playerMerit / totalMerit) × rewardPool
```

## Ruler Settings
- Set distribution rate: 0-50% of kingdom income
- Distribute manually (23-hour cooldown)
- View history and eligible subjects

## Eligibility
Must have:
- 50+ reputation in kingdom
- Checked in within last 7 days
- Not the ruler
- Not banned

## Example
```
Kingdom income: 1000g/day
Distribution rate: 20%
Pool: 200g

Alice: 500 rep + 20 skill = 510 merit → 109g
Bob:   300 rep + 40 skill = 320 merit → 68g
Carol: 100 rep + 10 skill = 105 merit → 22g
```

## UI
- **Rulers**: Slider, distribute button, history (RulerRewardManagementCard)
- **Subjects**: Merit breakdown, estimated share (SubjectRewardCard)
- Integrated into KingdomDetailView

## Strategy
- Higher rep = more rewards (weighted 2×)
- Skills add bonus (weighted 1×)
- Generous kingdoms attract/retain subjects
- Low distribution = faster treasury growth




