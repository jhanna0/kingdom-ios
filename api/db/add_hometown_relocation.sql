-- Add hometown relocation tracking
-- Players can relocate their hometown once every 60 days
-- First hometown set (during onboarding) doesn't count toward cooldown

ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS last_hometown_change TIMESTAMP;

-- Set initial value to NULL for existing players (so they can change immediately if desired)
-- The cooldown only applies AFTER the first manual change

COMMENT ON COLUMN player_state.last_hometown_change IS 'Timestamp of last manual hometown relocation. NULL means never relocated (first change is free). Used to enforce 60-day cooldown between relocations.';


-- Players can relocate their hometown once every 60 days
-- First hometown set (during onboarding) doesn't count toward cooldown

ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS last_hometown_change TIMESTAMP;

-- Set initial value to NULL for existing players (so they can change immediately if desired)
-- The cooldown only applies AFTER the first manual change

COMMENT ON COLUMN player_state.last_hometown_change IS 'Timestamp of last manual hometown relocation. NULL means never relocated (first change is free). Used to enforce 60-day cooldown between relocations.';

