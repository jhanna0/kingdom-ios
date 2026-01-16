# Training System Implementation

## Overview
Implemented a two-step training system where users purchase training sessions with gold, then perform the training actions with cooldowns.

## Changes Made

### Backend (Python/FastAPI)

#### 1. Database Schema (`api/db/models/player_state.py`)
- Added training action cooldown columns:
  - `last_train_attack_action`
  - `last_train_defense_action`
  - `last_train_leadership_action`
  - `last_train_building_action`
- Added training session inventory:
  - `training_sessions_attack`
  - `training_sessions_defense`
  - `training_sessions_leadership`
  - `training_sessions_building`

#### 2. Migration (`api/db/add_training_actions.sql`)
- SQL migration to add all new columns with proper indexes

#### 3. API Endpoints (`api/routers/actions.py`)
- **Purchase Endpoints** (costs gold):
  - `POST /actions/train/attack/purchase`
  - `POST /actions/train/defense/purchase`
  - `POST /actions/train/leadership/purchase`
  - `POST /actions/train/building/purchase`
  
- **Training Action Endpoints** (requires session, has cooldown):
  - `POST /actions/train/attack`
  - `POST /actions/train/defense`
  - `POST /actions/train/leadership`
  - `POST /actions/train/building`

- **Cost Formula**: `100 * (current_stat_level ^ 1.5)`
  - Level 1→2: 100g
  - Level 5→6: 559g
  - Level 10→11: 1581g

- **Rewards**: Each training grants 25 XP
- **Cooldown**: 2 hours per training action
- **Requirements**: Must be checked into a kingdom to train

#### 4. Action Status Endpoint
- Updated `/actions/status` to include:
  - Training cooldown status
  - Current stat levels
  - Available training sessions
  - Purchase costs

### iOS (Swift/SwiftUI)

#### 1. API Models (`Services/API/ActionsAPI.swift`)
- Updated `ActionStatus` model with:
  - `sessionsAvailable: Int?`
  - `purchaseCost: Int?`
- Added `PurchaseTrainingResponse` model
- Updated `TrainingActionResponse` with `sessionsRemaining`
- Added purchase API methods:
  - `purchaseAttackTraining()`
  - `purchaseDefenseTraining()`
  - `purchaseLeadershipTraining()`
  - `purchaseBuildingTraining()`

#### 2. Character Sheet (`Views/Character/CharacterSheetView.swift`)
- **Removed**:
  - All emoji icons (replaced with SF Symbols)
  - XP purchase buttons
  - Direct training buttons
  - Excessive training UI
  
- **Added**:
  - Clean stat display with SF Symbols
  - Purchase training section with cost display
  - Gold balance in header
  - Purchase buttons for each stat
  - Success/error alerts

#### 3. Actions View (`Views/Actions/ActionsView.swift`)
- Added "Character Training" section at top of actions list
- Created `TrainingActionCard` component showing:
  - Current stat level
  - Available training sessions (ticket icon)
  - Cooldown timer
  - "Train Now" button when ready
  - Clear messaging when no sessions available
- Added training action methods:
  - `performTrainAttack()`
  - `performTrainDefense()`
  - `performTrainLeadership()`
  - `performTrainBuilding()`
- Shows XP rewards after training

## User Flow

1. **Purchase Training** (Character Sheet):
   - User views current stats and training costs
   - Spends gold to purchase training sessions
   - Sessions are added to inventory

2. **Perform Training** (Actions Page):
   - User sees available training sessions
   - Clicks "Train Now" when off cooldown
   - Must be checked into a kingdom
   - Consumes one session
   - Gains +1 stat and +25 XP
   - 2-hour cooldown before next training

## Design Philosophy

- **Two-step process**: Purchase (costs gold) → Perform (costs time)
- **Progression gating**: Forces users to engage with Actions page
- **Resource management**: Users must balance gold spending
- **Clean UI**: Removed excessive emojis, using SF Symbols instead
- **Clear feedback**: Shows costs, sessions available, cooldowns

## Files Modified

### Backend
- `api/db/models/player_state.py`
- `api/db/add_training_actions.sql`
- `api/routers/actions.py`

### iOS
- `ios/KingdomApp/KingdomApp/KingdomApp/Services/API/ActionsAPI.swift`
- `ios/KingdomApp/KingdomApp/KingdomApp/Views/Character/CharacterSheetView.swift`
- `ios/KingdomApp/KingdomApp/KingdomApp/Views/Actions/ActionsView.swift`

## Next Steps

1. Run database migration: `psql $DATABASE_URL -f api/db/add_training_actions.sql`
2. Restart API server
3. Test purchase flow in Character Sheet
4. Test training actions in Actions page
5. Verify cooldowns work correctly
6. Test with multiple training sessions queued



