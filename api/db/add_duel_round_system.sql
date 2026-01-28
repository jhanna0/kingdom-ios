-- Migration: Add PvP Duel Round System (simultaneous rounds)
-- Date: 2026-01-27
-- Description:
--   Adds round-based simultaneous submission fields to duel_matches.
--   Replaces turn-based flow at the application layer, but keeps existing
--   turn fields for backwards compatibility during rollout.

-- Round tracking
ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS round_number INTEGER DEFAULT 1;

ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS round_expires_at TIMESTAMP WITH TIME ZONE;

-- Pending submissions (persist across reconnects)
-- Stored shape (example):
--   [{"roll_number":1,"value":12.3,"outcome":"hit"}, ...]
ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS pending_challenger_round_rolls JSONB;

ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS pending_opponent_round_rolls JSONB;

-- Optional timestamps for debugging/UX
ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS pending_challenger_round_submitted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE duel_matches
ADD COLUMN IF NOT EXISTS pending_opponent_round_submitted_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN duel_matches.round_number IS 'Current simultaneous round number (starts at 1)';
COMMENT ON COLUMN duel_matches.round_expires_at IS 'Round submission deadline (shared timer)';
COMMENT ON COLUMN duel_matches.pending_challenger_round_rolls IS 'Challenger submitted roll list for current round';
COMMENT ON COLUMN duel_matches.pending_opponent_round_rolls IS 'Opponent submitted roll list for current round';
COMMENT ON COLUMN duel_matches.pending_challenger_round_submitted_at IS 'When challenger submitted current round';
COMMENT ON COLUMN duel_matches.pending_opponent_round_submitted_at IS 'When opponent submitted current round';

COMMIT;
