-- Add repeat_count column to player_activity_log
-- This allows consecutive identical actions to be stored as a single row with a count

ALTER TABLE player_activity_log 
ADD COLUMN IF NOT EXISTS repeat_count INTEGER NOT NULL DEFAULT 1;
