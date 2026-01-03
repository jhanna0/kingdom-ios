# Schema Refactor Plan

## The Reality

We already have tables that track everything. player_state is storing REDUNDANT counters.

---

## What We Already Have

### kingdom_history
```sql
-- Tracks every ruler change
ruler_id, kingdom_id, event_type, started_at, ended_at
```
**Computable:**
- `total_conquests` = `COUNT(*) FROM kingdom_history WHERE ruler_id = ?`
- `kingdoms_ruled` = `COUNT(*) FROM kingdom_history WHERE ruler_id = ? AND ended_at IS NULL`

### coup_events  
```sql
-- Tracks every coup
initiator_id, attacker_victory, attackers[], defenders[]
```
**Computable:**
- `coups_won` = `COUNT(*) FROM coup_events WHERE initiator_id = ? AND attacker_victory = true`
- `coups_failed` = `COUNT(*) FROM coup_events WHERE initiator_id = ? AND attacker_victory = false`

### user_kingdoms
```sql
-- Per-kingdom player data (ALREADY EXISTS!)
user_id, kingdom_id, local_reputation, checkins_count, gold_earned, gold_spent
```
**Rep is per-kingdom. There is no "global" rep.**

### contract_contributions (new)
**Computable:**
- `total_work_contributed` = `COUNT(*) FROM contract_contributions WHERE user_id = ?`
- `contracts_completed` = `COUNT(DISTINCT contract_id) FROM contract_contributions cc JOIN contracts c ON cc.contract_id = c.id WHERE cc.user_id = ? AND c.status = 'completed'`

---

## player_state: What Actually Needs to Stay

```sql
CREATE TABLE player_state (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id),
    
    -- Territory
    hometown_kingdom_id VARCHAR,
    current_kingdom_id VARCHAR,
    
    -- Resources
    gold INT DEFAULT 100,
    iron INT DEFAULT 0,
    steel INT DEFAULT 0,
    
    -- Progression
    level INT DEFAULT 1,
    experience INT DEFAULT 0,
    skill_points INT DEFAULT 0,
    
    -- Stats
    attack_power INT DEFAULT 1,
    defense_power INT DEFAULT 1,
    leadership INT DEFAULT 1,
    building_skill INT DEFAULT 1,
    intelligence INT DEFAULT 1,
    
    -- Combat debuff (temporary)
    attack_debuff INT DEFAULT 0,
    debuff_expires_at TIMESTAMP,
    
    -- Status
    is_alive BOOLEAN DEFAULT TRUE,
    
    -- One-time flags
    has_claimed_starting_city BOOLEAN DEFAULT FALSE,
    
    -- Training cost scaling (can't compute this easily)
    total_training_purchases INT DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);
```

**19 columns. That's it.**

---

## DELETE FROM player_state (redundant/dead)

### Computed from other tables:
```
total_conquests        → COUNT from kingdom_history
kingdoms_ruled         → COUNT from kingdom_history WHERE ended_at IS NULL
coups_won              → COUNT from coup_events
coups_failed           → COUNT from coup_events
times_executed         → need to add to coup_events
executions_ordered     → need to add to coup_events
contracts_completed    → COUNT from contracts
total_work_contributed → COUNT from contract_contributions
total_checkins         → SUM from user_kingdoms.checkins_count
reputation             → NO GLOBAL REP. Use user_kingdoms.local_reputation
```

### Dead code (never used):
```
honor, total_rewards_received, last_reward_received, last_reward_amount
game_data, origin_kingdom_id, home_kingdom_id
last_check_in_lat, last_check_in_lon, last_daily_check_in
last_mining_action, last_building_action, last_spy_action
crafting_progress, equipped_shield, properties
```

### Move to other tables:
```
training_contracts, crafting_queue, property_upgrade_contracts → contracts table
equipped_weapon, equipped_armor, inventory → player_items table
kingdom_reputation, check_in_history → user_kingdoms (already exists!)
last_*_action timestamps → action_cooldowns table
```

---

## New Tables

### contracts
```sql
CREATE TABLE contracts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    kingdom_id VARCHAR(128),
    
    type VARCHAR(32) NOT NULL,  -- 'weapon', 'armor', 'attack', 'defense', 'wall', 'property'
    tier INT,
    target_id VARCHAR(128),
    
    actions_required INT NOT NULL,
    gold_paid INT DEFAULT 0,
    iron_paid INT DEFAULT 0,
    steel_paid INT DEFAULT 0,
    
    status VARCHAR(16) DEFAULT 'in_progress',
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);
```

### contract_contributions
```sql
CREATE TABLE contract_contributions (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id),
    performed_at TIMESTAMP DEFAULT NOW(),
    gold_earned INT DEFAULT 0,
    xp_earned INT DEFAULT 0
);
```

### player_items
```sql
CREATE TABLE player_items (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    type VARCHAR(32) NOT NULL,
    tier INT NOT NULL,
    attack_bonus INT DEFAULT 0,
    defense_bonus INT DEFAULT 0,
    is_equipped BOOLEAN DEFAULT FALSE,
    crafted_at TIMESTAMP DEFAULT NOW()
);
```

### action_cooldowns
```sql
CREATE TABLE action_cooldowns (
    user_id BIGINT NOT NULL REFERENCES users(id),
    action_type VARCHAR(32) NOT NULL,
    last_performed TIMESTAMP NOT NULL,
    expires_at TIMESTAMP,
    PRIMARY KEY (user_id, action_type)
);
```

---

## Add to coup_events

```sql
ALTER TABLE coup_events ADD COLUMN executed_player_id BIGINT REFERENCES users(id);
```

Then:
- `times_executed` = `COUNT(*) FROM coup_events WHERE executed_player_id = ?`
- `executions_ordered` = `COUNT(*) FROM coup_events WHERE initiator_id = ? AND executed_player_id IS NOT NULL`

---

## Summary

| Before | After |
|--------|-------|
| 68 columns | 19 columns |
| Redundant counters | Computed from source tables |
| "Global reputation" | Per-kingdom only (user_kingdoms) |
| JSONB arrays | Proper normalized tables |
| Dead code | Deleted |
