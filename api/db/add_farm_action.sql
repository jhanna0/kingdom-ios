-- Add farm action column to player_state table
-- This action is always available (like patrol) and generates gold

ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS last_farm_action TIMESTAMP;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_player_state_last_farm_action ON player_state(last_farm_action);

