-- Add subscription system tables
-- Run with: psql $DATABASE_URL -f api/db/add_subscriptions.sql

-- 1. Subscriber themes table (server-driven theme definitions)
CREATE TABLE IF NOT EXISTS subscriber_themes (
    id VARCHAR PRIMARY KEY,  -- e.g., 'royal_purple'
    display_name VARCHAR NOT NULL,
    description VARCHAR,
    background_color VARCHAR NOT NULL,  -- hex color e.g., '#6B21A8'
    text_color VARCHAR NOT NULL,        -- hex color
    icon_background_color VARCHAR NOT NULL   -- hex color
);

-- Seed initial themes
INSERT INTO subscriber_themes (id, display_name, description, background_color, text_color, icon_background_color) VALUES
    ('royal_purple', 'Royal Purple', 'Regal purple with gold accents', '#6B21A8', '#FCD34D', '#9333EA'),
    ('forest_green', 'Forest Green', 'Natural green with cream tones', '#166534', '#FEF3C7', '#22C55E'),
    ('ocean_blue', 'Ocean Blue', 'Deep blue with silver highlights', '#1E40AF', '#E0E7FF', '#3B82F6'),
    ('crimson_knight', 'Crimson Knight', 'Bold red warrior theme', '#991B1B', '#FECACA', '#EF4444'),
    ('golden_crown', 'Golden Crown', 'Majestic gold royalty', '#CA8A04', '#FFFFFF', '#EAB308')
ON CONFLICT (id) DO NOTHING;

-- 2. Subscriptions table (tracks subscription history)
CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id VARCHAR NOT NULL,
    original_transaction_id VARCHAR NOT NULL,
    started_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_expires ON subscriptions(user_id, expires_at);

-- 3. User customization preferences (separate from auth/signup data)
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    subscriber_theme_id VARCHAR REFERENCES subscriber_themes(id) ON DELETE SET NULL,
    selected_title_achievement_id INTEGER
);
