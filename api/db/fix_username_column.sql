-- Fix: Remove username column from users table
-- We use display_name instead of username, and apple_user_id as the unique identifier

BEGIN;

-- Drop username column if it exists (and any constraints)
ALTER TABLE users DROP COLUMN IF EXISTS username CASCADE;

COMMIT;

-- Verify
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;



