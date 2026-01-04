-- Add wood resource to player_state
-- Wood is harvested from lumbermill buildings via "chop wood" action
-- Required for property upgrades after T1 (except land clearing)

ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS wood INTEGER DEFAULT 0;

-- Update existing players to have 0 wood
UPDATE player_state SET wood = 0 WHERE wood IS NULL;


