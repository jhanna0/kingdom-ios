-- ============================================
-- UNIFIED SCHEMA MIGRATION
-- Creates new tables and migrates ALL existing data
-- Run once: docker exec -i kingdom-db psql -U admin -d kingdom < api/db/unified_migration.sql
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: CREATE NEW TABLES
-- ============================================

-- 1a. Unified contracts table (replaces training_contracts, crafting_queue, property_upgrade_contracts JSONB + contracts table for buildings)
CREATE TABLE IF NOT EXISTS unified_contracts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    kingdom_id VARCHAR(128) REFERENCES kingdoms(id) ON DELETE CASCADE,
    type VARCHAR(32) NOT NULL,
    tier INTEGER,
    target_id VARCHAR(128),
    actions_required INTEGER NOT NULL DEFAULT 1,
    gold_paid INTEGER DEFAULT 0,
    iron_paid INTEGER DEFAULT 0,
    steel_paid INTEGER DEFAULT 0,
    reward_pool INTEGER DEFAULT 0,
    status VARCHAR(16) NOT NULL DEFAULT 'in_progress',
    kingdom_name VARCHAR(256),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_uc_user_status ON unified_contracts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_uc_kingdom_status ON unified_contracts(kingdom_id, status);
CREATE INDEX IF NOT EXISTS idx_uc_type_status ON unified_contracts(type, status);

-- 1b. Contract contributions table (one row per action performed)
CREATE TABLE IF NOT EXISTS contract_contributions (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES unified_contracts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    performed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    gold_earned INTEGER DEFAULT 0,
    xp_earned INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_cc_contract ON contract_contributions(contract_id);
CREATE INDEX IF NOT EXISTS idx_cc_user ON contract_contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_cc_user_time ON contract_contributions(user_id, performed_at);

-- 1c. Player items table (replaces inventory, equipped_weapon, equipped_armor JSONB)
CREATE TABLE IF NOT EXISTS player_items (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(32) NOT NULL,
    tier INTEGER NOT NULL DEFAULT 1,
    attack_bonus INTEGER DEFAULT 0,
    defense_bonus INTEGER DEFAULT 0,
    is_equipped BOOLEAN DEFAULT FALSE,
    crafted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pi_user ON player_items(user_id);
CREATE INDEX IF NOT EXISTS idx_pi_user_equipped ON player_items(user_id, is_equipped);

-- 1d. Action cooldowns table (replaces all last_*_action columns in player_state)
CREATE TABLE IF NOT EXISTS action_cooldowns (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(32) NOT NULL,
    last_performed TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP,
    PRIMARY KEY (user_id, action_type)
);

-- ============================================
-- STEP 2: MIGRATE COOLDOWNS FROM player_state
-- ============================================

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'work', last_work_action, NULL FROM player_state WHERE last_work_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'patrol', last_patrol_action, patrol_expires_at FROM player_state WHERE last_patrol_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'farm', last_farm_action, NULL FROM player_state WHERE last_farm_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'sabotage', last_sabotage_action, NULL FROM player_state WHERE last_sabotage_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'scout', last_scout_action, NULL FROM player_state WHERE last_scout_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'training', last_training_action, NULL FROM player_state WHERE last_training_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'crafting', last_crafting_action, NULL FROM player_state WHERE last_crafting_action IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO action_cooldowns (user_id, action_type, last_performed, expires_at)
SELECT user_id, 'intelligence', last_intelligence_action, NULL FROM player_state WHERE last_intelligence_action IS NOT NULL
ON CONFLICT DO NOTHING;

-- ============================================
-- STEP 3: MIGRATE EQUIPPED ITEMS FROM player_state JSONB
-- ============================================

-- Migrate equipped weapons
INSERT INTO player_items (user_id, type, tier, attack_bonus, defense_bonus, is_equipped, crafted_at)
SELECT 
    user_id,
    'weapon',
    COALESCE((equipped_weapon->>'tier')::integer, 1),
    COALESCE((equipped_weapon->>'attackBonus')::integer, 1),
    0,
    TRUE,
    NOW()
FROM player_state 
WHERE equipped_weapon IS NOT NULL 
  AND equipped_weapon::text != 'null' 
  AND equipped_weapon::text != '{}';

-- Migrate equipped armor
INSERT INTO player_items (user_id, type, tier, attack_bonus, defense_bonus, is_equipped, crafted_at)
SELECT 
    user_id,
    'armor',
    COALESCE((equipped_armor->>'tier')::integer, 1),
    0,
    COALESCE((equipped_armor->>'defenseBonus')::integer, 1),
    TRUE,
    NOW()
FROM player_state 
WHERE equipped_armor IS NOT NULL 
  AND equipped_armor::text != 'null' 
  AND equipped_armor::text != '{}';

-- ============================================
-- STEP 4: MIGRATE INVENTORY FROM player_state JSONB
-- ============================================

INSERT INTO player_items (user_id, type, tier, attack_bonus, defense_bonus, is_equipped, crafted_at)
SELECT 
    ps.user_id,
    COALESCE(item->>'type', 'weapon'),
    COALESCE((item->>'tier')::integer, 1),
    COALESCE((item->>'attackBonus')::integer, 0),
    COALESCE((item->>'defenseBonus')::integer, 0),
    FALSE,
    NOW()
FROM player_state ps
CROSS JOIN LATERAL jsonb_array_elements(ps.inventory) AS item
WHERE ps.inventory IS NOT NULL 
  AND ps.inventory::text != '[]' 
  AND ps.inventory::text != 'null'
  AND jsonb_array_length(ps.inventory) > 0;

-- ============================================
-- STEP 5: MIGRATE TRAINING CONTRACTS FROM player_state JSONB
-- ============================================

INSERT INTO unified_contracts (user_id, type, tier, actions_required, gold_paid, status, created_at, completed_at)
SELECT 
    ps.user_id,
    COALESCE(contract->>'type', 'attack'),
    COALESCE((contract->>'statLevel')::integer, 1),
    COALESCE((contract->>'actionsRequired')::integer, 3),
    COALESCE((contract->>'cost')::integer, 0),
    CASE 
        WHEN COALESCE((contract->>'actionsCompleted')::integer, 0) >= COALESCE((contract->>'actionsRequired')::integer, 3) 
        THEN 'completed' 
        ELSE 'in_progress' 
    END,
    COALESCE((contract->>'createdAt')::timestamp, NOW()),
    CASE 
        WHEN COALESCE((contract->>'actionsCompleted')::integer, 0) >= COALESCE((contract->>'actionsRequired')::integer, 3) 
        THEN NOW() 
        ELSE NULL 
    END
FROM player_state ps
CROSS JOIN LATERAL jsonb_array_elements(ps.training_contracts) AS contract
WHERE ps.training_contracts IS NOT NULL 
  AND ps.training_contracts::text != '[]' 
  AND ps.training_contracts::text != 'null'
  AND jsonb_array_length(ps.training_contracts) > 0;

-- Create contributions for training contracts (based on actions_completed count)
DO $$
DECLARE
    tc RECORD;
    actions_done INTEGER;
    i INTEGER;
BEGIN
    FOR tc IN 
        SELECT ps.user_id, contract, uc.id as contract_id
        FROM player_state ps
        CROSS JOIN LATERAL jsonb_array_elements(ps.training_contracts) AS contract
        JOIN unified_contracts uc ON uc.user_id = ps.user_id 
            AND uc.type = COALESCE(contract->>'type', 'attack')
            AND uc.status IN ('in_progress', 'completed')
        WHERE ps.training_contracts IS NOT NULL 
          AND ps.training_contracts::text != '[]'
          AND jsonb_array_length(ps.training_contracts) > 0
    LOOP
        actions_done := COALESCE((tc.contract->>'actionsCompleted')::integer, 0);
        FOR i IN 1..actions_done LOOP
            INSERT INTO contract_contributions (contract_id, user_id, performed_at)
            VALUES (tc.contract_id, tc.user_id, NOW());
        END LOOP;
    END LOOP;
END $$;

-- ============================================
-- STEP 6: MIGRATE CRAFTING QUEUE FROM player_state JSONB
-- ============================================

INSERT INTO unified_contracts (user_id, type, tier, actions_required, gold_paid, iron_paid, steel_paid, status, created_at)
SELECT 
    ps.user_id,
    COALESCE(craft->>'equipmentType', 'weapon'),
    COALESCE((craft->>'tier')::integer, 1),
    COALESCE((craft->>'actionsRequired')::integer, 1),
    COALESCE((craft->>'goldCost')::integer, 0),
    COALESCE((craft->>'ironCost')::integer, 0),
    COALESCE((craft->>'steelCost')::integer, 0),
    CASE 
        WHEN COALESCE((craft->>'actionsCompleted')::integer, 0) >= COALESCE((craft->>'actionsRequired')::integer, 1) 
        THEN 'completed' 
        ELSE 'in_progress' 
    END,
    COALESCE((craft->>'createdAt')::timestamp, NOW())
FROM player_state ps
CROSS JOIN LATERAL jsonb_array_elements(ps.crafting_queue) AS craft
WHERE ps.crafting_queue IS NOT NULL 
  AND ps.crafting_queue::text != '[]' 
  AND ps.crafting_queue::text != 'null'
  AND jsonb_array_length(ps.crafting_queue) > 0;

-- ============================================
-- STEP 7: MIGRATE KINGDOM BUILDING CONTRACTS FROM contracts TABLE
-- ============================================

INSERT INTO unified_contracts (user_id, kingdom_id, kingdom_name, type, tier, actions_required, gold_paid, reward_pool, status, created_at, completed_at)
SELECT 
    created_by,
    kingdom_id,
    kingdom_name,
    building_type,
    building_level,
    total_actions_required,
    COALESCE(construction_cost, 0),
    COALESCE(reward_pool, 0),
    status,
    created_at,
    completed_at
FROM contracts
WHERE NOT EXISTS (
    SELECT 1 FROM unified_contracts uc 
    WHERE uc.kingdom_id = contracts.kingdom_id 
      AND uc.type = contracts.building_type 
      AND uc.tier = contracts.building_level
);

-- Migrate contributions from contracts.action_contributions JSONB
DO $$
DECLARE
    c RECORD;
    user_id_text TEXT;
    action_count INTEGER;
    uc_id BIGINT;
    i INTEGER;
BEGIN
    FOR c IN 
        SELECT 
            contracts.id as old_id, 
            contracts.kingdom_id,
            contracts.building_type,
            contracts.building_level,
            contracts.action_contributions
        FROM contracts
        WHERE action_contributions IS NOT NULL 
          AND action_contributions::text != '{}'
    LOOP
        -- Find the corresponding unified_contract
        SELECT id INTO uc_id FROM unified_contracts 
        WHERE kingdom_id = c.kingdom_id 
          AND type = c.building_type 
          AND tier = c.building_level
        LIMIT 1;
        
        IF uc_id IS NOT NULL THEN
            FOR user_id_text, action_count IN 
                SELECT key, value::integer 
                FROM jsonb_each_text(c.action_contributions)
                WHERE key NOT LIKE '\_%'
                  AND key ~ '^\d+$'
            LOOP
                FOR i IN 1..action_count LOOP
                    INSERT INTO contract_contributions (contract_id, user_id, performed_at)
                    VALUES (uc_id, user_id_text::bigint, NOW());
                END LOOP;
            END LOOP;
        END IF;
    END LOOP;
END $$;

-- ============================================
-- STEP 8: MIGRATE PROPERTY UPGRADE CONTRACTS FROM player_state JSONB
-- ============================================

INSERT INTO unified_contracts (user_id, type, tier, target_id, actions_required, gold_paid, status, created_at)
SELECT 
    ps.user_id,
    'property',
    COALESCE((contract->>'targetTier')::integer, 2),
    contract->>'propertyId',
    COALESCE((contract->>'actionsRequired')::integer, 10),
    COALESCE((contract->>'cost')::integer, 0),
    CASE 
        WHEN COALESCE((contract->>'actionsCompleted')::integer, 0) >= COALESCE((contract->>'actionsRequired')::integer, 10) 
        THEN 'completed' 
        ELSE 'in_progress' 
    END,
    COALESCE((contract->>'createdAt')::timestamp, NOW())
FROM player_state ps
CROSS JOIN LATERAL jsonb_array_elements(
    CASE 
        WHEN ps.property_upgrade_contracts IS NULL THEN '[]'::jsonb
        WHEN ps.property_upgrade_contracts::text = 'null' THEN '[]'::jsonb
        WHEN ps.property_upgrade_contracts::text LIKE '[%' THEN ps.property_upgrade_contracts
        ELSE '[]'::jsonb
    END
) AS contract
WHERE ps.property_upgrade_contracts IS NOT NULL 
  AND ps.property_upgrade_contracts::text != '[]' 
  AND ps.property_upgrade_contracts::text != 'null'
  AND ps.property_upgrade_contracts::text LIKE '[%';

-- ============================================
-- STEP 9: MIGRATE REPUTATION AND CHECK-IN DATA TO user_kingdoms
-- ============================================

-- Migrate reputation and check-in data from player_state to user_kingdoms
-- For each player's hometown_kingdom_id, update or create their user_kingdoms record
INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation, checkins_count, gold_earned, gold_spent)
SELECT 
    ps.user_id,
    ps.hometown_kingdom_id,
    COALESCE(ps.reputation, 0),
    COALESCE(ps.total_checkins, 0),
    0,
    0
FROM player_state ps
WHERE ps.hometown_kingdom_id IS NOT NULL
ON CONFLICT (user_id, kingdom_id) 
DO UPDATE SET
    local_reputation = EXCLUDED.local_reputation,
    checkins_count = EXCLUDED.checkins_count;

-- Migrate per-kingdom reputation from kingdom_reputation JSONB
DO $$
DECLARE
    ps_record RECORD;
    kingdom_id_text TEXT;
    rep_value INTEGER;
BEGIN
    FOR ps_record IN 
        SELECT user_id, kingdom_reputation 
        FROM player_state 
        WHERE kingdom_reputation IS NOT NULL 
          AND kingdom_reputation::text != '{}'
    LOOP
        FOR kingdom_id_text, rep_value IN 
            SELECT key, value::integer 
            FROM jsonb_each_text(ps_record.kingdom_reputation)
        LOOP
            INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation, checkins_count, gold_earned, gold_spent)
            VALUES (ps_record.user_id, kingdom_id_text, rep_value, 0, 0, 0)
            ON CONFLICT (user_id, kingdom_id)
            DO UPDATE SET
                local_reputation = GREATEST(user_kingdoms.local_reputation, EXCLUDED.local_reputation);
        END LOOP;
    END LOOP;
END $$;

-- Migrate check-in history from check_in_history JSONB
DO $$
DECLARE
    ps_record RECORD;
    kingdom_id_text TEXT;
    checkin_count INTEGER;
BEGIN
    FOR ps_record IN 
        SELECT user_id, check_in_history 
        FROM player_state 
        WHERE check_in_history IS NOT NULL 
          AND check_in_history::text != '{}'
    LOOP
        FOR kingdom_id_text, checkin_count IN 
            SELECT key, value::integer 
            FROM jsonb_each_text(ps_record.check_in_history)
        LOOP
            INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation, checkins_count, gold_earned, gold_spent)
            VALUES (ps_record.user_id, kingdom_id_text, 0, checkin_count, 0, 0)
            ON CONFLICT (user_id, kingdom_id)
            DO UPDATE SET
                checkins_count = GREATEST(user_kingdoms.checkins_count, EXCLUDED.checkins_count);
        END LOOP;
    END LOOP;
END $$;

-- ============================================
-- STEP 10: CLEANUP - DROP OLD COLUMNS FROM player_state
-- ============================================

-- Drop cooldown columns (now in action_cooldowns table)
ALTER TABLE player_state DROP COLUMN IF EXISTS last_work_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_patrol_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS patrol_expires_at;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_farm_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_sabotage_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_scout_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_training_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_crafting_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_building_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_mining_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_intelligence_action;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_spy_action;

-- Drop equipment/inventory columns (now in player_items table)
ALTER TABLE player_state DROP COLUMN IF EXISTS equipped_weapon;
ALTER TABLE player_state DROP COLUMN IF EXISTS equipped_armor;
ALTER TABLE player_state DROP COLUMN IF EXISTS equipped_shield;
ALTER TABLE player_state DROP COLUMN IF EXISTS inventory;

-- Drop contract columns (now in unified_contracts table)
ALTER TABLE player_state DROP COLUMN IF EXISTS training_contracts;
ALTER TABLE player_state DROP COLUMN IF EXISTS crafting_queue;
ALTER TABLE player_state DROP COLUMN IF EXISTS crafting_progress;
ALTER TABLE player_state DROP COLUMN IF EXISTS property_upgrade_contracts;

-- Drop properties JSONB (properties are in properties table)
ALTER TABLE player_state DROP COLUMN IF EXISTS properties;

-- Drop old kingdom tracking columns (only hometown_kingdom_id and current_kingdom_id remain)
ALTER TABLE player_state DROP COLUMN IF EXISTS origin_kingdom_id;
ALTER TABLE player_state DROP COLUMN IF EXISTS home_kingdom_id;

-- Drop reputation/check-in columns (now in user_kingdoms table)
ALTER TABLE player_state DROP COLUMN IF EXISTS reputation;
ALTER TABLE player_state DROP COLUMN IF EXISTS kingdom_reputation;
ALTER TABLE player_state DROP COLUMN IF EXISTS check_in_history;
ALTER TABLE player_state DROP COLUMN IF EXISTS total_checkins;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_check_in;
ALTER TABLE player_state DROP COLUMN IF EXISTS last_daily_check_in;

-- ============================================
-- STEP 11: CENTRALIZE hometown_kingdom_id IN player_state
-- ============================================

-- IMPORTANT: hometown_kingdom_id should ONLY exist in player_state, not in users table
-- This prevents the /auth/me and /player/state endpoints from returning different values

-- First, ensure EVERY user has hometown_kingdom_id set in player_state
-- Use current_kingdom_id as the source of truth (it's already the correct ID format)
DO $$
DECLARE
    rows_updated INTEGER;
BEGIN
    UPDATE player_state
    SET hometown_kingdom_id = current_kingdom_id
    WHERE hometown_kingdom_id IS NULL 
       OR hometown_kingdom_id != current_kingdom_id;
    
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE 'Updated % player_state rows with hometown_kingdom_id from current_kingdom_id', rows_updated;
END $$;

-- Verify all player_states have hometown_kingdom_id set
DO $$
DECLARE
    states_with_hometown INTEGER;
    total_states INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_states FROM player_state;
    
    SELECT COUNT(*) INTO states_with_hometown
    FROM player_state
    WHERE hometown_kingdom_id IS NOT NULL;
    
    IF states_with_hometown != total_states THEN
        RAISE EXCEPTION 'DATA LOSS RISK: Only % of % player_states have hometown_kingdom_id set. Aborting!', 
            states_with_hometown, total_states;
    END IF;
    
    RAISE NOTICE 'SAFETY CHECK PASSED: All % player_states have hometown_kingdom_id set', states_with_hometown;
END $$;

-- Drop the unique constraint that uses hometown_kingdom_id
ALTER TABLE users DROP CONSTRAINT IF EXISTS unique_name_per_hometown;

-- NOW it's safe to drop the column from users table
ALTER TABLE users DROP COLUMN IF EXISTS hometown_kingdom_id;

DO $$
BEGIN
    RAISE NOTICE 'Successfully removed hometown_kingdom_id from users table - now centralized in player_state';
END $$;

-- ============================================
-- DONE! 
-- ============================================

COMMIT;

-- Summary of what was migrated:
-- 1. action_cooldowns: All last_*_action timestamps from player_state
-- 2. player_items: equipped_weapon, equipped_armor, inventory from player_state
-- 3. unified_contracts: training_contracts, crafting_queue, property_upgrade_contracts from player_state
-- 4. unified_contracts: All kingdom building contracts from contracts table
-- 5. contract_contributions: All action counts converted to individual rows
-- 6. user_kingdoms: reputation, kingdom_reputation, check_in_history, total_checkins from player_state
-- 7. CLEANED UP: Removed 30+ old columns from player_state
-- 8. CENTRALIZED: hometown_kingdom_id moved from users table to player_state (single source of truth)

SELECT 'Migration complete!' as status;
SELECT 'action_cooldowns: ' || count(*) FROM action_cooldowns;
SELECT 'player_items: ' || count(*) FROM player_items;
SELECT 'unified_contracts: ' || count(*) FROM unified_contracts;
SELECT 'contract_contributions: ' || count(*) FROM contract_contributions;

