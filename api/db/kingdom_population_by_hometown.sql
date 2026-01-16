-- Count how many players have each kingdom as their hometown
-- Shows population distribution across kingdoms

SELECT 
    k.name AS kingdom_name,
    k.id AS kingdom_id,
    COUNT(ps.user_id) AS population,
    k.ruler_id,
    u.display_name AS ruler_name
FROM kingdoms k
LEFT JOIN player_state ps ON ps.hometown_kingdom_id = k.id
LEFT JOIN users u ON k.ruler_id = u.id
GROUP BY k.id, k.name, k.ruler_id, u.display_name
ORDER BY population DESC, k.name;

-- Alternative: Show only kingdoms with at least 1 player
-- SELECT 
--     k.name AS kingdom_name,
--     k.id AS kingdom_id,
--     COUNT(ps.user_id) AS population,
--     k.ruler_id,
--     u.display_name AS ruler_name
-- FROM kingdoms k
-- INNER JOIN player_state ps ON ps.hometown_kingdom_id = k.id
-- LEFT JOIN users u ON k.ruler_id = u.id
-- GROUP BY k.id, k.name, k.ruler_id, u.display_name
-- ORDER BY population DESC, k.name;

-- Summary stats
-- SELECT 
--     COUNT(DISTINCT hometown_kingdom_id) AS kingdoms_with_players,
--     COUNT(*) AS total_players_with_hometown,
--     SUM(CASE WHEN hometown_kingdom_id IS NULL THEN 1 ELSE 0 END) AS players_without_hometown
-- FROM player_state;
