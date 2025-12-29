-- Add invasion system

CREATE TABLE IF NOT EXISTS invasion_events (
    id SERIAL PRIMARY KEY,
    
    -- Which city is attacking which
    attacking_from_kingdom_id VARCHAR NOT NULL,
    target_kingdom_id VARCHAR NOT NULL,
    
    -- Who started it
    initiator_id BIGINT NOT NULL REFERENCES users(id),
    initiator_name VARCHAR NOT NULL,
    
    -- Status
    status VARCHAR NOT NULL DEFAULT 'declared',  -- 'declared' or 'resolved'
    
    -- Timing (2 hour warning)
    declared_at TIMESTAMP NOT NULL DEFAULT NOW(),
    battle_time TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    
    -- Participants (JSONB arrays of player IDs)
    attackers JSONB DEFAULT '[]'::jsonb,
    defenders JSONB DEFAULT '[]'::jsonb,
    
    -- Combat results (filled after resolution)
    attacker_victory BOOLEAN,
    attacker_strength INTEGER,
    defender_strength INTEGER,
    total_defense_with_walls INTEGER,
    loot_distributed INTEGER,
    
    -- Cost tracking
    cost_per_attacker INTEGER DEFAULT 100,
    total_cost_paid INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_invasion_target ON invasion_events(target_kingdom_id);
CREATE INDEX idx_invasion_status ON invasion_events(status);
CREATE INDEX idx_invasion_battle_time ON invasion_events(battle_time);

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_invasion_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invasion_updated_at_trigger
BEFORE UPDATE ON invasion_events
FOR EACH ROW
EXECUTE FUNCTION update_invasion_updated_at();

-- Add invasion cooldown to player_state
ALTER TABLE player_state ADD COLUMN IF NOT EXISTS last_invasion_attempt TIMESTAMP;

-- Add empire/faction tracking to kingdoms
-- A city keeps its ID (identity) but can belong to different empires
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS empire_id VARCHAR;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS original_kingdom_id VARCHAR;

-- Set initial values: each city starts as its own empire
UPDATE kingdoms SET empire_id = id WHERE empire_id IS NULL;
UPDATE kingdoms SET original_kingdom_id = id WHERE original_kingdom_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_kingdoms_empire ON kingdoms(empire_id);

-- Kingdom history table - track every ruler and conquest
CREATE TABLE IF NOT EXISTS kingdom_history (
    id SERIAL PRIMARY KEY,
    kingdom_id VARCHAR NOT NULL,
    
    -- Ruler info
    ruler_id BIGINT NOT NULL REFERENCES users(id),
    ruler_name VARCHAR NOT NULL,
    
    -- Empire info
    empire_id VARCHAR NOT NULL,  -- Which empire/faction
    
    -- How they got power
    event_type VARCHAR NOT NULL,  -- 'founded', 'coup', 'invasion', 'reconquest'
    
    -- Timing
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMP,  -- NULL if still ruling
    
    -- Related event
    coup_id INTEGER REFERENCES coup_events(id),
    invasion_id INTEGER REFERENCES invasion_events(id),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_kingdom_history_kingdom ON kingdom_history(kingdom_id);
CREATE INDEX idx_kingdom_history_ruler ON kingdom_history(ruler_id);
CREATE INDEX idx_kingdom_history_current ON kingdom_history(kingdom_id, ended_at) WHERE ended_at IS NULL;

