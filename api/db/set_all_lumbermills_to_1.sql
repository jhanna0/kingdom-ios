-- Update all kingdoms to have lumbermill level 1
-- This ensures all cities can gather wood for construction
-- Run: docker exec -i kingdom-db psql -U admin -d kingdom < api/db/set_all_lumbermills_to_1.sql

BEGIN;

-- Update all kingdoms to have lumbermill level 1 (if currently at 0 or null)
UPDATE kingdoms 
SET lumbermill_level = 1, 
    updated_at = NOW()
WHERE lumbermill_level < 1 OR lumbermill_level IS NULL;

-- Show results
SELECT 
    COUNT(*) as total_kingdoms,
    COUNT(*) FILTER (WHERE lumbermill_level >= 1) as kingdoms_with_lumbermill,
    COUNT(*) FILTER (WHERE lumbermill_level = 1) as level_1_lumbermills
FROM kingdoms;

COMMIT;

SELECT 'All kingdoms now have lumbermill level 1!' as status;
