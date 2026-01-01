-- Remove premium/subscription bloat from users table
-- This is not a mobile game with IAP

ALTER TABLE users DROP COLUMN IF EXISTS is_premium;
ALTER TABLE users DROP COLUMN IF EXISTS premium_expires_at;

