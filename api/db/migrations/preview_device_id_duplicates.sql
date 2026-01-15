-- Preview: Show all duplicate device_ids
-- Run this FIRST to see what duplicates exist before running the migration
-- This is a READ-ONLY query that makes NO changes

-- Show all device_ids that have multiple accounts
SELECT 
    device_id,
    COUNT(*) as account_count,
    ARRAY_AGG(id ORDER BY created_at) as user_ids,
    ARRAY_AGG(display_name ORDER BY created_at) as display_names,
    ARRAY_AGG(created_at ORDER BY created_at) as created_dates
FROM users 
WHERE device_id IS NOT NULL 
  AND is_active = true
GROUP BY device_id 
HAVING COUNT(*) > 1
ORDER BY account_count DESC;

-- Summary statistics
SELECT 
    COUNT(DISTINCT device_id) as devices_with_duplicates,
    SUM(cnt - 1) as total_duplicate_accounts_to_clear
FROM (
    SELECT device_id, COUNT(*) as cnt
    FROM users 
    WHERE device_id IS NOT NULL 
      AND is_active = true
    GROUP BY device_id 
    HAVING COUNT(*) > 1
) subq;
