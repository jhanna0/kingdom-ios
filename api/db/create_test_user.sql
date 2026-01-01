-- Create test user for Apple review process
-- This script properly initializes ALL required fields

-- First, delete any existing test user
DELETE FROM player_state WHERE user_id IN (SELECT id FROM users WHERE apple_user_id = 'appletest');
DELETE FROM users WHERE apple_user_id = 'appletest';

-- Insert the test user
INSERT INTO users (apple_user_id, email, display_name, is_active, is_verified, created_at, updated_at)
VALUES ('appletest', 'appletest@example.com', 'Apple Reviewer', true, true, NOW(), NOW());

-- Insert player state with ALL columns (using COALESCE for defaults)
INSERT INTO player_state (
    user_id,
    hometown_kingdom_id,
    origin_kingdom_id,
    home_kingdom_id,
    current_kingdom_id,
    gold,
    level,
    experience,
    skill_points,
    attack_power,
    defense_power,
    leadership,
    building_skill,
    intelligence,
    attack_debuff,
    debuff_expires_at,
    reputation,
    honor,
    kingdom_reputation,
    check_in_history,
    last_check_in,
    last_check_in_lat,
    last_check_in_lon,
    last_daily_check_in,
    total_checkins,
    total_conquests,
    kingdoms_ruled,
    has_claimed_starting_city,
    coups_won,
    coups_failed,
    times_executed,
    executions_ordered,
    last_coup_attempt,
    contracts_completed,
    total_work_contributed,
    total_training_purchases,
    iron,
    steel,
    last_mining_action,
    last_crafting_action,
    last_building_action,
    last_spy_action,
    last_work_action,
    last_patrol_action,
    last_sabotage_action,
    last_scout_action,
    last_intelligence_action,
    patrol_expires_at,
    last_training_action,
    training_contracts,
    property_upgrade_contracts,
    equipped_weapon,
    equipped_armor,
    equipped_shield,
    inventory,
    crafting_queue,
    crafting_progress,
    properties,
    total_rewards_received,
    last_reward_received,
    last_reward_amount,
    is_alive,
    game_data,
    created_at,
    updated_at
)
VALUES (
    (SELECT id FROM users WHERE apple_user_id = 'appletest'),
    NULL,  -- hometown_kingdom_id
    NULL,  -- origin_kingdom_id
    NULL,  -- home_kingdom_id
    NULL,  -- current_kingdom_id
    1000,  -- gold
    1,     -- level
    0,     -- experience
    0,     -- skill_points
    1,     -- attack_power
    1,     -- defense_power
    1,     -- leadership
    1,     -- building_skill
    1,     -- intelligence
    0,     -- attack_debuff
    NULL,  -- debuff_expires_at
    0,     -- reputation
    100,   -- honor
    '{}',  -- kingdom_reputation
    '{}',  -- check_in_history
    NULL,  -- last_check_in
    NULL,  -- last_check_in_lat
    NULL,  -- last_check_in_lon
    NULL,  -- last_daily_check_in
    0,     -- total_checkins
    0,     -- total_conquests
    0,     -- kingdoms_ruled
    false, -- has_claimed_starting_city
    0,     -- coups_won
    0,     -- coups_failed
    0,     -- times_executed
    0,     -- executions_ordered
    NULL,  -- last_coup_attempt
    0,     -- contracts_completed
    0,     -- total_work_contributed
    0,     -- total_training_purchases
    0,     -- iron
    0,     -- steel
    NULL,  -- last_mining_action
    NULL,  -- last_crafting_action
    NULL,  -- last_building_action
    NULL,  -- last_spy_action
    NULL,  -- last_work_action
    NULL,  -- last_patrol_action
    NULL,  -- last_sabotage_action
    NULL,  -- last_scout_action
    NULL,  -- last_intelligence_action
    NULL,  -- patrol_expires_at
    NULL,  -- last_training_action
    '[]',  -- training_contracts
    '[]',  -- property_upgrade_contracts
    NULL,  -- equipped_weapon
    NULL,  -- equipped_armor
    NULL,  -- equipped_shield
    '[]',  -- inventory
    '[]',  -- crafting_queue
    '{}',  -- crafting_progress
    '[]',  -- properties
    0,     -- total_rewards_received
    NULL,  -- last_reward_received
    0,     -- last_reward_amount
    true,  -- is_alive
    '{}',  -- game_data
    NOW(), -- created_at
    NOW()  -- updated_at
);

-- Verify the user was created
SELECT u.id, u.apple_user_id, u.display_name, ps.gold, ps.level, ps.honor
FROM users u
LEFT JOIN player_state ps ON u.id = ps.user_id
WHERE u.apple_user_id = 'appletest';

