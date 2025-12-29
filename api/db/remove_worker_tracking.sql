-- Remove deprecated worker tracking from contracts system
-- Workers are no longer tracked - users just contribute directly to contracts

-- Remove workers column from contracts table
ALTER TABLE contracts DROP COLUMN IF EXISTS workers;

-- Remove active_contract_id from player_state table
ALTER TABLE player_state DROP COLUMN IF EXISTS active_contract_id;

-- Note: action_contributions column remains - this tracks who contributed what
-- This is the only tracking we need for proportional reward distribution

