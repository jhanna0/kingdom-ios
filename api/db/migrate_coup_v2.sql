-- Coup V2: Phase computed from time
--
-- resolved_at IS NULL + now < pledge_end_time → 'pledge'
-- resolved_at IS NULL + now >= pledge_end_time → 'battle'  
-- resolved_at IS NOT NULL → 'resolved'
--
-- No cronjob needed. No status column needed.

-- Ensure pledge_end_time exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'coup_events' AND column_name = 'end_time'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'coup_events' AND column_name = 'pledge_end_time'
    ) THEN
        ALTER TABLE coup_events RENAME COLUMN end_time TO pledge_end_time;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'coup_events' AND column_name = 'pledge_end_time'
    ) THEN
        ALTER TABLE coup_events ADD COLUMN pledge_end_time TIMESTAMP NOT NULL DEFAULT NOW();
    END IF;
END $$;

-- Index on resolved_at for active coup queries
CREATE INDEX IF NOT EXISTS idx_coup_events_resolved_at ON coup_events(resolved_at);
CREATE INDEX IF NOT EXISTS idx_coup_events_pledge_end_time ON coup_events(pledge_end_time);

-- status column is deprecated, can be dropped eventually
-- For now, just ignore it - resolved_at is the source of truth

-- ============================================================
-- COUP BATTLE SYSTEM: Territory-based combat
-- ============================================================
-- 
-- Battle phase is now interactive:
-- - 3 territories with tug-of-war bars (0-100)
-- - Players fight every 10 minutes 
-- - Win condition: First to capture 2 of 3 territories
--

-- Territory control per coup
CREATE TABLE IF NOT EXISTS coup_territories (
    id SERIAL PRIMARY KEY,
    coup_id INTEGER NOT NULL REFERENCES coup_events(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,  -- 'coupers_territory', 'crowns_territory', 'throne_room'
    control_bar DOUBLE PRECISION NOT NULL DEFAULT 50.0,  -- 0 = attackers captured, 100 = defenders captured
    captured_by VARCHAR(20) DEFAULT NULL,  -- NULL, 'attackers', 'defenders'
    captured_at TIMESTAMP DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(coup_id, territory_name)
);

CREATE INDEX IF NOT EXISTS idx_coup_territories_coup_id ON coup_territories(coup_id);

-- Battle action log (each fight)
CREATE TABLE IF NOT EXISTS coup_battle_actions (
    id SERIAL PRIMARY KEY,
    coup_id INTEGER NOT NULL REFERENCES coup_events(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,
    side VARCHAR(20) NOT NULL,  -- 'attackers' or 'defenders'
    
    -- Roll results
    roll_count INTEGER NOT NULL,
    rolls JSONB NOT NULL DEFAULT '[]',  -- Array of roll outcomes: [{value, outcome}]
    best_outcome VARCHAR(20) NOT NULL,  -- 'miss', 'hit', 'injure'
    
    -- Bar movement
    push_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    bar_before DOUBLE PRECISION NOT NULL,
    bar_after DOUBLE PRECISION NOT NULL,
    
    -- Injury tracking
    injured_player_id BIGINT DEFAULT NULL REFERENCES users(id) ON DELETE SET NULL,
    
    performed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coup_battle_actions_coup_id ON coup_battle_actions(coup_id);
CREATE INDEX IF NOT EXISTS idx_coup_battle_actions_player_id ON coup_battle_actions(player_id);
CREATE INDEX IF NOT EXISTS idx_coup_battle_actions_performed_at ON coup_battle_actions(performed_at);

-- Track injuries: players who must sit out their next action
CREATE TABLE IF NOT EXISTS coup_injuries (
    id SERIAL PRIMARY KEY,
    coup_id INTEGER NOT NULL REFERENCES coup_events(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    injured_by_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    injury_action_id INTEGER REFERENCES coup_battle_actions(id) ON DELETE SET NULL,
    
    -- Injury expires after one missed action (or after 20 mins)
    injured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,  -- injured_at + 20 minutes
    cleared_at TIMESTAMP DEFAULT NULL,  -- Set when player takes their next action
    
    UNIQUE(coup_id, player_id, injured_at)
);

CREATE INDEX IF NOT EXISTS idx_coup_injuries_coup_id ON coup_injuries(coup_id);
CREATE INDEX IF NOT EXISTS idx_coup_injuries_player_id ON coup_injuries(player_id);
CREATE INDEX IF NOT EXISTS idx_coup_injuries_expires_at ON coup_injuries(expires_at);

-- ============================================================
-- COUP PARTICIPANTS: Proper relational tracking of sides
-- ============================================================
-- Replaces the JSONB arrays (attackers/defenders) on coup_events
-- with a proper junction table for participant tracking.

CREATE TABLE IF NOT EXISTS coup_participants (
    id SERIAL PRIMARY KEY,
    coup_id INTEGER NOT NULL REFERENCES coup_events(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    side VARCHAR(20) NOT NULL CHECK (side IN ('attackers', 'defenders')),
    pledged_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(coup_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_coup_participants_coup_id ON coup_participants(coup_id);
CREATE INDEX IF NOT EXISTS idx_coup_participants_user_id ON coup_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_coup_participants_side ON coup_participants(coup_id, side);

-- Migrate existing data from JSONB arrays (idempotent)
INSERT INTO coup_participants (coup_id, user_id, side)
SELECT ce.id, (jsonb_array_elements_text(ce.attackers))::bigint, 'attackers'
FROM coup_events ce
WHERE ce.attackers IS NOT NULL AND jsonb_array_length(ce.attackers) > 0
ON CONFLICT (coup_id, user_id) DO NOTHING;

INSERT INTO coup_participants (coup_id, user_id, side)
SELECT ce.id, (jsonb_array_elements_text(ce.defenders))::bigint, 'defenders'
FROM coup_events ce
WHERE ce.defenders IS NOT NULL AND jsonb_array_length(ce.defenders) > 0
ON CONFLICT (coup_id, user_id) DO NOTHING;

-- Add winner tracking to coup_events
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'coup_events' AND column_name = 'winner_side'
    ) THEN
        ALTER TABLE coup_events ADD COLUMN winner_side VARCHAR(20) DEFAULT NULL;
    END IF;
END $$;

-- Add gold_per_winner to track spoils for notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'coup_events' AND column_name = 'gold_per_winner'
    ) THEN
        ALTER TABLE coup_events ADD COLUMN gold_per_winner INTEGER DEFAULT NULL;
    END IF;
END $$;

-- ============================================================
-- COUP FIGHT SESSIONS: In-progress fight state (like hunt sessions)
-- ============================================================
--
-- Stores the state of a fight in progress:
-- - Created when player starts a fight on a territory
-- - Updated as player does rolls one by one
-- - Deleted when player resolves (applies push, sets cooldown)
-- - If player exits mid-fight, session persists and they can resume
--

CREATE TABLE IF NOT EXISTS coup_fight_sessions (
    id SERIAL PRIMARY KEY,
    coup_id INTEGER NOT NULL REFERENCES coup_events(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_name VARCHAR(50) NOT NULL,
    side VARCHAR(20) NOT NULL,  -- 'attackers' or 'defenders'
    
    -- How many rolls the player gets (1 + attack_power)
    max_rolls INTEGER NOT NULL DEFAULT 1,
    
    -- Rolls completed so far: [{value: 45.2, outcome: "hit"}, ...]
    rolls JSONB NOT NULL DEFAULT '[]'::jsonb,
    
    -- Combat stats snapshot (for calculating hits)
    hit_chance INTEGER NOT NULL DEFAULT 50,  -- 0-100 percentage
    enemy_avg_defense DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    
    -- Bar snapshot at start
    bar_before DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- One active session per player per coup
    UNIQUE(coup_id, player_id)
);

-- Add unique constraint if table already existed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'coup_fight_sessions_coup_id_player_id_key'
    ) THEN
        ALTER TABLE coup_fight_sessions ADD CONSTRAINT coup_fight_sessions_coup_id_player_id_key UNIQUE (coup_id, player_id);
    END IF;
EXCEPTION WHEN others THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_coup_fight_sessions_coup_id ON coup_fight_sessions(coup_id);
CREATE INDEX IF NOT EXISTS idx_coup_fight_sessions_player_id ON coup_fight_sessions(player_id);

-- ============================================================
-- KINGDOM RULER TRACKING: When current ruler took power
-- ============================================================
-- Add ruler_started_at to kingdoms for tracking reign length

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'kingdoms' AND column_name = 'ruler_started_at'
    ) THEN
        ALTER TABLE kingdoms ADD COLUMN ruler_started_at TIMESTAMP DEFAULT NULL;
    END IF;
END $$;

-- Backfill ruler_started_at from kingdom_history if available
UPDATE kingdoms k
SET ruler_started_at = (
    SELECT started_at 
    FROM kingdom_history kh 
    WHERE kh.kingdom_id = k.id 
      AND kh.ruler_id = k.ruler_id 
      AND kh.ended_at IS NULL
    LIMIT 1
)
WHERE k.ruler_id IS NOT NULL 
  AND k.ruler_started_at IS NULL;
