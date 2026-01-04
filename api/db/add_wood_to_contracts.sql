-- Add wood_paid to unified_contracts for tracking wood costs
-- Wood is required for property upgrades after T1

ALTER TABLE unified_contracts
ADD COLUMN IF NOT EXISTS wood_paid INTEGER DEFAULT 0;

-- Update existing contracts to have 0 wood paid
UPDATE unified_contracts SET wood_paid = 0 WHERE wood_paid IS NULL;


