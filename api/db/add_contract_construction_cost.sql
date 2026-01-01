-- Add construction cost field to contracts
-- This is separate from reward_pool - it's what the RULER pays upfront to START building
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS construction_cost INTEGER DEFAULT 0;

-- Update existing contracts to have a reasonable construction cost based on their level
-- Formula: 1000 * (2^(level-1)) * (1 + population/50)
UPDATE contracts 
SET construction_cost = CAST(
    1000 * POWER(2, building_level - 1) * (1 + base_population / 50.0)
    AS INTEGER
)
WHERE construction_cost = 0;



