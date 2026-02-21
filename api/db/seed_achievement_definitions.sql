-- Seed Achievement Definitions
-- Based on docs/ACHIEVEMENT_TYPES.md
-- NO XP IS GIVEN. ONLY GOLD!!!

-- =====================================================
-- HUNTING ACHIEVEMENTS - Per-Animal Types
-- =====================================================

-- Squirrel (icon: leaf.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_squirrel', 1, 50, '{"gold": 25}', 'Squirrel Chaser I', 'Hunt 50 squirrels', 'leaf.fill', 'hunting', 100),
    ('hunt_squirrel', 2, 100, '{"gold": 50}', 'Squirrel Chaser II', 'Hunt 100 squirrels', 'leaf.fill', 'hunting', 101),
    ('hunt_squirrel', 3, 250, '{"gold": 100}', 'Squirrel Chaser III', 'Hunt 250 squirrels', 'leaf.fill', 'hunting', 102),
    ('hunt_squirrel', 4, 500, '{"gold": 200}', 'Squirrel Chaser IV', 'Hunt 500 squirrels', 'leaf.fill', 'hunting', 103),
    ('hunt_squirrel', 5, 1000, '{"gold": 500}', 'Squirrel Chaser V', 'Hunt 1000 squirrels', 'leaf.fill', 'hunting', 104),
    ('hunt_squirrel', 6, 2500, '{"gold": 750}', 'Squirrel Chaser VI', 'Hunt 2500 squirrels', 'leaf.fill', 'hunting', 105),
    ('hunt_squirrel', 7, 5000, '{"gold": 1000}', 'Squirrel Chaser VII', 'Hunt 5000 squirrels', 'leaf.fill', 'hunting', 106),
    ('hunt_squirrel', 8, 10000, '{"gold": 1500}', 'Squirrel Chaser VIII', 'Hunt 10000 squirrels', 'leaf.fill', 'hunting', 107),
    ('hunt_squirrel', 9, 25000, '{"gold": 2000}', 'Squirrel Chaser IX', 'Hunt 25000 squirrels', 'leaf.fill', 'hunting', 108),
    ('hunt_squirrel', 10, 50000, '{"gold": 3000}', 'Squirrel Chaser X', 'Hunt 50000 squirrels', 'leaf.fill', 'hunting', 109)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Rabbit (icon: hare.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_rabbit', 1, 50, '{"gold": 25}', 'Rabbit Hunter I', 'Hunt 50 rabbits', 'hare.fill', 'hunting', 110),
    ('hunt_rabbit', 2, 100, '{"gold": 50}', 'Rabbit Hunter II', 'Hunt 100 rabbits', 'hare.fill', 'hunting', 111),
    ('hunt_rabbit', 3, 250, '{"gold": 100}', 'Rabbit Hunter III', 'Hunt 250 rabbits', 'hare.fill', 'hunting', 112),
    ('hunt_rabbit', 4, 500, '{"gold": 200}', 'Rabbit Hunter IV', 'Hunt 500 rabbits', 'hare.fill', 'hunting', 113),
    ('hunt_rabbit', 5, 1000, '{"gold": 500}', 'Rabbit Hunter V', 'Hunt 1000 rabbits', 'hare.fill', 'hunting', 114),
    ('hunt_rabbit', 6, 2500, '{"gold": 750}', 'Rabbit Hunter VI', 'Hunt 2500 rabbits', 'hare.fill', 'hunting', 115),
    ('hunt_rabbit', 7, 5000, '{"gold": 1000}', 'Rabbit Hunter VII', 'Hunt 5000 rabbits', 'hare.fill', 'hunting', 116),
    ('hunt_rabbit', 8, 10000, '{"gold": 1500}', 'Rabbit Hunter VIII', 'Hunt 10000 rabbits', 'hare.fill', 'hunting', 117),
    ('hunt_rabbit', 9, 25000, '{"gold": 2000}', 'Rabbit Hunter IX', 'Hunt 25000 rabbits', 'hare.fill', 'hunting', 118),
    ('hunt_rabbit', 10, 50000, '{"gold": 3000}', 'Rabbit Hunter X', 'Hunt 50000 rabbits', 'hare.fill', 'hunting', 119)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Deer (icon: leaf.circle.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_deer', 1, 25, '{"gold": 50}', 'Deer Stalker I', 'Hunt 25 deer', 'leaf.circle.fill', 'hunting', 120),
    ('hunt_deer', 2, 50, '{"gold": 100}', 'Deer Stalker II', 'Hunt 50 deer', 'leaf.circle.fill', 'hunting', 121),
    ('hunt_deer', 3, 100, '{"gold": 200}', 'Deer Stalker III', 'Hunt 100 deer', 'leaf.circle.fill', 'hunting', 122),
    ('hunt_deer', 4, 250, '{"gold": 500}', 'Deer Stalker IV', 'Hunt 250 deer', 'leaf.circle.fill', 'hunting', 123),
    ('hunt_deer', 5, 500, '{"gold": 1000}', 'Deer Stalker V', 'Hunt 500 deer', 'leaf.circle.fill', 'hunting', 124),
    ('hunt_deer', 6, 1000, '{"gold": 1500}', 'Deer Stalker VI', 'Hunt 1000 deer', 'leaf.circle.fill', 'hunting', 125),
    ('hunt_deer', 7, 2500, '{"gold": 2000}', 'Deer Stalker VII', 'Hunt 2500 deer', 'leaf.circle.fill', 'hunting', 126),
    ('hunt_deer', 8, 5000, '{"gold": 2500}', 'Deer Stalker VIII', 'Hunt 5000 deer', 'leaf.circle.fill', 'hunting', 127),
    ('hunt_deer', 9, 10000, '{"gold": 3000}', 'Deer Stalker IX', 'Hunt 10000 deer', 'leaf.circle.fill', 'hunting', 128),
    ('hunt_deer', 10, 25000, '{"gold": 4000}', 'Deer Stalker X', 'Hunt 25000 deer', 'leaf.circle.fill', 'hunting', 129)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Boar (icon: pawprint.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_boar', 1, 10, '{"gold": 75}', 'Boar Slayer I', 'Hunt 10 boars', 'pawprint.fill', 'hunting', 130),
    ('hunt_boar', 2, 25, '{"gold": 150}', 'Boar Slayer II', 'Hunt 25 boars', 'pawprint.fill', 'hunting', 131),
    ('hunt_boar', 3, 50, '{"gold": 300}', 'Boar Slayer III', 'Hunt 50 boars', 'pawprint.fill', 'hunting', 132),
    ('hunt_boar', 4, 100, '{"gold": 600}', 'Boar Slayer IV', 'Hunt 100 boars', 'pawprint.fill', 'hunting', 133),
    ('hunt_boar', 5, 250, '{"gold": 1500}', 'Boar Slayer V', 'Hunt 250 boars', 'pawprint.fill', 'hunting', 134),
    ('hunt_boar', 6, 500, '{"gold": 2000}', 'Boar Slayer VI', 'Hunt 500 boars', 'pawprint.fill', 'hunting', 135),
    ('hunt_boar', 7, 1000, '{"gold": 2500}', 'Boar Slayer VII', 'Hunt 1000 boars', 'pawprint.fill', 'hunting', 136),
    ('hunt_boar', 8, 2500, '{"gold": 3000}', 'Boar Slayer VIII', 'Hunt 2500 boars', 'pawprint.fill', 'hunting', 137),
    ('hunt_boar', 9, 5000, '{"gold": 4000}', 'Boar Slayer IX', 'Hunt 5000 boars', 'pawprint.fill', 'hunting', 138),
    ('hunt_boar', 10, 10000, '{"gold": 5000}', 'Boar Slayer X', 'Hunt 10000 boars', 'pawprint.fill', 'hunting', 139)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Bear (icon: flame.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_bear', 1, 5, '{"gold": 100}', 'Bear Slayer I', 'Hunt 5 bears', 'flame.fill', 'hunting', 140),
    ('hunt_bear', 2, 10, '{"gold": 200}', 'Bear Slayer II', 'Hunt 10 bears', 'flame.fill', 'hunting', 141),
    ('hunt_bear', 3, 25, '{"gold": 500}', 'Bear Slayer III', 'Hunt 25 bears', 'flame.fill', 'hunting', 142),
    ('hunt_bear', 4, 50, '{"gold": 1000}', 'Bear Slayer IV', 'Hunt 50 bears', 'flame.fill', 'hunting', 143),
    ('hunt_bear', 5, 100, '{"gold": 2500}', 'Bear Slayer V', 'Hunt 100 bears', 'flame.fill', 'hunting', 144),
    ('hunt_bear', 6, 250, '{"gold": 3000}', 'Bear Slayer VI', 'Hunt 250 bears', 'flame.fill', 'hunting', 145),
    ('hunt_bear', 7, 500, '{"gold": 3500}', 'Bear Slayer VII', 'Hunt 500 bears', 'flame.fill', 'hunting', 146),
    ('hunt_bear', 8, 1000, '{"gold": 4000}', 'Bear Slayer VIII', 'Hunt 1000 bears', 'flame.fill', 'hunting', 147),
    ('hunt_bear', 9, 2500, '{"gold": 4500}', 'Bear Slayer IX', 'Hunt 2500 bears', 'flame.fill', 'hunting', 148),
    ('hunt_bear', 10, 5000, '{"gold": 5000}', 'Bear Slayer X', 'Hunt 5000 bears', 'flame.fill', 'hunting', 149)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Moose (icon: crown.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('hunt_moose', 1, 3, '{"gold": 150}', 'Moose Hunter I', 'Hunt 3 moose', 'crown.fill', 'hunting', 150),
    ('hunt_moose', 2, 5, '{"gold": 300}', 'Moose Hunter II', 'Hunt 5 moose', 'crown.fill', 'hunting', 151),
    ('hunt_moose', 3, 10, '{"gold": 600}', 'Moose Hunter III', 'Hunt 10 moose', 'crown.fill', 'hunting', 152),
    ('hunt_moose', 4, 25, '{"gold": 1500}', 'Moose Hunter IV', 'Hunt 25 moose', 'crown.fill', 'hunting', 153),
    ('hunt_moose', 5, 50, '{"gold": 3000}', 'Moose Hunter V', 'Hunt 50 moose', 'crown.fill', 'hunting', 154),
    ('hunt_moose', 6, 100, '{"gold": 3500}', 'Moose Hunter VI', 'Hunt 100 moose', 'crown.fill', 'hunting', 155),
    ('hunt_moose', 7, 250, '{"gold": 4000}', 'Moose Hunter VII', 'Hunt 250 moose', 'crown.fill', 'hunting', 156),
    ('hunt_moose', 8, 500, '{"gold": 4500}', 'Moose Hunter VIII', 'Hunt 500 moose', 'crown.fill', 'hunting', 157),
    ('hunt_moose', 9, 1000, '{"gold": 5000}', 'Moose Hunter IX', 'Hunt 1000 moose', 'crown.fill', 'hunting', 158),
    ('hunt_moose', 10, 2500, '{"gold": 5500}', 'Moose Hunter X', 'Hunt 2500 moose', 'crown.fill', 'hunting', 159)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- =====================================================
-- HUNTING ACHIEVEMENTS - Total Hunts
-- =====================================================

INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('hunts_completed', 1, 250, '{"gold": 50}', 'Novice Hunter', 'Complete 250 hunts', 'target', 'hunting', 160, 'Total successful hunts'),
    ('hunts_completed', 2, 500, '{"gold": 100}', 'Skilled Hunter', 'Complete 500 hunts', 'target', 'hunting', 161, 'Total successful hunts'),
    ('hunts_completed', 3, 1000, '{"gold": 200}', 'Expert Hunter', 'Complete 1000 hunts', 'target', 'hunting', 162, 'Total successful hunts'),
    ('hunts_completed', 4, 2500, '{"gold": 500}', 'Master Hunter', 'Complete 2500 hunts', 'target', 'hunting', 163, 'Total successful hunts'),
    ('hunts_completed', 5, 5000, '{"gold": 1000}', 'Veteran Hunter', 'Complete 5000 hunts', 'target', 'hunting', 164, 'Total successful hunts'),
    ('hunts_completed', 6, 10000, '{"gold": 2500}', 'Legendary Hunter', 'Complete 10000 hunts', 'target', 'hunting', 165, 'Total successful hunts'),
    ('hunts_completed', 7, 25000, '{"gold": 5000}', 'Mythic Hunter', 'Complete 25000 hunts', 'target', 'hunting', 166, 'Total successful hunts')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- FISHING ACHIEVEMENTS - Per-Fish Types
-- =====================================================

-- Minnow (icon: fish.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('catch_minnow', 1, 50, '{"gold": 25}', 'Minnow Catcher I', 'Catch 50 minnows', 'fish.fill', 'fishing', 200),
    ('catch_minnow', 2, 100, '{"gold": 50}', 'Minnow Catcher II', 'Catch 100 minnows', 'fish.fill', 'fishing', 201),
    ('catch_minnow', 3, 250, '{"gold": 100}', 'Minnow Catcher III', 'Catch 250 minnows', 'fish.fill', 'fishing', 202),
    ('catch_minnow', 4, 500, '{"gold": 200}', 'Minnow Catcher IV', 'Catch 500 minnows', 'fish.fill', 'fishing', 203),
    ('catch_minnow', 5, 1000, '{"gold": 500}', 'Minnow Catcher V', 'Catch 1000 minnows', 'fish.fill', 'fishing', 204),
    ('catch_minnow', 6, 2500, '{"gold": 750}', 'Minnow Catcher VI', 'Catch 2500 minnows', 'fish.fill', 'fishing', 205),
    ('catch_minnow', 7, 5000, '{"gold": 1000}', 'Minnow Catcher VII', 'Catch 5000 minnows', 'fish.fill', 'fishing', 206),
    ('catch_minnow', 8, 10000, '{"gold": 1500}', 'Minnow Catcher VIII', 'Catch 10000 minnows', 'fish.fill', 'fishing', 207),
    ('catch_minnow', 9, 25000, '{"gold": 2000}', 'Minnow Catcher IX', 'Catch 25000 minnows', 'fish.fill', 'fishing', 208),
    ('catch_minnow', 10, 50000, '{"gold": 3000}', 'Minnow Catcher X', 'Catch 50000 minnows', 'fish.fill', 'fishing', 209)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Bass (icon: fish.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('catch_bass', 1, 50, '{"gold": 25}', 'Bass Fisher I', 'Catch 50 bass', 'fish.fill', 'fishing', 210),
    ('catch_bass', 2, 100, '{"gold": 50}', 'Bass Fisher II', 'Catch 100 bass', 'fish.fill', 'fishing', 211),
    ('catch_bass', 3, 250, '{"gold": 100}', 'Bass Fisher III', 'Catch 250 bass', 'fish.fill', 'fishing', 212),
    ('catch_bass', 4, 500, '{"gold": 200}', 'Bass Fisher IV', 'Catch 500 bass', 'fish.fill', 'fishing', 213),
    ('catch_bass', 5, 1000, '{"gold": 500}', 'Bass Fisher V', 'Catch 1000 bass', 'fish.fill', 'fishing', 214),
    ('catch_bass', 6, 2500, '{"gold": 750}', 'Bass Fisher VI', 'Catch 2500 bass', 'fish.fill', 'fishing', 215),
    ('catch_bass', 7, 5000, '{"gold": 1000}', 'Bass Fisher VII', 'Catch 5000 bass', 'fish.fill', 'fishing', 216),
    ('catch_bass', 8, 10000, '{"gold": 1500}', 'Bass Fisher VIII', 'Catch 10000 bass', 'fish.fill', 'fishing', 217),
    ('catch_bass', 9, 25000, '{"gold": 2000}', 'Bass Fisher IX', 'Catch 25000 bass', 'fish.fill', 'fishing', 218),
    ('catch_bass', 10, 50000, '{"gold": 3000}', 'Bass Fisher X', 'Catch 50000 bass', 'fish.fill', 'fishing', 219)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Salmon (icon: fish.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('catch_salmon', 1, 25, '{"gold": 50}', 'Salmon Seeker I', 'Catch 25 salmon', 'fish.fill', 'fishing', 220),
    ('catch_salmon', 2, 50, '{"gold": 100}', 'Salmon Seeker II', 'Catch 50 salmon', 'fish.fill', 'fishing', 221),
    ('catch_salmon', 3, 100, '{"gold": 200}', 'Salmon Seeker III', 'Catch 100 salmon', 'fish.fill', 'fishing', 222),
    ('catch_salmon', 4, 250, '{"gold": 500}', 'Salmon Seeker IV', 'Catch 250 salmon', 'fish.fill', 'fishing', 223),
    ('catch_salmon', 5, 500, '{"gold": 1000}', 'Salmon Seeker V', 'Catch 500 salmon', 'fish.fill', 'fishing', 224),
    ('catch_salmon', 6, 1000, '{"gold": 1500}', 'Salmon Seeker VI', 'Catch 1000 salmon', 'fish.fill', 'fishing', 225),
    ('catch_salmon', 7, 2500, '{"gold": 2000}', 'Salmon Seeker VII', 'Catch 2500 salmon', 'fish.fill', 'fishing', 226),
    ('catch_salmon', 8, 5000, '{"gold": 2500}', 'Salmon Seeker VIII', 'Catch 5000 salmon', 'fish.fill', 'fishing', 227),
    ('catch_salmon', 9, 10000, '{"gold": 3000}', 'Salmon Seeker IX', 'Catch 10000 salmon', 'fish.fill', 'fishing', 228),
    ('catch_salmon', 10, 25000, '{"gold": 4000}', 'Salmon Seeker X', 'Catch 25000 salmon', 'fish.fill', 'fishing', 229)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Catfish (icon: fish.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('catch_catfish', 1, 10, '{"gold": 75}', 'Catfish Hunter I', 'Catch 10 catfish', 'fish.fill', 'fishing', 230),
    ('catch_catfish', 2, 25, '{"gold": 150}', 'Catfish Hunter II', 'Catch 25 catfish', 'fish.fill', 'fishing', 231),
    ('catch_catfish', 3, 50, '{"gold": 300}', 'Catfish Hunter III', 'Catch 50 catfish', 'fish.fill', 'fishing', 232),
    ('catch_catfish', 4, 100, '{"gold": 600}', 'Catfish Hunter IV', 'Catch 100 catfish', 'fish.fill', 'fishing', 233),
    ('catch_catfish', 5, 250, '{"gold": 1500}', 'Catfish Hunter V', 'Catch 250 catfish', 'fish.fill', 'fishing', 234),
    ('catch_catfish', 6, 500, '{"gold": 2000}', 'Catfish Hunter VI', 'Catch 500 catfish', 'fish.fill', 'fishing', 235),
    ('catch_catfish', 7, 1000, '{"gold": 2500}', 'Catfish Hunter VII', 'Catch 1000 catfish', 'fish.fill', 'fishing', 236),
    ('catch_catfish', 8, 2500, '{"gold": 3000}', 'Catfish Hunter VIII', 'Catch 2500 catfish', 'fish.fill', 'fishing', 237),
    ('catch_catfish', 9, 5000, '{"gold": 4000}', 'Catfish Hunter IX', 'Catch 5000 catfish', 'fish.fill', 'fishing', 238),
    ('catch_catfish', 10, 10000, '{"gold": 5000}', 'Catfish Hunter X', 'Catch 10000 catfish', 'fish.fill', 'fishing', 239)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- Legendary Carp (icon: sparkles)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order)
VALUES
    ('catch_legendary_carp', 1, 3, '{"gold": 150}', 'Legend Finder I', 'Catch 3 legendary carp', 'sparkles', 'fishing', 240),
    ('catch_legendary_carp', 2, 5, '{"gold": 250}', 'Legend Finder II', 'Catch 5 legendary carp', 'sparkles', 'fishing', 241),
    ('catch_legendary_carp', 3, 10, '{"gold": 400}', 'Legend Finder III', 'Catch 10 legendary carp', 'sparkles', 'fishing', 242),
    ('catch_legendary_carp', 4, 25, '{"gold": 600}', 'Legend Finder IV', 'Catch 25 legendary carp', 'sparkles', 'fishing', 243),
    ('catch_legendary_carp', 5, 50, '{"gold": 1000}', 'Legend Finder V', 'Catch 50 legendary carp', 'sparkles', 'fishing', 244),
    ('catch_legendary_carp', 6, 100, '{"gold": 1500}', 'Legend Finder VI', 'Catch 100 legendary carp', 'sparkles', 'fishing', 245),
    ('catch_legendary_carp', 7, 250, '{"gold": 2000}', 'Legend Finder VII', 'Catch 250 legendary carp', 'sparkles', 'fishing', 246),
    ('catch_legendary_carp', 8, 500, '{"gold": 3000}', 'Legend Finder VIII', 'Catch 500 legendary carp', 'sparkles', 'fishing', 247),
    ('catch_legendary_carp', 9, 1000, '{"gold": 4000}', 'Legend Finder IX', 'Catch 1000 legendary carp', 'sparkles', 'fishing', 248),
    ('catch_legendary_carp', 10, 2500, '{"gold": 5000}', 'Legend Finder X', 'Catch 2500 legendary carp', 'sparkles', 'fishing', 249)
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order;

-- =====================================================
-- FISHING ACHIEVEMENTS - General Fishing
-- =====================================================

INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('fish_caught', 1, 250, '{"gold": 50}', 'Novice Angler', 'Catch 250 fish', 'fish.fill', 'fishing', 250, 'Total fish caught (any type)'),
    ('fish_caught', 2, 500, '{"gold": 100}', 'Skilled Angler', 'Catch 500 fish', 'fish.fill', 'fishing', 251, 'Total fish caught (any type)'),
    ('fish_caught', 3, 1000, '{"gold": 200}', 'Expert Angler', 'Catch 1000 fish', 'fish.fill', 'fishing', 252, 'Total fish caught (any type)'),
    ('fish_caught', 4, 2500, '{"gold": 500}', 'Master Angler', 'Catch 2500 fish', 'fish.fill', 'fishing', 253, 'Total fish caught (any type)'),
    ('fish_caught', 5, 5000, '{"gold": 1000}', 'Veteran Angler', 'Catch 5000 fish', 'fish.fill', 'fishing', 254, 'Total fish caught (any type)'),
    ('fish_caught', 6, 10000, '{"gold": 2500}', 'Legendary Angler', 'Catch 10000 fish', 'fish.fill', 'fishing', 255, 'Total fish caught (any type)'),
    ('fish_caught', 7, 25000, '{"gold": 3500}', 'Mythic Angler', 'Catch 25000 fish', 'fish.fill', 'fishing', 256, 'Total fish caught (any type)'),
    ('fish_caught', 8, 50000, '{"gold": 5000}', 'Eternal Angler', 'Catch 50000 fish', 'fish.fill', 'fishing', 257, 'Total fish caught (any type)')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Pet Fish
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('pet_fish_caught', 1, 1, '{"gold": 500}', 'Lucky Fisher', 'Catch a pet fish', 'star.fill', 'fishing', 260, 'Get the Pet Fish')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- FORAGING ACHIEVEMENTS
-- =====================================================

INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('foraging_completed', 1, 250, '{"gold": 50}', 'Berry Picker I', 'Complete 250 foraging sessions', 'leaf.fill', 'foraging', 300, 'Total foraging sessions'),
    ('foraging_completed', 2, 500, '{"gold": 100}', 'Berry Picker II', 'Complete 500 foraging sessions', 'leaf.fill', 'foraging', 301, 'Total foraging sessions'),
    ('foraging_completed', 3, 1000, '{"gold": 200}', 'Berry Picker III', 'Complete 1000 foraging sessions', 'leaf.fill', 'foraging', 302, 'Total foraging sessions'),
    ('foraging_completed', 4, 2500, '{"gold": 500}', 'Berry Picker IV', 'Complete 2500 foraging sessions', 'leaf.fill', 'foraging', 303, 'Total foraging sessions'),
    ('foraging_completed', 5, 5000, '{"gold": 1000}', 'Berry Picker V', 'Complete 5000 foraging sessions', 'leaf.fill', 'foraging', 304, 'Total foraging sessions'),
    ('foraging_completed', 6, 10000, '{"gold": 2500}', 'Berry Picker VI', 'Complete 10000 foraging sessions', 'leaf.fill', 'foraging', 305, 'Total foraging sessions'),
    ('foraging_completed', 7, 25000, '{"gold": 5000}', 'Berry Picker VII', 'Complete 25000 foraging sessions', 'leaf.fill', 'foraging', 306, 'Total foraging sessions')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Rare Egg Finds (icon: oval.fill)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('find_rare_egg', 1, 1, '{"gold": 100}', 'Egg Hunter I', 'Find 1 rare egg', 'oval.fill', 'foraging', 310, 'Rare eggs found while foraging'),
    ('find_rare_egg', 2, 4, '{"gold": 250}', 'Egg Hunter II', 'Find 4 rare eggs', 'oval.fill', 'foraging', 311, 'Rare eggs found while foraging'),
    ('find_rare_egg', 3, 8, '{"gold": 500}', 'Egg Hunter III', 'Find 8 rare eggs', 'oval.fill', 'foraging', 312, 'Rare eggs found while foraging'),
    ('find_rare_egg', 4, 16, '{"gold": 750}', 'Egg Hunter IV', 'Find 16 rare eggs', 'oval.fill', 'foraging', 313, 'Rare eggs found while foraging'),
    ('find_rare_egg', 5, 32, '{"gold": 1250}', 'Egg Hunter V', 'Find 32 rare eggs', 'oval.fill', 'foraging', 314, 'Rare eggs found while foraging')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- MERCHANT ACHIEVEMENTS
-- =====================================================

-- Direct Trades (player to player)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('direct_trades', 1, 25, '{"gold": 50}', 'Trader I', 'Complete 25 direct trades', 'arrow.left.arrow.right', 'merchant', 350, 'Direct trades completed'),
    ('direct_trades', 2, 100, '{"gold": 150}', 'Trader II', 'Complete 100 direct trades', 'arrow.left.arrow.right', 'merchant', 351, 'Direct trades completed'),
    ('direct_trades', 3, 250, '{"gold": 300}', 'Trader III', 'Complete 250 direct trades', 'arrow.left.arrow.right', 'merchant', 352, 'Direct trades completed'),
    ('direct_trades', 4, 500, '{"gold": 750}', 'Trader IV', 'Complete 500 direct trades', 'arrow.left.arrow.right', 'merchant', 353, 'Direct trades completed'),
    ('direct_trades', 5, 1000, '{"gold": 1500}', 'Trader V', 'Complete 1000 direct trades', 'arrow.left.arrow.right', 'merchant', 354, 'Direct trades completed'),
    ('direct_trades', 6, 2500, '{"gold": 5000}', 'Master Trader', 'Complete 2500 direct trades', 'arrow.left.arrow.right', 'merchant', 355, 'Direct trades completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Market Trades
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('market_trades', 1, 50, '{"gold": 50}', 'Market Trader I', 'Complete 50 market trades', 'storefront.fill', 'merchant', 360, 'Market trades completed'),
    ('market_trades', 2, 250, '{"gold": 150}', 'Market Trader II', 'Complete 250 market trades', 'storefront.fill', 'merchant', 361, 'Market trades completed'),
    ('market_trades', 3, 500, '{"gold": 300}', 'Market Trader III', 'Complete 500 market trades', 'storefront.fill', 'merchant', 362, 'Market trades completed'),
    ('market_trades', 4, 1000, '{"gold": 750}', 'Market Trader IV', 'Complete 1000 market trades', 'storefront.fill', 'merchant', 363, 'Market trades completed'),
    ('market_trades', 5, 2500, '{"gold": 1500}', 'Market Trader V', 'Complete 2500 market trades', 'storefront.fill', 'merchant', 364, 'Market trades completed'),
    ('market_trades', 6, 5000, '{"gold": 5000}', 'Exchange Tycoon', 'Complete 5000 market trades', 'storefront.fill', 'merchant', 365, 'Market trades completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- BUILDING ACHIEVEMENTS
-- =====================================================

-- Building Contracts
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('building_contracts', 1, 100, '{"gold": 50}', 'Community Builder I', 'Complete 100 building contracts', 'building.2.fill', 'building', 370, 'Building contracts completed'),
    ('building_contracts', 2, 500, '{"gold": 100}', 'Community Builder II', 'Complete 500 building contracts', 'building.2.fill', 'building', 371, 'Building contracts completed'),
    ('building_contracts', 3, 1000, '{"gold": 200}', 'Community Builder III', 'Complete 1000 building contracts', 'building.2.fill', 'building', 372, 'Building contracts completed'),
    ('building_contracts', 4, 2500, '{"gold": 500}', 'Community Builder IV', 'Complete 2500 building contracts', 'building.2.fill', 'building', 373, 'Building contracts completed'),
    ('building_contracts', 5, 5000, '{"gold": 1000}', 'Community Builder V', 'Complete 5000 building contracts', 'building.2.fill', 'building', 374, 'Building contracts completed'),
    ('building_contracts', 6, 10000, '{"gold": 2500}', 'Community Builder VI', 'Complete 10000 building contracts', 'building.2.fill', 'building', 375, 'Building contracts completed'),
    ('building_contracts', 7, 25000, '{"gold": 5000}', 'Master Community Builder', 'Complete 25000 building contracts', 'building.2.fill', 'building', 376, 'Building contracts completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- TRAINING ACHIEVEMENTS
-- =====================================================

-- Training Contracts
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('training_contracts', 1, 25, '{"gold": 50}', 'Erudite I', 'Complete 25 training sessions', 'figure.strengthtraining.traditional', 'training', 380, 'Training sessions completed'),
    ('training_contracts', 2, 100, '{"gold": 100}', 'Erudite II', 'Complete 100 training sessions', 'figure.strengthtraining.traditional', 'training', 381, 'Training sessions completed'),
    ('training_contracts', 3, 250, '{"gold": 200}', 'Erudite III', 'Complete 250 training sessions', 'figure.strengthtraining.traditional', 'training', 382, 'Training sessions completed'),
    ('training_contracts', 4, 500, '{"gold": 500}', 'Erudite IV', 'Complete 500 training sessions', 'figure.strengthtraining.traditional', 'training', 383, 'Training sessions completed'),
    ('training_contracts', 5, 1000, '{"gold": 1000}', 'Erudite V', 'Complete 1000 training sessions', 'figure.strengthtraining.traditional', 'training', 384, 'Training sessions completed'),
    ('training_contracts', 6, 2500, '{"gold": 2500}', 'Master Erudite', 'Complete 2500 training sessions', 'figure.strengthtraining.traditional', 'training', 385, 'Training sessions completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- LEVEL ACHIEVEMENTS
-- =====================================================

-- Experiments Completed
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('experiments_completed', 1, 10, '{"gold": 50}', 'Scientist I', 'Complete 10 experiments', 'flask.fill', 'science', 400, 'Experiments completed'),
    ('experiments_completed', 2, 50, '{"gold": 100}', 'Scientist II', 'Complete 50 experiments', 'flask.fill', 'science', 401, 'Experiments completed'),
    ('experiments_completed', 3, 100, '{"gold": 200}', 'Scientist III', 'Complete 100 experiments', 'flask.fill', 'science', 402, 'Experiments completed'),
    ('experiments_completed', 4, 250, '{"gold": 500}', 'Scientist IV', 'Complete 250 experiments', 'flask.fill', 'science', 403, 'Experiments completed'),
    ('experiments_completed', 5, 500, '{"gold": 1000}', 'Scientist V', 'Complete 500 experiments', 'flask.fill', 'science', 404, 'Experiments completed'),
    ('experiments_completed', 6, 1000, '{"gold": 2500}', 'Mad Scientist', 'Complete 1000 experiments', 'flask.fill', 'science', 405, 'Experiments completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Blueprints Earned
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('blueprints_earned', 1, 5, '{"gold": 100}', 'Inventor I', 'Earn 5 blueprints', 'doc.text.fill', 'science', 410, 'Blueprints discovered'),
    ('blueprints_earned', 2, 15, '{"gold": 200}', 'Inventor II', 'Earn 15 blueprints', 'doc.text.fill', 'science', 411, 'Blueprints discovered'),
    ('blueprints_earned', 3, 30, '{"gold": 400}', 'Inventor III', 'Earn 30 blueprints', 'doc.text.fill', 'science', 412, 'Blueprints discovered'),
    ('blueprints_earned', 4, 50, '{"gold": 800}', 'Inventor IV', 'Earn 50 blueprints', 'doc.text.fill', 'science', 413, 'Blueprints discovered'),
    ('blueprints_earned', 5, 100, '{"gold": 2000}', 'Inventor V', 'Earn 100 blueprints', 'doc.text.fill', 'science', 414, 'Blueprints discovered')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- GATHERING ACHIEVEMENTS
-- =====================================================

-- Wood Chopped
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('wood_gathered', 1, 500, '{"gold": 25}', 'Woodcutter I', 'Gather 500 wood', 'leaf.fill', 'gathering', 420, 'Wood gathered'),
    ('wood_gathered', 2, 2500, '{"gold": 50}', 'Woodcutter II', 'Gather 2500 wood', 'leaf.fill', 'gathering', 421, 'Wood gathered'),
    ('wood_gathered', 3, 5000, '{"gold": 100}', 'Woodcutter III', 'Gather 5000 wood', 'leaf.fill', 'gathering', 422, 'Wood gathered'),
    ('wood_gathered', 4, 10000, '{"gold": 200}', 'Woodcutter IV', 'Gather 10000 wood', 'leaf.fill', 'gathering', 423, 'Wood gathered'),
    ('wood_gathered', 5, 25000, '{"gold": 500}', 'Woodcutter V', 'Gather 25000 wood', 'leaf.fill', 'gathering', 424, 'Wood gathered'),
    ('wood_gathered', 6, 50000, '{"gold": 1000}', 'Woodcutter VI', 'Gather 50000 wood', 'leaf.fill', 'gathering', 425, 'Wood gathered'),
    ('wood_gathered', 7, 100000, '{"gold": 2500}', 'Lumberjack', 'Gather 100000 wood', 'leaf.fill', 'gathering', 426, 'Wood gathered')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Iron Mined
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('iron_gathered', 1, 500, '{"gold": 25}', 'Miner I', 'Gather 500 iron', 'cube.fill', 'gathering', 430, 'Iron gathered'),
    ('iron_gathered', 2, 2500, '{"gold": 50}', 'Miner II', 'Gather 2500 iron', 'cube.fill', 'gathering', 431, 'Iron gathered'),
    ('iron_gathered', 3, 5000, '{"gold": 100}', 'Miner III', 'Gather 5000 iron', 'cube.fill', 'gathering', 432, 'Iron gathered'),
    ('iron_gathered', 4, 10000, '{"gold": 200}', 'Miner IV', 'Gather 10000 iron', 'cube.fill', 'gathering', 433, 'Iron gathered'),
    ('iron_gathered', 5, 25000, '{"gold": 500}', 'Miner V', 'Gather 25000 iron', 'cube.fill', 'gathering', 434, 'Iron gathered'),
    ('iron_gathered', 6, 50000, '{"gold": 1000}', 'Miner VI', 'Gather 50000 iron', 'cube.fill', 'gathering', 435, 'Iron gathered'),
    ('iron_gathered', 7, 100000, '{"gold": 2500}', 'Master Miner', 'Gather 100000 iron', 'cube.fill', 'gathering', 436, 'Iron gathered')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- CRAFTING ACHIEVEMENTS
-- =====================================================

-- Items Crafted (Total)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('items_crafted', 1, 100, '{"gold": 50}', 'Apprentice Smith I', 'Craft 100 items', 'hammer.fill', 'crafting', 400, 'Total items crafted'),
    ('items_crafted', 2, 500, '{"gold": 200}', 'Apprentice Smith II', 'Craft 500 items', 'hammer.fill', 'crafting', 401, 'Total items crafted'),
    ('items_crafted', 3, 1000, '{"gold": 500}', 'Journeyman Smith', 'Craft 1000 items', 'hammer.fill', 'crafting', 402, 'Total items crafted'),
    ('items_crafted', 4, 2500, '{"gold": 1000}', 'Expert Smith', 'Craft 2500 items', 'hammer.fill', 'crafting', 403, 'Total items crafted'),
    ('items_crafted', 5, 5000, '{"gold": 2000}', 'Master Smith', 'Craft 5000 items', 'hammer.fill', 'crafting', 404, 'Total items crafted'),
    ('items_crafted', 6, 10000, '{"gold": 4000}', 'Veteran Smith', 'Craft 10000 items', 'hammer.fill', 'crafting', 405, 'Total items crafted'),
    ('items_crafted', 7, 25000, '{"gold": 10000}', 'Legendary Smith', 'Craft 25000 items', 'hammer.fill', 'crafting', 406, 'Total items crafted')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Weapons Crafted
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('weapons_crafted', 1, 25, '{"gold": 50}', 'Blade Forger I', 'Craft 25 weapons', 'wrench.and.screwdriver', 'crafting', 410, 'Weapons crafted'),
    ('weapons_crafted', 2, 50, '{"gold": 100}', 'Blade Forger II', 'Craft 50 weapons', 'wrench.and.screwdriver', 'crafting', 411, 'Weapons crafted'),
    ('weapons_crafted', 3, 100, '{"gold": 200}', 'Blade Forger III', 'Craft 100 weapons', 'wrench.and.screwdriver', 'crafting', 412, 'Weapons crafted'),
    ('weapons_crafted', 4, 250, '{"gold": 500}', 'Blade Forger IV', 'Craft 250 weapons', 'wrench.and.screwdriver', 'crafting', 413, 'Weapons crafted'),
    ('weapons_crafted', 5, 500, '{"gold": 1000}', 'Blade Forger V', 'Craft 500 weapons', 'wrench.and.screwdriver', 'crafting', 414, 'Weapons crafted'),
    ('weapons_crafted', 6, 1000, '{"gold": 2500}', 'Blade Forger VI', 'Craft 1000 weapons', 'wrench.and.screwdriver', 'crafting', 415, 'Weapons crafted')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Armor Crafted
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('armor_crafted', 1, 25, '{"gold": 50}', 'Armor Smith I', 'Craft 25 armor pieces', 'shield.fill', 'crafting', 420, 'Armor crafted'),
    ('armor_crafted', 2, 50, '{"gold": 100}', 'Armor Smith II', 'Craft 50 armor pieces', 'shield.fill', 'crafting', 421, 'Armor crafted'),
    ('armor_crafted', 3, 100, '{"gold": 200}', 'Armor Smith III', 'Craft 100 armor pieces', 'shield.fill', 'crafting', 422, 'Armor crafted'),
    ('armor_crafted', 4, 250, '{"gold": 500}', 'Armor Smith IV', 'Craft 250 armor pieces', 'shield.fill', 'crafting', 423, 'Armor crafted'),
    ('armor_crafted', 5, 500, '{"gold": 1000}', 'Armor Smith V', 'Craft 500 armor pieces', 'shield.fill', 'crafting', 424, 'Armor crafted'),
    ('armor_crafted', 6, 1000, '{"gold": 2500}', 'Armor Smith VI', 'Craft 1000 armor pieces', 'shield.fill', 'crafting', 425, 'Armor crafted')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Tier 5 Items Crafted
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('craft_tier_5_item', 1, 1, '{"gold": 150}', 'Master Craftsman I', 'Craft 1 Tier 5 item', 'star.fill', 'crafting', 430, 'Tier 5 items crafted'),
    ('craft_tier_5_item', 2, 5, '{"gold": 300}', 'Master Craftsman II', 'Craft 5 Tier 5 items', 'star.fill', 'crafting', 431, 'Tier 5 items crafted'),
    ('craft_tier_5_item', 3, 10, '{"gold": 600}', 'Master Craftsman III', 'Craft 10 Tier 5 items', 'star.fill', 'crafting', 432, 'Tier 5 items crafted'),
    ('craft_tier_5_item', 4, 25, '{"gold": 1500}', 'Master Craftsman IV', 'Craft 25 Tier 5 items', 'star.fill', 'crafting', 433, 'Tier 5 items crafted'),
    ('craft_tier_5_item', 5, 50, '{"gold": 3000}', 'Master Craftsman V', 'Craft 50 Tier 5 items', 'star.fill', 'crafting', 434, 'Tier 5 items crafted')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- PROPERTIES ACHIEVEMENTS
-- =====================================================

-- Kingdoms with Properties (Monopoly)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('kingdoms_with_properties', 1, 1, '{"gold": 50}', 'Monopoly I', 'Own property in 1 kingdom', 'house.fill', 'properties', 960, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 2, 2, '{"gold": 100}', 'Monopoly II', 'Own property in 2 kingdoms', 'house.fill', 'properties', 961, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 3, 3, '{"gold": 200}', 'Monopoly III', 'Own property in 3 kingdoms', 'house.fill', 'properties', 962, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 4, 4, '{"gold": 300}', 'Monopoly IV', 'Own property in 4 kingdoms', 'house.fill', 'properties', 963, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 5, 5, '{"gold": 500}', 'Monopoly V', 'Own property in 5 kingdoms', 'house.fill', 'properties', 964, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 6, 6, '{"gold": 750}', 'Monopoly VI', 'Own property in 6 kingdoms', 'house.fill', 'properties', 965, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 7, 7, '{"gold": 1000}', 'Monopoly VII', 'Own property in 7 kingdoms', 'house.fill', 'properties', 966, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 8, 8, '{"gold": 1500}', 'Monopoly VIII', 'Own property in 8 kingdoms', 'house.fill', 'properties', 967, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 9, 9, '{"gold": 2000}', 'Monopoly IX', 'Own property in 9 kingdoms', 'house.fill', 'properties', 968, 'Kingdoms with properties'),
    ('kingdoms_with_properties', 10, 10, '{"gold": 3000}', 'Monopoly X', 'Own property in 10 kingdoms', 'house.fill', 'properties', 969, 'Kingdoms with properties')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Items Sacrificed (Fortification)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('items_sacrificed', 1, 10, '{"gold": 75}', 'Proud Homeowner I', 'Convert 10 items to fortify', 'brick.fill', 'properties', 970, 'Items converted for fortification'),
    ('items_sacrificed', 2, 25, '{"gold": 150}', 'Proud Homeowner II', 'Convert 25 items to fortify', 'brick.fill', 'properties', 971, 'Items converted for fortification'),
    ('items_sacrificed', 3, 50, '{"gold": 300}', 'Proud Homeowner III', 'Convert 50 items to fortify', 'brick.fill', 'properties', 972, 'Items converted for fortification'),
    ('items_sacrificed', 4, 100, '{"gold": 600}', 'Proud Homeowner IV', 'Convert 100 items to fortify', 'brick.fill', 'properties', 973, 'Items converted for fortification'),
    ('items_sacrificed', 5, 250, '{"gold": 1500}', 'Proud Homeowner V', 'Convert 250 items to fortify', 'brick.fill', 'properties', 974, 'Items converted for fortification'),
    ('items_sacrificed', 6, 500, '{"gold": 3000}', 'Proud Homeowner VI', 'Convert 500 items to fortify', 'brick.fill', 'properties', 975, 'Items converted for fortification')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Max Fortification
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('max_fortification', 1, 1, '{"gold": 250}', 'Fortress Builder I', 'Reach 100% fortification on property', 'building.columns.fill', 'properties', 980, 'Properties at max fortification')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- RULER ACHIEVEMENTS
-- =====================================================

-- Empire Size
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('empire_size', 1, 1, '{"gold": 100}', 'First Crown', 'Become a ruler', 'crown.fill', 'ruler', 560, 'Kingdoms in empire'),
    ('empire_size', 2, 2, '{"gold": 500}', 'Dual Ruler', '2 kingdoms in empire', 'map.fill', 'ruler', 561, 'Kingdoms in empire'),
    ('empire_size', 3, 3, '{"gold": 1000}', 'Triple Crown', '3 kingdoms in empire', 'map.fill', 'ruler', 562, 'Kingdoms in empire'),
    ('empire_size', 4, 5, '{"gold": 2500}', 'Emperor', '5 kingdoms in empire', 'map.fill', 'ruler', 563, 'Kingdoms in empire'),
    ('empire_size', 5, 7, '{"gold": 5000}', 'High Emperor', '7 kingdoms in empire', 'map.fill', 'ruler', 564, 'Kingdoms in empire'),
    ('empire_size', 6, 10, '{"gold": 10000}', 'World Conqueror', '10 kingdoms in empire', 'map.fill', 'ruler', 565, 'Kingdoms in empire')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Treasury Collected
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('treasury_collected', 1, 1000, '{"gold": 50}', 'Tax Collector I', 'Collect 1,000g in taxes', 'banknote.fill', 'ruler', 570, 'Total taxes collected'),
    ('treasury_collected', 2, 5000, '{"gold": 100}', 'Tax Collector II', 'Collect 5,000g in taxes', 'banknote.fill', 'ruler', 571, 'Total taxes collected'),
    ('treasury_collected', 3, 25000, '{"gold": 250}', 'Tax Collector III', 'Collect 25,000g in taxes', 'banknote.fill', 'ruler', 572, 'Total taxes collected'),
    ('treasury_collected', 4, 100000, '{"gold": 500}', 'Tax Collector IV', 'Collect 100,000g in taxes', 'banknote.fill', 'ruler', 573, 'Total taxes collected'),
    ('treasury_collected', 5, 500000, '{"gold": 1000}', 'Tax Collector V', 'Collect 500,000g in taxes', 'banknote.fill', 'ruler', 574, 'Total taxes collected'),
    ('treasury_collected', 6, 1000000, '{"gold": 2500}', 'Master Treasurer', 'Collect 1,000,000g in taxes', 'banknote.fill', 'ruler', 575, 'Total taxes collected')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- COUP ACHIEVEMENTS
-- =====================================================

-- Coups Initiated
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('coups_initiated', 1, 1, '{"gold": 100}', 'Schemer I', 'Initiate 1 coup', 'theatermasks.fill', 'coup', 600, 'Coups initiated'),
    ('coups_initiated', 2, 3, '{"gold": 200}', 'Schemer II', 'Initiate 3 coups', 'theatermasks.fill', 'coup', 601, 'Coups initiated')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Coups Won
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('coups_won', 1, 1, '{"gold": 150}', 'Usurper I', 'Win 1 coup', 'bolt.fill', 'coup', 610, 'Successful coups'),
    ('coups_won', 2, 3, '{"gold": 300}', 'Usurper II', 'Win 3 coups', 'bolt.fill', 'coup', 611, 'Successful coups'),
    ('coups_won', 3, 5, '{"gold": 600}', 'Usurper III', 'Win 5 coups', 'bolt.fill', 'coup', 612, 'Successful coups'),
    ('coups_won', 4, 10, '{"gold": 1500}', 'Usurper IV', 'Win 10 coups', 'bolt.fill', 'coup', 613, 'Successful coups'),
    ('coups_won', 5, 25, '{"gold": 3000}', 'Kingslayer', 'Win 25 coups', 'bolt.fill', 'coup', 614, 'Successful coups')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- INVASION & BATTLE ACHIEVEMENTS
-- =====================================================

-- Invasions Participated
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('invasions_participated', 1, 1, '{"gold": 50}', 'Warrior I', 'Participate in 1 invasion', 'figure.walk', 'battle', 650, 'Invasions participated in'),
    ('invasions_participated', 2, 5, '{"gold": 100}', 'Warrior II', 'Participate in 5 invasions', 'figure.walk', 'battle', 651, 'Invasions participated in'),
    ('invasions_participated', 3, 15, '{"gold": 200}', 'Warrior III', 'Participate in 15 invasions', 'figure.walk', 'battle', 652, 'Invasions participated in'),
    ('invasions_participated', 4, 30, '{"gold": 500}', 'Warrior IV', 'Participate in 30 invasions', 'figure.walk', 'battle', 653, 'Invasions participated in'),
    ('invasions_participated', 5, 50, '{"gold": 1000}', 'Warrior V', 'Participate in 50 invasions', 'figure.walk', 'battle', 654, 'Invasions participated in'),
    ('invasions_participated', 6, 100, '{"gold": 2500}', 'Veteran', 'Participate in 100 invasions', 'figure.walk', 'battle', 655, 'Invasions participated in')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Invasions Won (Attacker)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('invasions_won_attack', 1, 1, '{"gold": 150}', 'Conqueror I', 'Win 1 invasion as attacker', 'flag.fill', 'battle', 660, 'Invasions won as attacker'),
    ('invasions_won_attack', 2, 3, '{"gold": 300}', 'Conqueror II', 'Win 3 invasions as attacker', 'flag.fill', 'battle', 661, 'Invasions won as attacker'),
    ('invasions_won_attack', 3, 10, '{"gold": 600}', 'Conqueror III', 'Win 10 invasions as attacker', 'flag.fill', 'battle', 662, 'Invasions won as attacker'),
    ('invasions_won_attack', 4, 25, '{"gold": 1500}', 'Conqueror IV', 'Win 25 invasions as attacker', 'flag.fill', 'battle', 663, 'Invasions won as attacker')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Invasions Won (Defender)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('invasions_won_defend', 1, 1, '{"gold": 150}', 'Defender I', 'Defend 1 invasion successfully', 'shield.checkered', 'battle', 670, 'Invasions defended'),
    ('invasions_won_defend', 2, 3, '{"gold": 300}', 'Defender II', 'Defend 3 invasions successfully', 'shield.checkered', 'battle', 671, 'Invasions defended'),
    ('invasions_won_defend', 3, 10, '{"gold": 600}', 'Defender III', 'Defend 10 invasions successfully', 'shield.checkered', 'battle', 672, 'Invasions defended'),
    ('invasions_won_defend', 4, 25, '{"gold": 1500}', 'Defender IV', 'Defend 25 invasions successfully', 'shield.checkered', 'battle', 673, 'Invasions defended'),
    ('invasions_won_defend', 5, 50, '{"gold": 3000}', 'Legendary Defender', 'Defend 50 invasions successfully', 'shield.checkered', 'battle', 674, 'Invasions defended')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- PVP ACHIEVEMENTS
-- =====================================================

-- Duels Fought
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('duels_fought', 1, 10, '{"gold": 25}', 'Duelist I', 'Fight 10 duels', 'figure.fencing', 'pvp', 700, 'Total duels fought'),
    ('duels_fought', 2, 50, '{"gold": 50}', 'Duelist II', 'Fight 50 duels', 'figure.fencing', 'pvp', 701, 'Total duels fought'),
    ('duels_fought', 3, 100, '{"gold": 100}', 'Duelist III', 'Fight 100 duels', 'figure.fencing', 'pvp', 702, 'Total duels fought'),
    ('duels_fought', 4, 250, '{"gold": 200}', 'Duelist IV', 'Fight 250 duels', 'figure.fencing', 'pvp', 703, 'Total duels fought'),
    ('duels_fought', 5, 500, '{"gold": 500}', 'Duelist V', 'Fight 500 duels', 'figure.fencing', 'pvp', 704, 'Total duels fought'),
    ('duels_fought', 6, 1000, '{"gold": 1000}', 'Duelist VI', 'Fight 1000 duels', 'figure.fencing', 'pvp', 705, 'Total duels fought'),
    ('duels_fought', 7, 2500, '{"gold": 2500}', 'Arena Legend', 'Fight 2500 duels', 'figure.fencing', 'pvp', 706, 'Total duels fought')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Duels Won
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('duels_won', 1, 5, '{"gold": 25}', 'Victor I', 'Win 5 duels', 'trophy.fill', 'pvp', 710, 'Duels won'),
    ('duels_won', 2, 25, '{"gold": 50}', 'Victor II', 'Win 25 duels', 'trophy.fill', 'pvp', 711, 'Duels won'),
    ('duels_won', 3, 50, '{"gold": 100}', 'Victor III', 'Win 50 duels', 'trophy.fill', 'pvp', 712, 'Duels won'),
    ('duels_won', 4, 100, '{"gold": 200}', 'Victor IV', 'Win 100 duels', 'trophy.fill', 'pvp', 713, 'Duels won'),
    ('duels_won', 5, 250, '{"gold": 500}', 'Victor V', 'Win 250 duels', 'trophy.fill', 'pvp', 714, 'Duels won'),
    ('duels_won', 6, 500, '{"gold": 1000}', 'Victor VI', 'Win 500 duels', 'trophy.fill', 'pvp', 715, 'Duels won'),
    ('duels_won', 7, 1000, '{"gold": 2500}', 'Grand Champion', 'Win 1000 duels', 'trophy.fill', 'pvp', 716, 'Duels won')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- INTELLIGENCE ACHIEVEMENTS
-- =====================================================

-- Operations Attempted
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('operations_attempted', 1, 10, '{"gold": 25}', 'Spy I', 'Attempt 10 infiltrations', 'eye.fill', 'intelligence', 800, 'Infiltration attempts'),
    ('operations_attempted', 2, 25, '{"gold": 50}', 'Spy II', 'Attempt 25 infiltrations', 'eye.fill', 'intelligence', 801, 'Infiltration attempts'),
    ('operations_attempted', 3, 50, '{"gold": 100}', 'Spy III', 'Attempt 50 infiltrations', 'eye.fill', 'intelligence', 802, 'Infiltration attempts'),
    ('operations_attempted', 4, 100, '{"gold": 200}', 'Spy IV', 'Attempt 100 infiltrations', 'eye.fill', 'intelligence', 803, 'Infiltration attempts'),
    ('operations_attempted', 5, 250, '{"gold": 500}', 'Spy V', 'Attempt 250 infiltrations', 'eye.fill', 'intelligence', 804, 'Infiltration attempts'),
    ('operations_attempted', 6, 500, '{"gold": 1000}', 'Spy VI', 'Attempt 500 infiltrations', 'eye.fill', 'intelligence', 805, 'Infiltration attempts'),
    ('operations_attempted', 7, 1000, '{"gold": 2500}', 'Spymaster', 'Attempt 1000 infiltrations', 'eye.fill', 'intelligence', 806, 'Infiltration attempts')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Intel Gathered
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('intel_gathered', 1, 5, '{"gold": 50}', 'Intel Collector I', 'Gather intel 5 times', 'doc.text.magnifyingglass', 'intelligence', 810, 'Intel gathered'),
    ('intel_gathered', 2, 15, '{"gold": 100}', 'Intel Collector II', 'Gather intel 15 times', 'doc.text.magnifyingglass', 'intelligence', 811, 'Intel gathered'),
    ('intel_gathered', 3, 30, '{"gold": 200}', 'Intel Collector III', 'Gather intel 30 times', 'doc.text.magnifyingglass', 'intelligence', 812, 'Intel gathered'),
    ('intel_gathered', 4, 75, '{"gold": 500}', 'Intel Collector IV', 'Gather intel 75 times', 'doc.text.magnifyingglass', 'intelligence', 813, 'Intel gathered'),
    ('intel_gathered', 5, 150, '{"gold": 1000}', 'Intel Collector V', 'Gather intel 150 times', 'doc.text.magnifyingglass', 'intelligence', 814, 'Intel gathered'),
    ('intel_gathered', 6, 300, '{"gold": 2500}', 'Intelligence Director', 'Gather intel 300 times', 'doc.text.magnifyingglass', 'intelligence', 815, 'Intel gathered')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Sabotages Completed
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('sabotages_completed', 1, 1, '{"gold": 150}', 'Saboteur I', 'Complete 1 sabotage', 'wrench.and.screwdriver.fill', 'intelligence', 820, 'Sabotages completed'),
    ('sabotages_completed', 2, 5, '{"gold": 300}', 'Saboteur II', 'Complete 5 sabotages', 'wrench.and.screwdriver.fill', 'intelligence', 821, 'Sabotages completed'),
    ('sabotages_completed', 3, 10, '{"gold": 600}', 'Saboteur III', 'Complete 10 sabotages', 'wrench.and.screwdriver.fill', 'intelligence', 822, 'Sabotages completed'),
    ('sabotages_completed', 4, 25, '{"gold": 1500}', 'Saboteur IV', 'Complete 25 sabotages', 'wrench.and.screwdriver.fill', 'intelligence', 823, 'Sabotages completed'),
    ('sabotages_completed', 5, 50, '{"gold": 3000}', 'Master Saboteur', 'Complete 50 sabotages', 'wrench.and.screwdriver.fill', 'intelligence', 824, 'Sabotages completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Vault Heists
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('heists_completed', 1, 1, '{"gold": 150}', 'Thief I', 'Complete 1 vault heist', 'dollarsign.circle.fill', 'intelligence', 830, 'Vault heists completed'),
    ('heists_completed', 2, 3, '{"gold": 300}', 'Thief II', 'Complete 3 vault heists', 'dollarsign.circle.fill', 'intelligence', 831, 'Vault heists completed'),
    ('heists_completed', 3, 5, '{"gold": 600}', 'Thief III', 'Complete 5 vault heists', 'dollarsign.circle.fill', 'intelligence', 832, 'Vault heists completed'),
    ('heists_completed', 4, 10, '{"gold": 1500}', 'Thief IV', 'Complete 10 vault heists', 'dollarsign.circle.fill', 'intelligence', 833, 'Vault heists completed'),
    ('heists_completed', 5, 25, '{"gold": 3000}', 'Master Thief', 'Complete 25 vault heists', 'dollarsign.circle.fill', 'intelligence', 834, 'Vault heists completed')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- GARDENING ACHIEVEMENTS
-- =====================================================

-- Plants Grown
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('plants_grown', 1, 25, '{"gold": 25}', 'Gardener I', 'Grow 25 plants', 'leaf.fill', 'gardening', 850, 'Total plants grown'),
    ('plants_grown', 2, 100, '{"gold": 50}', 'Gardener II', 'Grow 100 plants', 'leaf.fill', 'gardening', 851, 'Total plants grown'),
    ('plants_grown', 3, 250, '{"gold": 100}', 'Gardener III', 'Grow 250 plants', 'leaf.fill', 'gardening', 852, 'Total plants grown'),
    ('plants_grown', 4, 500, '{"gold": 200}', 'Gardener IV', 'Grow 500 plants', 'leaf.fill', 'gardening', 853, 'Total plants grown'),
    ('plants_grown', 5, 1000, '{"gold": 500}', 'Gardener V', 'Grow 1000 plants', 'leaf.fill', 'gardening', 854, 'Total plants grown'),
    ('plants_grown', 6, 2500, '{"gold": 1000}', 'Gardener VI', 'Grow 2500 plants', 'leaf.fill', 'gardening', 855, 'Total plants grown'),
    ('plants_grown', 7, 5000, '{"gold": 2500}', 'Master Gardener', 'Grow 5000 plants', 'leaf.fill', 'gardening', 856, 'Total plants grown')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Flowers Grown
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('flowers_grown', 1, 10, '{"gold": 25}', 'Florist I', 'Grow 10 flowers', 'camera.macro', 'gardening', 860, 'Flowers grown'),
    ('flowers_grown', 2, 50, '{"gold": 50}', 'Florist II', 'Grow 50 flowers', 'camera.macro', 'gardening', 861, 'Flowers grown'),
    ('flowers_grown', 3, 150, '{"gold": 100}', 'Florist III', 'Grow 150 flowers', 'camera.macro', 'gardening', 862, 'Flowers grown'),
    ('flowers_grown', 4, 400, '{"gold": 200}', 'Florist IV', 'Grow 400 flowers', 'camera.macro', 'gardening', 863, 'Flowers grown'),
    ('flowers_grown', 5, 1000, '{"gold": 500}', 'Florist V', 'Grow 1000 flowers', 'camera.macro', 'gardening', 864, 'Flowers grown'),
    ('flowers_grown', 6, 2500, '{"gold": 1000}', 'Master Florist', 'Grow 2500 flowers', 'camera.macro', 'gardening', 865, 'Flowers grown')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Rare Flowers Grown
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('rare_flowers_grown', 1, 1, '{"gold": 100}', 'Rare Bloom I', 'Grow 1 rare flower', 'sparkle', 'gardening', 870, 'Rare flowers grown'),
    ('rare_flowers_grown', 2, 5, '{"gold": 200}', 'Rare Bloom II', 'Grow 5 rare flowers', 'sparkle', 'gardening', 871, 'Rare flowers grown'),
    ('rare_flowers_grown', 3, 15, '{"gold": 400}', 'Rare Bloom III', 'Grow 15 rare flowers', 'sparkle', 'gardening', 872, 'Rare flowers grown'),
    ('rare_flowers_grown', 4, 30, '{"gold": 800}', 'Rare Bloom IV', 'Grow 30 rare flowers', 'sparkle', 'gardening', 873, 'Rare flowers grown'),
    ('rare_flowers_grown', 5, 50, '{"gold": 1500}', 'Rare Bloom V', 'Grow 50 rare flowers', 'sparkle', 'gardening', 874, 'Rare flowers grown'),
    ('rare_flowers_grown', 6, 100, '{"gold": 3000}', 'Legendary Botanist', 'Grow 100 rare flowers', 'sparkle', 'gardening', 875, 'Rare flowers grown')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Wheat Harvested
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('wheat_harvested', 1, 50, '{"gold": 25}', 'Farmer I', 'Harvest 50 wheat', 'carrot.fill', 'gardening', 880, 'Wheat harvested'),
    ('wheat_harvested', 2, 200, '{"gold": 50}', 'Farmer II', 'Harvest 200 wheat', 'carrot.fill', 'gardening', 881, 'Wheat harvested'),
    ('wheat_harvested', 3, 500, '{"gold": 100}', 'Farmer III', 'Harvest 500 wheat', 'carrot.fill', 'gardening', 882, 'Wheat harvested'),
    ('wheat_harvested', 4, 1000, '{"gold": 200}', 'Farmer IV', 'Harvest 1000 wheat', 'carrot.fill', 'gardening', 883, 'Wheat harvested'),
    ('wheat_harvested', 5, 2500, '{"gold": 500}', 'Farmer V', 'Harvest 2500 wheat', 'carrot.fill', 'gardening', 884, 'Wheat harvested'),
    ('wheat_harvested', 6, 5000, '{"gold": 1000}', 'Master Farmer', 'Harvest 5000 wheat', 'carrot.fill', 'gardening', 885, 'Wheat harvested')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Weeds Cleared
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('weeds_cleared', 1, 25, '{"gold": 25}', 'Weed Puller I', 'Clear 25 weeds', 'xmark.circle.fill', 'gardening', 890, 'Weeds cleared'),
    ('weeds_cleared', 2, 100, '{"gold": 50}', 'Weed Puller II', 'Clear 100 weeds', 'xmark.circle.fill', 'gardening', 891, 'Weeds cleared'),
    ('weeds_cleared', 3, 250, '{"gold": 100}', 'Weed Puller III', 'Clear 250 weeds', 'xmark.circle.fill', 'gardening', 892, 'Weeds cleared'),
    ('weeds_cleared', 4, 500, '{"gold": 200}', 'Weed Puller IV', 'Clear 500 weeds', 'xmark.circle.fill', 'gardening', 893, 'Weeds cleared'),
    ('weeds_cleared', 5, 1000, '{"gold": 500}', 'Weed Puller V', 'Clear 1000 weeds', 'xmark.circle.fill', 'gardening', 894, 'Weeds cleared')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Flower Colors Collected
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('flower_colors', 1, 3, '{"gold": 100}', 'Color Collector I', 'Collect 3 different flower colors', 'paintpalette.fill', 'gardening', 900, 'Unique flower colors'),
    ('flower_colors', 2, 6, '{"gold": 250}', 'Color Collector II', 'Collect 6 different flower colors', 'paintpalette.fill', 'gardening', 901, 'Unique flower colors'),
    ('flower_colors', 3, 10, '{"gold": 500}', 'Rainbow Garden', 'Collect all 10 flower colors', 'paintpalette.fill', 'gardening', 902, 'Unique flower colors')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- EXPLORATION ACHIEVEMENTS
-- =====================================================

-- Kingdoms Visited (World Traveler)
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('kingdoms_visited', 1, 5, '{"gold": 50}', 'World Traveler I', 'Visit 5 different kingdoms', 'map.fill', 'exploration', 950, 'Kingdoms visited'),
    ('kingdoms_visited', 2, 10, '{"gold": 100}', 'World Traveler II', 'Visit 10 different kingdoms', 'map.fill', 'exploration', 951, 'Kingdoms visited'),
    ('kingdoms_visited', 3, 25, '{"gold": 250}', 'World Traveler III', 'Visit 25 different kingdoms', 'map.fill', 'exploration', 952, 'Kingdoms visited'),
    ('kingdoms_visited', 4, 50, '{"gold": 500}', 'World Traveler IV', 'Visit 50 different kingdoms', 'map.fill', 'exploration', 953, 'Kingdoms visited'),
    ('kingdoms_visited', 5, 100, '{"gold": 1000}', 'World Traveler V', 'Visit 100 different kingdoms', 'map.fill', 'exploration', 954, 'Kingdoms visited'),
    ('kingdoms_visited', 6, 250, '{"gold": 2500}', 'Globe Trotter', 'Visit 250 different kingdoms', 'map.fill', 'exploration', 955, 'Kingdoms visited')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Check-ins
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('checkins_completed', 1, 50, '{"gold": 50}', 'I Was Here', 'Check in 50 times', 'location.circle.fill', 'exploration', 1010, 'Total check-ins'),
    ('checkins_completed', 2, 150, '{"gold": 100}', 'Frequent Flyer', 'Check in 150 times', 'location.circle.fill', 'exploration', 1011, 'Total check-ins'),
    ('checkins_completed', 3, 500, '{"gold": 250}', 'The Usual', 'Check in 500 times', 'location.circle.fill', 'exploration', 1012, 'Total check-ins'),
    ('checkins_completed', 4, 1500, '{"gold": 500}', 'Come Here Often?', 'Check in 1,500 times', 'location.circle.fill', 'exploration', 1013, 'Total check-ins'),
    ('checkins_completed', 5, 5000, '{"gold": 1000}', 'Do You Even Leave?', 'Check in 5,000 times', 'location.circle.fill', 'exploration', 1014, 'Total check-ins'),
    ('checkins_completed', 6, 15000, '{"gold": 2500}', 'Touched Grass 15000x', 'Check in 15,000 times', 'location.circle.fill', 'exploration', 1015, 'Total check-ins'),
    ('checkins_completed', 7, 50000, '{"gold": 5000}', 'I Live Here Now', 'Check in 50,000 times', 'location.circle.fill', 'exploration', 1016, 'Total check-ins')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- REPUTATION ACHIEVEMENTS
-- =====================================================

INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('reputation_earned', 1, 500, '{"gold": 100}', 'Resident', 'Earn 500 reputation', 'star.fill', 'reputation', 1000, 'Reputation in current kingdom'),
    ('reputation_earned', 2, 1000, '{"gold": 250}', 'Citizen', 'Earn 1000 reputation', 'star.fill', 'reputation', 1001, 'Reputation in current kingdom'),
    ('reputation_earned', 3, 15000, '{"gold": 1500}', 'Notable', 'Earn 15000 reputation', 'star.fill', 'reputation', 1002, 'Reputation in current kingdom'),
    ('reputation_earned', 4, 25000, '{"gold": 3000}', 'Champion', 'Earn 25000 reputation', 'star.fill', 'reputation', 1003, 'Reputation in current kingdom'),
    ('reputation_earned', 5, 50000, '{"gold": 5000}', 'Legendary', 'Earn 50000 reputation', 'star.fill', 'reputation', 1004, 'Reputation in current kingdom')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- SOCIAL ACHIEVEMENTS
-- =====================================================

-- Friends Made
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('friends_made', 1, 5, '{"gold": 50}', 'Small Talk', 'Make 5 friends', 'person.2.fill', 'social', 1020, 'Friends made'),
    ('friends_made', 2, 15, '{"gold": 150}', 'Mr. Popular', 'Make 15 friends', 'person.2.fill', 'social', 1021, 'Friends made'),
    ('friends_made', 3, 30, '{"gold": 300}', 'Mrs. Popular', 'Make 30 friends', 'person.2.fill', 'social', 1022, 'Friends made'),
    ('friends_made', 4, 50, '{"gold": 600}', 'Deep Network', 'Make 50 friends', 'person.2.fill', 'social', 1023, 'Friends made'),
    ('friends_made', 5, 100, '{"gold": 1500}', 'The Man', 'Make 100 friends', 'person.2.fill', 'social', 1024, 'Friends made'),
    ('friends_made', 6, 250, '{"gold": 3000}', 'I Have 250 Friends', 'Make 250 friends', 'person.2.fill', 'social', 1025, 'Friends made')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- =====================================================
-- PROGRESSION ACHIEVEMENTS
-- =====================================================

-- Gold Held
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('gold_held', 1, 1000, '{"gold": 100}', 'Piggy Bank', 'Hold 1,000 gold', 'g.circle.fill', 'progression', 1030, 'Gold held at once'),
    ('gold_held', 2, 2500, '{"gold": 250}', 'Stacking Paper', 'Hold 2,500 gold', 'g.circle.fill', 'progression', 1031, 'Gold held at once'),
    ('gold_held', 3, 5000, '{"gold": 500}', 'Money Bags', 'Hold 5,000 gold', 'g.circle.fill', 'progression', 1032, 'Gold held at once'),
    ('gold_held', 4, 10000, '{"gold": 1000}', 'Baller', 'Hold 10,000 gold', 'g.circle.fill', 'progression', 1033, 'Gold held at once'),
    ('gold_held', 5, 50000, '{"gold": 5000}', 'Fat Stacks', 'Hold 50,000 gold', 'g.circle.fill', 'progression', 1034, 'Gold held at once'),
    ('gold_held', 6, 1000000, '{"gold": 25000}', 'Literally A Millionaire', 'Hold 1,000,000 gold', 'g.circle.fill', 'progression', 1035, 'Gold held at once')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Player Level
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('player_level', 1, 3, '{"gold": 50}', 'Tutorial Island', 'Reach level 3', 'star.circle.fill', 'progression', 1040, 'Player level reached'),
    ('player_level', 2, 5, '{"gold": 500}', 'High Five', 'Reach level 5', 'star.circle.fill', 'progression', 1041, 'Player level reached'),
    ('player_level', 3, 8, '{"gold": 1000}', 'Gr8', 'Reach level 8', 'star.circle.fill', 'progression', 1042, 'Player level reached'),
    ('player_level', 4, 10, '{"gold": 2000}', '10th B-Day', 'Reach level 10', 'star.circle.fill', 'progression', 1043, 'Player level reached'),
    ('player_level', 5, 12, '{"gold": 3000}', 'Dirty Dozen', 'Reach level 12', 'star.circle.fill', 'progression', 1044, 'Player level reached'),
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;

-- Total Skill Points
INSERT INTO achievement_definitions 
    (achievement_type, tier, target_value, rewards, display_name, description, icon, category, display_order, type_display_name)
VALUES
    ('total_skill_points', 1, 5, '{"gold": 50}', 'Trying It', 'Earn 5 total skill points', 'chart.bar.fill', 'progression', 1050, 'Total skill points earned'),
    ('total_skill_points', 2, 10, '{"gold": 150}', 'Spreading Out', 'Earn 10 total skill points', 'chart.bar.fill', 'progression', 1051, 'Total skill points earned'),
    ('total_skill_points', 3, 20, '{"gold": 300}', 'Well Rounded', 'Earn 20 total skill points', 'chart.bar.fill', 'progression', 1052, 'Total skill points earned'),
    ('total_skill_points', 4, 30, '{"gold": 750}', 'Swiss Army Knife', 'Earn 30 total skill points', 'chart.bar.fill', 'progression', 1053, 'Total skill points earned'),
    ('total_skill_points', 5, 40, '{"gold": 1500}', 'Almost There', 'Earn 40 total skill points', 'chart.bar.fill', 'progression', 1054, 'Total skill points earned'),
    ('total_skill_points', 6, 45, '{"gold": 3000}', 'Maxed Main BTW', 'Earn 45 total skill points', 'chart.bar.fill', 'progression', 1055, 'Total skill points earned')
ON CONFLICT (achievement_type, tier) DO UPDATE SET
    target_value = EXCLUDED.target_value,
    rewards = EXCLUDED.rewards,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    display_order = EXCLUDED.display_order,
    type_display_name = EXCLUDED.type_display_name;
