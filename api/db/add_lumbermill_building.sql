-- Add lumbermill building to kingdoms
-- Lumbermill allows citizens to chop wood for construction

ALTER TABLE kingdoms
ADD COLUMN IF NOT EXISTS lumbermill_level INTEGER DEFAULT 0;

-- Update existing kingdoms to have lumbermill level 0
UPDATE kingdoms SET lumbermill_level = 0 WHERE lumbermill_level IS NULL;



