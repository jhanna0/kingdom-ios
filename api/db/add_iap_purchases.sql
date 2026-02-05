-- ============================================================
-- IN-APP PURCHASES TABLE
-- ============================================================
-- Tracks all App Store purchases for:
-- 1. Preventing duplicate redemptions (via unique transaction_id)
-- 2. Handling refunds from Apple
-- 3. Purchase history for support/analytics
--
-- Run: psql $DATABASE_URL -f api/db/add_iap_purchases.sql
-- ============================================================

-- Create the purchases table
CREATE TABLE IF NOT EXISTS purchases (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- App Store transaction info
    product_id VARCHAR NOT NULL,
    transaction_id VARCHAR UNIQUE NOT NULL,
    original_transaction_id VARCHAR,
    
    -- Purchase details
    price_usd FLOAT,
    currency VARCHAR(3),
    
    -- Resources granted
    gold_granted INTEGER DEFAULT 0,
    meat_granted INTEGER DEFAULT 0,
    books_granted INTEGER DEFAULT 0,
    
    -- Verification
    environment VARCHAR DEFAULT 'Production',
    verified_with_apple BOOLEAN DEFAULT FALSE,
    verification_error VARCHAR,
    
    -- Status
    status VARCHAR DEFAULT 'completed',
    refunded_at TIMESTAMPTZ,
    
    -- Timestamps
    purchased_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_purchases_user_id ON purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_purchases_transaction_id ON purchases(transaction_id);
CREATE INDEX IF NOT EXISTS idx_purchases_user_product ON purchases(user_id, product_id);
CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status);

-- ============================================================
-- VERIFY
-- ============================================================
SELECT 'purchases table created successfully' AS status;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'purchases'
ORDER BY ordinal_position;
