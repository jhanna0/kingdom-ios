-- Add property_upgrade_contracts field to track active property upgrades
-- Works like training contracts - player pays gold, gets contract, completes actions

ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS property_upgrade_contracts JSONB DEFAULT '[]'::jsonb;



