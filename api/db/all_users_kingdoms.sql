-- Get all users with their ruled kingdom and hometown kingdom
-- Ordered by user ID descending

SELECT 
    u.id AS user_id,
    u.display_name AS display_name,
    hometown_k.name AS hometown_kingdom_name,
	k.name AS kingdom_name
FROM 
    users u
LEFT JOIN 
    kingdoms k ON k.ruler_id = u.id
LEFT JOIN 
    player_state ps ON u.id = ps.user_id
LEFT JOIN 
    kingdoms hometown_k ON ps.hometown_kingdom_id = hometown_k.id
ORDER BY 
    u.id DESC;
