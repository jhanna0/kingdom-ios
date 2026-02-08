-- Migration: Convert local_reputation from Integer to Float
-- Purpose: Support philosophy skill bonus (+10% per tier) with precision
-- Date: 2026-02-08
--
-- This migration changes local_reputation to Float so philosophy bonuses
-- can accumulate fractionally. The frontend always receives int values.

-- Step 1: Alter column type (PostgreSQL handles Integer -> Float gracefully)
ALTER TABLE user_kingdoms 
ALTER COLUMN local_reputation TYPE DOUBLE PRECISION;

-- Step 2: Set default for new records
ALTER TABLE user_kingdoms 
ALTER COLUMN local_reputation SET DEFAULT 0.0;

-- Verify the change
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_kingdoms' AND column_name = 'local_reputation';
