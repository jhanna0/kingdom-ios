-- ============================================================
-- DUEL SWING PHASE MIGRATION
-- ============================================================
-- Adds fields for player-controlled swing-by-swing combat
-- Each player controls their own swings independently
-- Round resolves when both players have stopped

-- Round phase tracking
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS round_phase VARCHAR(20) DEFAULT 'style_selection';
-- Values: 'style_selection', 'swinging', 'resolving'

-- Challenger swing state (independent of opponent)
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_swings_used INTEGER DEFAULT 0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_max_swings INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_best_outcome VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_best_push FLOAT DEFAULT 0.0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_submitted BOOLEAN DEFAULT FALSE;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_submitted_at TIMESTAMP;

-- Opponent swing state (independent of challenger)
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_swings_used INTEGER DEFAULT 0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_max_swings INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_best_outcome VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_best_push FLOAT DEFAULT 0.0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_submitted BOOLEAN DEFAULT FALSE;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_submitted_at TIMESTAMP;

-- Swing phase timeout (separate from round timeout)
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS swing_phase_expires_at TIMESTAMP;

-- Comments for clarity
COMMENT ON COLUMN duel_matches.round_phase IS 'Current phase: style_selection, swinging, resolving';
COMMENT ON COLUMN duel_matches.challenger_swings_used IS 'Swings used by challenger this round';
COMMENT ON COLUMN duel_matches.challenger_best_outcome IS 'Best outcome so far: miss, hit, critical';
COMMENT ON COLUMN duel_matches.challenger_submitted IS 'Has challenger stopped/submitted this round';
COMMENT ON COLUMN duel_matches.swing_phase_expires_at IS 'When swing phase times out (auto-stop)';
