-- Backfill Activity Statistics from Existing Data
-- ================================================
-- Run AFTER add_activity_stats.sql (creates the tables)
--
-- This migration parses existing hunt_sessions and fishing_sessions
-- JSONB data to populate player_hunt_kills and player_fish_catches
-- with historical counts.


-- ============================================================
-- BACKFILL HUNT KILLS FROM hunt_sessions JSONB
-- ============================================================
-- Parses session_data->>'animal_id' from completed hunts
-- and credits each participant with a kill.

INSERT INTO player_hunt_kills (user_id, kingdom_id, animal_id, kill_count, first_kill_at, last_kill_at)
SELECT 
    (p.value->>'player_id')::bigint as user_id,
    kingdom_id,
    session_data->>'animal_id' as animal_id,
    COUNT(*) as kill_count,
    MIN(completed_at) as first_kill_at,
    MAX(completed_at) as last_kill_at
FROM hunt_sessions,
    jsonb_each(session_data->'participants') as p
WHERE 
    status = 'completed'
    AND session_data->>'animal_id' IS NOT NULL
    AND session_data->>'animal_id' != ''
    -- Only count kills, not escapes
    AND (session_data->>'animal_escaped' IS NULL OR session_data->>'animal_escaped' = 'false')
GROUP BY 
    (p.value->>'player_id')::bigint,
    kingdom_id,
    session_data->>'animal_id'
ON CONFLICT (user_id, kingdom_id, animal_id) DO UPDATE SET
    kill_count = EXCLUDED.kill_count,
    first_kill_at = COALESCE(player_hunt_kills.first_kill_at, EXCLUDED.first_kill_at),
    last_kill_at = GREATEST(player_hunt_kills.last_kill_at, EXCLUDED.last_kill_at);


-- ============================================================
-- BACKFILL TOTAL FISH CAUGHT FROM fishing_sessions JSONB
-- ============================================================
-- NOTE: Historical fishing sessions only stored total counts, NOT per-fish-type.
-- The session_data structure was: {"fish_caught": 5, "stats": {"successful_catches": 5}}
-- Per-fish-type tracking (fish_catches: {"minnow": 3, "bass": 2}) was added later.
--
-- This backfill creates a TOTAL fish count using a special "_total" fish_id.
-- The achievements system needs to handle this specially for the fish_caught achievement.

INSERT INTO player_fish_catches (user_id, fish_id, catch_count, first_catch_at, last_catch_at)
SELECT 
    created_by as user_id,
    '_total' as fish_id,
    SUM(COALESCE((session_data->>'fish_caught')::int, 0)) as catch_count,
    MIN(completed_at) as first_catch_at,
    MAX(completed_at) as last_catch_at
FROM fishing_sessions
WHERE 
    status = 'collected'
    AND (session_data->>'fish_caught')::int > 0
GROUP BY 
    created_by
ON CONFLICT (user_id, fish_id) DO UPDATE SET
    catch_count = EXCLUDED.catch_count,
    first_catch_at = COALESCE(player_fish_catches.first_catch_at, EXCLUDED.first_catch_at),
    last_catch_at = GREATEST(player_fish_catches.last_catch_at, EXCLUDED.last_catch_at);


-- ============================================================
-- BACKFILL FORAGING FINDS FROM player_inventory
-- ============================================================
-- Since no one has traded/hatched rare eggs yet, inventory quantity = finds.
-- This is a one-time backfill; going forward, finds are tracked at drop time.

INSERT INTO player_foraging_finds (user_id, item_id, find_count, first_find_at, last_find_at)
SELECT 
    user_id,
    item_id,
    quantity as find_count,
    NOW() as first_find_at,  -- Unknown exact time, but they have them
    NOW() as last_find_at
FROM player_inventory
WHERE item_id = 'rare_egg' AND quantity > 0
ON CONFLICT (user_id, item_id) DO UPDATE SET
    find_count = EXCLUDED.find_count,
    first_find_at = COALESCE(player_foraging_finds.first_find_at, EXCLUDED.first_find_at),
    last_find_at = GREATEST(player_foraging_finds.last_find_at, EXCLUDED.last_find_at);


-- ============================================================
-- VERIFICATION QUERIES (run these manually to check)
-- ============================================================
-- Total kills per animal type (global):
--   SELECT animal_id, SUM(kill_count) as total FROM player_hunt_kills GROUP BY animal_id ORDER BY total DESC;
--
-- Top hunters by total kills (global):
--   SELECT user_id, SUM(kill_count) as total FROM player_hunt_kills GROUP BY user_id ORDER BY total DESC LIMIT 10;
--
-- Top hunters in a specific kingdom:
--   SELECT user_id, SUM(kill_count) as total FROM player_hunt_kills WHERE kingdom_id = 'YOUR_KINGDOM_ID' GROUP BY user_id ORDER BY total DESC LIMIT 10;
--
-- Compare with old hunt_sessions query:
--   SELECT session_data->>'animal_id' as animal, COUNT(*) 
--   FROM hunt_sessions 
--   WHERE status = 'completed' AND session_data->>'animal_id' IS NOT NULL
--   GROUP BY session_data->>'animal_id';
--
-- Total catches per fish type (global):
--   SELECT fish_id, SUM(catch_count) as total FROM player_fish_catches GROUP BY fish_id ORDER BY total DESC;
--
-- Top fishers by total catches (global):
--   SELECT user_id, SUM(catch_count) as total FROM player_fish_catches GROUP BY user_id ORDER BY total DESC LIMIT 10;
--
-- Check if fishing sessions have fish_catches data:
--   SELECT COUNT(*) as sessions_with_data 
--   FROM fishing_sessions 
--   WHERE status = 'collected' 
--   AND session_data->'fish_catches' IS NOT NULL
--   AND jsonb_typeof(session_data->'fish_catches') = 'object';
--
-- Sample fishing session data:
--   SELECT fishing_id, created_by, session_data->'fish_catches', completed_at
--   FROM fishing_sessions
--   WHERE status = 'collected' AND session_data->'fish_catches' IS NOT NULL
--   LIMIT 5;
