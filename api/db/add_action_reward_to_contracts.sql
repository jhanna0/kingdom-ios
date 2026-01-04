-- Add action_reward to unified_contracts
-- This allows rulers to set the price per action, enabling ruler-driven economics
-- The upfront cost is calculated as: actions_required × action_reward

ALTER TABLE unified_contracts
ADD COLUMN IF NOT EXISTS action_reward INTEGER DEFAULT 0;

-- Update existing contracts to have a reasonable action reward
-- Calculate backwards from existing reward_pool: action_reward = reward_pool / actions_required
-- Only kingdom_building contracts should have action_reward > 0
-- Personal contracts (property, training, crafting) earn no gold
UPDATE unified_contracts 
SET action_reward = CASE
    WHEN category = 'kingdom_building' AND actions_required > 0 AND reward_pool > 0 
    THEN reward_pool / actions_required
    ELSE 0
END
WHERE action_reward = 0;

-- Add index for queries
CREATE INDEX IF NOT EXISTS idx_uc_action_reward ON unified_contracts(action_reward);

