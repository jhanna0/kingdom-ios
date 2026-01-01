-- Add coup events system
-- This tracks active coup attempts with 2-hour voting periods

CREATE TABLE IF NOT EXISTS coup_events (
    id SERIAL PRIMARY KEY,
    kingdom_id VARCHAR NOT NULL,
    initiator_id BIGINT NOT NULL REFERENCES users(id),
    initiator_name VARCHAR NOT NULL,
    
    -- Status: 'voting', 'resolved'
    status VARCHAR NOT NULL DEFAULT 'voting',
    
    -- Timing (2-hour voting window)
    start_time TIMESTAMP NOT NULL DEFAULT NOW(),
    end_time TIMESTAMP NOT NULL,
    
    -- Participants (JSONB arrays of player IDs)
    attackers JSONB DEFAULT '[]'::jsonb,  -- Players who joined attackers
    defenders JSONB DEFAULT '[]'::jsonb,  -- Players who joined defenders
    
    -- Resolution data
    attacker_victory BOOLEAN,
    attacker_strength INTEGER,
    defender_strength INTEGER,
    total_defense_with_walls INTEGER,
    resolved_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_coup_events_kingdom_id ON coup_events(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_coup_events_status ON coup_events(status);
CREATE INDEX IF NOT EXISTS idx_coup_events_end_time ON coup_events(end_time);
CREATE INDEX IF NOT EXISTS idx_coup_events_initiator ON coup_events(initiator_id);

-- Create a function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_coup_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS coup_events_updated_at ON coup_events;
CREATE TRIGGER coup_events_updated_at
    BEFORE UPDATE ON coup_events
    FOR EACH ROW
    EXECUTE FUNCTION update_coup_events_updated_at();

COMMENT ON TABLE coup_events IS 'Active and historical coup events with 2-hour voting periods';
COMMENT ON COLUMN coup_events.status IS 'Current status: voting (active) or resolved (completed)';
COMMENT ON COLUMN coup_events.attackers IS 'Array of player IDs who joined the coup attackers';
COMMENT ON COLUMN coup_events.defenders IS 'Array of player IDs who joined the defenders';



