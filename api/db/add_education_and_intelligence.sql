-- Migration: Add education_level to kingdoms and intelligence to player_state
-- Run this migration to add the new education building and intelligence skill

-- Add education_level column to kingdoms table
ALTER TABLE kingdoms 
ADD COLUMN IF NOT EXISTS education_level INTEGER DEFAULT 0;

-- Add intelligence column to player_state table
ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS intelligence INTEGER DEFAULT 1;

-- Create indexes for potential queries
CREATE INDEX IF NOT EXISTS idx_kingdoms_education_level ON kingdoms(education_level);
CREATE INDEX IF NOT EXISTS idx_player_state_intelligence ON player_state(intelligence);

-- Comments for documentation
COMMENT ON COLUMN kingdoms.education_level IS 'Education building level (0-5). Reduces training actions required for citizens.';
COMMENT ON COLUMN player_state.intelligence IS 'Intelligence skill level (1+). Improves sabotage success and patrol detection rates.';

