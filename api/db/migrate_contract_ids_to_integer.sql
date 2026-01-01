-- Migrate contract IDs from UUID strings to auto-incrementing integers
-- This aligns contracts with users (which use BigInteger IDs)

-- Step 1: Create a new table with integer IDs
CREATE TABLE contracts_new (
    id BIGSERIAL PRIMARY KEY,
    kingdom_id VARCHAR NOT NULL,
    kingdom_name VARCHAR NOT NULL,
    building_type VARCHAR NOT NULL,
    building_level INTEGER NOT NULL,
    base_population INTEGER DEFAULT 0,
    base_hours_required FLOAT NOT NULL,
    work_started_at TIMESTAMP,
    total_actions_required INTEGER NOT NULL DEFAULT 1000,
    actions_completed INTEGER DEFAULT 0,
    action_contributions JSONB DEFAULT '{}',
    reward_pool INTEGER DEFAULT 0,
    created_by BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    status VARCHAR DEFAULT 'open',
    FOREIGN KEY (kingdom_id) REFERENCES kingdoms(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Step 2: Copy data from old table (if any exists)
-- Note: This will assign new sequential IDs
INSERT INTO contracts_new (
    kingdom_id, kingdom_name, building_type, building_level,
    base_population, base_hours_required, work_started_at,
    total_actions_required, actions_completed, action_contributions,
    reward_pool, created_by, created_at, completed_at, status
)
SELECT 
    kingdom_id, kingdom_name, building_type, building_level,
    base_population, base_hours_required, work_started_at,
    total_actions_required, actions_completed, action_contributions,
    reward_pool, created_by, created_at, completed_at, status
FROM contracts;

-- Step 3: Drop old table
DROP TABLE contracts;

-- Step 4: Rename new table
ALTER TABLE contracts_new RENAME TO contracts;

-- Step 5: Create indexes
CREATE INDEX idx_contracts_kingdom_id ON contracts(kingdom_id);
CREATE INDEX idx_contracts_created_by ON contracts(created_by);
CREATE INDEX idx_contracts_status ON contracts(status);



