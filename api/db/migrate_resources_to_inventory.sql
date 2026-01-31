-- MIGRATION: Move iron, steel, wood, stone from player_state columns to player_inventory table
-- This completes the inventory system refactor - all resources now use the proper inventory table
--
-- Run this BEFORE deploying the code changes that remove the columns
-- The code changes will ignore the columns, so this migration is safe to run first
--
-- To run: psql $DATABASE_URL -f api/db/migrate_resources_to_inventory.sql

BEGIN;

-- ============================================================
-- STEP 1: Migrate existing column data to player_inventory
-- ============================================================
-- Uses ON CONFLICT to handle players who might already have inventory rows
-- (shouldn't happen for these resources, but safe to handle)

-- Migrate IRON
INSERT INTO player_inventory (user_id, item_id, quantity)
SELECT user_id, 'iron', iron 
FROM player_state 
WHERE iron > 0
ON CONFLICT (user_id, item_id) 
DO UPDATE SET quantity = player_inventory.quantity + EXCLUDED.quantity;

-- Migrate WOOD
INSERT INTO player_inventory (user_id, item_id, quantity)
SELECT user_id, 'wood', wood 
FROM player_state 
WHERE wood > 0
ON CONFLICT (user_id, item_id) 
DO UPDATE SET quantity = player_inventory.quantity + EXCLUDED.quantity;

-- Migrate STONE
INSERT INTO player_inventory (user_id, item_id, quantity)
SELECT user_id, 'stone', stone 
FROM player_state 
WHERE stone > 0
ON CONFLICT (user_id, item_id) 
DO UPDATE SET quantity = player_inventory.quantity + EXCLUDED.quantity;

-- ============================================================
-- STEP 2: Verify migration counts
-- ============================================================

DO $$
DECLARE
    iron_players INTEGER;
    wood_players INTEGER;
    stone_players INTEGER;
    inv_iron INTEGER;
    inv_wood INTEGER;
    inv_stone INTEGER;
BEGIN
    -- Count players with resources in old columns
    SELECT COUNT(*) INTO iron_players FROM player_state WHERE iron > 0;
    SELECT COUNT(*) INTO wood_players FROM player_state WHERE wood > 0;
    SELECT COUNT(*) INTO stone_players FROM player_state WHERE stone > 0;
    
    -- Count inventory rows created
    SELECT COUNT(*) INTO inv_iron FROM player_inventory WHERE item_id = 'iron';
    SELECT COUNT(*) INTO inv_wood FROM player_inventory WHERE item_id = 'wood';
    SELECT COUNT(*) INTO inv_stone FROM player_inventory WHERE item_id = 'stone';
    
    RAISE NOTICE '=== Migration Summary ===';
    RAISE NOTICE 'Iron:  % players migrated -> % inventory rows', iron_players, inv_iron;
    RAISE NOTICE 'Wood:  % players migrated -> % inventory rows', wood_players, inv_wood;
    RAISE NOTICE 'Stone: % players migrated -> % inventory rows', stone_players, inv_stone;
END $$;

-- ============================================================
-- STEP 3: Drop the old columns (OPTIONAL - do this after verifying)
-- ============================================================
-- Uncomment these lines AFTER confirming the migration worked
-- and AFTER deploying the code changes

-- ALTER TABLE player_state DROP COLUMN IF EXISTS iron;
-- ALTER TABLE player_state DROP COLUMN IF EXISTS wood;
-- ALTER TABLE player_state DROP COLUMN IF EXISTS stone;

COMMIT;

-- ============================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================
-- If something goes wrong, you can restore from inventory back to columns:
--
-- UPDATE player_state ps
-- SET iron = COALESCE((SELECT quantity FROM player_inventory pi WHERE pi.user_id = ps.user_id AND pi.item_id = 'iron'), 0),
--     wood = COALESCE((SELECT quantity FROM player_inventory pi WHERE pi.user_id = ps.user_id AND pi.item_id = 'wood'), 0),
--     stone = COALESCE((SELECT quantity FROM player_inventory pi WHERE pi.user_id = ps.user_id AND pi.item_id = 'stone'), 0);
