-- Migration: Add PvP Arena Duel System
-- Date: 2026-01-12
-- Description: Adds tables for 1v1 PvP duels in the Town Hall arena

-- ============================================================
-- DUEL MATCHES TABLE
-- ============================================================
-- Core table for duel state. Simple 1v1 with a single tug-of-war bar.

CREATE TABLE IF NOT EXISTS duel_matches (
    id SERIAL PRIMARY KEY,
    
    -- Match identification
    match_code VARCHAR(8) UNIQUE NOT NULL,  -- Short code for sharing (e.g., "ABC123")
    kingdom_id VARCHAR(255) NOT NULL,        -- Town Hall location
    
    -- Players
    challenger_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenger_name VARCHAR(255) NOT NULL,
    opponent_id INTEGER REFERENCES users(id) ON DELETE CASCADE,  -- NULL until accepted
    opponent_name VARCHAR(255),
    
    -- Match state: 'waiting', 'ready', 'fighting', 'complete', 'cancelled', 'expired'
    status VARCHAR(20) NOT NULL DEFAULT 'waiting',
    
    -- Combat bar (0-100): 0 = challenger wins, 100 = opponent wins
    -- Starts at 50 (neutral)
    control_bar FLOAT NOT NULL DEFAULT 50.0,
    
    -- Turn tracking: whose turn is it? ('challenger' or 'opponent')
    current_turn VARCHAR(20),
    turn_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Stats snapshots at match start (for fair play)
    challenger_stats JSONB,  -- {attack, defense, leadership, level}
    opponent_stats JSONB,
    
    -- Results
    winner_id INTEGER REFERENCES users(id),
    winner_side VARCHAR(20),  -- 'challenger' or 'opponent'
    
    -- Rewards
    wager_gold INTEGER DEFAULT 0,  -- Optional gold wager
    winner_gold_earned INTEGER,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,  -- When opponent accepted and fight began
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,  -- Invitation expires after this
    
    -- Indexes for fast lookups
    CONSTRAINT valid_status CHECK (status IN ('waiting', 'ready', 'fighting', 'complete', 'cancelled', 'expired'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_duel_matches_kingdom ON duel_matches(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_challenger ON duel_matches(challenger_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_opponent ON duel_matches(opponent_id);
CREATE INDEX IF NOT EXISTS idx_duel_matches_status ON duel_matches(status);
CREATE INDEX IF NOT EXISTS idx_duel_matches_code ON duel_matches(match_code);

-- ============================================================
-- DUEL INVITATIONS TABLE
-- ============================================================
-- Track pending invitations sent to specific friends

CREATE TABLE IF NOT EXISTS duel_invitations (
    id SERIAL PRIMARY KEY,
    match_id INTEGER NOT NULL REFERENCES duel_matches(id) ON DELETE CASCADE,
    inviter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Status: 'pending', 'accepted', 'declined', 'expired'
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    
    -- One invitation per person per match
    CONSTRAINT unique_invitation UNIQUE (match_id, invitee_id),
    CONSTRAINT valid_invite_status CHECK (status IN ('pending', 'accepted', 'declined', 'expired'))
);

CREATE INDEX IF NOT EXISTS idx_duel_invitations_match ON duel_invitations(match_id);
CREATE INDEX IF NOT EXISTS idx_duel_invitations_invitee ON duel_invitations(invitee_id);
CREATE INDEX IF NOT EXISTS idx_duel_invitations_status ON duel_invitations(status);

-- ============================================================
-- DUEL ACTIONS TABLE
-- ============================================================
-- Log of each attack/roll during a duel

CREATE TABLE IF NOT EXISTS duel_actions (
    id SERIAL PRIMARY KEY,
    match_id INTEGER NOT NULL REFERENCES duel_matches(id) ON DELETE CASCADE,
    player_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    side VARCHAR(20) NOT NULL,  -- 'challenger' or 'opponent'
    
    -- Roll info
    roll_value FLOAT NOT NULL,  -- 0.0-1.0 random value
    outcome VARCHAR(20) NOT NULL,  -- 'miss', 'hit', 'critical'
    
    -- Bar movement
    push_amount FLOAT NOT NULL DEFAULT 0.0,
    bar_before FLOAT NOT NULL,
    bar_after FLOAT NOT NULL,
    
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_duel_actions_match ON duel_actions(match_id);
CREATE INDEX IF NOT EXISTS idx_duel_actions_player ON duel_actions(player_id);

-- ============================================================
-- DUEL STATS TABLE (Lifetime stats per player)
-- ============================================================

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

COMMIT;
