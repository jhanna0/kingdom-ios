"""
Achievement System Router
Backend-driven achievement diary with tiered rewards
"""
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime

from db import get_db
from db.models.user import User
from db.models.player_state import PlayerState
from routers.auth import get_current_user
from routers.actions.tax_utils import apply_kingdom_tax
from schemas.achievements import (
    Achievement,
    AchievementTier,
    AchievementRewards,
    AchievementCategory,
    AchievementsResponse,
    ClaimRewardRequest,
    ClaimRewardResponse,
)


router = APIRouter(prefix="/achievements", tags=["achievements"])


# Category display configuration with explicit ordering
# Order determines how categories appear in the UI (lower = first)
CATEGORY_CONFIG = {
    # Core progression (most common activities)
    "building": {"display_name": "Building", "icon": "building.2.fill", "order": 1},
    "training": {"display_name": "Training", "icon": "figure.strengthtraining.traditional", "order": 2},
    "gathering": {"display_name": "Gathering", "icon": "leaf.fill", "order": 3},
    "crafting": {"display_name": "Crafting", "icon": "hammer.fill", "order": 4},
    
    # Activities
    "hunting": {"display_name": "Hunting", "icon": "scope", "order": 5},
    "fishing": {"display_name": "Fishing", "icon": "fish.fill", "order": 6},
    "foraging": {"display_name": "Foraging", "icon": "leaf.fill", "order": 7},
    "gardening": {"display_name": "Gardening", "icon": "leaf.fill", "order": 8},
    
    # Economy & Science
    "merchant": {"display_name": "Merchant", "icon": "storefront.fill", "order": 9},
    "science": {"display_name": "Science", "icon": "flask.fill", "order": 10},
    
    # PvP (more common than coups/battles)
    "pvp": {"display_name": "PvP", "icon": "figure.fencing", "order": 11},
    "intelligence": {"display_name": "Intelligence", "icon": "eye.fill", "order": 12},
    
    # Kingdom stuff (rarer)
    "fortification": {"display_name": "Fortification", "icon": "brick.fill", "order": 13},
    "ruler": {"display_name": "Ruler", "icon": "crown.fill", "order": 14},
    
    # Rare events (least common)
    "coup": {"display_name": "Coup", "icon": "theatermasks.fill", "order": 15},
    "battle": {"display_name": "Battle", "icon": "flag.fill", "order": 16},
    
    # Meta
    "progression": {"display_name": "Progression", "icon": "star.fill", "order": 20},
    "general": {"display_name": "General", "icon": "trophy.fill", "order": 99},
}


def get_player_achievement_progress(user_id: int, db: Session) -> Dict[str, int]:
    """
    Calculate current progress for all achievement types.
    OPTIMIZED: Single combined query for all scalar stats to minimize DB round trips.
    """
    progress = {}
    
    # Get player state for basic counters (ORM query - needed for object)
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    if state:
        progress["contracts_completed"] = state.contracts_completed or 0
        progress["total_conquests"] = state.total_conquests or 0
        progress["coups_won"] = state.coups_won or 0
        progress["coups_failed"] = state.coups_failed or 0
        progress["kingdoms_ruled"] = state.kingdoms_ruled or 0
        progress["player_level"] = state.level or 1
        
        total_skills = (
            (state.attack_power or 0) + (state.defense_power or 0) +
            (state.leadership or 0) + (state.building_skill or 0) +
            (state.intelligence or 0) + (state.science or 0) +
            (state.faith or 0) + (state.philosophy or 0) + (state.merchant or 0)
        )
        progress["total_skill_points"] = total_skills
    
    # =========================================================================
    # SINGLE COMBINED QUERY FOR ALL SCALAR STATS
    # =========================================================================
    combined_query = text("""
        SELECT
            -- Checkins
            COALESCE((SELECT SUM(checkins_count) FROM user_kingdoms WHERE user_id = :user_id), 0) as total_checkins,
            
            -- Foraging sessions
            COALESCE((SELECT COUNT(*) FROM foraging_sessions WHERE user_id = :user_id AND status = 'collected'), 0) as foraging_completed,
            
            -- Merchant: Direct trades
            COALESCE((SELECT COUNT(*) FROM trade_offers WHERE (sender_id = :user_id OR recipient_id = :user_id) AND status = 'accepted'), 0) as direct_trades,
            
            -- Merchant: Market trades  
            COALESCE((SELECT COUNT(*) FROM market_transactions WHERE buyer_id = :user_id OR seller_id = :user_id), 0) as market_trades,
            
            -- Contract contributions (actions completed) - count from contract_contributions joined with unified_contracts
            COALESCE((SELECT COUNT(*) FROM contract_contributions cc JOIN unified_contracts uc ON cc.contract_id = uc.id WHERE cc.user_id = :user_id AND uc.category = 'personal_property'), 0) as building_contracts,
            COALESCE((SELECT COUNT(*) FROM contract_contributions cc JOIN unified_contracts uc ON cc.contract_id = uc.id WHERE cc.user_id = :user_id AND uc.category = 'personal_training'), 0) as training_contracts,
            COALESCE((SELECT COUNT(*) FROM unified_contracts WHERE user_id = :user_id AND completed_at IS NOT NULL AND category = 'personal_crafting' AND type IN ('weapon', 'armor')), 0) as items_crafted,
            COALESCE((SELECT COUNT(*) FROM unified_contracts WHERE user_id = :user_id AND completed_at IS NOT NULL AND category = 'personal_crafting' AND type = 'weapon'), 0) as weapons_crafted,
            COALESCE((SELECT COUNT(*) FROM unified_contracts WHERE user_id = :user_id AND completed_at IS NOT NULL AND category = 'personal_crafting' AND type = 'armor'), 0) as armor_crafted,
            COALESCE((SELECT COUNT(*) FROM unified_contracts WHERE user_id = :user_id AND completed_at IS NOT NULL AND category = 'personal_crafting' AND type IN ('weapon', 'armor') AND tier = 5), 0) as craft_tier_5_item,
            
            -- Science stats
            COALESCE((SELECT experiments_completed FROM science_stats WHERE user_id = :user_id), 0) as experiments_completed,
            COALESCE((SELECT total_blueprints_earned FROM science_stats WHERE user_id = :user_id), 0) as blueprints_earned,
            
            -- Gathering
            COALESCE((SELECT SUM(amount_gathered) FROM daily_gathering WHERE user_id = :user_id AND resource_type = 'wood'), 0) as wood_gathered,
            COALESCE((SELECT SUM(amount_gathered) FROM daily_gathering WHERE user_id = :user_id AND resource_type = 'iron'), 0) as iron_gathered,
            
            -- Fortification stats
            COALESCE((SELECT items_sacrificed FROM player_fortification_stats WHERE user_id = :user_id), 0) as items_sacrificed,
            COALESCE((SELECT CASE WHEN max_fortification_reached THEN 1 ELSE 0 END FROM player_fortification_stats WHERE user_id = :user_id), 0) as max_fortification,
            
            -- Ruler stats
            COALESCE((SELECT COUNT(*) FROM kingdoms WHERE ruler_id = :user_id), 0) as empire_size,
            COALESCE((SELECT SUM(total_income_collected) FROM kingdoms WHERE ruler_id = :user_id), 0) as treasury_collected,
            
            -- Coup stats
            COALESCE((SELECT COUNT(*) FROM coup_events WHERE initiator_id = :user_id), 0) as coups_initiated,
            
            -- Duel stats
            COALESCE((SELECT wins FROM duel_stats WHERE user_id = :user_id), 0) as duels_won,
            COALESCE((SELECT wins + losses FROM duel_stats WHERE user_id = :user_id), 0) as duels_fought,
            
            -- Intelligence stats
            COALESCE((SELECT operations_attempted FROM player_intelligence_stats WHERE user_id = :user_id), 0) as operations_attempted,
            COALESCE((SELECT intel_gathered FROM player_intelligence_stats WHERE user_id = :user_id), 0) as intel_gathered,
            COALESCE((SELECT sabotages_completed FROM player_intelligence_stats WHERE user_id = :user_id), 0) as sabotages_completed,
            COALESCE((SELECT heists_completed FROM player_intelligence_stats WHERE user_id = :user_id), 0) as heists_completed
    """)
    
    combined_result = db.execute(combined_query, {"user_id": user_id}).first()
    if combined_result:
        progress["total_checkins"] = int(combined_result.total_checkins)
        progress["foraging_completed"] = int(combined_result.foraging_completed)
        progress["direct_trades"] = int(combined_result.direct_trades)
        progress["market_trades"] = int(combined_result.market_trades)
        progress["building_contracts"] = int(combined_result.building_contracts)
        progress["training_contracts"] = int(combined_result.training_contracts)
        progress["items_crafted"] = int(combined_result.items_crafted)
        progress["weapons_crafted"] = int(combined_result.weapons_crafted)
        progress["armor_crafted"] = int(combined_result.armor_crafted)
        progress["craft_tier_5_item"] = int(combined_result.craft_tier_5_item)
        progress["experiments_completed"] = int(combined_result.experiments_completed)
        progress["blueprints_earned"] = int(combined_result.blueprints_earned)
        progress["wood_gathered"] = int(combined_result.wood_gathered)
        progress["iron_gathered"] = int(combined_result.iron_gathered)
        progress["items_sacrificed"] = int(combined_result.items_sacrificed)
        progress["max_fortification"] = int(combined_result.max_fortification)
        progress["empire_size"] = int(combined_result.empire_size)
        progress["treasury_collected"] = int(combined_result.treasury_collected)
        progress["coups_initiated"] = int(combined_result.coups_initiated)
        progress["duels_won"] = int(combined_result.duels_won)
        progress["duels_fought"] = int(combined_result.duels_fought)
        progress["operations_attempted"] = int(combined_result.operations_attempted)
        progress["intel_gathered"] = int(combined_result.intel_gathered)
        progress["sabotages_completed"] = int(combined_result.sabotages_completed)
        progress["heists_completed"] = int(combined_result.heists_completed)
    
    # =========================================================================
    # SECOND COMBINED QUERY: Battle + Garden (more complex aggregations)
    # =========================================================================
    complex_query = text("""
        SELECT
            -- Battle stats (requires JOIN)
            COALESCE((
                SELECT COUNT(DISTINCT bp.battle_id)
                FROM battle_participants bp
                JOIN battles b ON b.id = bp.battle_id
                WHERE bp.user_id = :user_id AND b.type = 'invasion'
            ), 0) as invasions_participated,
            COALESCE((
                SELECT COUNT(DISTINCT bp.battle_id)
                FROM battle_participants bp
                JOIN battles b ON b.id = bp.battle_id
                WHERE bp.user_id = :user_id AND b.type = 'invasion' 
                AND b.resolved_at IS NOT NULL AND b.attacker_victory = true AND bp.side = 'attackers'
            ), 0) as invasions_won_attack,
            COALESCE((
                SELECT COUNT(DISTINCT bp.battle_id)
                FROM battle_participants bp
                JOIN battles b ON b.id = bp.battle_id
                WHERE bp.user_id = :user_id AND b.type = 'invasion'
                AND b.resolved_at IS NOT NULL AND b.attacker_victory = false AND bp.side = 'defenders'
            ), 0) as invasions_won_defend,
            
            -- Garden stats
            COALESCE((SELECT COUNT(*) FROM garden_history WHERE user_id = :user_id AND action IN ('harvested', 'discarded') AND plant_type IS NOT NULL), 0) as plants_grown,
            COALESCE((SELECT COUNT(*) FROM garden_history WHERE user_id = :user_id AND action = 'discarded' AND plant_type = 'flower'), 0) as flowers_grown,
            COALESCE((SELECT COUNT(*) FROM garden_history WHERE user_id = :user_id AND action = 'discarded' AND plant_type = 'flower' AND flower_rarity = 'rare'), 0) as rare_flowers_grown,
            COALESCE((SELECT SUM(wheat_gained) FROM garden_history WHERE user_id = :user_id AND action = 'harvested'), 0) as wheat_harvested,
            COALESCE((SELECT COUNT(*) FROM garden_history WHERE user_id = :user_id AND action = 'discarded' AND plant_type = 'weed'), 0) as weeds_cleared,
            COALESCE((SELECT COUNT(DISTINCT flower_color) FROM garden_history WHERE user_id = :user_id AND plant_type = 'flower' AND flower_color IS NOT NULL), 0) as flower_colors
    """)
    
    complex_result = db.execute(complex_query, {"user_id": user_id}).first()
    if complex_result:
        progress["invasions_participated"] = int(complex_result.invasions_participated)
        progress["invasions_won_attack"] = int(complex_result.invasions_won_attack)
        progress["invasions_won_defend"] = int(complex_result.invasions_won_defend)
        progress["plants_grown"] = int(complex_result.plants_grown)
        progress["flowers_grown"] = int(complex_result.flowers_grown)
        progress["rare_flowers_grown"] = int(complex_result.rare_flowers_grown)
        progress["wheat_harvested"] = int(complex_result.wheat_harvested)
        progress["weeds_cleared"] = int(complex_result.weeds_cleared)
        progress["flower_colors"] = int(complex_result.flower_colors)
    
    # =========================================================================
    # ITEMIZED QUERIES (need multiple rows - can't combine)
    # =========================================================================
    
    # Hunt kills by animal
    hunt_query = text("""
        SELECT animal_id, SUM(kill_count) as kill_count
        FROM player_hunt_kills
        WHERE user_id = :user_id
        GROUP BY animal_id
    """)
    hunt_results = db.execute(hunt_query, {"user_id": user_id}).fetchall()
    total_hunts = 0
    for row in hunt_results:
        kill_count = int(row.kill_count)
        total_hunts += kill_count
        progress[f"hunt_{row.animal_id}"] = kill_count
    progress["hunts_completed"] = total_hunts
    
    # Fish catches by fish type
    fish_query = text("""
        SELECT fish_id, catch_count
        FROM player_fish_catches
        WHERE user_id = :user_id
    """)
    fish_results = db.execute(fish_query, {"user_id": user_id}).fetchall()
    total_fish = 0
    for row in fish_results:
        catch_count = int(row.catch_count)
        total_fish += catch_count
        if row.fish_id == "pet_fish":
            progress["pet_fish_caught"] = catch_count
        progress[f"catch_{row.fish_id}"] = catch_count
    progress["fish_caught"] = total_fish
    
    # Foraging finds by item type
    foraging_finds_query = text("""
        SELECT item_id, find_count
        FROM player_foraging_finds
        WHERE user_id = :user_id
    """)
    for row in db.execute(foraging_finds_query, {"user_id": user_id}).fetchall():
        progress[f"find_{row.item_id}"] = int(row.find_count)
    
    return progress


def get_achievement_definitions(db: Session) -> List[Dict[str, Any]]:
    """Get all active achievement definitions from database"""
    query = text("""
        SELECT 
            id, achievement_type, tier, target_value, rewards,
            display_name, description, icon, category, display_order,
            type_display_name
        FROM achievement_definitions
        WHERE is_active = TRUE
        ORDER BY category, display_order, tier
    """)
    results = db.execute(query).fetchall()
    return [dict(row._mapping) for row in results]


def get_player_claims(user_id: int, db: Session) -> Dict[int, datetime]:
    """Get all claimed achievement tier IDs for a player"""
    query = text("""
        SELECT achievement_tier_id, claimed_at
        FROM player_achievement_claims
        WHERE user_id = :user_id
    """)
    results = db.execute(query, {"user_id": user_id}).fetchall()
    return {row.achievement_tier_id: row.claimed_at for row in results}


@router.get("", response_model=AchievementsResponse)
def get_achievements(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all achievements with player progress.
    
    Returns achievements grouped by category, with progress bars
    and claimable status for each tier.
    """
    # Get player progress for all achievement types
    progress = get_player_achievement_progress(user.id, db)
    
    # Get all achievement definitions
    definitions = get_achievement_definitions(db)
    
    # Get player's claimed tiers
    claims = get_player_claims(user.id, db)
    
    # Group by achievement type, then by category
    achievements_by_type: Dict[str, Dict[str, Any]] = {}
    
    for defn in definitions:
        achievement_type = defn["achievement_type"]
        tier_id = defn["id"]
        
        if achievement_type not in achievements_by_type:
            achievements_by_type[achievement_type] = {
                "achievement_type": achievement_type,
                "icon": defn["icon"],
                "category": defn["category"],
                "type_display_name": defn.get("type_display_name"),
                "tiers": [],
                "current_value": progress.get(achievement_type, 0),
            }
        
        # Parse rewards
        rewards_data = defn["rewards"] or {}
        rewards = AchievementRewards(
            gold=rewards_data.get("gold", 0),
            experience=rewards_data.get("experience", 0),
            items=rewards_data.get("items", [])
        )
        
        current_value = progress.get(achievement_type, 0)
        is_completed = current_value >= defn["target_value"]
        is_claimed = tier_id in claims
        claimed_at = claims.get(tier_id)
        
        tier = AchievementTier(
            id=defn["id"],
            tier=defn["tier"],
            target_value=defn["target_value"],
            rewards=rewards,
            display_name=defn["display_name"],
            description=defn["description"],
            is_completed=is_completed,
            is_claimed=is_claimed,
            claimed_at=claimed_at
        )
        
        achievements_by_type[achievement_type]["tiers"].append(tier)
    
    # Build Achievement objects with computed fields
    achievements: List[Achievement] = []
    total_tiers = 0
    total_completed = 0
    total_claimed = 0
    total_claimable = 0
    
    for ach_data in achievements_by_type.values():
        tiers = ach_data["tiers"]
        current_value = ach_data["current_value"]
        
        # Find current tier (highest completed) and next target
        current_tier = 0
        next_tier_target = None
        has_claimable = False
        display_name = ""
        description = ""
        
        for tier in sorted(tiers, key=lambda t: t.tier):
            total_tiers += 1
            
            if tier.is_claimed:
                total_claimed += 1
            
            if tier.is_completed:
                current_tier = tier.tier
                total_completed += 1
                if not tier.is_claimed:
                    has_claimable = True
                    total_claimable += 1
            
            # Find the first unclaimed tier for display
            if not tier.is_claimed and next_tier_target is None:
                next_tier_target = tier.target_value
                display_name = tier.display_name
                description = tier.description
        
        # If all claimed, use last tier info
        if not display_name and tiers:
            last_tier = max(tiers, key=lambda t: t.tier)
            display_name = last_tier.display_name
            description = last_tier.description
        
        # Calculate progress percentage to next unclaimed tier
        progress_percent = 0.0
        if next_tier_target is not None and next_tier_target > 0:
            # Find the previous tier's target (or 0 if first tier)
            prev_target = 0
            for tier in sorted(tiers, key=lambda t: t.tier):
                if tier.target_value == next_tier_target:
                    break
                if tier.is_claimed:
                    prev_target = tier.target_value
            
            # Progress from prev_target to next_tier_target
            range_size = next_tier_target - prev_target
            progress_in_range = current_value - prev_target
            progress_percent = min(100.0, max(0.0, (progress_in_range / range_size) * 100))
        elif next_tier_target is None and tiers:
            # All tiers completed
            progress_percent = 100.0
        
        achievement = Achievement(
            achievement_type=ach_data["achievement_type"],
            display_name=display_name,
            description=description,
            icon=ach_data["icon"],
            category=ach_data["category"],
            type_display_name=ach_data.get("type_display_name"),
            current_value=current_value,
            tiers=sorted(tiers, key=lambda t: t.tier),
            current_tier=current_tier,
            next_tier_target=next_tier_target,
            progress_percent=progress_percent,
            has_claimable=has_claimable
        )
        achievements.append(achievement)
    
    # Group by category
    categories_dict: Dict[str, List[Achievement]] = {}
    for ach in achievements:
        cat = ach.category
        if cat not in categories_dict:
            categories_dict[cat] = []
        categories_dict[cat].append(ach)
    
    # Build category response - sort by configured order (hunting, fishing, foraging first)
    categories = []
    sorted_categories = sorted(
        categories_dict.items(),
        key=lambda x: CATEGORY_CONFIG.get(x[0], {"order": 50})["order"]
    )
    for cat_key, cat_achievements in sorted_categories:
        cat_config = CATEGORY_CONFIG.get(cat_key, {"display_name": cat_key.title(), "icon": "star.fill", "order": 50})
        categories.append(AchievementCategory(
            category=cat_key,
            display_name=cat_config["display_name"],
            icon=cat_config["icon"],
            achievements=sorted(cat_achievements, key=lambda a: a.tiers[0].tier if a.tiers else 0)
        ))
    
    # Calculate overall progress percent (claimed / total tiers)
    overall_progress_percent = 0.0
    if total_tiers > 0:
        overall_progress_percent = round((total_claimed / total_tiers) * 100, 1)
    
    return AchievementsResponse(
        categories=categories,
        total_achievements=len(achievements),
        total_tiers=total_tiers,
        total_completed=total_completed,
        total_claimed=total_claimed,
        total_claimable=total_claimable,
        overall_progress_percent=overall_progress_percent
    )


@router.post("/claim", response_model=ClaimRewardResponse)
def claim_achievement_reward(
    request: ClaimRewardRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Claim reward for a completed achievement tier.
    
    Validates:
    - Tier exists and is active
    - Player has met the requirement
    - Player hasn't already claimed this tier
    
    Grants rewards and records the claim.
    """
    tier_id = request.achievement_tier_id
    
    # Get the achievement tier definition
    tier_query = text("""
        SELECT 
            id, achievement_type, tier, target_value, rewards,
            display_name, description, is_active
        FROM achievement_definitions
        WHERE id = :tier_id
    """)
    tier_result = db.execute(tier_query, {"tier_id": tier_id}).first()
    
    if not tier_result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Achievement tier not found"
        )
    
    tier_data = dict(tier_result._mapping)
    
    if not tier_data["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This achievement is no longer active"
        )
    
    # Check if already claimed
    claim_check = text("""
        SELECT id FROM player_achievement_claims
        WHERE user_id = :user_id AND achievement_tier_id = :tier_id
    """)
    existing_claim = db.execute(claim_check, {"user_id": user.id, "tier_id": tier_id}).first()
    
    if existing_claim:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already claimed this reward"
        )
    
    # Get player progress for this achievement type
    progress = get_player_achievement_progress(user.id, db)
    current_value = progress.get(tier_data["achievement_type"], 0)
    
    if current_value < tier_data["target_value"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You need {tier_data['target_value']} to claim this reward (current: {current_value})"
        )
    
    # Get player state for rewards
    state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player state not found"
        )
    
    # Parse rewards
    rewards_data = tier_data["rewards"] or {}
    gold_reward = rewards_data.get("gold", 0)
    xp_reward = rewards_data.get("experience", 0)
    
    # Apply kingdom tax to gold reward
    tax_amount = 0
    tax_rate = 0
    net_gold = gold_reward
    
    if gold_reward > 0 and state.hometown_kingdom_id:
        net_gold, tax_amount, tax_rate = apply_kingdom_tax(
            db, state.hometown_kingdom_id, state, gold_reward
        )
    
    # Grant rewards (net gold after tax)
    old_level = state.level
    state.gold = (state.gold or 0) + net_gold
    state.experience = (state.experience or 0) + xp_reward
    
    # Check for level up (simple check - can be expanded)
    new_level = None
    xp_for_next_level = state.level * 100  # Simple formula
    while state.experience >= xp_for_next_level:
        state.level += 1
        state.skill_points = (state.skill_points or 0) + 3
        state.experience -= xp_for_next_level
        xp_for_next_level = state.level * 100
        new_level = state.level
    
    # Record the claim
    claim_insert = text("""
        INSERT INTO player_achievement_claims (user_id, achievement_tier_id, claimed_at)
        VALUES (:user_id, :tier_id, NOW())
    """)
    db.execute(claim_insert, {"user_id": user.id, "tier_id": tier_id})
    
    db.commit()
    
    return ClaimRewardResponse(
        success=True,
        message=f"Claimed {tier_data['display_name']}!",
        rewards_granted=AchievementRewards(
            gold=int(net_gold),  # Net gold after tax
            experience=xp_reward,
            items=rewards_data.get("items", [])
        ),
        new_gold=int(state.gold),
        new_experience=state.experience,
        new_level=new_level,
        tax_amount=int(tax_amount) if tax_amount > 0 else None,
        tax_rate=tax_rate if tax_rate > 0 else None,
        achievement_type=tier_data["achievement_type"],
        tier=tier_data["tier"],
        display_name=tier_data["display_name"]
    )


@router.get("/summary")
def get_achievements_summary(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a quick summary of achievement progress.
    Useful for badges/notifications.
    """
    # Count claimable achievements
    progress = get_player_achievement_progress(user.id, db)
    definitions = get_achievement_definitions(db)
    claims = get_player_claims(user.id, db)
    
    claimable_count = 0
    total_tiers = len(definitions)
    claimed_count = len(claims)
    
    for defn in definitions:
        tier_id = defn["id"]
        achievement_type = defn["achievement_type"]
        current_value = progress.get(achievement_type, 0)
        
        is_completed = current_value >= defn["target_value"]
        is_claimed = tier_id in claims
        
        if is_completed and not is_claimed:
            claimable_count += 1
    
    return {
        "total_tiers": total_tiers,
        "claimed_count": claimed_count,
        "claimable_count": claimable_count,
        "completion_percent": round((claimed_count / total_tiers) * 100, 1) if total_tiers > 0 else 0
    }
