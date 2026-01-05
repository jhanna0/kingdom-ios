-- Add weather caching to city_boundaries table
-- Weather is cached hourly per city to avoid excessive API calls

ALTER TABLE city_boundaries
ADD COLUMN IF NOT EXISTS weather_data JSONB,
ADD COLUMN IF NOT EXISTS weather_cached_at TIMESTAMP;

-- Index for efficient weather queries
CREATE INDEX IF NOT EXISTS idx_city_boundaries_weather_cached_at ON city_boundaries(weather_cached_at);

COMMENT ON COLUMN city_boundaries.weather_data IS 'Cached weather data from Open-Meteo API (refreshed hourly)';
COMMENT ON COLUMN city_boundaries.weather_cached_at IS 'Timestamp when weather was last fetched';



