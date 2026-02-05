-- Fix existing tier 3 property contracts to have option_id = 'workshop'
-- These were created before the multiple-property-rooms feature added option_id tracking

UPDATE unified_contracts 
SET option_id = 'workshop'
WHERE type = 'property' 
  AND tier = 3 
  AND option_id IS NULL;

-- Show what was updated
SELECT id, user_id, tier, option_id, created_at
FROM unified_contracts
WHERE type = 'property' AND tier = 3;
