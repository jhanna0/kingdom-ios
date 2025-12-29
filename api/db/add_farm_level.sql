-- Add farm_level column to kingdoms table
-- Farm speeds up contract completion for all citizens

ALTER TABLE kingdoms 
ADD COLUMN IF NOT EXISTS farm_level INTEGER DEFAULT 0;

-- Add comment
COMMENT ON COLUMN kingdoms.farm_level IS 'Farm level - speeds up contract completion for citizens (0-5)';

