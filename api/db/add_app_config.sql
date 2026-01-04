-- Migration: Add app_config table for version checking and maintenance mode
-- This allows the backend to control which app versions are allowed and enable maintenance mode

CREATE TABLE IF NOT EXISTS app_config (
    id SERIAL PRIMARY KEY,
    platform TEXT NOT NULL DEFAULT 'ios',  -- 'ios', 'android', or 'all'
    min_version TEXT NOT NULL,             -- dotted semantic version like '1.0.0'
    maintenance BOOLEAN NOT NULL DEFAULT FALSE,
    maintenance_message TEXT,
    link_url TEXT DEFAULT 'https://testflight.apple.com/join/4jxSyUmW',
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('UTC', now())
);

-- Create index for efficient platform lookups
CREATE INDEX IF NOT EXISTS idx_app_config_platform ON app_config(platform);

-- Insert initial config for iOS
INSERT INTO app_config (platform, min_version, maintenance, maintenance_message, link_url)
VALUES (
    'ios',
    '1.0.0',
    FALSE,
    'Kingdom: Territory is currently undergoing maintenance. Please check back later.',
    'https://testflight.apple.com/join/4jxSyUmW'
)
ON CONFLICT DO NOTHING;

-- Insert fallback config for all platforms
INSERT INTO app_config (platform, min_version, maintenance, maintenance_message)
VALUES (
    'all',
    '1.0.0',
    FALSE,
    'Kingdom: Territory is currently undergoing maintenance. Please check back later.'
)
ON CONFLICT DO NOTHING;

