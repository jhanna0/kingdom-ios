"""
City service - Business logic for city boundary lookups

FAST LOADING - TWO ENDPOINTS:
1. /cities/current - Returns ONLY the city user is in (< 2s) - UNBLOCKS FRONTEND
2. /cities/neighbors - Returns neighbor cities IMMEDIATELY, fetches boundaries in background
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional, Dict
from datetime import datetime, timedelta, date, time
import math
import asyncio

from db import CityBoundary, Kingdom, User, get_db, CoupEvent
from db.models import Battle
from schemas import CityBoundaryResponse, BoundaryResponse, KingdomData, BuildingData, BuildingUpgradeCost, BuildingTierInfo, BuildingClickAction, BuildingCatchupInfo, BUILDING_COLORS, AllianceInfo, ActiveAllianceInfo, ActiveCoupData
from routers.alliances import are_empires_allied, get_alliance_between, get_active_alliances_for_empire
from services.catchup_service import get_catchup_status, EXEMPT_BUILDINGS
from osm_service import (
    find_user_city_fast,
    fetch_nearby_city_candidates,
    fetch_city_boundary_by_id,
    _distance_to_polygon_edge,
    _min_distance_between_polygons,
)
from routers.tiers import BUILDING_TYPES


# Boundary simplification settings
# ✅ IMPLEMENTED: Simplified boundaries are now pre-computed and cached in the database
#    - New cities: simplified_boundary_geojson is computed and stored on creation
#    - Existing cities: backfilled on-the-fly when accessed (lazy migration)
#    - This eliminates redundant computation on every API request
SIMPLIFY_BOUNDARIES = True
SIMPLIFY_TARGET_POINTS = 250


def _triangle_area(p1: List[float], p2: List[float], p3: List[float]) -> float:
    """Calculate area of triangle formed by three points using cross product."""
    return abs((p2[0] - p1[0]) * (p3[1] - p1[1]) - (p3[0] - p1[0]) * (p2[1] - p1[1])) / 2


def simplify_boundary(coords: List[List[float]], target_points: int = SIMPLIFY_TARGET_POINTS) -> List[List[float]]:
    """
    Simplify polygon using Visvalingam-Whyatt algorithm.
    
    Unlike Douglas-Peucker, this algorithm:
    - Works by area rather than distance (better for polygons)
    - Removes points progressively from least important to most
    - Doesn't create self-intersections or weird loops
    
    Args:
        coords: List of [lat, lon] coordinate pairs (closed polygon)
        target_points: Target number of points to keep (default from SIMPLIFY_TARGET_POINTS)
        
    Returns:
        Simplified list of [lat, lon] coordinate pairs
    """
    # Skip if disabled or already small enough
    if not SIMPLIFY_BOUNDARIES or not coords or len(coords) <= target_points:
        return coords
    
    try:
        original_count = len(coords)
        
        # Work with a copy, ensure it's closed
        points = [list(c) for c in coords]
        if points[0] != points[-1]:
            points.append(list(points[0]))
        
        # For closed polygon, we work with all but the closing point
        # (we'll add it back at the end)
        working = points[:-1]
        n = len(working)
        
        if n <= target_points:
            return coords
        
        # Calculate initial areas for each point
        # Area = triangle formed with previous and next point
        areas = []
        for i in range(n):
            prev_idx = (i - 1) % n
            next_idx = (i + 1) % n
            area = _triangle_area(working[prev_idx], working[i], working[next_idx])
            areas.append(area)
        
        # Track which points are still active
        active = [True] * n
        points_remaining = n
        
        # Remove points until we reach target
        while points_remaining > target_points:
            # Find point with minimum area (least important)
            min_area = float('inf')
            min_idx = -1
            
            for i in range(n):
                if active[i] and areas[i] < min_area:
                    min_area = areas[i]
                    min_idx = i
            
            if min_idx == -1:
                break
            
            # Remove this point
            active[min_idx] = False
            points_remaining -= 1
            
            # Update areas of neighboring points
            # Find previous active point
            prev_idx = (min_idx - 1) % n
            while not active[prev_idx] and prev_idx != min_idx:
                prev_idx = (prev_idx - 1) % n
            
            # Find next active point
            next_idx = (min_idx + 1) % n
            while not active[next_idx] and next_idx != min_idx:
                next_idx = (next_idx + 1) % n
            
            # Update their areas
            if active[prev_idx]:
                prev_prev = (prev_idx - 1) % n
                while not active[prev_prev] and prev_prev != prev_idx:
                    prev_prev = (prev_prev - 1) % n
                if active[prev_prev]:
                    areas[prev_idx] = _triangle_area(working[prev_prev], working[prev_idx], working[next_idx])
            
            if active[next_idx]:
                next_next = (next_idx + 1) % n
                while not active[next_next] and next_next != next_idx:
                    next_next = (next_next + 1) % n
                if active[next_next]:
                    areas[next_idx] = _triangle_area(working[prev_idx], working[next_idx], working[next_next])
        
        # Build result from active points
        result = [working[i] for i in range(n) if active[i]]
        
        # Close the polygon
        if result and result[0] != result[-1]:
            result.append(result[0])
        
        new_count = len(result)
        if new_count < original_count:
            reduction = 100 - (new_count / original_count * 100)
            print(f"   📐 Simplified boundary: {original_count} → {new_count} points ({reduction:.0f}% reduction)")
        
        return result
        
    except Exception as e:
        print(f"   ⚠️ Boundary simplification failed: {e}")
        return coords


def get_buildings_for_kingdom(
    db: Session, 
    kingdom: Kingdom, 
    current_user: Optional[User] = None,
    include_upgrade_costs: bool = True
) -> list:
    """
    Build the buildings array for a kingdom with all metadata, upgrade costs, and catchup info.
    
    This is THE SINGLE SOURCE OF TRUTH for building data.
    Used by both /kingdoms/{id} and city service endpoints.
    
    Args:
        db: Database session
        kingdom: The kingdom to get buildings for
        current_user: Optional user for catchup info (None = no catchup check)
        include_upgrade_costs: Whether to calculate upgrade costs
        
    Returns:
        List of building dicts with full metadata
    """
    from services.kingdom_service import calculate_actions_required, calculate_construction_cost, get_active_citizens_count
    from db.models import PlayerState, KingdomBuilding
    
    # Get active citizens count for cost calculations
    active_citizens_count = get_active_citizens_count(db, kingdom.id) if include_upgrade_costs else 0
    
    # Load all buildings for this kingdom from the table
    kingdom_buildings_rows = db.query(KingdomBuilding).filter(
        KingdomBuilding.kingdom_id == kingdom.id
    ).all()
    building_levels_map = {b.building_type: b.level for b in kingdom_buildings_rows}
    
    # Get player's building skill and hometown if user is logged in
    building_skill = 0
    user_hometown_id = None
    if current_user:
        player_state = db.query(PlayerState).filter(
            PlayerState.user_id == current_user.id
        ).first()
        if player_state:
            building_skill = player_state.building_skill or 0
            user_hometown_id = player_state.hometown_kingdom_id
    
    # Catch-up only applies to your HOMETOWN - you can only contribute to your hometown's buildings
    is_hometown = user_hometown_id and kingdom.id == user_hometown_id
    
    buildings = []
    for building_type, building_meta in BUILDING_TYPES.items():
        # Try new table first, fallback to old column
        level = building_levels_map.get(building_type)
        if level is None:
            level_attr = f"{building_type}_level"
            level = getattr(kingdom, level_attr, 0)
        
        max_level = building_meta["max_tier"]
        
        # Calculate upgrade cost for next level
        upgrade_cost = None
        if include_upgrade_costs and level < max_level:
            next_level = level + 1
            farm_level = kingdom.farm_level if hasattr(kingdom, 'farm_level') else 0
            actions = calculate_actions_required(building_meta["display_name"], next_level, active_citizens_count, farm_level)
            construction_cost = calculate_construction_cost(next_level, active_citizens_count)
            upgrade_cost = {
                "actions_required": actions,
                "construction_cost": construction_cost,
                "can_afford": kingdom.treasury_gold >= construction_cost
            }
        
        # Get current tier info
        tiers_data = building_meta.get("tiers", {})
        current_tier_data = tiers_data.get(level, tiers_data.get(1, {}))
        tier_name = current_tier_data.get("name", f"Level {level}")
        tier_benefit = current_tier_data.get("benefit", "")
        
        # Build all tiers info
        all_tiers = []
        for tier_num in range(1, max_level + 1):
            tier_data = tiers_data.get(tier_num, {})
            all_tiers.append({
                "tier": tier_num,
                "name": tier_data.get("name", f"Level {tier_num}"),
                "benefit": tier_data.get("benefit", ""),
                "description": tier_data.get("description", ""),
                "per_action_costs": tier_data.get("per_action_costs", [])
            })
        
        # Get click action if defined (only clickable if level > 0)
        click_action = None
        click_action_meta = building_meta.get("click_action")
        if click_action_meta and level > 0:
            click_action = {
                "type": click_action_meta.get("type", ""),
                "resource": click_action_meta.get("resource"),
                "exhausted": False,
                "exhausted_message": None
            }
            
            # Check daily gathering limits for gathering-type buildings
            # Limit is GLOBAL per user based on HOMETOWN building level
            if click_action_meta.get("type") == "gathering" and current_user:
                resource = click_action_meta.get("resource")
                if resource:
                    from routers.actions.gathering import get_daily_limit, get_gathered_today, DAILY_LIMIT_PER_LEVEL
                    daily_limit = get_daily_limit(db, current_user, resource)
                    gathered_today = get_gathered_today(db, current_user.id, resource)
                    if gathered_today >= daily_limit:
                        click_action["exhausted"] = True
                        
                        # Calculate time until reset
                        now = datetime.now()
                        tomorrow_midnight = datetime.combine(date.today() + timedelta(days=1), time.min)
                        remaining = tomorrow_midnight - now
                        hours, remainder = divmod(int(remaining.total_seconds()), 3600)
                        minutes, _ = divmod(remainder, 60)
                        time_str = f"{hours}h {minutes}m"
                        
                        # Stone/iron share a combined mine limit
                        if resource == "wood":
                            click_action["exhausted_message"] = f"You've chopped all available wood for today. Resets in {time_str}."
                        else:
                            click_action["exhausted_message"] = f"The mine is exhausted for today. Resets in {time_str}."
                    
                    # Add limit info for UI
                    click_action["daily_limit"] = daily_limit
                    click_action["gathered_today"] = gathered_today
                    click_action["remaining_today"] = max(0, daily_limit - gathered_today)
        
        # Get catch-up info ONLY for hometown (you can only contribute to your hometown's buildings)
        catchup_info = None
        if current_user and is_hometown and level > 0 and building_type not in EXEMPT_BUILDINGS:
            catchup_status = get_catchup_status(
                db, current_user.id, kingdom.id, 
                building_type, level, building_skill
            )
            catchup_info = {
                "needs_catchup": catchup_status["needs_catchup"],
                "can_use": catchup_status["can_use_building"],
                "actions_required": catchup_status["actions_required"],
                "actions_completed": catchup_status["actions_completed"],
                "actions_remaining": catchup_status["actions_remaining"]
            }
        
        # Get permit info for buildings that require permits (non-hometown)
        permit_info = None
        if current_user and level > 0:
            from services.building_permit_service import check_building_access, PERMIT_REQUIRED_BUILDINGS
            if building_type in PERMIT_REQUIRED_BUILDINGS:
                player_state = current_user.player_state
                if player_state:
                    access = check_building_access(db, current_user, player_state, kingdom, building_type)
                    permit_info = {
                        "can_access": access["can_access"],
                        "reason": access["reason"],
                        "is_hometown": access["is_hometown"],
                        "is_allied": access["is_allied"],
                        "needs_permit": access["needs_permit"],
                        "has_valid_permit": access["has_valid_permit"],
                        "permit_expires_at": access["permit_expires_at"].isoformat() + "Z" if access["permit_expires_at"] else None,
                        "permit_minutes_remaining": access["permit_minutes_remaining"],
                        "hometown_has_building": access["hometown_has_building"],
                        "hometown_building_level": access["hometown_building_level"],
                        "has_active_catchup": access["has_active_catchup"],
                        "can_buy_permit": access["can_buy_permit"],
                        "permit_cost": access["permit_cost"],
                        "permit_duration_minutes": access["permit_duration_minutes"],
                    }
        
        buildings.append({
            "type": building_type,
            "display_name": building_meta["display_name"],
            "icon": building_meta["icon"],
            "color": BUILDING_COLORS.get(building_type, "#666666"),
            "category": building_meta["category"],
            "description": building_meta["description"],
            "level": level,
            "max_level": max_level,
            "sort_order": building_meta.get("sort_order", 100),
            "upgrade_cost": upgrade_cost,
            "click_action": click_action,
            "catchup": catchup_info,
            "permit": permit_info,
            "tier_name": tier_name,
            "tier_benefit": tier_benefit,
            "all_tiers": all_tiers
        })
    
    return buildings


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in meters (Haversine formula)"""
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def _is_point_in_polygon(lat: float, lon: float, polygon: List[List[float]]) -> bool:
    """Check if a point is inside a polygon using ray-casting algorithm"""
    if not polygon or len(polygon) < 3:
        return False
    x, y = lat, lon
    n = len(polygon)
    inside = False
    p1x, p1y = polygon[0]
    for i in range(1, n + 1):
        p2x, p2y = polygon[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside


def _get_kingdom_data(db: Session, osm_ids: List[str], current_user=None) -> Dict[str, KingdomData]:
    """Get or create kingdom data for cities. Returns dict of osm_id -> KingdomData"""
    from db.models import UserKingdom
    from db.models import PlayerState
    
    if not osm_ids:
        return {}
    
    # Fetch existing kingdoms
    kingdoms = db.query(Kingdom).filter(Kingdom.id.in_(osm_ids)).all()
    existing_ids = {k.id for k in kingdoms}
    
    # Get user's current location and hometown (which kingdom they're in)
    user_current_kingdom_id = None
    user_hometown_kingdom_id = None
    if current_user:
        player_state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
        if player_state:
            user_current_kingdom_id = player_state.current_kingdom_id
            user_hometown_kingdom_id = player_state.hometown_kingdom_id
    
    # Get user's kingdoms for relationship checking
    user_kingdom_ids = set()
    user_empire_id = None  # User's empire ID (from hometown kingdom)
    if current_user:
        user_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).all()
        user_kingdom_ids = {k.id for k in user_kingdoms}
        # Get user's empire_id from their hometown kingdom
        if user_hometown_kingdom_id:
            hometown_kingdom = db.query(Kingdom).filter(Kingdom.id == user_hometown_kingdom_id).first()
            if hometown_kingdom:
                user_empire_id = hometown_kingdom.empire_id
    
    # Batch fetch ruler names
    ruler_ids = [k.ruler_id for k in kingdoms if k.ruler_id]
    rulers = {}
    if ruler_ids:
        ruler_users = db.query(User).filter(User.id.in_(ruler_ids)).all()
        rulers = {u.id: u.display_name for u in ruler_users}
    
    # Batch calculate population stats for all kingdoms
    from db.models import PlayerState, UserKingdom
    kingdom_ids = [k.id for k in kingdoms]
    
    # Count currently checked-in players per kingdom
    current_players = {}
    if kingdom_ids:
        player_counts = db.query(
            PlayerState.current_kingdom_id,
            func.count(PlayerState.user_id)
        ).filter(
            PlayerState.current_kingdom_id.in_(kingdom_ids)
        ).group_by(PlayerState.current_kingdom_id).all()
        current_players = {kingdom_id: count for kingdom_id, count in player_counts}
    
    # Count active citizens (all alive citizens whose hometown is this kingdom)
    from services.kingdom_service import get_active_citizens_batch
    active_citizens = get_active_citizens_batch(db, kingdom_ids)
    
    # Build result
    result = {}
    for kingdom in kingdoms:
        ruler_name = rulers.get(kingdom.ruler_id) if kingdom.ruler_id else None
        # Can claim ONLY if:
        # 1. Kingdom is unclaimed (no ruler)
        # 2. User doesn't already rule any kingdoms
        # 3. User is INSIDE this kingdom
        # 4. This is the user's HOMETOWN (you can only claim your hometown as your kingdom)
        can_claim = (
            kingdom.ruler_id is None and 
            len(user_kingdom_ids) == 0 and 
            user_current_kingdom_id == kingdom.id and
            user_hometown_kingdom_id == kingdom.id
        )
        
        # Can declare war / form alliance ONLY if:
        # - User is a ruler of a different kingdom
        # - User is INSIDE this kingdom (traveling into it)
        # - This kingdom has a ruler
        # - This kingdom's ruler is not the current user
        can_interact = (
            len(user_kingdom_ids) > 0 and
            user_current_kingdom_id == kingdom.id and
            kingdom.ruler_id is not None and
            kingdom.ruler_id != current_user.id if current_user else False
        )
        
        # Determine relationship to player using Alliance table
        is_allied = False
        is_enemy = False
        alliance_info = None
        
        if user_kingdom_ids and kingdom.ruler_id and kingdom.ruler_id != (current_user.id if current_user else None):
            # Get this kingdom's empire ID
            target_empire_id = kingdom.empire_id or kingdom.id
            
            # Check each of user's ruled kingdoms for alliance
            for user_kingdom_id in user_kingdom_ids:
                user_kingdom = db.query(Kingdom).filter(Kingdom.id == user_kingdom_id).first()
                if user_kingdom:
                    user_empire_id = user_kingdom.empire_id or user_kingdom.id
                    
                    # Check if allied using the Alliance table
                    if are_empires_allied(db, user_empire_id, target_empire_id):
                        is_allied = True
                        # Get alliance details for display
                        alliance = get_alliance_between(db, user_empire_id, target_empire_id)
                        if alliance:
                            alliance_info = {
                                "id": alliance.id,
                                "days_remaining": alliance.days_remaining,
                                "expires_at": alliance.expires_at.isoformat() if alliance.expires_at else None
                            }
                        break
            
            # Legacy enemy check (still using JSONB for now - wars not implemented yet)
            kingdom_enemies = set(kingdom.enemies) if kingdom.enemies else set()
            is_enemy = bool(user_kingdom_ids & kingdom_enemies)
        
        # Coup eligibility check
        can_stage_coup = False
        coup_ineligibility_reason = None
        
        if current_user and user_current_kingdom_id == kingdom.id:
            # Must be inside the kingdom to stage a coup
            if kingdom.ruler_id is None:
                coup_ineligibility_reason = "Kingdom has no ruler"
            elif kingdom.ruler_id == current_user.id:
                coup_ineligibility_reason = "You are the ruler"
            else:
                # Check player stats
                from routers.coups import (
                    COUP_LEADERSHIP_REQUIREMENT,
                    COUP_REPUTATION_REQUIREMENT,
                    _check_player_cooldown,
                    _check_kingdom_cooldown
                )
                
                player_state_for_coup = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
                user_kingdom_record = db.query(UserKingdom).filter(
                    UserKingdom.user_id == current_user.id,
                    UserKingdom.kingdom_id == kingdom.id
                ).first()
                kingdom_rep = int(user_kingdom_record.local_reputation) if user_kingdom_record else 0  # Convert float to int
                
                if player_state_for_coup.leadership < COUP_LEADERSHIP_REQUIREMENT:
                    coup_ineligibility_reason = f"Need T{COUP_LEADERSHIP_REQUIREMENT} leadership (you have T{player_state_for_coup.leadership})"
                elif kingdom_rep < COUP_REPUTATION_REQUIREMENT:
                    coup_ineligibility_reason = f"Need {COUP_REPUTATION_REQUIREMENT} kingdom rep (you have {kingdom_rep})"
                else:
                    # Check cooldowns
                    can_player, player_msg = _check_player_cooldown(db, current_user.id)
                    can_kingdom, kingdom_msg = _check_kingdom_cooldown(db, kingdom.id)
                    
                    if not can_player:
                        coup_ineligibility_reason = player_msg
                    elif not can_kingdom:
                        coup_ineligibility_reason = kingdom_msg
                    else:
                        can_stage_coup = True
        
        # SINGLE SOURCE OF TRUTH: Get buildings with all metadata, costs, and catchup info
        buildings_data = get_buildings_for_kingdom(db, kingdom, current_user)
        
        # Convert dicts to Pydantic models for this endpoint
        buildings = []
        for b in buildings_data:
            upgrade_cost = None
            if b["upgrade_cost"]:
                upgrade_cost = BuildingUpgradeCost(
                    actions_required=b["upgrade_cost"]["actions_required"],
                    construction_cost=b["upgrade_cost"]["construction_cost"],
                    can_afford=b["upgrade_cost"]["can_afford"]
                )
            
            click_action = None
            if b["click_action"]:
                click_action = BuildingClickAction(
                    type=b["click_action"]["type"],
                    resource=b["click_action"].get("resource")
                )
            
            catchup_info = None
            if b["catchup"]:
                catchup_info = BuildingCatchupInfo(
                    needs_catchup=b["catchup"]["needs_catchup"],
                    can_use=b["catchup"]["can_use"],
                    actions_required=b["catchup"]["actions_required"],
                    actions_completed=b["catchup"]["actions_completed"],
                    actions_remaining=b["catchup"]["actions_remaining"]
                )
            
            all_tiers = [
                BuildingTierInfo(
                    tier=t["tier"],
                    name=t["name"],
                    benefit=t["benefit"],
                    description=t["description"]
                ) for t in b["all_tiers"]
            ]
            
            buildings.append(BuildingData(
                type=b["type"],
                display_name=b["display_name"],
                icon=b["icon"],
                color=b["color"],
                category=b["category"],
                description=b["description"],
                level=b["level"],
                max_level=b["max_level"],
                sort_order=b["sort_order"],
                upgrade_cost=upgrade_cost,
                click_action=click_action,
                catchup=catchup_info,
                tier_name=b["tier_name"],
                tier_benefit=b["tier_benefit"],
                all_tiers=all_tiers
            ))
        
        # CALCULATE LIVE: Count players in kingdom RIGHT NOW
        checked_in_count = current_players.get(kingdom.id, 0)
        citizen_count = active_citizens.get(kingdom.id, 0)
        
        # Check for active battle involving this kingdom
        # A kingdom is "at war" if:
        # 1. It's being attacked (battle.kingdom_id == this kingdom) - coup or invasion target
        # 2. It's attacking another kingdom (battle.attacking_from_kingdom_id == this kingdom) - invasion source
        active_coup_data = None
        
        # First check if this kingdom is being attacked
        active_battle = db.query(Battle).filter(
            Battle.kingdom_id == kingdom.id,
            Battle.resolved_at.is_(None)
        ).first()
        
        # Also check if this kingdom is ATTACKING another kingdom (invasions only)
        attacking_battle = db.query(Battle).filter(
            Battle.attacking_from_kingdom_id == kingdom.id,
            Battle.resolved_at.is_(None)
        ).first()
        
        # Kingdom is at war if involved in any battle (attacking OR defending)
        is_at_war = (active_battle is not None) or (attacking_battle is not None)
        
        # For active_coup_data, show any battle this kingdom is involved in:
        # - Primary: battles targeting this kingdom (coups or invasions where this is the target)
        # - Secondary: battles where this kingdom is attacking (invasions launched from here)
        # This allows players in the attacking kingdom to access the invasion they're participating in
        battle_to_show = active_battle if active_battle else attacking_battle
        
        if battle_to_show:
            attacker_ids = battle_to_show.get_attacker_ids()
            defender_ids = battle_to_show.get_defender_ids()
            user_side = None
            can_pledge = False
            
            if current_user:
                if current_user.id in attacker_ids:
                    user_side = 'attackers'
                elif current_user.id in defender_ids:
                    user_side = 'defenders'
                
                # Can pledge if pledge phase is open and user hasn't pledged
                can_pledge = (
                    battle_to_show.is_pledge_phase and
                    current_user.id not in attacker_ids and
                    current_user.id not in defender_ids
                )
            
            active_coup_data = ActiveCoupData(
                id=battle_to_show.id,
                kingdom_id=kingdom.id,
                kingdom_name=kingdom.name,
                initiator_name=battle_to_show.initiator_name,
                status=battle_to_show.current_phase,
                time_remaining_seconds=battle_to_show.time_remaining_seconds,
                attacker_count=len(attacker_ids),
                defender_count=len(defender_ids),
                user_side=user_side,
                can_pledge=can_pledge,
                pledge_end_time=battle_to_show.pledge_end_time.isoformat() if battle_to_show.pledge_end_time else None,
                battle_type=battle_to_show.type  # "coup" or "invasion"
            )
        
        # Get active alliances for player's hometown only
        active_alliances_data = []
        print(f"🤝 Alliance check: kingdom.id={kingdom.id}, user_hometown_kingdom_id={user_hometown_kingdom_id}, match={kingdom.id == user_hometown_kingdom_id}")
        if kingdom.id == user_hometown_kingdom_id:
            # This is the player's hometown - fetch all active alliances
            hometown_empire_id = kingdom.empire_id or kingdom.id
            print(f"🤝 Fetching alliances for hometown empire: {hometown_empire_id}")
            try:
                alliance_list = get_active_alliances_for_empire(db, hometown_empire_id)
                print(f"🤝 Found {len(alliance_list)} alliances: {alliance_list}")
                active_alliances_data = [
                    ActiveAllianceInfo(**a) for a in alliance_list
                ]
                print(f"🤝 Created {len(active_alliances_data)} ActiveAllianceInfo objects")
            except Exception as e:
                print(f"🤝 ERROR fetching alliances: {e}")
                import traceback
                traceback.print_exc()
        
        # Is this kingdom part of the current user's empire?
        is_empire = False
        if user_empire_id and kingdom.empire_id:
            is_empire = kingdom.empire_id == user_empire_id
        
        result[kingdom.id] = KingdomData(
            id=kingdom.id,
            ruler_id=kingdom.ruler_id,
            ruler_name=ruler_name,
            level=kingdom.level,
            population=checked_in_count,  # LIVE COUNT of players in kingdom
            active_citizens=citizen_count,  # LIVE COUNT of active citizens
            treasury_gold=kingdom.treasury_gold,
            buildings=buildings,  # DYNAMIC BUILDINGS with metadata + upgrade costs
            travel_fee=kingdom.travel_fee,
            can_claim=can_claim,
            can_declare_war=can_interact,
            can_form_alliance=can_interact and not is_allied,  # Can't form if already allied
            is_allied=is_allied,
            is_enemy=is_enemy,
            is_empire=is_empire,  # True if this kingdom is ruled by current user
            alliance_info=AllianceInfo(**alliance_info) if alliance_info else None,
            allies=list(kingdom.allies) if kingdom.allies else [],
            enemies=list(kingdom.enemies) if kingdom.enemies else [],
            active_alliances=active_alliances_data,  # Only populated for player's hometown
            can_stage_coup=can_stage_coup,
            coup_ineligibility_reason=coup_ineligibility_reason,
            is_at_war=is_at_war,  # Backend is source of truth! (defending OR attacking)
            active_coup=active_coup_data
        )
    
    return result


def _ensure_kingdom_exists(db: Session, osm_id: str, name: str):
    """Create kingdom if it doesn't exist"""
    existing = db.query(Kingdom).filter(Kingdom.id == osm_id).first()
    if not existing:
        new_kingdom = Kingdom(
            id=osm_id,
            name=name,
            city_boundary_osm_id=osm_id,
            ruler_id=None,
            population=0,
            level=1,
            treasury_gold=0,
            townhall_level=1  # All kingdoms start with Town Hall level 1
        )
        db.add(new_kingdom)
        db.commit()


async def get_current_city(
    db: Session,
    lat: float,
    lon: float,
    current_user = None
) -> Optional[CityBoundaryResponse]:
    """
    FAST - Get ONLY the city the user is currently in.
    This should return in < 2 seconds to unblock the frontend.
    
    Strategy:
    1. Check cache first (instant)
    2. If not cached, call fast OSM query
    3. Fetch boundary for just this ONE city
    """
    print(f"🎯 Getting current city for ({lat:.4f}, {lon:.4f})")
    
    # Step 1: Check cache - find city user is inside
    lat_delta = 0.5  # ~55km
    lon_delta = 0.5 / max(0.1, math.cos(math.radians(lat)))
    
    cached_cities = db.query(CityBoundary).filter(
        CityBoundary.center_lat.between(lat - lat_delta, lat + lat_delta),
        CityBoundary.center_lon.between(lon - lon_delta, lon + lon_delta)
    ).all()
    
    # Check which cached cities user is inside - collect ALL matches
    matching_cities = []
    for city in cached_cities:
        boundary = city.boundary_geojson.get("coordinates", [])
        if boundary and _is_point_in_polygon(lat, lon, boundary):
            matching_cities.append((city, boundary))
    
    # Prefer highest admin_level (most specific: 8=city > 7=borough > 6=county)
    if matching_cities:
        matching_cities.sort(key=lambda x: x[0].admin_level, reverse=True)
        city, boundary = matching_cities[0]
        
        print(f"   💾 Found in cache: {city.name} (level {city.admin_level})")
        city.access_count += 1
        city.last_accessed = datetime.utcnow()
        db.commit()
        
        _ensure_kingdom_exists(db, city.osm_id, city.name)
        kingdoms = _get_kingdom_data(db, [city.osm_id], current_user)
        
        # Use cached simplified boundary if available, otherwise compute and store it
        if city.simplified_boundary_geojson:
            simplified = city.simplified_boundary_geojson.get("coordinates", [])
        else:
            # Backfill: Compute and store simplified boundary for this city
            simplified = simplify_boundary(boundary)
            city.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
            db.commit()
        
        return CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=simplified,
            radius_meters=city.radius_meters,
            cached=True,
            is_current=True,
            kingdom=kingdoms.get(city.osm_id)
        )
    
    # Step 2: Not in cache - call OSM
    print(f"   🌐 Not in cache, calling OSM...")
    city_info = await find_user_city_fast(lat, lon)
    
    if not city_info:
        print(f"   ⚠️ No city found at this location")
        return None
    
    osm_id = city_info["osm_id"]
    
    # Check if we have this city cached (just not with user inside)
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if cached:
        print(f"   💾 Found boundary in cache: {cached.name}")
        cached.access_count += 1
        cached.last_accessed = datetime.utcnow()
        db.commit()
        
        _ensure_kingdom_exists(db, cached.osm_id, cached.name)
        kingdoms = _get_kingdom_data(db, [cached.osm_id], current_user)
        
        # Use cached simplified boundary if available, otherwise compute and store it
        if cached.simplified_boundary_geojson:
            simplified = cached.simplified_boundary_geojson.get("coordinates", [])
        else:
            # Backfill: Compute and store simplified boundary for this city
            simplified = simplify_boundary(cached.boundary_geojson.get("coordinates", []))
            cached.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
            db.commit()
        
        return CityBoundaryResponse(
            osm_id=cached.osm_id,
            name=cached.name,
            admin_level=cached.admin_level,
            center_lat=cached.center_lat,
            center_lon=cached.center_lon,
            boundary=simplified,
            radius_meters=cached.radius_meters,
            cached=True,
            is_current=True,
            kingdom=kingdoms.get(cached.osm_id)
        )
    
    # Step 3: Fetch boundary from OSM
    print(f"   🌐 Fetching boundary for {city_info['name']}...")
    boundary_data = await fetch_city_boundary_by_id(osm_id, city_info.get("name", "Unknown"))
    
    if not boundary_data:
        # Return city with center only, no boundary
        print(f"   ⚠️ Could not fetch boundary, returning center only")
        _ensure_kingdom_exists(db, osm_id, city_info.get("name", "Unknown"))
        kingdoms = _get_kingdom_data(db, [osm_id], current_user)
        
        return CityBoundaryResponse(
            osm_id=osm_id,
            name=city_info.get("name", "Unknown"),
            admin_level=city_info.get("admin_level", 8),
            center_lat=city_info.get("center_lat", lat),
            center_lon=city_info.get("center_lon", lon),
            boundary=[],
            radius_meters=5000.0,
            cached=False,
            is_current=True,
            kingdom=kingdoms.get(osm_id)
        )
    
    # Cache it (with race condition protection)
    # Pre-compute and store simplified boundary for efficient retrieval
    simplified = simplify_boundary(boundary_data["boundary"])
    
    try:
        new_city = CityBoundary(
            osm_id=osm_id,
            name=boundary_data["name"],
            admin_level=boundary_data["admin_level"],
            center_lat=boundary_data["center_lat"],
            center_lon=boundary_data["center_lon"],
            boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
            simplified_boundary_geojson={"type": "Polygon", "coordinates": simplified},
            radius_meters=boundary_data["radius_meters"],
            boundary_points_count=len(boundary_data["boundary"]),
            access_count=1,
            osm_metadata=boundary_data.get("osm_tags", {})
        )
        db.add(new_city)
        db.commit()
    except Exception as e:
        # Race condition - another request already cached it
        db.rollback()
        if "duplicate key" in str(e).lower():
            print(f"   ⏭️  {osm_id} already cached by another request")
            # Fetch from DB to get the existing record
            cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
            if cached:
                cached.access_count += 1
                cached.last_accessed = datetime.utcnow()
                db.commit()
        else:
            # Some other error - re-raise
            raise
    
    _ensure_kingdom_exists(db, osm_id, boundary_data["name"])
    kingdoms = _get_kingdom_data(db, [osm_id], current_user)
    
    print(f"   ✅ Got current city: {boundary_data['name']}")
    
    return CityBoundaryResponse(
        osm_id=osm_id,
        name=boundary_data["name"],
        admin_level=boundary_data["admin_level"],
        center_lat=boundary_data["center_lat"],
        center_lon=boundary_data["center_lon"],
        boundary=simplified,  # Use pre-computed simplified boundary
        radius_meters=boundary_data["radius_meters"],
        cached=False,
        is_current=True,
        kingdom=kingdoms.get(osm_id)
    )


async def get_neighbor_cities(
    db: Session,
    lat: float,
    lon: float,
    current_user = None
) -> List[CityBoundaryResponse]:
    """
    Get cities that DIRECTLY TOUCH the current city (shared borders only).
    admin_level=8 ONLY (cities, not counties).
    """
    print(f"🏘️ Loading neighbors for ({lat:.4f}, {lon:.4f})")
    
    # Step 1: Find the current city (prefer highest admin_level)
    current_city = None
    lat_delta = 0.5
    lon_delta = 0.5 / max(0.1, math.cos(math.radians(lat)))
    
    cached_cities = db.query(CityBoundary).filter(
        CityBoundary.center_lat.between(lat - lat_delta, lat + lat_delta),
        CityBoundary.center_lon.between(lon - lon_delta, lon + lon_delta)
    ).all()
    
    # Find all cities containing the point, then pick highest admin_level
    matching_cities = []
    for city in cached_cities:
        boundary = city.boundary_geojson.get("coordinates", [])
        if boundary and _is_point_in_polygon(lat, lon, boundary):
            matching_cities.append(city)
    
    if matching_cities:
        matching_cities.sort(key=lambda c: c.admin_level, reverse=True)
        current_city = matching_cities[0]
    
    # Step 2: Get candidates (from cache or OSM)
    candidates = []
    is_boundary_sharing = True  # Assume true (already precise)
    
    if current_city and current_city.neighbor_ids is not None:
        print(f"   💾 Cached candidates for {current_city.name}")
        candidates = current_city.neighbor_ids  # Now stores full candidate dicts
        # Check if these were from boundary sharing or radius search
        is_boundary_sharing = candidates[0].get("is_boundary_sharing", True) if candidates else True
    
    # Step 3: Fetch from OSM if not cached
    if not candidates:
        print(f"   🌐 Fetching candidates from OSM...")
        
        candidates, is_boundary_sharing = await fetch_nearby_city_candidates(lat, lon)
        
        if not candidates:
            print(f"   ⚠️ No neighbors found")
            return []
        
        print(f"   🌐 OSM returned {len(candidates)} candidates")
        
        # Cache candidates with metadata
        if current_city:
            for c in candidates:
                c["is_boundary_sharing"] = is_boundary_sharing
            current_city.neighbor_ids = candidates
            current_city.neighbors_updated_at = datetime.utcnow()
            db.commit()
            print(f"   💾 Cached {len(candidates)} candidates for {current_city.name}")
    else:
        print(f"   🌐 Using {len(candidates)} cached candidates")
    
    # Step 4: Dynamic filtering based on source and cached boundaries
    # Boundary-sharing candidates are already precise; radius candidates need filtering
    current_boundary = None
    if current_city and current_city.boundary_geojson:
        coords = current_city.boundary_geojson.get("coordinates", [])
        if coords:
            current_boundary = [(c[0], c[1]) for c in coords]
    
    # Get cached boundaries for candidates
    candidate_osm_ids = [c["osm_id"] for c in candidates]
    cached_boundaries = {
        c.osm_id: [(p[0], p[1]) for p in c.boundary_geojson.get("coordinates", [])]
        for c in db.query(CityBoundary).filter(CityBoundary.osm_id.in_(candidate_osm_ids)).all()
        if c.boundary_geojson and c.boundary_geojson.get("coordinates")
    }
    
    neighbor_ids = []
    boundary_count = 0
    radius_count = 0
    
    for city in candidates:
        osm_id = city["osm_id"]
        source = city.get("source", "radius")
        
        if source == "boundary":
            # Boundary-sharing = already a true neighbor
            neighbor_ids.append(city)
            boundary_count += 1
        else:
            # Radius search = needs filtering
            if osm_id in cached_boundaries and current_boundary:
                # BEST: boundary-to-boundary check (precise)
                dist = _min_distance_between_polygons(current_boundary, cached_boundaries[osm_id])
                if dist <= 5000:  # Within 5km = neighbor (accounts for water/gaps)
                    city["edge_distance"] = dist
                    neighbor_ids.append(city)
                    radius_count += 1
            elif current_boundary:
                # FALLBACK: center-to-edge check (generous for cities across water/gaps)
                dist = _distance_to_polygon_edge(city["center_lat"], city["center_lon"], current_boundary)
                if dist <= 8000:  # Within 8km of edge - accounts for water/gaps
                    city["edge_distance"] = dist
                    neighbor_ids.append(city)
                    radius_count += 1
            else:
                # No boundary at all - include if reasonably close
                if city.get("distance", float('inf')) <= 15000:
                    neighbor_ids.append(city)
                    radius_count += 1
    
    neighbor_ids.sort(key=lambda c: c.get("edge_distance", c.get("distance", 0)))
    neighbor_ids = neighbor_ids[:20]
    print(f"   🎯 {len(neighbor_ids)} neighbors ({boundary_count} boundary, {radius_count} radius-filtered)")
    
    # EMPIRE EXPANSION: Also load neighbors of any empire kingdoms in the initial results
    # AND the current city if it's part of the empire
    if current_user:
        from db.models import PlayerState
        player_state = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
        print(f"   👑 Empire check: player_state={player_state is not None}, hometown={player_state.hometown_kingdom_id if player_state else None}")
        
        if player_state and player_state.hometown_kingdom_id:
            hometown = db.query(Kingdom).filter(Kingdom.id == player_state.hometown_kingdom_id).first()
            print(f"   👑 Hometown kingdom: {hometown.id if hometown else None}, empire_id={hometown.empire_id if hometown else None}")
            
            if hometown:
                # Use empire_id if set, otherwise hometown id IS the empire (capital)
                user_empire_id = hometown.empire_id or hometown.id
                print(f"   👑 User empire_id: {user_empire_id}")
                initial_osm_ids = {n["osm_id"] for n in neighbor_ids}
                
                # Also check if CURRENT city is part of empire
                empire_ids_to_expand = []
                if current_city:
                    current_kingdom = db.query(Kingdom).filter(Kingdom.id == current_city.osm_id).first()
                    if current_kingdom:
                        k_empire = current_kingdom.empire_id or current_kingdom.id
                        if k_empire == user_empire_id:
                            empire_ids_to_expand.append(current_city.osm_id)
                            print(f"   👑 Current city {current_city.name} is part of empire!")
                
                # Batch query: find which neighbors are empire kingdoms  
                neighbor_kingdoms = db.query(Kingdom).filter(Kingdom.id.in_(initial_osm_ids)).all()
                for k in neighbor_kingdoms:
                    k_empire = k.empire_id or k.id
                    if k_empire == user_empire_id:
                        empire_ids_to_expand.append(k.id)
                
                print(f"   👑 Empire kingdoms to expand: {empire_ids_to_expand}")
                
                if empire_ids_to_expand:
                    print(f"   👑 Found {len(empire_ids_to_expand)} empire kingdoms, expanding...")
                    
                    # Get cached neighbors for each empire kingdom
                    empire_cities = db.query(CityBoundary).filter(CityBoundary.osm_id.in_(empire_ids_to_expand)).all()
                    for empire_city in empire_cities:
                        # Fetch neighbors from OSM if not cached
                        if not empire_city.neighbor_ids:
                            print(f"   👑 Fetching neighbors for {empire_city.name} from OSM...")
                            emp_candidates, _ = await fetch_nearby_city_candidates(
                                empire_city.center_lat, 
                                empire_city.center_lon
                            )
                            if emp_candidates:
                                empire_city.neighbor_ids = emp_candidates
                                empire_city.neighbors_updated_at = datetime.utcnow()
                                db.commit()
                                print(f"   👑 Cached {len(emp_candidates)} neighbors for {empire_city.name}")
                        
                        if empire_city.neighbor_ids:
                            for emp_neighbor in empire_city.neighbor_ids:
                                if emp_neighbor["osm_id"] not in initial_osm_ids:
                                    neighbor_ids.append(emp_neighbor)
                                    initial_osm_ids.add(emp_neighbor["osm_id"])
                    
                    print(f"   👑 Expanded to {len(neighbor_ids)} total neighbors")
    
    # Check which ones we have cached
    osm_ids = [n["osm_id"] for n in neighbor_ids]
    cached_by_id = {c.osm_id: c for c in db.query(CityBoundary).filter(CityBoundary.osm_id.in_(osm_ids)).all()}
    
    print(f"   💾 {len(cached_by_id)}/{len(osm_ids)} boundaries cached")
    
    # Build result - return immediately with what we have
    result_cities = []
    
    for city_info in neighbor_ids:
        osm_id = city_info["osm_id"]
        name = city_info.get("name", "Unknown")
        
        _ensure_kingdom_exists(db, osm_id, name)
        
        if osm_id in cached_by_id:
            # Have boundary cached - return full data
            city = cached_by_id[osm_id]
            city.access_count += 1
            city.last_accessed = datetime.utcnow()
            result_cities.append(city)
        else:
            # NOT cached - return center point only
            temp_city = type('TempCity', (), {
                'osm_id': osm_id,
                'name': name,
                'admin_level': city_info.get("admin_level", 8),
                'center_lat': city_info.get("center_lat", 0.0),
                'center_lon': city_info.get("center_lon", 0.0),
                'boundary_geojson': {"coordinates": []},  # Empty - frontend should fetch via batch endpoint
                'simplified_boundary_geojson': None,  # No cached simplified boundary
                'radius_meters': 5000.0,  # Estimated
                'cached': False
            })()
            result_cities.append(temp_city)
    
    db.commit()
    
    # Get kingdom data
    kingdoms = _get_kingdom_data(db, [c.osm_id for c in result_cities], current_user)
    
    cached_count = len(cached_by_id)
    uncached_count = len(result_cities) - cached_count
    print(f"   ✅ Returning {len(result_cities)} neighbors ({cached_count} with boundaries, {uncached_count} center-only)")
    
    # Build response with cached simplified boundaries
    response = []
    for city in result_cities:
        # Use cached simplified boundary if available, otherwise compute and store it
        if city.simplified_boundary_geojson:
            simplified = city.simplified_boundary_geojson.get("coordinates", [])
        else:
            # Backfill: Compute and store simplified boundary for this city
            simplified = simplify_boundary(city.boundary_geojson.get("coordinates", []))
            city.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
        
        response.append(CityBoundaryResponse(
            osm_id=city.osm_id,
            name=city.name,
            admin_level=city.admin_level,
            center_lat=city.center_lat,
            center_lon=city.center_lon,
            boundary=simplified,
            radius_meters=city.radius_meters,
            cached=True,
            is_current=False,
            kingdom=kingdoms.get(city.osm_id)
        ))
    
    # Commit any backfill updates
    db.commit()
    
    return response


# Legacy endpoint - combines current + neighbors (for backward compat)
async def get_cities_near_location(
    db: Session,
    lat: float,
    lon: float,
    radius: float = 30.0,  # Ignored - kept for backward compat with legacy endpoint
    current_user = None
) -> List[CityBoundaryResponse]:
    """Legacy endpoint - returns current city + neighbors together"""
    current = await get_current_city(db, lat, lon, current_user)
    neighbors = await get_neighbor_cities(db, lat, lon, current_user)
    
    result = []
    if current:
        result.append(current)
    result.extend(neighbors)
    return result


async def get_city_boundary(db: Session, osm_id: str) -> Optional[BoundaryResponse]:
    """Lazy-load boundary for a single city."""
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    
    if cached:
        cached.access_count += 1
        cached.last_accessed = datetime.utcnow()
        db.commit()
        
        # Use cached simplified boundary if available, otherwise compute and store it
        if cached.simplified_boundary_geojson:
            simplified = cached.simplified_boundary_geojson.get("coordinates", [])
        else:
            # Backfill: Compute and store simplified boundary for this city
            simplified = simplify_boundary(cached.boundary_geojson.get("coordinates", []))
            cached.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
            db.commit()
        
        return BoundaryResponse(
            osm_id=cached.osm_id,
            name=cached.name,
            boundary=simplified,
            radius_meters=cached.radius_meters,
            from_cache=True
        )
    
    print(f"🌐 Lazy-loading boundary for {osm_id}")
    boundary_data = await fetch_city_boundary_by_id(osm_id)
    
    if not boundary_data:
        return None
    
    # Cache it (with race condition protection)
    # Pre-compute and store simplified boundary for efficient retrieval
    simplified = simplify_boundary(boundary_data["boundary"])
    
    try:
        new_city = CityBoundary(
            osm_id=osm_id,
            name=boundary_data["name"],
            admin_level=boundary_data["admin_level"],
            center_lat=boundary_data["center_lat"],
            center_lon=boundary_data["center_lon"],
            boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
            simplified_boundary_geojson={"type": "Polygon", "coordinates": simplified},
            radius_meters=boundary_data["radius_meters"],
            boundary_points_count=len(boundary_data["boundary"]),
            access_count=1,
            osm_metadata=boundary_data.get("osm_tags", {})
        )
        db.add(new_city)
        db.commit()
    except Exception as e:
        # Race condition - another request already cached it
        db.rollback()
        if "duplicate key" in str(e).lower():
            print(f"   ⏭️  {osm_id} already cached by another request")
            # Fetch from DB to get the existing record
            cached = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
            if cached:
                cached.access_count += 1
                cached.last_accessed = datetime.utcnow()
                db.commit()
        else:
            # Some other error - re-raise
            raise
    
    return BoundaryResponse(
        osm_id=osm_id,
        name=boundary_data["name"],
        boundary=simplified,  # Use pre-computed simplified boundary
        radius_meters=boundary_data["radius_meters"],
        from_cache=False
    )


async def get_city_boundaries_batch(db: Session, osm_ids: List[str]) -> List[BoundaryResponse]:
    """
    Fetch multiple city boundaries in parallel.
    
    Much faster than calling get_city_boundary() sequentially.
    Returns boundaries in same order as requested osm_ids.
    """
    print(f"📦 Batch loading {len(osm_ids)} boundaries...")
    
    # Check cache first
    cached = db.query(CityBoundary).filter(CityBoundary.osm_id.in_(osm_ids)).all()
    cached_by_id = {c.osm_id: c for c in cached}
    
    print(f"   💾 {len(cached)}/{len(osm_ids)} already cached")
    
    # Update access counts for cached items
    for city in cached:
        city.access_count += 1
        city.last_accessed = datetime.utcnow()
    db.commit()
    
    # Fetch missing ones in parallel
    missing_ids = [osm_id for osm_id in osm_ids if osm_id not in cached_by_id]
    
    if missing_ids:
        print(f"   🌐 Fetching {len(missing_ids)} from OSM in parallel...")
        
        # Fetch all in parallel using asyncio.gather
        fetch_tasks = [fetch_city_boundary_by_id(osm_id) for osm_id in missing_ids]
        boundary_results = await asyncio.gather(*fetch_tasks, return_exceptions=True)
        
        # Cache successful fetches
        newly_cached = {}
        for osm_id, boundary_data in zip(missing_ids, boundary_results):
            # Skip exceptions and None results
            if isinstance(boundary_data, Exception):
                print(f"   ❌ Error fetching {osm_id}: {boundary_data}")
                continue
            if not boundary_data:
                print(f"   ⚠️  No data for {osm_id}")
                continue
            
            try:
                # Pre-compute and store simplified boundary for efficient retrieval
                simplified = simplify_boundary(boundary_data["boundary"])
                
                new_city = CityBoundary(
                    osm_id=osm_id,
                    name=boundary_data["name"],
                    admin_level=boundary_data["admin_level"],
                    center_lat=boundary_data["center_lat"],
                    center_lon=boundary_data["center_lon"],
                    boundary_geojson={"type": "Polygon", "coordinates": boundary_data["boundary"]},
                    simplified_boundary_geojson={"type": "Polygon", "coordinates": simplified},
                    radius_meters=boundary_data["radius_meters"],
                    boundary_points_count=len(boundary_data["boundary"]),
                    access_count=1,
                    osm_metadata=boundary_data.get("osm_tags", {})
                )
                db.add(new_city)
                db.flush()  # Get it into session without committing
                newly_cached[osm_id] = new_city
                print(f"   ✅ Cached {boundary_data['name']}")
            except Exception as e:
                # Race condition - another request cached it
                db.rollback()
                if "duplicate key" in str(e).lower():
                    print(f"   ⏭️  {osm_id} already cached by another request")
                    # Fetch from DB
                    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
                    if city:
                        newly_cached[osm_id] = city
                else:
                    print(f"   ❌ Error caching {osm_id}: {e}")
        
        try:
            db.commit()
        except Exception as e:
            db.rollback()
            print(f"   ⚠️  Commit error (likely race condition): {e}")
            # Re-fetch to get latest state
            for osm_id in missing_ids:
                if osm_id not in newly_cached:
                    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
                    if city:
                        newly_cached[osm_id] = city
        
        # Update cached_by_id with newly cached items
        cached_by_id.update(newly_cached)
    
    # Build response in same order as input
    result = []
    for osm_id in osm_ids:
        if osm_id in cached_by_id:
            city = cached_by_id[osm_id]
            
            # Use cached simplified boundary if available, otherwise compute and store it
            if city.simplified_boundary_geojson:
                simplified = city.simplified_boundary_geojson.get("coordinates", [])
            else:
                # Backfill: Compute and store simplified boundary for this city
                simplified = simplify_boundary(city.boundary_geojson.get("coordinates", []))
                city.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
            
            result.append(BoundaryResponse(
                osm_id=city.osm_id,
                name=city.name,
                boundary=simplified,
                radius_meters=city.radius_meters,
                from_cache=(osm_id in cached_by_id and osm_id not in missing_ids)
            ))
        else:
            # Failed to fetch - return empty boundary
            result.append(BoundaryResponse(
                osm_id=osm_id,
                name=f"City-{osm_id}",
                boundary=[],
                radius_meters=5000.0,
                from_cache=False
            ))
    
    print(f"   ✅ Batch complete: {len([r for r in result if r.boundary])} with boundaries")
    return result


def get_city_by_id(db: Session, osm_id: str) -> Optional[CityBoundaryResponse]:
    """Get a specific city from cache"""
    city = db.query(CityBoundary).filter(CityBoundary.osm_id == osm_id).first()
    if not city:
        return None
    
    city.access_count += 1
    city.last_accessed = datetime.utcnow()
    db.commit()
    
    kingdoms = _get_kingdom_data(db, [osm_id], None)
    
    # Use cached simplified boundary if available, otherwise compute and store it
    if city.simplified_boundary_geojson:
        simplified = city.simplified_boundary_geojson.get("coordinates", [])
    else:
        # Backfill: Compute and store simplified boundary for this city
        simplified = simplify_boundary(city.boundary_geojson.get("coordinates", []))
        city.simplified_boundary_geojson = {"type": "Polygon", "coordinates": simplified}
        db.commit()
    
    return CityBoundaryResponse(
        osm_id=city.osm_id,
        name=city.name,
        admin_level=city.admin_level,
        center_lat=city.center_lat,
        center_lon=city.center_lon,
        boundary=simplified,
        radius_meters=city.radius_meters,
        cached=True,
        kingdom=kingdoms.get(osm_id)
    )


def get_city_stats(db: Session) -> dict:
    """Get cache statistics"""
    total = db.query(CityBoundary).count()
    top = db.query(CityBoundary).order_by(CityBoundary.access_count.desc()).limit(10).all()
    return {
        "total_cached": total,
        "top_accessed": [
            {"osm_id": c.osm_id, "name": c.name, "access_count": c.access_count}
            for c in top
        ]
    }
