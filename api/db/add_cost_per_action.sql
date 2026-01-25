-- ============================================
-- ADD cost_per_action TO unified_contracts
-- For Pay-As-You-Go training system
-- 
-- Run: docker exec -i kingdom-db psql -U admin -d kingdom < api/db/add_cost_per_action.sql
-- ============================================

BEGIN;

-- Add cost_per_action column for Pay-As-You-Go training
-- This stores the base gold cost per action (burned/destroyed)
-- Tax is calculated on top at runtime and goes to kingdom treasury
ALTER TABLE unified_contracts 
ADD COLUMN IF NOT EXISTS cost_per_action INTEGER DEFAULT 0;

-- Add comment explaining the column
COMMENT ON COLUMN unified_contracts.cost_per_action IS 
'Pay-As-You-Go: Base gold cost per action. For training contracts, this is locked in at purchase time using formula: 10 + 2 * total_skill_points. This amount is BURNED (destroyed) each action. Tax is added on top and goes to kingdom.';

-- For existing in-progress training contracts, we need to set a reasonable cost_per_action
-- based on their gold_paid and actions_required (best effort migration)
-- Formula: If gold was paid upfront, estimate what per-action cost would have been
UPDATE unified_contracts
SET cost_per_action = CASE 
    WHEN actions_required > 0 AND gold_paid > 0 
    THEN GREATEST(10, gold_paid / actions_required)  -- Estimate from upfront cost
    ELSE 10  -- Minimum base cost
END
WHERE category = 'personal_training'
  AND cost_per_action = 0
  AND completed_at IS NULL;  -- Only update active contracts

COMMIT;

-- Verify the migration
SELECT 'Migration complete!' as status;
SELECT 
    'Active training contracts updated: ' || COUNT(*) 
FROM unified_contracts 
WHERE category = 'personal_training' 
  AND completed_at IS NULL 
  AND cost_per_action > 0;
