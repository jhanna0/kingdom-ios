# Secret Coup Conspiracy System

## Overview

Coups are **SECRET conspiracies** that remain hidden until executed. The king cannot know about them unless someone snitches!

## How It Works

### Phase 1: Initiation (Secret)
```
Player initiates a secret coup conspiracy
- Costs gold to start
- Only the leader knows
- No public announcement
```

**Function**: `initiate_coup(player_id)`
- Returns success message ONLY to the initiator
- Creates a `CoupConspiracy` object
- No one else knows it exists

### Phase 2: Recruitment (Private)
```
Leader privately invites trusted allies
- Invitations are PRIVATE messages
- Invited players must decide: Join or Reject
- Risk: Rejecting players might snitch!
```

**Functions**:
- `invite_to_coup(leader_id, target_id)` - Send private invitation
- `check_coup_invitation(player_id)` - Check if you have an invitation
- `respond_to_coup_invitation(player_id, accept=True/False)` - Accept or reject

### Phase 3: The Snitch Risk
```
When a player REJECTS an invitation:
- 30% chance they inform the king
- If they snitch, the conspiracy is EXPOSED
- King can then execute all conspirators
- If they don't snitch, conspiracy stays secret
```

**Key Mechanic**: Trust is crucial! Inviting the wrong person can expose everyone.

### Phase 4: Execution (Public)
```
When leader has enough conspirators:
- Leader executes the coup
- THIS IS THE MOMENT IT BECOMES PUBLIC
- Either succeeds or fails immediately
- Everyone learns about it at once
```

**Function**: `execute_coup(player_id)`
- Requires minimum number of conspirators (default: 3)
- Success chance based on conspirator count
- Creates public event visible to all
- Either: New ruler crowned, or all conspirators exposed

## Success Calculation

```
Base Success Chance: 30%
+ 15% per extra conspirator beyond minimum
Maximum: 95%

Example:
- 3 conspirators (minimum): 30% chance
- 4 conspirators: 45% chance  
- 5 conspirators: 60% chance
- 6 conspirators: 75% chance
- 7+ conspirators: 90-95% chance
```

## Strategic Considerations

### For Coup Leaders:
✓ **Build trust** before inviting
✓ **Invite slowly** - rushing risks exposure
✓ **Choose wisely** - wrong invitation = death
✓ **Know when to strike** - balance size vs secrecy
✗ **Don't invite too many** - more people = more risk of snitches
✗ **Don't wait too long** - king might discover through other means

### For Kings/Rulers:
✓ **Build loyalty** - happy citizens don't join coups
✓ **Watch for suspicious behavior** - private meetings, room changes
✓ **Reward informants** - encourage snitching
✓ **Execute threats preemptively** - but not too many (tyranny breeds rebellion)
✗ **Don't ignore warnings** - if someone snitches, act fast
✗ **Don't be a tyrant** - makes you a target

### For Citizens:
✓ **If invited**: Carefully consider joining
✓ **If loyal to king**: Report the conspiracy
✓ **If unsure**: Rejecting has risks (conspirators might target you later)
✗ **Don't snitch lightly** - making enemies is dangerous
✗ **Don't join impulsively** - failed coups = execution

## Comparison: Old vs New System

### Old System (Public Declaration)
❌ King knows immediately when coup is declared
❌ King has time to execute conspirators
❌ No element of surprise
❌ No trust dynamics
❌ Unrealistic

### New System (Secret Conspiracy) ✓
✅ King doesn't know until coup is executed
✅ Surprise attacks possible
✅ Trust is crucial (risk of snitches)
✅ Realistic political intrigue
✅ Dramatic tension

## Example Flow

```
1. Bob secretly initiates coup against Alice (King)
   - Only Bob knows
   - Cost: 50 gold
   
2. Bob invites Charlie (Private)
   - Charlie accepts
   - Now 2 conspirators
   
3. Bob invites Eve (Private)
   - Eve accepts
   - Now 3 conspirators (minimum met!)
   
4. Bob invites Frank (Private)
   - Frank REJECTS
   - 30% chance Frank snitches...
   
   Path A: Frank doesn't snitch
   - Conspiracy stays secret
   - Bob can execute the coup
   - Chance of success: 30% (3 conspirators)
   
   Path B: Frank snitches
   - Conspiracy EXPOSED publicly
   - Alice learns about the plot
   - Alice executes Bob, Charlie, Eve
   - Alice rewards Frank
```

## Public Events

### If Coup NOT Discovered:
- **No events** until coup is executed
- Then: "COUP SUCCESS" or "COUP FAILED"

### If Coup IS Discovered:
- "CONSPIRACY DISCOVERED! [Informant] exposed [Leader]'s plot!"
- Then likely: Multiple executions

## Code Example

```python
# Bob starts a secret conspiracy
game.initiate_coup("bob")
# Output: "You have secretly initiated a coup conspiracy..."

# Bob invites Charlie
game.invite_to_coup("bob", "charlie")
# Output: "You have secretly invited Charlie..."

# Charlie checks his invitation
invitation = game.check_coup_invitation("charlie")
# Output: {'leader': 'Bob', 'town': 'Westmarch', 'message': '...'}

# Charlie accepts
game.respond_to_coup_invitation("charlie", accept=True)
# Output: "You have joined the conspiracy! Conspirators: 2"

# Bob checks status (only conspirators can see this)
status = game.get_conspiracy_status("bob")
# Output: {'conspirators': 2, 'min_required': 3, 'can_execute': False, ...}

# After recruiting enough people...
game.execute_coup("bob")
# Output: "COUP SUCCESS! Bob has seized power..."
# OR: "COUP FAILED! Bob's conspiracy has been crushed!"
```

## Game Balance

| Factor | Value | Reasoning |
|--------|-------|-----------|
| Initiation Cost | 50 gold | Low enough to attempt, high enough to matter |
| Min Conspirators | 3 | Requires recruiting, not solo |
| Snitch Chance | 30% | High risk but not guaranteed |
| Base Success | 30% | Minimum viable but risky |
| Per-Conspirator Bonus | 15% | Rewards larger conspiracies |
| Max Success | 95% | Never 100% - always some risk |

## Future Enhancements

1. **Loyalty System**: Higher loyalty = lower snitch chance
2. **Influence**: High influence over invitee = less likely to snitch
3. **Room-Based Discovery**: King can "spy" on tavern conversations
4. **Time Decay**: Longer conspiracy = higher discovery risk
5. **Counter-Conspiracy**: Exposed conspirators can counter-coup
6. **Partial Exposure**: Only some conspirators exposed, others stay hidden
7. **Conspiracy Ranks**: Inner circle vs outer supporters
8. **Multiple Simultaneous Conspiracies**: Competing coups!

---

This system creates **Game of Thrones-level intrigue** where trust, timing, and strategy matter more than raw numbers!


