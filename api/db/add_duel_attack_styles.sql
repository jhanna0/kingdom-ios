-- Add attack style columns to duel_matches table
-- Run this migration to add support for the attack style system

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS style_lock_expires_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS challenger_style VARCHAR(20),
ADD COLUMN IF NOT EXISTS opponent_style VARCHAR(20),
ADD COLUMN IF NOT EXISTS challenger_style_locked_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS opponent_style_locked_at TIMESTAMP;

-- Add comments for documentation
COMMENT ON COLUMN duel_matches.style_lock_expires_at IS 'When the style selection phase ends for the current round';
COMMENT ON COLUMN duel_matches.challenger_style IS 'Attack style chosen by challenger (balanced, aggressive, precise, power, guard, feint)';
COMMENT ON COLUMN duel_matches.opponent_style IS 'Attack style chosen by opponent';
COMMENT ON COLUMN duel_matches.challenger_style_locked_at IS 'When challenger locked in their style';
COMMENT ON COLUMN duel_matches.opponent_style_locked_at IS 'When opponent locked in their style';
