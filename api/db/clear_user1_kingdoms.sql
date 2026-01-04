-- Clear kingdom ruling history for User 1 (Gerard the Wise)
-- This allows them to claim a starting city for free

-- 1. Remove User 1 as ruler from any kingdoms they rule
UPDATE kingdoms
SET ruler_id = NULL
WHERE ruler_id = 1;

-- 2. Reset player state kingdom counters
UPDATE player_state
SET 
    kingdoms_ruled = 0,
    total_conquests = 0,
    has_claimed_starting_city = false
WHERE user_id = 1;

-- 3. (Optional) Reset user_kingdoms association table
-- This clears conquest history but keeps check-in stats
UPDATE user_kingdoms
SET times_conquered = 0
WHERE user_id = 1;

-- Verify the changes
SELECT 
    'User 1 Player State' as check_type,
    gold,
    kingdoms_ruled,
    total_conquests,
    has_claimed_starting_city
FROM player_state
WHERE user_id = 1;

SELECT 
    'Kingdoms previously ruled by User 1' as check_type,
    id,
    name,
    ruler_id
FROM kingdoms
WHERE id IN (
    SELECT kingdom_id FROM user_kingdoms WHERE user_id = 1 AND times_conquered > 0
);


