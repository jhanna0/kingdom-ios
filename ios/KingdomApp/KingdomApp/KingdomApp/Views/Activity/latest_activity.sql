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
    
    -- Scout, sabotage, etc. (excluding farm and patrol)
    SELECT user_id,
           last_performed AS activity_time,
           action_type AS activity_type
    FROM action_cooldowns
    WHERE action_type NOT IN ('farm', 'patrol')
    
    UNION ALL
    
    -- Gathering wood/iron
    SELECT user_id,
           gather_date::timestamp AS activity_time,
           'gathering_' || resource_type AS activity_type
    FROM daily_gathering
    
    UNION ALL
    
    -- Duels
    SELECT challenger_id AS user_id,
           COALESCE(completed_at, started_at, created_at) AS activity_time,
           'duel' AS activity_type
    FROM duel_matches
    WHERE status IN ('fighting', 'complete')
    
    UNION ALL
    
    SELECT opponent_id AS user_id,
           COALESCE(completed_at, started_at, created_at) AS activity_time,
           'duel' AS activity_type
    FROM duel_matches
    WHERE status IN ('fighting', 'complete') AND opponent_id IS NOT NULL
    
    UNION ALL
    
    -- Battle/Coup fight actions
    SELECT player_id AS user_id,
           performed_at AS activity_time,
           'battle' AS activity_type
    FROM battle_actions
    
    UNION ALL
    
    SELECT player_id AS user_id,
           performed_at AS activity_time,
           'coup_fight' AS activity_type
    FROM coup_battle_actions
    
    UNION ALL
    
    -- Science minigame
    SELECT user_id,
           COALESCE(collected_at, created_at) AS activity_time,
           'science' AS activity_type
    FROM science_sessions
    WHERE status IN ('active', 'collected')
    
    UNION ALL
    
    -- Kitchen (baking)
    SELECT user_id,
           started_at AS activity_time,
           'baking' AS activity_type
    FROM oven_slots
    WHERE started_at IS NOT NULL
    
    UNION ALL
    
    -- Garden (watering)
    SELECT user_id,
           last_watered_at AS activity_time,
           'watering' AS activity_type
    FROM garden_slots
    WHERE last_watered_at IS NOT NULL
    
    UNION ALL
    
    -- Market orders
    SELECT player_id AS user_id,
           created_at AS activity_time,
           'market_' || order_type AS activity_type
    FROM market_orders
    
    UNION ALL
    
    -- Trade offers (sender)
    SELECT sender_id AS user_id,
           created_at AS activity_time,
           'trade_offer' AS activity_type
    FROM trade_offers
    
    UNION ALL
    
    -- Trade offers (recipient responding)
    SELECT recipient_id AS user_id,
           responded_at AS activity_time,
           'trade_response' AS activity_type
    FROM trade_offers
    WHERE responded_at IS NOT NULL
    
    UNION ALL
    
    -- Achievement claims
    SELECT user_id,
           claimed_at AS activity_time,
           'achievement' AS activity_type
    FROM player_achievement_claims
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
    k.name AS kingdom_name,
    COALESCE(ps.attack_power, 0) + COALESCE(ps.defense_power, 0) + COALESCE(ps.leadership, 0) + 
    COALESCE(ps.building_skill, 0) + COALESCE(ps.intelligence, 0) + COALESCE(ps.science, 0) + 
    COALESCE(ps.faith, 0) + COALESCE(ps.philosophy, 0) + COALESCE(ps.merchant, 0) AS total_skills,
    r.activity_type, 
    r.activity_time,
    CASE
        WHEN NOW() - r.activity_time < INTERVAL '1 minute' THEN 'just now'
        WHEN NOW() - r.activity_time < INTERVAL '1 hour' THEN EXTRACT(MINUTE FROM NOW() - r.activity_time)::int || 'm ago'
        WHEN NOW() - r.activity_time < INTERVAL '1 day' THEN EXTRACT(HOUR FROM NOW() - r.activity_time)::int || 'h ago'
        WHEN NOW() - r.activity_time < INTERVAL '7 days' THEN EXTRACT(DAY FROM NOW() - r.activity_time)::int || 'd ago'
        ELSE TO_CHAR(r.activity_time, 'Mon DD')
    END AS time_ago,
    ROUND(ps.gold::numeric, 0) AS gold,
    COALESCE(pi.quantity, 0) AS meat
FROM ranked r
JOIN player_state ps ON r.user_id = ps.user_id
LEFT JOIN kingdoms k ON ps.hometown_kingdom_id = k.id
LEFT JOIN player_inventory pi ON r.user_id = pi.user_id AND pi.item_id = 'meat'
WHERE r.rn = 1
ORDER BY r.activity_time DESC
LIMIT 20;