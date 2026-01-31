-- Backfill Activity Statistics from Existing Data
-- ================================================
-- Run AFTER add_activity_stats.sql (creates the tables)
--
-- This migration parses existing hunt_sessions JSONB data
-- to populate player_hunt_kills with historical counts.
--
-- NOTE: Fishing catches were not stored historically, so there's
-- nothing to backfill for player_fish_catches. New catches will
-- be tracked going forward.


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
