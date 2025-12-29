# Training Cost Scaling System

## Overview

To prevent players from easily maxing out all their stats, training costs now scale exponentially based on **total training purchases** rather than just individual stat levels. This creates meaningful strategic choices about which stats to prioritize.

## Cost Formula

```
Final Cost = Base Cost × Global Multiplier
```

Where:
- **Base Cost** = `100 × (stat_level^1.5)` 
  - Level 1→2: 100g base
  - Level 5→6: 559g base
  - Level 10→11: 1,581g base

- **Global Multiplier** = `1.15^(total_training_purchases)`
  - 0 purchases: 1.0× (no increase)
  - 5 purchases: 2.01× (costs doubled)
  - 10 purchases: 4.05× (costs quadrupled)
  - 15 purchases: 8.14× (costs 8× more expensive)
  - 20 purchases: 16.37× (costs 16× more expensive)

## Examples

### First Training Session (Attack 1→2)
- Base cost: 100g
- Global multiplier: 1.0× (0 purchases)
- **Final cost: 100g**

### After 5 Training Sessions (Defense 3→4)
- Base cost: 520g
- Global multiplier: 2.01× (5 purchases)
- **Final cost: ~1,045g**

### After 10 Training Sessions (Leadership 2→3)
- Base cost: 283g
- Global multiplier: 4.05× (10 purchases)
- **Final cost: ~1,146g**

### After 20 Training Sessions (Any stat)
- Base cost: varies
- Global multiplier: 16.37× (20 purchases)
- **Final cost: 16× more expensive than base!**

## Strategic Impact

1. **Forces Specialization**: Players must choose which stats to prioritize
2. **Prevents Power Creep**: Can't easily max everything out
3. **Creates Build Diversity**: Different players will specialize differently
4. **Maintains Challenge**: Even high-level players face tough choices

## Implementation Details

### Backend Changes
- Added `total_training_purchases` field to `PlayerState` model
- Updated `calculate_training_cost()` function to include global multiplier
- Purchase counter increments on each training purchase (not completion)

### iOS Changes
- Added `totalTrainingPurchases` to Player model
- Updated all training cost calculation methods
- Syncs with backend API automatically
- Persists locally in UserDefaults

### Database Migration
Run: `api/db/add_training_purchases_counter.sql`

This migration:
1. Adds the new column with default 0
2. Backfills existing players based on current stats
3. Creates an index for performance

## Testing

To test the system:
1. Run the database migration
2. Purchase multiple training sessions
3. Observe cost increases in the Character Sheet
4. Verify costs match the formula above

## Future Considerations

- Could add kingdom/building bonuses to reduce global multiplier
- Could add "reset" mechanics at a cost
- Could add prestige system for stat resets

