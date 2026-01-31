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
    ('hunt_squirrel', 5, 1000, '{"gold": 500}', 'Squirrel Chaser V', 'Hunt 1000 squirrels', 'leaf.fill', 'hunting', 104)
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
    ('hunt_rabbit', 5, 1000, '{"gold": 500}', 'Rabbit Hunter V', 'Hunt 1000 rabbits', 'hare.fill', 'hunting', 114)
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
    ('hunt_deer', 5, 500, '{"gold": 1000}', 'Deer Stalker V', 'Hunt 500 deer', 'leaf.circle.fill', 'hunting', 124)
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
    ('hunt_boar', 5, 250, '{"gold": 1500}', 'Boar Slayer V', 'Hunt 250 boars', 'pawprint.fill', 'hunting', 134)
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
    ('hunt_bear', 5, 100, '{"gold": 2500}', 'Bear Slayer V', 'Hunt 100 bears', 'flame.fill', 'hunting', 144)
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
    ('hunt_moose', 5, 50, '{"gold": 3000}', 'Moose Hunter V', 'Hunt 50 moose', 'crown.fill', 'hunting', 154)
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
    ('catch_minnow', 5, 1000, '{"gold": 500}', 'Minnow Catcher V', 'Catch 1000 minnows', 'fish.fill', 'fishing', 204)
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
    ('catch_bass', 5, 1000, '{"gold": 500}', 'Bass Fisher V', 'Catch 1000 bass', 'fish.fill', 'fishing', 214)
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
    ('catch_salmon', 5, 500, '{"gold": 1000}', 'Salmon Seeker V', 'Catch 500 salmon', 'fish.fill', 'fishing', 224)
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
    ('catch_catfish', 5, 250, '{"gold": 1500}', 'Catfish Hunter V', 'Catch 250 catfish', 'fish.fill', 'fishing', 234)
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
    ('catch_legendary_carp', 2, 5, '{"gold": 300}', 'Legend Finder II', 'Catch 5 legendary carp', 'sparkles', 'fishing', 241),
    ('catch_legendary_carp', 3, 10, '{"gold": 600}', 'Legend Finder III', 'Catch 10 legendary carp', 'sparkles', 'fishing', 242),
    ('catch_legendary_carp', 4, 25, '{"gold": 1500}', 'Legend Finder IV', 'Catch 25 legendary carp', 'sparkles', 'fishing', 243),
    ('catch_legendary_carp', 5, 50, '{"gold": 3000}', 'Legend Finder V', 'Catch 50 legendary carp', 'sparkles', 'fishing', 244)
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
    ('fish_caught', 6, 10000, '{"gold": 2500}', 'Legendary Angler', 'Catch 10000 fish', 'fish.fill', 'fishing', 255, 'Total fish caught (any type)')
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
