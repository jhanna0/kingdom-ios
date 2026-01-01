-- Add total_training_purchases field to track global training cost scaling
-- This makes each training purchase increase the cost of ALL future training
-- Forces strategic choices - players can't easily max everything!

-- Add the new column with default value of 0
ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS total_training_purchases INTEGER DEFAULT 0;

-- Update existing players to have a reasonable starting value based on their stats
-- This ensures existing players don't get hit with massive costs immediately
-- We calculate it as: (attack + defense + leadership + building + intelligence) - 5 (starting stats)
UPDATE player_state 
SET total_training_purchases = GREATEST(0, 
    (attack_power + defense_power + leadership + building_skill + intelligence) - 5
)
WHERE total_training_purchases = 0;

-- Create an index for efficient queries
CREATE INDEX IF NOT EXISTS idx_player_state_training_purchases 
ON player_state(total_training_purchases);



