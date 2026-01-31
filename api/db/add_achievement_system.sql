-- Achievement System Migration
-- Backend-driven achievement diary with tiered rewards

-- Achievement Definitions (backend-controlled)
-- Each row is a single tier of an achievement type
CREATE TABLE IF NOT EXISTS achievement_definitions (
    id SERIAL PRIMARY KEY,
    
    -- Achievement identification
    achievement_type VARCHAR(100) NOT NULL,  -- e.g., 'hunt_rabbit', 'contracts_completed'
    tier INTEGER NOT NULL DEFAULT 1,         -- 1, 2, 3, etc.
    
    -- Requirements
    target_value INTEGER NOT NULL,           -- e.g., 10, 50, 100
    
    -- Rewards (flexible JSONB)
    -- Format: {"gold": 100, "experience": 50, "items": [{"id": "iron", "quantity": 5}]}
    rewards JSONB NOT NULL DEFAULT '{}',
    
    -- Display info (sent to frontend)
    display_name VARCHAR(255) NOT NULL,      -- e.g., "Rabbit Hunter I"
    description VARCHAR(500),                -- e.g., "Hunt 10 rabbits"
    icon VARCHAR(100),                       -- SF Symbol name
    category VARCHAR(100) DEFAULT 'general', -- For grouping: hunting, combat, economy, etc.
    type_display_name VARCHAR(255),          -- e.g., "Squirrel Hunting" (shared across tiers)
    
    -- Ordering and availability
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,          -- Can disable without deleting
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Each achievement type can only have one of each tier
    CONSTRAINT uq_achievement_type_tier UNIQUE (achievement_type, tier)
);

-- Player Achievement Progress
-- Tracks current progress for each achievement type
CREATE TABLE IF NOT EXISTS player_achievement_progress (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Achievement type (denormalized for fast queries)
    achievement_type VARCHAR(100) NOT NULL,
    
    -- Current progress
    current_value INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- One row per user per achievement type
    CONSTRAINT uq_player_achievement_type UNIQUE (user_id, achievement_type)
);

-- Player Achievement Claims
-- Records which tier rewards have been claimed
CREATE TABLE IF NOT EXISTS player_achievement_claims (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- The specific tier that was claimed
    achievement_tier_id INTEGER NOT NULL REFERENCES achievement_definitions(id),
    
    -- Claim timestamp
    claimed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- One claim per user per tier
    CONSTRAINT uq_player_tier_claim UNIQUE (user_id, achievement_tier_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_achievement_definitions_type ON achievement_definitions(achievement_type);
CREATE INDEX IF NOT EXISTS idx_achievement_definitions_category ON achievement_definitions(category);
CREATE INDEX IF NOT EXISTS idx_achievement_definitions_active ON achievement_definitions(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_player_achievement_progress_user ON player_achievement_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_player_achievement_progress_type ON player_achievement_progress(achievement_type);

CREATE INDEX IF NOT EXISTS idx_player_achievement_claims_user ON player_achievement_claims(user_id);
CREATE INDEX IF NOT EXISTS idx_player_achievement_claims_tier ON player_achievement_claims(achievement_tier_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_achievement_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS achievement_definitions_updated_at ON achievement_definitions;
CREATE TRIGGER achievement_definitions_updated_at
    BEFORE UPDATE ON achievement_definitions
    FOR EACH ROW EXECUTE FUNCTION update_achievement_timestamp();

DROP TRIGGER IF EXISTS player_achievement_progress_updated_at ON player_achievement_progress;
CREATE TRIGGER player_achievement_progress_updated_at
    BEFORE UPDATE ON player_achievement_progress
    FOR EACH ROW EXECUTE FUNCTION update_achievement_timestamp();

-- Comments for documentation
COMMENT ON TABLE achievement_definitions IS 'Backend-managed achievement definitions with tiered rewards';
COMMENT ON TABLE player_achievement_progress IS 'Player progress tracking for each achievement type';
COMMENT ON TABLE player_achievement_claims IS 'Records of which achievement tier rewards have been claimed';
COMMENT ON COLUMN achievement_definitions.achievement_type IS 'Unique identifier for achievement category (e.g., hunt_rabbit, contracts_completed)';
COMMENT ON COLUMN achievement_definitions.rewards IS 'JSONB rewards: {"gold": 100, "experience": 50, "items": [...]}';
