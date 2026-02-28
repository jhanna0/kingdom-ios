-- Get all users with their ruled kingdom, hometown kingdom, and current active building contract
-- Ordered by user ID descending

WITH latest_kingdom_contract AS (
    SELECT DISTINCT ON (kingdom_id)
        kingdom_id,
        type AS building_type,
        tier AS building_level
    FROM unified_contracts
    WHERE category = 'kingdom_building' 
        AND completed_at IS NULL
    ORDER BY kingdom_id, created_at DESC
)
SELECT 
    u.id AS user_id,
    u.display_name AS display_name,
    hometown_k.name AS hometown_kingdom_name,
    k.name AS kingdom_name,
    lkc.building_type,
    lkc.building_level
FROM 
    users u
LEFT JOIN 
    kingdoms k ON k.ruler_id = u.id
LEFT JOIN 
    player_state ps ON u.id = ps.user_id
LEFT JOIN 
    kingdoms hometown_k ON ps.hometown_kingdom_id = hometown_k.id
LEFT JOIN 
    latest_kingdom_contract lkc ON k.id = lkc.kingdom_id
ORDER BY 
    u.id DESC;
