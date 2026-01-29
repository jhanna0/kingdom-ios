-- ============================================================
-- COMPLETE DUEL SYSTEM MIGRATION
-- ============================================================
-- Generated from current backend model (api/db/models/duel.py)
-- Run this to set up the full duel system from scratch
-- All statements use IF NOT EXISTS / IF EXISTS for idempotency
-- ============================================================

-- ============================================================
-- 1. CORE TABLES
-- ============================================================

-- Main duel matches table
CREATE TABLE IF NOT EXISTS duel_matches (
    id SERIAL PRIMARY KEY,
    
    -- Match identification
    match_code VARCHAR(8) UNIQUE NOT NULL,
    kingdom_id VARCHAR(255) NOT NULL,
    
    -- Players
    challenger_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenger_name VARCHAR(255) NOT NULL,
    opponent_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    opponent_name VARCHAR(255),
    
    -- Match state
    status VARCHAR(20) NOT NULL DEFAULT 'waiting',
    
    -- Combat bar (0-100): 0 = challenger wins, 100 = opponent wins
    control_bar FLOAT NOT NULL DEFAULT 50.0,
    
    -- Legacy turn tracking (kept for backwards compat)
    current_turn VARCHAR(20),
    turn_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Stats snapshots at match start
    challenger_stats JSONB,
    opponent_stats JSONB,
    
    -- Results
    winner_id INTEGER REFERENCES users(id),
    winner_side VARCHAR(20),
    
    -- Wager
    wager_gold INTEGER DEFAULT 0,
    winner_gold_earned INTEGER,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for duel_matches
CREATE INDEX IF NOT EXISTS idx_duel_matches_kingdom ON duel_matches(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_challenger ON duel_matches(challenger_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_opponent ON duel_matches(opponent_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_status ON duel_matches(status);
CREATE INDEX IF NOT EXISTS idx_duel_matches_code ON duel_matches(match_code);

-- Duel invitations
CREATE TABLE IF NOT EXISTS duel_invitations (
    id SERIAL PRIMARY KEY,
    match_id INTEGER NOT NULL REFERENCES duel_matches(id) ON DELETE CASCADE,
    inviter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT unique_invitation UNIQUE (match_id, invitee_id)
);

CREATE INDEX IF NOT EXISTS idx_duel_invitations_match ON duel_invitations(match_id);
CREATE INDEX IF NOT EXISTS idx_duel_invitations_invitee ON duel_invitations(invitee_id);
CREATE INDEX IF NOT EXISTS idx_duel_invitations_status ON duel_invitations(status);

-- Duel actions (round resolution history)
CREATE TABLE IF NOT EXISTS duel_actions (
    id SERIAL PRIMARY KEY,
    match_id INTEGER NOT NULL REFERENCES duel_matches(id) ON DELETE CASCADE,
    player_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    side VARCHAR(20) NOT NULL,
    roll_value FLOAT NOT NULL,
    outcome VARCHAR(20) NOT NULL,
    push_amount FLOAT NOT NULL DEFAULT 0.0,
    bar_before FLOAT NOT NULL,
    bar_after FLOAT NOT NULL,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_duel_actions_match ON duel_actions(match_id);
CREATE INDEX IF NOT EXISTS idx_duel_actions_player ON duel_actions(player_id);

-- Duel stats (lifetime per player)
CREATE TABLE IF NOT EXISTS duel_stats (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    total_gold_won INTEGER NOT NULL DEFAULT 0,
    total_gold_lost INTEGER NOT NULL DEFAULT 0,
    win_streak INTEGER NOT NULL DEFAULT 0,
    best_win_streak INTEGER NOT NULL DEFAULT 0,
    last_duel_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_duel_stats_user ON duel_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_duel_stats_wins ON duel_stats(wins DESC);

-- Pairing history (for fair turn alternation)
CREATE TABLE IF NOT EXISTS duel_pairing_history (
    id SERIAL PRIMARY KEY,
    player_a_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    player_b_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_first_player_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_match_id INTEGER REFERENCES duel_matches(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_pairing UNIQUE (player_a_id, player_b_id),
    CONSTRAINT proper_pair_order CHECK (player_a_id < player_b_id)
);

CREATE INDEX IF NOT EXISTS idx_duel_pairing_a ON duel_pairing_history(player_a_id);
CREATE INDEX IF NOT EXISTS idx_duel_pairing_b ON duel_pairing_history(player_b_id);

-- ============================================================
-- 2. ROUND SYSTEM COLUMNS
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS round_number INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS round_phase VARCHAR(20) DEFAULT 'style_selection';
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS round_expires_at TIMESTAMP WITH TIME ZONE;

-- ============================================================
-- 3. STYLE SELECTION COLUMNS
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS style_lock_expires_at TIMESTAMP;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_style VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_style VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_style_locked_at TIMESTAMP;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_style_locked_at TIMESTAMP;

-- ============================================================
-- 4. SWING PHASE - CHALLENGER STATE
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_swings_used INTEGER DEFAULT 0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_max_swings INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_best_outcome VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_best_push FLOAT DEFAULT 0.0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_submitted BOOLEAN DEFAULT FALSE;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS challenger_submitted_at TIMESTAMP;

-- ============================================================
-- 5. SWING PHASE - OPPONENT STATE
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_swings_used INTEGER DEFAULT 0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_max_swings INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_best_outcome VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_best_push FLOAT DEFAULT 0.0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_submitted BOOLEAN DEFAULT FALSE;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS opponent_submitted_at TIMESTAMP;

-- ============================================================
-- 6. SWING PHASE TIMEOUT
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS swing_phase_expires_at TIMESTAMP;

-- ============================================================
-- 7. LEGACY TURN TRACKING (for backwards compat)
-- ============================================================

ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS first_turn_player_id INTEGER REFERENCES users(id);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS turn_swings_used INTEGER DEFAULT 0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS turn_max_swings INTEGER DEFAULT 1;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS turn_best_outcome VARCHAR(20);
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS turn_best_push FLOAT DEFAULT 0.0;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS turn_rolls JSONB;

-- Legacy round submission fields
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS pending_challenger_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS pending_opponent_round_rolls JSONB;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS pending_challenger_round_submitted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE duel_matches ADD COLUMN IF NOT EXISTS pending_opponent_round_submitted_at TIMESTAMP WITH TIME ZONE;

-- ============================================================
-- 8. UPDATE STATUS CONSTRAINT
-- ============================================================
-- Drop old constraint if exists, add new one with all statuses

ALTER TABLE duel_matches DROP CONSTRAINT IF EXISTS valid_status;
ALTER TABLE duel_matches ADD CONSTRAINT valid_status 
    CHECK (status IN ('waiting', 'pending_acceptance', 'ready', 'fighting', 'complete', 'cancelled', 'expired', 'declined'));

-- ============================================================
-- DONE
-- ============================================================
