# Education Building & Intelligence Skill System

## Overview
This document describes the Education Building (for rulers) and Intelligence Skill (for players) systems added to the Kingdom game.

---

## Education Building (Ruler Feature)

### Description
A new building tier that rulers can construct to benefit their citizens by reducing the number of actions required for training.

### Database Schema
- **Table**: `kingdoms`
- **Column**: `education_level` (INTEGER, default: 0)
- **Range**: 0-5 (T0 through T5)

### Benefits by Tier
Each tier reduces the number of training actions required:

| Tier | Reduction | Effect |
|------|-----------|--------|
| T0   | 0%        | No bonus (default) |
| T1   | 5%        | Training 5% faster |
| T2   | 10%       | Training 10% faster |
| T3   | 15%       | Training 15% faster |
| T4   | 20%       | Training 20% faster |
| T5   | 25%       | Training 25% faster (max) |

### Formula
```python
base_actions = 3 + (stat_level // 3)
education_reduction = 1.0 - (education_level * 0.05)
reduced_actions = max(1, int(base_actions * education_reduction))
```

### Example
A player training from level 10 → 11:
- **Base actions required**: 6
- **With T3 Education**: 6 × 0.85 = 5 actions
- **With T5 Education**: 6 × 0.75 = 4 actions

### Implementation Files
- Backend Database: `api/db/models/kingdom.py`
- Backend Schema: `api/schemas/kingdom.py`
- Backend Logic: `api/routers/actions/training.py`
- iOS Model: `ios/KingdomApp/KingdomApp/KingdomApp/Models/Kingdom.swift`
- iOS API Model: `ios/KingdomApp/KingdomApp/KingdomApp/Services/API/Models/KingdomModels.swift`

---

## Intelligence Skill (Player Feature)

### Description
A new player skill that improves sabotage success rates and patrol detection capabilities. At tier 5, unlocks the ability to attempt vault heists.

### Database Schema
- **Table**: `player_state`
- **Column**: `intelligence` (INTEGER, default: 1)
- **Range**: 1-∞ (levels up like other stats)

### Benefits by Tier

#### T1: Sabotage & Patrol Basics
- **Sabotage**: 2% better at avoiding detection
- **Patrol**: 2% better at catching saboteurs

#### T2: Enhanced Operations
- **Sabotage**: 4% better at avoiding detection
- **Patrol**: 4% better at catching saboteurs

#### T3: Expert Operative
- **Sabotage**: 6% better at avoiding detection
- **Patrol**: 6% better at catching saboteurs

#### T4: Master Spy
- **Sabotage**: 8% better at avoiding detection
- **Patrol**: 8% better at catching saboteurs

#### T5: Criminal Mastermind
- **Sabotage**: 10% better at avoiding detection
- **Patrol**: 10% better at catching saboteurs
- **NEW ABILITY**: Vault Heist - Attempt to steal 10% of enemy kingdom vault

### Sabotage Mechanics

The intelligence skill modifies the sabotage detection formula:

```python
# Base detection calculation (patrols, city size, building skill)
base_detection_chance = calculate_base_detection(...)

# Intelligence reduces detection (multiplicative)
saboteur_intel_multiplier = 1.0 - (intelligence * 0.02)
patrol_intel_multiplier = 1.0 + (avg_patrol_intelligence * 0.02)

final_detection = base_detection * saboteur_intel_multiplier * patrol_intel_multiplier
```

### Patrol Mechanics

When on patrol, your intelligence increases the chance of catching saboteurs:
- The system calculates the **average intelligence** of all active patrols
- Each point of intelligence adds +2% to detection rate
- Multiple high-intelligence patrols are very effective

### Vault Heist (Intelligence T5 Ability)

#### Requirements
- Intelligence level 5 or higher
- Must be checked into target kingdom
- Cannot target your own kingdom
- Kingdom vault must have at least 500g
- Costs 1000g to attempt

#### Cooldown
- **7 days (168 hours)** between heist attempts
- One of the longest cooldowns in the game

#### Mechanics

**Detection Formula**:
```python
base_detection = 0.30  # 30% base
vault_level_bonus = vault_level * 0.05  # +5% per level
intelligence_reduction = (intelligence - 5) * 0.04  # -4% per level above 5
patrol_bonus = active_patrols * 0.02  # +2% per patrol

detection_chance = clamp(
    0.01,  # minimum 1%
    0.95,  # maximum 95%
    base_detection + vault_level_bonus - intelligence_reduction + patrol_bonus
)
```

**Success**:
- Steal 10% of kingdom's vault
- Gain 100 reputation in your hometown
- Gain 200 XP
- Net profit: stolen_gold - 1000g cost

**Failure (Caught)**:
- Lose 1000g (heist cost)
- Lose 500 reputation in target kingdom
- **Banned from target kingdom**
- No gold stolen

#### Example Detection Rates

| Scenario | Detection Chance |
|----------|------------------|
| T5 Intelligence, No patrols, T0 vault | 30% - 0% + 0% = **30%** |
| T5 Intelligence, 2 patrols, T2 vault | 30% + 10% + 4% = **44%** |
| T7 Intelligence, 2 patrols, T2 vault | 30% + 10% - 8% + 4% = **36%** |
| T10 Intelligence, 5 patrols, T5 vault | 30% + 25% - 20% + 10% = **45%** |

### API Endpoints

#### New Endpoint
```
POST /actions/vault-heist/{kingdom_id}
```

**Response (Success)**:
```json
{
  "success": true,
  "caught": false,
  "message": "Successfully stole 5000g from Kingdom's vault!",
  "gold_stolen": 5000,
  "detection_chance": 35.0,
  "cost_paid": 1000,
  "net_profit": 4000,
  "reputation_gained": 100,
  "experience_gained": 200,
  "next_heist_available_at": "2025-01-05T12:00:00Z"
}
```

**Response (Caught)**:
```json
{
  "success": false,
  "caught": true,
  "message": "Caught attempting to rob the vault! Lost 500 reputation and banned from Kingdom.",
  "detection_chance": 45.0,
  "cost_paid": 1000,
  "reputation_lost": 500,
  "banned": true,
  "next_heist_available_at": "2025-01-05T12:00:00Z"
}
```

### Implementation Files

#### Backend
- Database Model: `api/db/models/player_state.py`
- Schema: `api/schemas/user.py`
- Player Mapping: `api/routers/player.py`
- Sabotage Logic: `api/routers/actions/sabotage.py`
- Vault Heist: `api/routers/actions/vault_heist.py`
- Router Registration: `api/routers/actions/__init__.py`

#### iOS
- Player Model: `ios/KingdomApp/KingdomApp/KingdomApp/Models/Player.swift`
- API Model: `ios/KingdomApp/KingdomApp/KingdomApp/Services/API/Models/PlayerModels.swift`

---

## Database Migration

### Migration File
`api/db/add_education_and_intelligence.sql`

### To Apply Migration

```bash
# Connect to your PostgreSQL database
psql -U your_username -d kingdom_db

# Run the migration
\i api/db/add_education_and_intelligence.sql
```

### Migration Contents
```sql
-- Add education_level column to kingdoms table
ALTER TABLE kingdoms 
ADD COLUMN IF NOT EXISTS education_level INTEGER DEFAULT 0;

-- Add intelligence column to player_state table
ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS intelligence INTEGER DEFAULT 1;

-- Create indexes for potential queries
CREATE INDEX IF NOT EXISTS idx_kingdoms_education_level ON kingdoms(education_level);
CREATE INDEX IF NOT EXISTS idx_player_state_intelligence ON player_state(intelligence);
```

---

## Testing Recommendations

### Education Building Testing
1. Create a kingdom with different education levels (0-5)
2. Purchase training contracts and verify actions required
3. Confirm formula: `base * (1 - education_level * 0.05)`
4. Test minimum of 1 action is enforced

### Intelligence - Sabotage Testing
1. Create players with different intelligence levels
2. Attempt sabotage with various intelligence vs patrol intelligence
3. Monitor detection rates and verify they match expected probabilities
4. Test edge cases (intelligence = 1, very high intelligence)

### Intelligence - Vault Heist Testing
1. Verify requirement check (intelligence < 5 should fail)
2. Test cooldown enforcement (7 days)
3. Verify gold cost (1000g)
4. Test minimum vault amount (500g)
5. Test detection formula with various scenarios
6. Verify success/failure consequences
7. Test ban functionality
8. Verify cannot heist own kingdom

---

## Balance Considerations

### Education Building
- **Cost to Build**: Should be expensive to reflect the powerful benefit
- **Suggested Costs**: Similar to or higher than T5 market/mine
- **Population Impact**: Higher education attracts more players (future feature)

### Intelligence Skill
- **Training Costs**: Standard formula (100 × level^1.5)
- **Vault Heist Risk**: 30-45% detection is high-risk, high-reward
- **Economic Impact**: Can drain enemy vaults significantly
- **Ban Duration**: Currently permanent; consider temporary bans
- **Cooldown**: 7 days prevents spam but allows strategic planning

### Suggested Balancing Levers
1. Adjust `INTELLIGENCE_REDUCTION_PER_LEVEL` (currently 2%)
2. Adjust vault heist base detection (currently 30%)
3. Adjust vault heist cooldown (currently 7 days)
4. Adjust vault heist cost (currently 1000g)
5. Adjust ban duration (currently permanent)

---

## Future Enhancements

### Education Building
- Visual indicator on map for high-education kingdoms
- Migration bonus (players drawn to educated cities)
- Research speed bonus for crafting/building
- Knowledge-based mini-games or quests

### Intelligence Skill
- Counter-intelligence abilities
- Information gathering (view enemy stats)
- Diplomatic espionage (view kingdom intel)
- Assassination attempts (remove ruler temporarily)
- Temporary disguises (hide identity during sabotage)
- Intelligence network (coordinate with other spies)

---

## Summary of Changes

### Files Modified: 14
### Files Created: 2

**Database Models** (2):
- `api/db/models/kingdom.py` - Added education_level
- `api/db/models/player_state.py` - Added intelligence

**Schemas** (2):
- `api/schemas/kingdom.py` - Added education_level to KingdomState
- `api/schemas/user.py` - Added intelligence to PlayerState

**Backend Logic** (4):
- `api/routers/player.py` - Added intelligence to player_state_to_response
- `api/routers/actions/training.py` - Education bonus for training
- `api/routers/actions/sabotage.py` - Intelligence bonuses for sabotage/patrol
- `api/routers/actions/__init__.py` - Registered vault_heist router

**New Features** (2):
- `api/db/add_education_and_intelligence.sql` - Database migration
- `api/routers/actions/vault_heist.py` - New vault heist action

**iOS Models** (4):
- `ios/.../Models/Kingdom.swift` - Added educationLevel
- `ios/.../Models/Player.swift` - Added intelligence
- `ios/.../Services/API/Models/KingdomModels.swift` - Added education_level
- `ios/.../Services/API/Models/PlayerModels.swift` - Added intelligence

---

## API Documentation

### Education Level
- **Get**: Included in kingdom state (`GET /kingdoms/{id}`)
- **Set**: Ruler creates building contract for education building

### Intelligence
- **Get**: Included in player state (`GET /player/state`)
- **Train**: Purchase training contract (`POST /actions/train/purchase?training_type=intelligence`)
- **Use (Sabotage)**: Automatic bonus when attempting sabotage
- **Use (Patrol)**: Automatic bonus when on patrol
- **Use (Vault Heist)**: `POST /actions/vault-heist/{kingdom_id}` (T5+)

---

## Conclusion

The Education Building and Intelligence Skill systems add strategic depth to Kingdom by:
1. Rewarding rulers who invest in citizen development
2. Creating new progression paths for players
3. Adding high-stakes espionage gameplay
4. Balancing offense (sabotage) and defense (patrol) mechanics
5. Enabling asymmetric warfare through economic disruption

These systems integrate seamlessly with existing game mechanics while opening new gameplay possibilities for both rulers and subjects.

