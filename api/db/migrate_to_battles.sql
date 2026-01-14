-- =============================================================================
-- UNIFIED BATTLES SYSTEM
-- =============================================================================
-- Replaces separate coup_events and invasion_events with a single battles table.
-- 
-- Key insight: Coups and invasions are the SAME THING mechanically:
-- - Both have attackers vs defenders
-- - Both use territory-based tug-of-war combat
-- - Both result in ruler change
--
-- The ONLY difference:
-- - Coup: Internal (empire_id stays same)
-- - Invasion: External (empire_id changes to attacker's empire)
--
-- This migration:
-- 1. Creates unified battles table + all related tables
-- 2. Works on fresh DB (production) OR DB with existing coup_* tables (docker)
-- =============================================================================

-- =============================================================================
-- PHASE 1: CLEANUP - Drop old coup_* tables if they exist (Docker only)
-- =============================================================================
-- These only exist on Docker where we ran migrate_coup_v2.sql
-- Production is clean, so these will be no-ops

DROP TABLE IF EXISTS coup_fight_sessions CASCADE;
DROP TABLE IF EXISTS coup_injuries CASCADE;
DROP TABLE IF EXISTS coup_battle_actions CASCADE;
DROP TABLE IF EXISTS coup_territories CASCADE;
DROP TABLE IF EXISTS coup_participants CASCADE;
DROP TABLE IF EXISTS coup_events CASCADE;

-- Also drop old invasion_events if it exists
DROP TABLE IF EXISTS invasion_events CASCADE;

-- Drop old triggers/functions
DROP TRIGGER IF EXISTS coup_events_updated_at ON coup_events;
DROP FUNCTION IF EXISTS update_coup_events_updated_at();
DROP TRIGGER IF EXISTS invasion_updated_at_trigger ON invasion_events;
DROP FUNCTION IF EXISTS update_invasion_updated_at();

-- =============================================================================
-- PHASE 2: Create unified BATTLES table
-- =============================================================================

CREATE TABLE IF NOT EXISTS battles (
    id SERIAL PRIMARY KEY,
    
    -- TYPE: 'coup' (internal) or 'invasion' (external)
    type VARCHAR(20) NOT NULL CHECK (type IN ('coup', 'invasion')),
    
    -- TARGET KINGDOM (the kingdom being fought over)
    kingdom_id VARCHAR NOT NULL,
    
    -- For INVASIONS: Which kingdom is the attack coming from (NULL for coups)
    attacking_from_kingdom_id VARCHAR DEFAULT NULL,
    
    -- INITIATOR: Who started this battle
    initiator_id BIGINT NOT NULL REFERENCES users(id),
    initiator_name VARCHAR NOT NULL,
    
    -- TIMING (Two-phase system: pledge → battle → resolved)
    -- Phase computed from time, not stored:
    --   resolved_at IS NULL AND now < pledge_end_time → 'pledge'
    --   resolved_at IS NULL AND now >= pledge_end_time → 'battle'
    --   resolved_at IS NOT NULL → 'resolved'
    start_time TIMESTAMP NOT NULL DEFAULT NOW(),
    pledge_end_time TIMESTAMP NOT NULL,  -- When pledge phase ends, battle begins
    
    -- PARTICIPANTS (JSONB arrays - also stored in battle_participants table)
    -- Kept for backward compat and quick access
    attackers JSONB DEFAULT '[]'::jsonb,
    defenders JSONB DEFAULT '[]'::jsonb,
    
    -- RESOLUTION
    resolved_at TIMESTAMP DEFAULT NULL,
    attacker_victory BOOLEAN DEFAULT NULL,
    winner_side VARCHAR(20) DEFAULT NULL,  -- 'attackers' or 'defenders'
    
    -- COMBAT STATS (filled after resolution)
    attacker_strength INTEGER DEFAULT NULL,
    defender_strength INTEGER DEFAULT NULL,
    total_defense_with_walls INTEGER DEFAULT NULL,
    
    -- REWARDS
    gold_per_winner INTEGER DEFAULT NULL,  -- Spoils split among winners
    loot_distributed INTEGER DEFAULT NULL,  -- For invasions: treasury looted
    
    -- INVASION-SPECIFIC: Cost tracking
    cost_per_attacker INTEGER DEFAULT NULL,  -- Only for invasions
    total_cost_paid INTEGER DEFAULT NULL,
    
    -- INVASION: Wall defense bonus
    wall_defense_applied INTEGER DEFAULT NULL,  -- Wall bonus used in calculation
    
    -- RULER CHANGE TRACKING (for notifications)
    old_ruler_id BIGINT DEFAULT NULL,
    
    -- DEPRECATED: status column - use resolved_at instead
    -- Kept for backward compat, should be ignored
    status VARCHAR(20) DEFAULT NULL,
    
    -- TIMESTAMPS
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_battles_kingdom_id ON battles(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_battles_type ON battles(type);
CREATE INDEX IF NOT EXISTS idx_battles_resolved_at ON battles(resolved_at);
CREATE INDEX IF NOT EXISTS idx_battles_pledge_end_time ON battles(pledge_end_time);
CREATE INDEX IF NOT EXISTS idx_battles_initiator_id ON battles(initiator_id);
CREATE INDEX IF NOT EXISTS idx_battles_attacking_from ON battles(attacking_from_kingdom_id) WHERE attacking_from_kingdom_id IS NOT NULL;

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_battles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS battles_updated_at ON battles;
CREATE TRIGGER battles_updated_at
    BEFORE UPDATE ON battles
    FOR EACH ROW
    EXECUTE FUNCTION update_battles_updated_at();

COMMENT ON TABLE battles IS 'Unified table for coups (internal) and invasions (external) with territory-based combat';

-- =============================================================================
-- PHASE 3: BATTLE PARTICIPANTS - Proper relational tracking of sides
-- =============================================================================

CREATE TABLE IF NOT EXISTS battle_participants (
    id SERIAL PRIMARY KEY,
    battle_id INTEGER NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    side VARCHAR(20) NOT NULL CHECK (side IN ('attackers', 'defenders')),
    pledged_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(battle_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_battle_participants_battle_id ON battle_participants(battle_id);
CREATE INDEX IF NOT EXISTS idx_battle_participants_user_id ON battle_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_battle_participants_side ON battle_participants(battle_id, side);

-- =============================================================================
-- PHASE 4: BATTLE TERRITORIES - 3 territories with tug-of-war bars
-- =============================================================================

CREATE TABLE IF NOT EXISTS battle_territories (
    id SERIAL PRIMARY KEY,
    battle_id INTEGER NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,  -- 'coupers_territory', 'crowns_territory', 'throne_room'
    control_bar DOUBLE PRECISION NOT NULL DEFAULT 50.0,  -- 0 = attackers captured, 100 = defenders captured
    captured_by VARCHAR(20) DEFAULT NULL,  -- NULL, 'attackers', 'defenders'
    captured_at TIMESTAMP DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(battle_id, territory_name)
);

CREATE INDEX IF NOT EXISTS idx_battle_territories_battle_id ON battle_territories(battle_id);

-- =============================================================================
-- PHASE 5: BATTLE ACTIONS - Log of each fight
-- =============================================================================

CREATE TABLE IF NOT EXISTS battle_actions (
    id SERIAL PRIMARY KEY,
    battle_id INTEGER NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,
    side VARCHAR(20) NOT NULL,  -- 'attackers' or 'defenders'
    
    -- Roll results
    roll_count INTEGER NOT NULL,
    rolls JSONB NOT NULL DEFAULT '[]',  -- Array of roll outcomes: [{value, outcome}]
    best_outcome VARCHAR(20) NOT NULL,  -- 'miss', 'hit', 'injure'
    
    -- Bar movement
    push_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    bar_before DOUBLE PRECISION NOT NULL,
    bar_after DOUBLE PRECISION NOT NULL,
    
    -- Injury tracking
    injured_player_id BIGINT DEFAULT NULL REFERENCES users(id) ON DELETE SET NULL,
    
    performed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_battle_actions_battle_id ON battle_actions(battle_id);
CREATE INDEX IF NOT EXISTS idx_battle_actions_player_id ON battle_actions(player_id);
CREATE INDEX IF NOT EXISTS idx_battle_actions_performed_at ON battle_actions(performed_at);

-- =============================================================================
-- PHASE 6: BATTLE INJURIES - Players who must sit out
-- =============================================================================

CREATE TABLE IF NOT EXISTS battle_injuries (
    id SERIAL PRIMARY KEY,
    battle_id INTEGER NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    injured_by_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    injury_action_id INTEGER REFERENCES battle_actions(id) ON DELETE SET NULL,
    
    -- Injury expires after 20 minutes
    injured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    cleared_at TIMESTAMP DEFAULT NULL,
    
    UNIQUE(battle_id, player_id, injured_at)
);

CREATE INDEX IF NOT EXISTS idx_battle_injuries_battle_id ON battle_injuries(battle_id);
CREATE INDEX IF NOT EXISTS idx_battle_injuries_player_id ON battle_injuries(player_id);
CREATE INDEX IF NOT EXISTS idx_battle_injuries_expires_at ON battle_injuries(expires_at);

-- =============================================================================
-- PHASE 7: FIGHT SESSIONS - In-progress fight state
-- =============================================================================

CREATE TABLE IF NOT EXISTS fight_sessions (
    id SERIAL PRIMARY KEY,
    battle_id INTEGER NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,
    side VARCHAR(20) NOT NULL,  -- 'attackers' or 'defenders'
    
    -- How many rolls the player gets (1 + attack_power)
    max_rolls INTEGER NOT NULL DEFAULT 1,
    
    -- Rolls completed so far: [{value: 45.2, outcome: "hit"}, ...]
    rolls JSONB NOT NULL DEFAULT '[]'::jsonb,
    
    -- Combat stats snapshot
    hit_chance INTEGER NOT NULL DEFAULT 50,  -- 0-100 percentage
    enemy_avg_defense DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    
    -- Bar snapshot at start
    bar_before DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- One active session per player per battle
    UNIQUE(battle_id, player_id)
);

CREATE INDEX IF NOT EXISTS idx_fight_sessions_battle_id ON fight_sessions(battle_id);
CREATE INDEX IF NOT EXISTS idx_fight_sessions_player_id ON fight_sessions(player_id);

-- =============================================================================
-- PHASE 8: UPDATE KINGDOM_HISTORY - Use unified battle_id
-- =============================================================================

-- Add battle_id column (replaces separate coup_id and invasion_id)
ALTER TABLE kingdom_history ADD COLUMN IF NOT EXISTS battle_id INTEGER REFERENCES battles(id) ON DELETE SET NULL;

-- The old coup_id and invasion_id columns may still exist from add_invasion_system.sql
-- We'll keep them for now for backward compat, but new code uses battle_id

-- =============================================================================
-- PHASE 9: ENSURE KINGDOM COLUMNS EXIST
-- =============================================================================

-- Empire tracking (may already exist from add_invasion_system.sql)
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS empire_id VARCHAR;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS original_kingdom_id VARCHAR;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS ruler_started_at TIMESTAMP DEFAULT NULL;

-- Set initial values: each city starts as its own empire
UPDATE kingdoms SET empire_id = id WHERE empire_id IS NULL;
UPDATE kingdoms SET original_kingdom_id = id WHERE original_kingdom_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_kingdoms_empire ON kingdoms(empire_id);

-- =============================================================================
-- PHASE 10: ENSURE PLAYER_STATE COLUMNS EXIST
-- =============================================================================

-- Invasion cooldown tracking (may already exist)
ALTER TABLE player_state ADD COLUMN IF NOT EXISTS last_invasion_attempt TIMESTAMP;

-- =============================================================================
-- DONE!
-- =============================================================================

COMMENT ON TABLE battles IS 'Unified combat events: coups (internal power struggles) and invasions (external conquest)';
COMMENT ON COLUMN battles.type IS 'coup = internal, invasion = external';
COMMENT ON COLUMN battles.kingdom_id IS 'The kingdom being fought over (target)';
COMMENT ON COLUMN battles.attacking_from_kingdom_id IS 'For invasions: which kingdom the attack originates from';
