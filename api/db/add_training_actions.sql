-- Add training contract system to player_state
-- Migration: Training works like building contracts
-- Date: 2025-12-29

-- Remove old training columns if they exist
ALTER TABLE player_state
DROP COLUMN IF EXISTS last_train_attack_action,
DROP COLUMN IF EXISTS last_train_defense_action,
DROP COLUMN IF EXISTS last_train_leadership_action,
DROP COLUMN IF EXISTS last_train_building_action,
DROP COLUMN IF EXISTS training_sessions_attack,
DROP COLUMN IF EXISTS training_sessions_defense,
DROP COLUMN IF EXISTS training_sessions_leadership,
DROP COLUMN IF EXISTS training_sessions_building;

-- Add new training system columns
ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS last_training_action TIMESTAMP,
ADD COLUMN IF NOT EXISTS training_contracts JSONB DEFAULT '[]'::jsonb;

-- Add index for training action cooldown
CREATE INDEX IF NOT EXISTS idx_player_state_last_training_action ON player_state(last_training_action);

