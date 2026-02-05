-- Add option_id to unified_contracts to track which room is being built
ALTER TABLE unified_contracts ADD COLUMN IF NOT EXISTS option_id VARCHAR(64);
