-- Building Permits system
-- Temporary access to buildings in foreign kingdoms
-- 10 gold for 10 minutes, free if allied/same empire

-- Create building_permits table
CREATE TABLE IF NOT EXISTS building_permits (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    kingdom_id VARCHAR NOT NULL REFERENCES kingdoms(id),
    building_type VARCHAR(32) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    purchased_at TIMESTAMP NOT NULL DEFAULT NOW(),
    gold_paid BIGINT NOT NULL DEFAULT 10,
    
    CONSTRAINT unique_user_kingdom_building_permit UNIQUE (user_id, kingdom_id, building_type)
);

-- Indexes for permit lookups
CREATE INDEX IF NOT EXISTS idx_permit_user_kingdom ON building_permits(user_id, kingdom_id);
CREATE INDEX IF NOT EXISTS idx_permit_expires ON building_permits(expires_at);

-- Add kingdom_id to daily_gathering for per-kingdom tracking
-- First drop the old primary key constraint
ALTER TABLE daily_gathering DROP CONSTRAINT IF EXISTS daily_gathering_pkey;

-- Add kingdom_id column (nullable first for existing data)
ALTER TABLE daily_gathering ADD COLUMN IF NOT EXISTS kingdom_id VARCHAR;

-- Update existing records to use hometown (they were all hometown-based before)
-- This requires a data migration - for now just set NULL records to be handled by code
-- New records will have kingdom_id set properly

-- Create new composite primary key including kingdom_id
-- Note: We need to handle this carefully since existing data doesn't have kingdom_id
-- For now, make kingdom_id nullable and handle in application code
-- Later migration can clean up and make it NOT NULL

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_daily_gathering_kingdom ON daily_gathering(user_id, kingdom_id, resource_type, gather_date);
