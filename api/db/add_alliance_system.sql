-- Alliance System Migration
-- Alliances are formal pacts between empires that provide mutual benefits

-- Alliance table
CREATE TABLE IF NOT EXISTS alliances (
    id SERIAL PRIMARY KEY,
    
    -- Participants (empires, not individual cities)
    initiator_empire_id VARCHAR NOT NULL,
    target_empire_id VARCHAR NOT NULL,
    
    -- Rulers at time of alliance
    initiator_ruler_id BIGINT NOT NULL REFERENCES users(id),
    target_ruler_id BIGINT REFERENCES users(id),  -- NULL until accepted
    initiator_ruler_name VARCHAR NOT NULL,
    target_ruler_name VARCHAR,
    
    -- Status: 'pending', 'active', 'expired', 'declined'
    status VARCHAR NOT NULL DEFAULT 'pending',
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    proposal_expires_at TIMESTAMP NOT NULL,  -- 7 days to accept
    accepted_at TIMESTAMP,
    expires_at TIMESTAMP,  -- 30 days after accepted
    
    -- Prevent duplicate active alliances between same empires
    CONSTRAINT unique_active_alliance UNIQUE (initiator_empire_id, target_empire_id, status)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_alliances_initiator ON alliances(initiator_empire_id, status);
CREATE INDEX IF NOT EXISTS idx_alliances_target ON alliances(target_empire_id, status);
CREATE INDEX IF NOT EXISTS idx_alliances_status ON alliances(status);
CREATE INDEX IF NOT EXISTS idx_alliances_expires ON alliances(expires_at) WHERE status = 'active';

-- Comments for documentation
COMMENT ON TABLE alliances IS 'Formal pacts between empires providing mutual benefits';
COMMENT ON COLUMN alliances.initiator_empire_id IS 'Empire that proposed the alliance';
COMMENT ON COLUMN alliances.target_empire_id IS 'Empire that must accept the alliance';
COMMENT ON COLUMN alliances.status IS 'pending=awaiting response, active=in effect, expired=time ran out, declined=rejected';
COMMENT ON COLUMN alliances.proposal_expires_at IS 'Pending proposals expire after 7 days';
COMMENT ON COLUMN alliances.expires_at IS 'Active alliances expire after 30 days';



