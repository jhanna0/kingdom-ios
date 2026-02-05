-- Subscriber customization - style presets (icon style + card style)
-- Run with: psql $DATABASE_URL -f api/db/update_subscriber_colors.sql

-- Drop old color columns
ALTER TABLE user_preferences DROP COLUMN IF EXISTS icon_background_color;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS icon_text_color;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS card_background_color;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS card_text_color;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS icon_color_id;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS card_color_id;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS subscriber_theme_id;

-- Add style columns (store preset IDs like 'royal_purple', 'ocean_blue')
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS icon_style VARCHAR;
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS card_style VARCHAR;

-- Drop unnecessary tables
DROP TABLE IF EXISTS subscriber_colors;
DROP TABLE IF EXISTS subscriber_themes;
