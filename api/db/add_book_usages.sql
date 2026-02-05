-- BOOK USAGES TABLE
-- =================
-- Tracks each book usage attempt with full state for debugging.
--
-- CRITICAL: Books are purchased with real money. This table must capture:
-- 1. Did it succeed or fail?
-- 2. What error occurred?
-- 3. What was the cooldown state before/after?
-- 4. Can we PROVE the cooldown was actually skipped?
--
-- Run: psql $DATABASE_URL -f api/db/add_book_usages.sql

-- Create the book_usages table
CREATE TABLE IF NOT EXISTS book_usages (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    
    -- What the book was used on
    slot VARCHAR NOT NULL,           -- personal, building, crafting
    action_type VARCHAR,             -- Optional: specific action being skipped
    
    -- Effect requested
    effect VARCHAR NOT NULL,         -- "skip_cooldown" or "reduce_cooldown"
    cooldown_reduction_minutes INTEGER,  -- Only for reduce_cooldown
    
    -- Result tracking - DID IT WORK?
    success BOOLEAN NOT NULL,        -- Did the operation succeed?
    error_message VARCHAR,           -- Error details if failed
    
    -- Book balance tracking
    books_before INTEGER NOT NULL,   -- Balance before attempt
    books_after INTEGER NOT NULL,    -- Balance after (verify deduction)
    
    -- Cooldown state tracking - PROVE it worked
    cooldowns_found INTEGER,         -- How many cooldowns were in the slot
    cooldowns_modified INTEGER,      -- How many we actually modified
    
    -- Timestamp
    used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for user history queries
CREATE INDEX IF NOT EXISTS idx_book_usages_user_id ON book_usages(user_id);

-- Verify
SELECT 'book_usages table created successfully' AS status;

\d book_usages
