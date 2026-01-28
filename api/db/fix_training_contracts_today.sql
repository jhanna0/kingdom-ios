-- Update training contracts with new formula
-- Actions: 10 + (current_tier × 10) + (total_skill_points × 2)
-- Gold/action: 25 + (target_tier × 25) + (total_skill_points × 6)
-- target_tier = current_tier + 1

UPDATE unified_contracts uc
SET 
    actions_required = 10 + (COALESCE(uc.tier, 0) * 10) + 
        ((COALESCE(ps.attack_power, 0) + COALESCE(ps.defense_power, 0) + COALESCE(ps.leadership, 0) + 
          COALESCE(ps.building_skill, 0) + COALESCE(ps.intelligence, 0) + COALESCE(ps.science, 0) + 
          COALESCE(ps.faith, 0) + COALESCE(ps.philosophy, 0) + COALESCE(ps.merchant, 0)) * 2),
    gold_per_action = 25 + ((COALESCE(uc.tier, 0) + 1) * 25) + 
        ((COALESCE(ps.attack_power, 0) + COALESCE(ps.defense_power, 0) + COALESCE(ps.leadership, 0) + 
          COALESCE(ps.building_skill, 0) + COALESCE(ps.intelligence, 0) + COALESCE(ps.science, 0) + 
          COALESCE(ps.faith, 0) + COALESCE(ps.philosophy, 0) + COALESCE(ps.merchant, 0)) * 6)
FROM users u
JOIN player_states ps ON ps.user_id = u.id
WHERE uc.user_id = u.id
  AND uc.category = 'personal_training'
  AND uc.completed_at IS NULL
  AND uc.created_at >= CURRENT_DATE;
