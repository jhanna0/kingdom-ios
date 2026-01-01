-- Remove property type column and last_income_collection
-- Properties are now a single 5-tier progression system (not separate types)

BEGIN;

-- Remove type column if it exists
ALTER TABLE properties DROP COLUMN IF EXISTS type;

-- Remove last_income_collection (no passive income anymore)
ALTER TABLE properties DROP COLUMN IF EXISTS last_income_collection;

-- Add index on owner_id and kingdom_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_properties_owner_kingdom 
ON properties(owner_id, kingdom_id);

COMMIT;



