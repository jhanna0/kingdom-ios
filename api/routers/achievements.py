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


# Category display configuration
CATEGORY_CONFIG = {
    "hunting": {"display_name": "Hunting", "icon": "scope"},
    "economy": {"display_name": "Economy", "icon": "hammer.fill"},
    "combat": {"display_name": "Combat", "icon": "flag.fill"},
    "social": {"display_name": "Social", "icon": "person.2.fill"},
    "progression": {"display_name": "Progression", "icon": "star.fill"},
    "general": {"display_name": "General", "icon": "trophy.fill"},
}


def get_player_achievement_progress(user_id: int, db: Session) -> Dict[str, int]:
    """
    Calculate current progress for all achievement types.
    Aggregates from various sources: player_state, hunt_sessions, user_kingdoms, etc.
    """
    progress = {}
    
    # Get player state for basic counters
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    if state:
        progress["contracts_completed"] = state.contracts_completed or 0
        progress["total_conquests"] = state.total_conquests or 0
        progress["coups_won"] = state.coups_won or 0
        progress["kingdoms_ruled"] = state.kingdoms_ruled or 0
        progress["player_level"] = state.level or 1
        
        # Calculate total skill points from all stats
        total_skills = (
            (state.attack_power or 0) +
            (state.defense_power or 0) +
            (state.leadership or 0) +
            (state.building_skill or 0) +
            (state.intelligence or 0) +
            (state.science or 0) +
            (state.faith or 0) +
            (state.philosophy or 0) +
            (state.merchant or 0)
        )
        progress["total_skill_points"] = total_skills
    
    # Get total check-ins from user_kingdoms
    checkin_query = text("""
        SELECT COALESCE(SUM(checkins_count), 0) as total_checkins
        FROM user_kingdoms
        WHERE user_id = :user_id
    """)
    result = db.execute(checkin_query, {"user_id": user_id}).first()
    progress["total_checkins"] = int(result.total_checkins) if result else 0
    
    # Get hunt creature kills from optimized stats table (sum across all kingdoms)
    hunt_query = text("""
        SELECT animal_id, SUM(kill_count) as kill_count
        FROM player_hunt_kills
        WHERE user_id = :user_id
        GROUP BY animal_id
    """)
    hunt_results = db.execute(hunt_query, {"user_id": user_id}).fetchall()
    
    total_hunts = 0
    for row in hunt_results:
        animal_id = row.animal_id
        kill_count = int(row.kill_count)
        total_hunts += kill_count
        
        # Map animal_id to achievement type (e.g., "rabbit" -> "hunt_rabbit")
        progress[f"hunt_{animal_id}"] = kill_count
    
    progress["hunts_completed"] = total_hunts
    
    # Get fishing stats from optimized stats table
    fish_query = text("""
        SELECT fish_id, catch_count
        FROM player_fish_catches
        WHERE user_id = :user_id
    """)
    fish_results = db.execute(fish_query, {"user_id": user_id}).fetchall()
    
    total_fish = 0
    pet_fish_count = 0
    for row in fish_results:
        fish_id = row.fish_id
        catch_count = int(row.catch_count)
        total_fish += catch_count
        
        # Track pet fish separately for achievements
        if fish_id == "pet_fish":
            pet_fish_count = catch_count
        
        # Map fish_id to achievement type (e.g., "minnow" -> "catch_minnow")
        progress[f"catch_{fish_id}"] = catch_count
    
    progress["fish_caught"] = total_fish
    progress["pet_fish_caught"] = pet_fish_count
    
    # Get foraging stats from foraging_sessions
    foraging_query = text("""
        SELECT COUNT(*) as total_forages
        FROM foraging_sessions
        WHERE user_id = :user_id
        AND status = 'collected'
    """)
    foraging_result = db.execute(foraging_query, {"user_id": user_id}).first()
    progress["foraging_completed"] = int(foraging_result.total_forages) if foraging_result else 0
    
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
    
    # Build category response
    categories = []
    for cat_key, cat_achievements in sorted(categories_dict.items()):
        cat_config = CATEGORY_CONFIG.get(cat_key, {"display_name": cat_key.title(), "icon": "star.fill"})
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
    
    # Grant rewards
    old_level = state.level
    state.gold = (state.gold or 0) + gold_reward
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
            gold=gold_reward,
            experience=xp_reward,
            items=rewards_data.get("items", [])
        ),
        new_gold=int(state.gold),
        new_experience=state.experience,
        new_level=new_level,
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
