-- Migration: Convert gold columns from INTEGER to FLOAT for precise tax calculations
-- Run this on the database to enable fractional gold storage

-- Player gold
ALTER TABLE player_state 
ALTER COLUMN gold TYPE DOUBLE PRECISION USING gold::DOUBLE PRECISION;

-- Kingdom treasury
ALTER TABLE kingdoms 
ALTER COLUMN treasury_gold TYPE DOUBLE PRECISION USING treasury_gold::DOUBLE PRECISION;

-- Set default values for new records
ALTER TABLE player_state ALTER COLUMN gold SET DEFAULT 100.0;
ALTER TABLE kingdoms ALTER COLUMN treasury_gold SET DEFAULT 0.0;
