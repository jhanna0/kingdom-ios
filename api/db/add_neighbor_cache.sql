-- Add neighbor caching to city_boundaries table
-- This caches the list of neighboring city OSM IDs to avoid repeated slow OSM queries

ALTER TABLE city_boundaries
ADD COLUMN IF NOT EXISTS neighbor_ids JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS neighbors_updated_at TIMESTAMP DEFAULT NULL;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_city_boundaries_neighbors_updated 
ON city_boundaries(neighbors_updated_at) 
WHERE neighbors_updated_at IS NOT NULL;

COMMENT ON COLUMN city_boundaries.neighbor_ids IS 'Cached list of neighboring city OSM IDs - permanent cache (cities dont move)';
COMMENT ON COLUMN city_boundaries.neighbors_updated_at IS 'When the neighbor list was first fetched from OSM (for reference only)';

