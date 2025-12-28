-- Migration script to add missing columns to kingdoms table
-- Run this to sync the database with the current Kingdom model
-- This script is safe to run multiple times (uses IF NOT EXISTS)

-- Game state columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS checked_in_players INTEGER DEFAULT 0;

-- Building columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS wall_level INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS vault_level INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS mine_level INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS market_level INTEGER DEFAULT 0;

-- Tax & Income columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS tax_rate INTEGER DEFAULT 10;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS last_income_collection TIMESTAMP DEFAULT NOW();
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS weekly_unique_check_ins INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS total_income_collected INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS income_history JSONB DEFAULT '[]';

-- Subject reward distribution columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS subject_reward_rate INTEGER DEFAULT 15;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS last_reward_distribution TIMESTAMP DEFAULT NOW();
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS total_rewards_distributed INTEGER DEFAULT 0;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS distribution_history JSONB DEFAULT '[]';

-- Daily quests column
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS active_quests JSONB DEFAULT '[]';

-- Alliances & Wars columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS allies JSONB DEFAULT '[]';
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS enemies JSONB DEFAULT '[]';

-- Defense/Attack stats columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS defense_rating INTEGER DEFAULT 10;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS military_strength INTEGER DEFAULT 5;

-- Kingdom metadata columns
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS kingdom_data JSONB DEFAULT '{}';

-- Timestamps column
ALTER TABLE kingdoms ADD COLUMN IF NOT EXISTS last_activity TIMESTAMP DEFAULT NOW();

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'kingdoms'
ORDER BY ordinal_position;
