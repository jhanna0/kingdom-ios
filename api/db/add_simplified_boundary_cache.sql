-- Add simplified_boundary_geojson column to cache pre-computed simplified boundaries
-- This eliminates the need to simplify boundaries on every request

-- Add the new column for simplified boundaries
ALTER TABLE city_boundaries 
ADD COLUMN IF NOT EXISTS simplified_boundary_geojson JSONB;

-- Backfill: Populate simplified boundaries for all existing cities
-- Note: This requires running the simplify_boundary function from Python
-- The backfill will be handled by a Python script after this migration

-- Add a comment to document the column
COMMENT ON COLUMN city_boundaries.simplified_boundary_geojson IS 
'Pre-computed simplified boundary (Visvalingam-Whyatt algorithm, ~250 points). Used for efficient data transfer to clients.';

-- Index on simplified_boundary_geojson for potential future queries
CREATE INDEX IF NOT EXISTS idx_city_boundaries_simplified_boundary ON city_boundaries USING gin (simplified_boundary_geojson);

-- Query to check which cities need backfill (optional diagnostic)
-- SELECT osm_id, name, 
--        jsonb_array_length(boundary_geojson->'coordinates') as original_points,
--        CASE 
--          WHEN simplified_boundary_geojson IS NULL THEN 'needs_backfill'
--          ELSE 'has_simplified'
--        END as status
-- FROM city_boundaries
-- ORDER BY created_at DESC;
