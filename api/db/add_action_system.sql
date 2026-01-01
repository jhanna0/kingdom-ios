-- Add action-based system to contracts and player_state
-- Migration: Action System
-- Date: 2025-12-28

-- Add action-based columns to contracts table
ALTER TABLE contracts 
ADD COLUMN IF NOT EXISTS total_actions_required INTEGER NOT NULL DEFAULT 1000,
ADD COLUMN IF NOT EXISTS actions_completed INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS action_contributions JSONB DEFAULT '{}'::jsonb;

-- Add action cooldown tracking to player_state table
ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS last_work_action TIMESTAMP,
ADD COLUMN IF NOT EXISTS last_patrol_action TIMESTAMP,
ADD COLUMN IF NOT EXISTS last_sabotage_action TIMESTAMP,
ADD COLUMN IF NOT EXISTS last_scout_action TIMESTAMP,
ADD COLUMN IF NOT EXISTS patrol_expires_at TIMESTAMP;

-- Update existing contracts to have action requirements based on building level
-- Formula: 100 * 2^(level-1) actions
-- Level 1: 100 actions, Level 2: 200, Level 3: 400, Level 4: 800, Level 5: 1600
UPDATE contracts
SET total_actions_required = CAST(100 * POWER(2, building_level - 1) AS INTEGER)
WHERE total_actions_required = 1000;  -- Only update default values

COMMENT ON COLUMN contracts.total_actions_required IS 'Total actions needed to complete contract';
COMMENT ON COLUMN contracts.actions_completed IS 'Current action progress';
COMMENT ON COLUMN contracts.action_contributions IS 'JSON object tracking {user_id: action_count}';
COMMENT ON COLUMN player_state.last_work_action IS 'Last time player contributed to a contract';
COMMENT ON COLUMN player_state.last_patrol_action IS 'Last time player started a patrol';
COMMENT ON COLUMN player_state.last_sabotage_action IS 'Last time player attempted sabotage';
COMMENT ON COLUMN player_state.last_scout_action IS 'Last time player scouted enemy kingdom';
COMMENT ON COLUMN player_state.patrol_expires_at IS 'When current patrol duty ends (10 min duration)';



