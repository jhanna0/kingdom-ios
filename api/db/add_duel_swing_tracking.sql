-- Add multi-swing tracking fields to duel_matches
-- Each turn, player can swing multiple times (1 + attack stat)
-- Turn only ends after all swings are used

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS turn_swings_used INTEGER DEFAULT 0;

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS turn_max_swings INTEGER DEFAULT 1;

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS turn_best_outcome VARCHAR(20);

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS turn_best_push FLOAT DEFAULT 0.0;

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS turn_rolls JSONB;

-- Add comment
COMMENT ON COLUMN duel_matches.turn_swings_used IS 'Number of swings used this turn';
COMMENT ON COLUMN duel_matches.turn_max_swings IS 'Max swings for this turn (1 + attack)';
COMMENT ON COLUMN duel_matches.turn_best_outcome IS 'Best outcome so far: miss, hit, critical';
COMMENT ON COLUMN duel_matches.turn_best_push IS 'Push amount from best outcome';
COMMENT ON COLUMN duel_matches.turn_rolls IS 'All rolls this turn for display';
