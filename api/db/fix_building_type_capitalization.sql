-- Fix building_type capitalization in unified_contracts
-- Convert lowercase building types to proper display names

UPDATE unified_contracts
SET type = 'Walls'
WHERE category = 'kingdom_building' AND type = 'wall';

UPDATE unified_contracts
SET type = 'Vault'
WHERE category = 'kingdom_building' AND type = 'vault';

UPDATE unified_contracts
SET type = 'Mine'
WHERE category = 'kingdom_building' AND type = 'mine';

UPDATE unified_contracts
SET type = 'Market'
WHERE category = 'kingdom_building' AND type = 'market';

UPDATE unified_contracts
SET type = 'Farm'
WHERE category = 'kingdom_building' AND type = 'farm';

UPDATE unified_contracts
SET type = 'Education Hall'
WHERE category = 'kingdom_building' AND type = 'education';

UPDATE unified_contracts
SET type = 'Lumbermill'
WHERE category = 'kingdom_building' AND type = 'lumbermill';

-- Verify the changes
SELECT id, kingdom_name, type, tier, status 
FROM unified_contracts 
WHERE category = 'kingdom_building'
ORDER BY created_at DESC;

