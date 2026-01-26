-- Migration: Add PvP Duel Turn History
-- Date: 2026-01-25
-- Description: Adds turn order tracking for fair first-turn alternation between rematches

-- ============================================================
-- ADD first_turn_player_id TO DUEL MATCHES
-- ============================================================
-- Track who went first in this match (used for pairing history)

ALTER TABLE duel_matches 
ADD COLUMN IF NOT EXISTS first_turn_player_id INTEGER REFERENCES users(id);

-- ============================================================
-- DUEL PAIRING HISTORY TABLE
-- ============================================================
-- Tracks which player went first in previous duels between the same pair.
-- Used to alternate who starts when the same two players duel again.
-- 
-- player_a_id is always the smaller ID (for consistent lookups).

CREATE TABLE IF NOT EXISTS duel_pairing_history (
    id SERIAL PRIMARY KEY,
    
    -- Always store with player_a_id < player_b_id for consistent lookups
    player_a_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    player_b_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Who went first in the last match
    last_first_player_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Reference to the match
    last_match_id INTEGER REFERENCES duel_matches(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Ensure unique pair (only one record per player pairing)
    CONSTRAINT unique_pairing UNIQUE (player_a_id, player_b_id),
    
    -- Ensure proper ordering (a < b)
    CONSTRAINT proper_pair_order CHECK (player_a_id < player_b_id)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_duel_pairing_a ON duel_pairing_history(player_a_id);
CREATE INDEX IF NOT EXISTS idx_duel_pairing_b ON duel_pairing_history(player_b_id);
CREATE INDEX IF NOT EXISTS idx_duel_pairing_pair ON duel_pairing_history(player_a_id, player_b_id);

-- Update the status check to include 'declined' status
ALTER TABLE duel_matches DROP CONSTRAINT IF EXISTS valid_status;
ALTER TABLE duel_matches ADD CONSTRAINT valid_status 
    CHECK (status IN ('waiting', 'pending_acceptance', 'ready', 'fighting', 'complete', 'cancelled', 'expired', 'declined'));

COMMIT;
