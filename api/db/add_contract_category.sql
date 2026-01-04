-- Add category field to unified_contracts to distinguish contract types
-- This makes it clean and avoids hardcoding type lists

ALTER TABLE unified_contracts
ADD COLUMN IF NOT EXISTS category VARCHAR(32);

-- Set category for existing contracts based on type
UPDATE unified_contracts
SET category = CASE
    WHEN type IN ('property') THEN 'personal_property'
    WHEN type IN ('attack', 'defense', 'leadership', 'building', 'intelligence') THEN 'personal_training'
    WHEN type IN ('weapon', 'armor') THEN 'personal_crafting'
    ELSE 'kingdom_building'
END
WHERE category IS NULL;

-- Make it NOT NULL after setting values
ALTER TABLE unified_contracts
ALTER COLUMN category SET NOT NULL;

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_unified_contracts_category ON unified_contracts(category);

COMMENT ON COLUMN unified_contracts.category IS 'Contract category: kingdom_building, personal_property, personal_training, personal_crafting';

