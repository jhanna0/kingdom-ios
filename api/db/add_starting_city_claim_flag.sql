-- Add has_claimed_starting_city field to player_state table
-- This prevents users from claiming multiple cities as their initial free claim
-- (Military conquest is still allowed after initial claim)

ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS has_claimed_starting_city BOOLEAN DEFAULT FALSE;

-- All existing users haven't claimed yet (or already claimed before this flag existed)
-- Set to FALSE by default to allow them one claim
UPDATE player_state
SET has_claimed_starting_city = FALSE
WHERE has_claimed_starting_city IS NULL;

-- Optional: Set to TRUE for users who already rule kingdoms (already claimed)
-- This prevents existing rulers from claiming another city
UPDATE player_state
SET has_claimed_starting_city = TRUE
WHERE kingdoms_ruled > 0;

