WITH all_activities AS (
    -- Hunting
    SELECT created_by AS user_id, 
           COALESCE(completed_at, updated_at) AS activity_time,
           'hunting' AS activity_type
    FROM hunt_sessions
    
    UNION ALL
    
    -- Foraging
    SELECT user_id,
           COALESCE(collected_at, created_at) AS activity_time,
           'foraging' AS activity_type
    FROM foraging_sessions
    
    UNION ALL
    
    -- Fishing
    SELECT created_by AS user_id,
           COALESCE(completed_at, updated_at) AS activity_time,
           'fishing' AS activity_type
    FROM fishing_sessions
    
    UNION ALL
    
    -- Building/Training (contract contributions)
    SELECT cc.user_id,
           cc.performed_at AS activity_time,
           CASE 
               WHEN uc.category = 'kingdom_building' THEN 'building'
               WHEN uc.category = 'personal_training' THEN 'training'
               WHEN uc.category = 'personal_crafting' THEN 'crafting'
               ELSE uc.type
           END AS activity_type
    FROM contract_contributions cc
    JOIN unified_contracts uc ON cc.contract_id = uc.id
    
    UNION ALL
    
    -- Farming, patrol, scout, etc.
    SELECT user_id,
           last_performed AS activity_time,
           action_type AS activity_type
    FROM action_cooldowns
    
    UNION ALL
    
    -- Gathering wood/iron
    SELECT user_id,
           gather_date::timestamp AS activity_time,
           'gathering_' || resource_type AS activity_type
    FROM daily_gathering
),
ranked AS (
    SELECT 
        a.user_id,
        u.display_name,
        a.activity_time,
        a.activity_type,
        ROW_NUMBER() OVER (PARTITION BY a.user_id ORDER BY a.activity_time DESC) AS rn
    FROM all_activities a
    JOIN users u ON a.user_id = u.id
)
SELECT 
    r.display_name, 
    r.activity_type, 
    r.activity_time,
    ROUND(ps.gold::numeric, 0) AS gold,
    COALESCE(pi.quantity, 0) AS meat
FROM ranked r
JOIN player_state ps ON r.user_id = ps.user_id
LEFT JOIN player_inventory pi ON r.user_id = pi.user_id AND pi.item_id = 'meat'
WHERE r.rn = 1
ORDER BY r.activity_time DESC
LIMIT 20;