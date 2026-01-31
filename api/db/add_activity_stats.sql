-- Activity Statistics Tables
-- ============================
-- Efficient tracking for achievements like "hunt 10 moose", "catch 5 legendary carp"
--
-- Run BEFORE the backfill migration (add_activity_stats_backfill.sql)
-- These tables are incremented in real-time as activities complete.


-- ============================================================
-- HUNTING STATS: Per-animal-type kill counts
-- ============================================================
-- Incremented when a hunt completes successfully (animal killed, not escaped)
-- animal_id matches config.py ANIMALS keys: squirrel, rabbit, deer, boar, bear, moose

CREATE TABLE IF NOT EXISTS player_hunt_kills (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kingdom_id VARCHAR NOT NULL REFERENCES kingdoms(id) ON DELETE CASCADE,
    animal_id VARCHAR(50) NOT NULL,
    kill_count INTEGER NOT NULL DEFAULT 0,
    first_kill_at TIMESTAMP,
    last_kill_at TIMESTAMP,
    PRIMARY KEY (user_id, kingdom_id, animal_id)
);

-- Index for kingdom leaderboard queries
CREATE INDEX IF NOT EXISTS idx_hunt_kills_kingdom ON player_hunt_kills(kingdom_id, kill_count DESC);

-- Index for achievement queries like "who has killed the most bears?"
CREATE INDEX IF NOT EXISTS idx_hunt_kills_animal_count ON player_hunt_kills(animal_id, kill_count DESC);

-- Index for player stats lookups
CREATE INDEX IF NOT EXISTS idx_hunt_kills_user ON player_hunt_kills(user_id);

COMMENT ON TABLE player_hunt_kills IS 'Per-animal-type kill counts per player for achievements';
COMMENT ON COLUMN player_hunt_kills.animal_id IS 'Animal type: squirrel, rabbit, deer, boar, bear, moose';
COMMENT ON COLUMN player_hunt_kills.kill_count IS 'Total successful kills of this animal type';


-- ============================================================
-- FISHING STATS: Per-fish-type catch counts  
-- ============================================================
-- Incremented when a fish is successfully caught (not escaped)
-- fish_id matches config.py FISH keys: minnow, bass, salmon, catfish, legendary_carp

CREATE TABLE IF NOT EXISTS player_fish_catches (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fish_id VARCHAR(50) NOT NULL,
    catch_count INTEGER NOT NULL DEFAULT 0,
    first_catch_at TIMESTAMP,
    last_catch_at TIMESTAMP,
    PRIMARY KEY (user_id, fish_id)
);

-- Index for achievement queries like "who has caught the most legendary carp?"
CREATE INDEX IF NOT EXISTS idx_fish_catches_fish_count ON player_fish_catches(fish_id, catch_count DESC);

-- Index for player stats lookups
CREATE INDEX IF NOT EXISTS idx_fish_catches_user ON player_fish_catches(user_id);

COMMENT ON TABLE player_fish_catches IS 'Per-fish-type catch counts per player for achievements';
COMMENT ON COLUMN player_fish_catches.fish_id IS 'Fish type: minnow, bass, salmon, catfish, legendary_carp';
COMMENT ON COLUMN player_fish_catches.catch_count IS 'Total successful catches of this fish type';


-- ============================================================
-- FORAGING STATS: Per-item-type find counts  
-- ============================================================
-- Incremented when a rare item is found during foraging
-- item_id matches rare foraging items: rare_egg, (future items)

CREATE TABLE IF NOT EXISTS player_foraging_finds (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id VARCHAR(50) NOT NULL,
    find_count INTEGER NOT NULL DEFAULT 0,
    first_find_at TIMESTAMP,
    last_find_at TIMESTAMP,
    PRIMARY KEY (user_id, item_id)
);

-- Index for achievement queries like "who has found the most rare eggs?"
CREATE INDEX IF NOT EXISTS idx_foraging_finds_item_count ON player_foraging_finds(item_id, find_count DESC);

-- Index for player stats lookups
CREATE INDEX IF NOT EXISTS idx_foraging_finds_user ON player_foraging_finds(user_id);

COMMENT ON TABLE player_foraging_finds IS 'Per-item-type rare find counts per player for achievements';
COMMENT ON COLUMN player_foraging_finds.item_id IS 'Rare item type: rare_egg, (future rare foraging items)';
COMMENT ON COLUMN player_foraging_finds.find_count IS 'Total finds of this rare item type';
