-- Migration: Deduplicate device_ids
-- Purpose: Find users with duplicate device_ids and remove device_id from newer accounts
-- This ensures only one account per device going forward
-- 
-- Run this BEFORE deploying the device_id blocking code to clean up existing duplicates

-- First, let's see what duplicates exist (preview query - don't run this in the UPDATE)
-- SELECT 
--     device_id,
--     COUNT(*) as account_count,
--     ARRAY_AGG(id ORDER BY created_at) as user_ids,
--     ARRAY_AGG(display_name ORDER BY created_at) as display_names,
--     ARRAY_AGG(created_at ORDER BY created_at) as created_dates
-- FROM users 
-- WHERE device_id IS NOT NULL 
--   AND is_active = true
-- GROUP BY device_id 
-- HAVING COUNT(*) > 1
-- ORDER BY account_count DESC;

-- Begin transaction
BEGIN;

-- Create a temporary table with the first (oldest) user for each device_id
-- This user gets to KEEP their device_id
CREATE TEMP TABLE first_device_users AS
SELECT DISTINCT ON (device_id) 
    id as keep_user_id,
    device_id,
    display_name,
    created_at
FROM users 
WHERE device_id IS NOT NULL 
  AND is_active = true
ORDER BY device_id, created_at ASC;

-- Show which users will keep their device_id
SELECT 'Users KEEPING device_id:' as action;
SELECT keep_user_id, device_id, display_name, created_at 
FROM first_device_users 
ORDER BY created_at;

-- Find users who will LOSE their device_id (duplicates)
SELECT 'Users LOSING device_id (duplicates):' as action;
SELECT 
    u.id as user_id,
    u.device_id,
    u.display_name,
    u.created_at,
    fdu.keep_user_id as original_account_id,
    fdu.display_name as original_display_name
FROM users u
JOIN first_device_users fdu ON u.device_id = fdu.device_id
WHERE u.id != fdu.keep_user_id
  AND u.is_active = true
ORDER BY u.device_id, u.created_at;

-- Count how many will be affected
SELECT 
    'Summary:' as info,
    COUNT(*) as duplicate_accounts_to_clear
FROM users u
JOIN first_device_users fdu ON u.device_id = fdu.device_id
WHERE u.id != fdu.keep_user_id
  AND u.is_active = true;

-- Actually clear the device_id from duplicate accounts
-- (keeping the first/oldest account's device_id intact)
UPDATE users 
SET device_id = NULL,
    updated_at = NOW()
WHERE id IN (
    SELECT u.id
    FROM users u
    JOIN first_device_users fdu ON u.device_id = fdu.device_id
    WHERE u.id != fdu.keep_user_id
      AND u.is_active = true
);

-- Verify the cleanup
SELECT 'After cleanup - remaining duplicates (should be 0):' as verification;
SELECT 
    device_id,
    COUNT(*) as account_count
FROM users 
WHERE device_id IS NOT NULL 
  AND is_active = true
GROUP BY device_id 
HAVING COUNT(*) > 1;

-- Drop temp table
DROP TABLE first_device_users;

-- Commit the transaction
COMMIT;

-- Final summary
SELECT 'Migration complete! Device IDs have been deduplicated.' as result;
