-- =============================================
-- ECONOMY ANALYTICS QUERIES
-- =============================================
-- Useful queries for analyzing meat/gold income rates
-- from hunting and fishing activities.

-- =============================================
-- HUNTING: Meat & Gold per Hour (ALL TIME)
-- =============================================
SELECT 
    COUNT(*) AS total_hunts,
    SUM((session_data->>'total_meat')::int + (session_data->>'bonus_meat')::int) AS total_meat,
    SUM(EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600.0) AS total_hours,
    ROUND((SUM((session_data->>'total_meat')::int + (session_data->>'bonus_meat')::int) / 
           NULLIF(SUM(EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600.0), 0))::numeric, 2) AS meat_per_hour
FROM hunt_sessions
WHERE status = 'completed'
  AND started_at IS NOT NULL
  AND completed_at IS NOT NULL;


-- =============================================
-- HUNTING: Per User Stats (Last 24 Hours)
-- =============================================
SELECT 
    u.display_name,
    h.created_by AS user_id,
    COUNT(*) AS hunts,
    SUM((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int) AS meat,
    SUM((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int) AS gold,
    ROUND(SUM(EXTRACT(EPOCH FROM (h.completed_at - h.started_at)) / 3600.0)::numeric, 2) AS hours,
    ROUND((SUM((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int) / 
           NULLIF(SUM(EXTRACT(EPOCH FROM (h.completed_at - h.started_at)) / 3600.0), 0))::numeric, 2) AS meat_per_hour,
    ROUND((SUM((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int) / 
           NULLIF(SUM(EXTRACT(EPOCH FROM (h.completed_at - h.started_at)) / 3600.0), 0))::numeric, 2) AS gold_per_hour
FROM hunt_sessions h
JOIN users u ON u.id = h.created_by
WHERE h.status = 'completed'
  AND h.completed_at >= NOW() - INTERVAL '24 hours'
  AND h.started_at IS NOT NULL
  AND h.completed_at IS NOT NULL
GROUP BY h.created_by, u.display_name
ORDER BY meat_per_hour DESC;


-- =============================================
-- HUNTING: Meat Breakdown by Animal
-- =============================================
SELECT 
    h.session_data->>'animal_id' AS animal,
    h.session_data->'animal_data'->>'name' AS animal_name,
    (h.session_data->'animal_data'->>'tier')::int AS tier,
    COUNT(*) AS hunts,
    SUM((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int) AS total_meat,
    ROUND(AVG((h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int)::numeric, 2) AS avg_meat_per_hunt,
    ROUND(AVG(EXTRACT(EPOCH FROM (h.completed_at - h.started_at)))::numeric, 2) AS avg_hunt_seconds
FROM hunt_sessions h
WHERE h.status = 'completed'
  AND h.completed_at >= NOW() - INTERVAL '24 hours'
  AND h.started_at IS NOT NULL
GROUP BY h.session_data->>'animal_id', h.session_data->'animal_data'->>'name', h.session_data->'animal_data'->>'tier'
ORDER BY total_meat DESC;


-- =============================================
-- HUNTING: Top Meat Drops (Last 24 Hours)
-- =============================================
SELECT 
    u.display_name,
    h.session_data->>'animal_id' AS animal,
    h.session_data->'animal_data'->>'name' AS animal_name,
    (h.session_data->>'total_meat')::int + (h.session_data->>'bonus_meat')::int AS meat,
    EXTRACT(EPOCH FROM (h.completed_at - h.started_at)) AS seconds,
    h.completed_at
FROM hunt_sessions h
JOIN users u ON u.id = h.created_by
WHERE h.status = 'completed'
  AND h.completed_at >= NOW() - INTERVAL '24 hours'
ORDER BY meat DESC
LIMIT 20;


-- =============================================
-- FISHING: Per User Stats (Last 24 Hours)
-- =============================================
SELECT 
    u.display_name,
    f.created_by AS user_id,
    COUNT(*) AS sessions,
    SUM((f.session_data->>'total_meat')::int) AS meat,
    SUM((f.session_data->>'total_meat')::int) AS gold,
    ROUND(SUM(EXTRACT(EPOCH FROM (f.completed_at - f.created_at)) / 3600.0)::numeric, 2) AS hours,
    ROUND((SUM((f.session_data->>'total_meat')::int) / 
           NULLIF(SUM(EXTRACT(EPOCH FROM (f.completed_at - f.created_at)) / 3600.0), 0))::numeric, 2) AS meat_per_hour,
    ROUND((SUM((f.session_data->>'total_meat')::int) / 
           NULLIF(SUM(EXTRACT(EPOCH FROM (f.completed_at - f.created_at)) / 3600.0), 0))::numeric, 2) AS gold_per_hour
FROM fishing_sessions f
JOIN users u ON u.id = f.created_by
WHERE f.status = 'collected'
  AND f.completed_at >= NOW() - INTERVAL '24 hours'
  AND f.created_at IS NOT NULL
  AND f.completed_at IS NOT NULL
GROUP BY f.created_by, u.display_name
ORDER BY meat_per_hour DESC;


-- =============================================
-- SESSION STATUS CHECKS
-- =============================================

-- Check hunt session statuses
SELECT status, COUNT(*), MAX(completed_at) as latest
FROM hunt_sessions
GROUP BY status;

-- Check fishing session statuses
SELECT status, COUNT(*), MAX(completed_at) as latest
FROM fishing_sessions
GROUP BY status;


-- =============================================
-- SAMPLE DATA INSPECTION
-- =============================================

-- Sample hunt session data structure
SELECT hunt_id, status, session_data->>'total_meat', session_data->>'bonus_meat', started_at, completed_at
FROM hunt_sessions
WHERE status = 'completed'
LIMIT 5;

-- Sample fishing session data structure
SELECT fishing_id, status, session_data->>'total_meat', created_at, completed_at
FROM fishing_sessions
WHERE status = 'collected'
LIMIT 5;
