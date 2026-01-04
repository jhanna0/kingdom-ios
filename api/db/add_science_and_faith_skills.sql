-- Add Science and Faith skills to player_state
-- Science: Better weapons and armor (crafting bonuses)
-- Faith: Random battle RNG heals, buffs, etc

ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS science INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS faith INT DEFAULT 0;

-- Update existing players to start at 0 for new skills
UPDATE player_state SET science = 0 WHERE science IS NULL;
UPDATE player_state SET faith = 0 WHERE faith IS NULL;

