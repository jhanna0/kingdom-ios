-- Add kingdom intelligence system for scouting/espionage
-- Allows players to gather military intelligence on enemy kingdoms

CREATE TABLE IF NOT EXISTS kingdom_intelligence (
    id SERIAL PRIMARY KEY,
    
    -- Target and gatherer info
    kingdom_id VARCHAR NOT NULL REFERENCES kingdoms(id),
    gatherer_id INTEGER NOT NULL REFERENCES users(id),
    gatherer_kingdom_id VARCHAR NOT NULL REFERENCES kingdoms(id),
    gatherer_name VARCHAR NOT NULL,
    
    -- Intelligence data (snapshot at time of gathering)
    wall_level INTEGER NOT NULL,
    total_attack_power INTEGER NOT NULL,
    total_defense_power INTEGER NOT NULL,
    active_citizen_count INTEGER NOT NULL,
    population_estimate INTEGER NOT NULL,
    treasury_estimate INTEGER,
    building_levels JSONB,
    top_players JSONB,
    
    -- Metadata
    intelligence_level INTEGER NOT NULL,  -- Gatherer's intelligence stat
    gathered_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    
    -- Only one active intel report per kingdom pair
    CONSTRAINT unique_intel_per_kingdom_pair UNIQUE(kingdom_id, gatherer_kingdom_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_intel_kingdom ON kingdom_intelligence(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_intel_gatherer_kingdom ON kingdom_intelligence(gatherer_kingdom_id);
CREATE INDEX IF NOT EXISTS idx_intel_expires ON kingdom_intelligence(expires_at);
CREATE INDEX IF NOT EXISTS idx_intel_gatherer ON kingdom_intelligence(gatherer_id);

-- Add last intelligence gathering timestamp to player_state
ALTER TABLE player_state 
ADD COLUMN IF NOT EXISTS last_intelligence_action TIMESTAMP;

-- Index for cooldown checks
CREATE INDEX IF NOT EXISTS idx_player_state_last_intelligence ON player_state(last_intelligence_action);

COMMENT ON TABLE kingdom_intelligence IS 'Stores scouted military intelligence on enemy kingdoms';
COMMENT ON COLUMN kingdom_intelligence.expires_at IS 'Intelligence becomes stale after 7 days';
COMMENT ON COLUMN kingdom_intelligence.intelligence_level IS 'Higher levels reveal more detailed information';

