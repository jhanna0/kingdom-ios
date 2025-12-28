-- Migration: Change User IDs from UUID strings to PostgreSQL auto-increment integers
-- WARNING: This will delete all existing data. Only run on development/fresh databases.

BEGIN;

-- Drop all foreign key constraints first
ALTER TABLE player_state DROP CONSTRAINT IF EXISTS player_state_user_id_fkey;
ALTER TABLE user_kingdoms DROP CONSTRAINT IF EXISTS user_kingdoms_user_id_fkey;
ALTER TABLE kingdoms DROP CONSTRAINT IF EXISTS kingdoms_ruler_id_fkey;
ALTER TABLE contracts DROP CONSTRAINT IF EXISTS contracts_created_by_fkey;
ALTER TABLE checkin_history DROP CONSTRAINT IF EXISTS checkin_history_user_id_fkey;
ALTER TABLE properties DROP CONSTRAINT IF EXISTS properties_owner_id_fkey;

-- Truncate all tables (removes all data)
TRUNCATE TABLE contracts CASCADE;
TRUNCATE TABLE checkin_history CASCADE;
TRUNCATE TABLE user_kingdoms CASCADE;
TRUNCATE TABLE player_state CASCADE;
TRUNCATE TABLE properties CASCADE;
TRUNCATE TABLE kingdoms CASCADE;
TRUNCATE TABLE users CASCADE;

-- Change users.id from String to BigInteger with auto-increment
ALTER TABLE users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE users ALTER COLUMN id TYPE BIGINT USING id::bigint;
CREATE SEQUENCE IF NOT EXISTS users_id_seq;
ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq');
ALTER SEQUENCE users_id_seq OWNED BY users.id;
SELECT setval('users_id_seq', 1, false);

-- Update foreign keys to BigInteger
ALTER TABLE player_state ALTER COLUMN user_id TYPE BIGINT USING user_id::bigint;
ALTER TABLE user_kingdoms ALTER COLUMN user_id TYPE BIGINT USING user_id::bigint;
ALTER TABLE kingdoms ALTER COLUMN ruler_id TYPE BIGINT USING ruler_id::bigint;
ALTER TABLE contracts ALTER COLUMN created_by TYPE BIGINT USING created_by::bigint;
ALTER TABLE checkin_history ALTER COLUMN user_id TYPE BIGINT USING user_id::bigint;
ALTER TABLE properties ALTER COLUMN owner_id TYPE BIGINT USING owner_id::bigint;

-- Re-add foreign key constraints
ALTER TABLE player_state ADD CONSTRAINT player_state_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE user_kingdoms ADD CONSTRAINT user_kingdoms_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE kingdoms ADD CONSTRAINT kingdoms_ruler_id_fkey 
    FOREIGN KEY (ruler_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE contracts ADD CONSTRAINT contracts_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE checkin_history ADD CONSTRAINT checkin_history_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE properties ADD CONSTRAINT properties_owner_id_fkey 
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

COMMIT;

-- Verify the changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'id';

