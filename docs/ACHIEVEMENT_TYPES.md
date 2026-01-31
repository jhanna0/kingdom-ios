# Achievement Types Reference

## Schema

```sql
achievement_definitions (
    id SERIAL PRIMARY KEY,
    achievement_type VARCHAR NOT NULL,
    tier INTEGER NOT NULL,
    target_value INTEGER NOT NULL,
    rewards JSONB,                       -- e.g. '{"gold": 100}'
    display_name VARCHAR,
    description VARCHAR,
    icon VARCHAR,                        -- SF Symbol name
    category VARCHAR,                    -- 'hunting', 'fishing', 'foraging'
    display_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(achievement_type, tier)
)
```

---

## Hunting Achievements

### Per-Animal Types

| Type | Animal | Icon | Category |
|------|--------|------|----------|
| `hunt_squirrel` | Squirrel 🐿️ | `leaf.fill` | hunting |
| `hunt_rabbit` | Rabbit 🐰 | `hare.fill` | hunting |
| `hunt_deer` | Deer 🦌 | `leaf.circle.fill` | hunting |
| `hunt_boar` | Wild Boar 🐗 | `pawprint.fill` | hunting |
| `hunt_bear` | Bear 🐻 | `flame.fill` | hunting |
| `hunt_moose` | Moose 🫎 | `crown.fill` | hunting |

#### Suggested Tiers

| Type | Tier | Target | Gold | Display Name |
|------|------|--------|------|--------------|
| `hunt_squirrel` | 1 | 50 | 25 | Squirrel Chaser I |
| `hunt_squirrel` | 2 | 100 | 50 | Squirrel Chaser II |
| `hunt_squirrel` | 3 | 250 | 100 | Squirrel Chaser III |
| `hunt_squirrel` | 4 | 500 | 200 | Squirrel Chaser IV |
| `hunt_squirrel` | 5 | 1000 | 500 | Squirrel Chaser V |
| `hunt_rabbit` | 1 | 50 | 25 | Rabbit Hunter I |
| `hunt_rabbit` | 2 | 100 | 50 | Rabbit Hunter II |
| `hunt_rabbit` | 3 | 250 | 100 | Rabbit Hunter III |
| `hunt_rabbit` | 4 | 500 | 200 | Rabbit Hunter IV |
| `hunt_rabbit` | 5 | 1000 | 500 | Rabbit Hunter V |
| `hunt_deer` | 1 | 25 | 50 | Deer Stalker I |
| `hunt_deer` | 2 | 50 | 100 | Deer Stalker II |
| `hunt_deer` | 3 | 100 | 200 | Deer Stalker III |
| `hunt_deer` | 4 | 250 | 500 | Deer Stalker IV |
| `hunt_deer` | 5 | 500 | 1000 | Deer Stalker V |
| `hunt_boar` | 1 | 10 | 75 | Boar Slayer I |
| `hunt_boar` | 2 | 25 | 150 | Boar Slayer II |
| `hunt_boar` | 3 | 50 | 300 | Boar Slayer III |
| `hunt_boar` | 4 | 100 | 600 | Boar Slayer IV |
| `hunt_boar` | 5 | 250 | 1500 | Boar Slayer V |
| `hunt_bear` | 1 | 5 | 100 | Bear Slayer I |
| `hunt_bear` | 2 | 10 | 200 | Bear Slayer II |
| `hunt_bear` | 3 | 25 | 500 | Bear Slayer III |
| `hunt_bear` | 4 | 50 | 1000 | Bear Slayer IV |
| `hunt_bear` | 5 | 100 | 2500 | Bear Slayer V |
| `hunt_moose` | 1 | 3 | 150 | Moose Hunter I |
| `hunt_moose` | 2 | 5 | 300 | Moose Hunter II |
| `hunt_moose` | 3 | 10 | 600 | Moose Hunter III |
| `hunt_moose` | 4 | 25 | 1500 | Moose Hunter IV |
| `hunt_moose` | 5 | 50 | 3000 | Moose Hunter V |

### Total Hunts

| Type | Tier | Target | Gold | Display Name |
|------|------|--------|------|--------------|
| `hunts_completed` | 1 | 250 | 50 | Novice Hunter |
| `hunts_completed` | 2 | 500 | 100 | Skilled Hunter |
| `hunts_completed` | 3 | 1000 | 200 | Expert Hunter |
| `hunts_completed` | 4 | 2500 | 500 | Master Hunter |
| `hunts_completed` | 5 | 5000 | 1000 | Veteran Hunter |
| `hunts_completed` | 6 | 10000 | 2500 | Legendary Hunter |
| `hunts_completed` | 7 | 25000 | 5000 | Mythic Hunter |

---

## Fishing Achievements

### Per-Fish Types

| Type | Fish | Icon | Category |
|------|------|------|----------|
| `catch_minnow` | Minnow 🐟 | `fish.fill` | fishing |
| `catch_bass` | Bass 🐟 | `fish.fill` | fishing |
| `catch_salmon` | Salmon 🐠 | `fish.fill` | fishing |
| `catch_catfish` | Catfish 🐡 | `fish.fill` | fishing |
| `catch_legendary_carp` | Legendary Carp 🎣 | `sparkles` | fishing |

#### Suggested Tiers

| Type | Tier | Target | Gold | Display Name |
|------|------|--------|------|--------------|
| `catch_minnow` | 1 | 50 | 25 | Minnow Catcher I |
| `catch_minnow` | 2 | 100 | 50 | Minnow Catcher II |
| `catch_minnow` | 3 | 250 | 100 | Minnow Catcher III |
| `catch_minnow` | 4 | 500 | 200 | Minnow Catcher IV |
| `catch_minnow` | 5 | 1000 | 500 | Minnow Catcher V |
| `catch_bass` | 1 | 50 | 25 | Bass Fisher I |
| `catch_bass` | 2 | 100 | 50 | Bass Fisher II |
| `catch_bass` | 3 | 250 | 100 | Bass Fisher III |
| `catch_bass` | 4 | 500 | 200 | Bass Fisher IV |
| `catch_bass` | 5 | 1000 | 500 | Bass Fisher V |
| `catch_salmon` | 1 | 25 | 50 | Salmon Seeker I |
| `catch_salmon` | 2 | 50 | 100 | Salmon Seeker II |
| `catch_salmon` | 3 | 100 | 200 | Salmon Seeker III |
| `catch_salmon` | 4 | 250 | 500 | Salmon Seeker IV |
| `catch_salmon` | 5 | 500 | 1000 | Salmon Seeker V |
| `catch_catfish` | 1 | 10 | 75 | Catfish Hunter I |
| `catch_catfish` | 2 | 25 | 150 | Catfish Hunter II |
| `catch_catfish` | 3 | 50 | 300 | Catfish Hunter III |
| `catch_catfish` | 4 | 100 | 600 | Catfish Hunter IV |
| `catch_catfish` | 5 | 250 | 1500 | Catfish Hunter V |
| `catch_legendary_carp` | 1 | 3 | 150 | Legend Finder I |
| `catch_legendary_carp` | 2 | 5 | 300 | Legend Finder II |
| `catch_legendary_carp` | 3 | 10 | 600 | Legend Finder III |
| `catch_legendary_carp` | 4 | 25 | 1500 | Legend Finder IV |
| `catch_legendary_carp` | 5 | 50 | 3000 | Legend Finder V |

### General Fishing

| Type | Tier | Target | Gold | Display Name |
|------|------|--------|------|--------------|
| `fish_caught` | 1 | 250 | 50 | Novice Angler |
| `fish_caught` | 2 | 500 | 100 | Skilled Angler |
| `fish_caught` | 3 | 1000 | 200 | Expert Angler |
| `fish_caught` | 4 | 2500 | 500 | Master Angler |
| `fish_caught` | 5 | 5000 | 1000 | Veteran Angler |
| `fish_caught` | 6 | 10000 | 2500 | Legendary Angler |
| `pet_fish_caught` | 1 | 1 | 500 | Lucky Fisher |

---

## Foraging Achievements

| Type | Tier | Target | Gold | Display Name |
|------|------|--------|------|--------------|
| `foraging_completed` | 1 | 250 | 50 | Berry Picker I |
| `foraging_completed` | 2 | 500 | 100 | Berry Picker II |
| `foraging_completed` | 3 | 1000 | 200 | Berry Picker III |
| `foraging_completed` | 4 | 2500 | 500 | Berry Picker IV |
| `foraging_completed` | 5 | 5000 | 1000 | Berry Picker V |
| `foraging_completed` | 6 | 10000 | 2500 | Berry Picker VI |
| `foraging_completed` | 7 | 25000 | 5000 | Berry Picker VII |

---

## Progress Source Tables

| Achievement Type | Source Table | Column |
|-----------------|--------------|--------|
| `hunt_<animal>` | `player_hunt_kills` | `kill_count` |
| `hunts_completed` | `player_hunt_kills` | `SUM(kill_count)` |
| `catch_<fish>` | `player_fish_catches` | `catch_count` |
| `fish_caught` | `fishing_sessions` | `session_data->>'fish_caught'` |
| `pet_fish_caught` | `fishing_sessions` | `session_data->>'pet_fish_dropped'` |
| `foraging_completed` | `foraging_sessions` | `COUNT(*)` |

---

## Example Insert

```sql
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_bear', 1, 1, '{"gold": 150}', 'Bear Slayer I', 'Hunt 1 bear', 'flame.fill', 'hunting', 140),
    ('hunt_bear', 2, 5, '{"gold": 500}', 'Bear Slayer II', 'Hunt 5 bears', 'flame.fill', 'hunting', 141),
    ('hunt_bear', 3, 20, '{"gold": 1500}', 'Bear Slayer III', 'Hunt 20 bears', 'flame.fill', 'hunting', 142)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description;
```

NO XP IS GIVEN. ONLY GOLD!!!