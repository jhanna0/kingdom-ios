-- Achievement Stats Migration
-- =============================
-- ONLY create tables for stats that CANNOT be computed from existing data.
-- 
-- COMPUTED FROM EXISTING TABLES (no new storage needed):
-- - Crafting: unified_contracts WHERE completed_at IS NOT NULL
-- - Kingdoms ruled: kingdom_history WHERE ruler_id = ?
-- - Days as ruler: kingdom_history (SUM of reign durations)
-- - Empire size: kingdoms WHERE ruler_id = ?
-- - Coups initiated: coup_events WHERE initiator_id = ?
-- - Battle stats: battle_participants + battles tables
-- - Garden stats: garden_history table
-- - Duel stats: duel_stats table (already exists)
--
-- NEED NEW TABLES (no existing history):
-- - Intelligence operations (no scout history exists)
-- - Fortification sacrifices (no sacrifice history exists)

-- ============================================================
-- PLAYER_INTELLIGENCE_STATS: Infiltration operations
-- ============================================================
-- No existing scout history table - need to track attempts and outcomes

CREATE TABLE IF NOT EXISTS player_intelligence_stats (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Operation attempts
    operations_attempted INTEGER NOT NULL DEFAULT 0,    -- Total scout attempts
    operations_succeeded INTEGER NOT NULL DEFAULT 0,    -- Passed detection roll
    
    -- Outcome wins
    intel_gathered INTEGER NOT NULL DEFAULT 0,          -- Intel outcomes
    sabotages_completed INTEGER NOT NULL DEFAULT 0,     -- Disruption outcomes
    heists_completed INTEGER NOT NULL DEFAULT 0,        -- Vault heist outcomes
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_intel_stats_user ON player_intelligence_stats(user_id);

COMMENT ON TABLE player_intelligence_stats IS 'Intelligence/infiltration operation stats per player';


-- ============================================================
-- PLAYER_FORTIFICATION_STATS: Property defense
-- ============================================================
-- No existing fortification history - need to track sacrifices

CREATE TABLE IF NOT EXISTS player_fortification_stats (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Fortification actions
    items_sacrificed INTEGER NOT NULL DEFAULT 0,        -- Equipment sacrificed
    fortification_gained INTEGER NOT NULL DEFAULT 0,    -- Total % gained
    max_fortification_reached BOOLEAN DEFAULT FALSE,    -- Ever hit 100%
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fort_stats_user ON player_fortification_stats(user_id);

COMMENT ON TABLE player_fortification_stats IS 'Property fortification stats per player';


-- ============================================================
-- INDEXES for computed achievement queries
-- ============================================================

-- Crafting queries on unified_contracts
CREATE INDEX IF NOT EXISTS idx_contracts_crafting_completed 
ON unified_contracts(user_id, type, tier) 
WHERE completed_at IS NOT NULL AND type IN ('weapon', 'armor');

-- Coup participation
CREATE INDEX IF NOT EXISTS idx_coup_participants_user 
ON coup_participants(user_id);

-- Coup initiator
CREATE INDEX IF NOT EXISTS idx_coup_events_initiator 
ON coup_events(initiator_id);

-- Invasion initiator
CREATE INDEX IF NOT EXISTS idx_invasion_events_initiator 
ON invasion_events(initiator_id);
