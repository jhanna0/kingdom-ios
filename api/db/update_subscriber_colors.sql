-- Simplify subscriber customization - store colors directly on user_preferences
-- Run with: psql $DATABASE_URL -f api/db/update_subscriber_colors.sql

-- Add color columns directly to user_preferences
ALTER TABLE user_preferences 
ADD COLUMN IF NOT EXISTS icon_background_color VARCHAR,  -- hex e.g., '#6B21A8'
ADD COLUMN IF NOT EXISTS icon_text_color VARCHAR,        -- hex
ADD COLUMN IF NOT EXISTS card_background_color VARCHAR;  -- hex

-- Drop the old columns if they exist (from previous migration attempt)
ALTER TABLE user_preferences DROP COLUMN IF EXISTS icon_color_id;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS card_color_id;
ALTER TABLE user_preferences DROP COLUMN IF EXISTS subscriber_theme_id;

-- Drop the unnecessary tables
DROP TABLE IF EXISTS subscriber_colors;
DROP TABLE IF EXISTS subscriber_themes;
