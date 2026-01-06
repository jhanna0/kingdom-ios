-- Create player_activity_log table for tracking all player actions
-- Used for activity feeds and player history

CREATE TABLE IF NOT EXISTS player_activity_log (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    
    -- Activity classification
    action_type VARCHAR NOT NULL,
    action_category VARCHAR NOT NULL,
    
    -- Core details
    description VARCHAR NOT NULL,
    kingdom_id VARCHAR,
    kingdom_name VARCHAR,
    
    -- Quantitative data
    amount INTEGER,
    
    -- Extended details (flexible JSON)
    details JSONB DEFAULT '{}',
    
    -- Visibility control
    visibility VARCHAR NOT NULL DEFAULT 'friends',
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_activity_user_id ON player_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_action_type ON player_activity_log(action_type);
CREATE INDEX IF NOT EXISTS idx_activity_action_category ON player_activity_log(action_category);
CREATE INDEX IF NOT EXISTS idx_activity_kingdom_id ON player_activity_log(kingdom_id);
CREATE INDEX IF NOT EXISTS idx_activity_created_at ON player_activity_log(created_at);

-- Composite indexes for efficient feed queries
CREATE INDEX IF NOT EXISTS idx_activity_user_created ON player_activity_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_kingdom_created ON player_activity_log(kingdom_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_type_created ON player_activity_log(action_type, created_at DESC);

-- Comments for documentation
COMMENT ON TABLE player_activity_log IS 'Comprehensive activity log for all player actions, used for activity feeds';
COMMENT ON COLUMN player_activity_log.action_type IS 'Type of action: travel, checkin, farm, patrol, scout, sabotage, build, train, etc.';
COMMENT ON COLUMN player_activity_log.action_category IS 'Category: kingdom, combat, economy, social';
COMMENT ON COLUMN player_activity_log.visibility IS 'Who can see this: public, friends, private';






