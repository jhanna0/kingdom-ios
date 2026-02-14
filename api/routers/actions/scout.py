"""
UNIFIED SCOUT ACTION
====================
Single intelligence action with tiered outcomes based on player's intelligence level (T1-T5).

Simple roll-based system:
1. Player scouts in enemy territory
2. Success chance = base_success[tier] - (patrol_coverage × coverage_impact)
3. If successful, roll for outcome based on tier
4. If failed, caught - small rep penalty only

Patrol coverage = active_patrols / kingdom_citizens (ratio-based, scales with kingdom size)
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
import random

from db import get_db
from db.models import User, PlayerState, Kingdom, KingdomIntelligence, UserKingdom, Contract
from db.models.action_cooldown import ActionCooldown
from routers.auth import get_current_user
from routers.alliances import are_empires_allied
from .utils import set_cooldown, check_cooldown_from_table, format_datetime_iso, check_and_deduct_food_cost, log_activity
from db.models.kingdom_event import KingdomEvent
from sqlalchemy import text as sql_text

router = APIRouter()


# ============================================================
# TUNABLE CONSTANTS - Adjust these to balance the game!
# ============================================================

# Cooldown
SCOUT_COOLDOWN_MINUTES = 30

# Base success chance by intelligence tier (T1-T5)
# Higher tier = better base chance
BASE_SUCCESS_BY_TIER = {
    1: 0.30,   # T1: 30% base
    2: 0.40,   # T2: 40% base
    3: 0.52,   # T3: 52% base
    4: 0.65,   # T4: 65% base
    5: 0.80,   # T5: 80% base
}

# Patrol coverage impact
# Formula: effective_penalty = patrol_coverage × PATROL_COVERAGE_MULTIPLIER
# e.g., 50% coverage × 0.8 = 40% penalty
PATROL_COVERAGE_MULTIPLIER = 0.80

# Success chance bounds
MIN_SUCCESS_CHANCE = 0.10  # 10% floor - always some chance
MAX_SUCCESS_CHANCE = 0.90  # 90% ceiling - never guaranteed

# Minimum citizens for coverage calculation (prevents division issues in tiny kingdoms)
MIN_CITIZENS_FOR_COVERAGE = 5

# Intel storage duration
INTEL_EXPIRY_HOURS = 1

# Caught penalties
CAUGHT_REP_LOSS_TARGET = 5     # Rep lost in target kingdom when caught

# Success rewards
SUCCESS_REP_REWARD = 10        # Rep gained at home for successful scout (flat)

# Disruption outcome config (T4+)
DISRUPTION_CONTRACT_DELAY_PERCENT = 0.10  # Add 10% more actions to contract

# Vault heist outcome config (T5)
HEIST_VAULT_PERCENT = 0.10    # Steal 5% of vault
HEIST_MIN_GOLD = 50           # Minimum gold to steal
HEIST_MAX_GOLD = 1000         # Maximum gold to steal per heist


# ============================================================
# OUTCOME CONFIGURATION
# ============================================================

# Which outcomes are available at each tier
# Each tier ADDS to previous tiers (cumulative unlocks)
OUTCOMES_BY_TIER = {
    1: ["basic_intel"],
    2: ["basic_intel", "military_intel"],
    3: ["basic_intel", "military_intel", "building_intel"],
    4: ["basic_intel", "military_intel", "building_intel", "disruption"],
    5: ["basic_intel", "military_intel", "building_intel", "disruption", "vault_heist"],
}

# Human-readable descriptions for each outcome
OUTCOME_DESCRIPTIONS = {
    "basic_intel": "Population & citizen count",
    "military_intel": "Attack power, defense power, wall level",
    "building_intel": "All building levels revealed",
    "disruption": "Delay active contract by 10%",
    "vault_heist": "Steal 10% of vault gold",
}

# Which tier unlocks each outcome (for display)
OUTCOME_UNLOCK_TIER = {
    "basic_intel": 1,
    "military_intel": 2,
    "building_intel": 3,
    "disruption": 4,
    "vault_heist": 5,
}

# Chance of getting "nothing" by tier
# Higher tier = less chance of nothing
NOTHING_CHANCE_BY_TIER = {
    1: 0.70,  # T1: 70% nothing
    2: 0.60,  # T2: 60% nothing
    3: 0.50,  # T3: 50% nothing
    4: 0.40,  # T4: 40% nothing
    5: 0.30,  # T5: 30% nothing
}

# Relative weights for outcomes (when you DO get something)
OUTCOME_WEIGHTS = {
    "basic_intel": 30,
    "military_intel": 30,
    "building_intel": 20,
    "disruption": 15,
    "vault_heist": 5,
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_success_chance(intelligence_tier: int, patrol_coverage: float) -> float:
    """
    Calculate scout success probability.
    
    Formula: base_success[tier] - (patrol_coverage × PATROL_COVERAGE_MULTIPLIER)
    Clamped to [MIN_SUCCESS_CHANCE, MAX_SUCCESS_CHANCE]
    
    Args:
        intelligence_tier: Player's intelligence level (1-5)
        patrol_coverage: Ratio of patrols/citizens (0.0 to 1.0+)
    
    Returns:
        Success probability (0.0 to 1.0)
    """
    tier = max(1, min(5, intelligence_tier))
    base_success = BASE_SUCCESS_BY_TIER.get(tier, BASE_SUCCESS_BY_TIER[1])
    
    coverage_penalty = patrol_coverage * PATROL_COVERAGE_MULTIPLIER
    success_chance = base_success - coverage_penalty
    
    return max(MIN_SUCCESS_CHANCE, min(MAX_SUCCESS_CHANCE, success_chance))


def get_patrol_coverage(db: Session, kingdom_id: str) -> tuple[float, int, int]:
    """
    Calculate patrol coverage ratio for a kingdom.
    
    Returns:
        Tuple of (coverage_ratio, active_patrols, total_citizens)
    """
    now = datetime.utcnow()
    
    # Count citizens (hometown = this kingdom)
    total_citizens = db.query(PlayerState).filter(
        PlayerState.hometown_kingdom_id == kingdom_id,
        PlayerState.is_alive == True
    ).count()
    
    # Count active patrols (anyone patrolling in this kingdom)
    players_in_kingdom = db.query(PlayerState.user_id).filter(
        PlayerState.current_kingdom_id == kingdom_id
    ).all()
    user_ids = [p.user_id for p in players_in_kingdom]
    
    active_patrols = 0
    if user_ids:
        active_patrols = db.query(ActionCooldown).filter(
            ActionCooldown.user_id.in_(user_ids),
            ActionCooldown.action_type == "patrol",
            ActionCooldown.expires_at > now
        ).count()
    
    # Calculate coverage ratio
    effective_citizens = max(total_citizens, MIN_CITIZENS_FOR_COVERAGE)
    coverage_ratio = active_patrols / effective_citizens
    
    return coverage_ratio, active_patrols, total_citizens


def roll_for_outcome(intelligence_tier: int) -> str | None:
    """
    Roll for which outcome the player gets based on their tier.
    
    First rolls for "nothing" based on tier.
    If not nothing, rolls among available outcomes for tier.
    
    Returns None if "nothing" is rolled.
    """
    tier = max(1, min(5, intelligence_tier))
    
    # First: check if we get nothing
    nothing_chance = NOTHING_CHANCE_BY_TIER.get(tier, 0.50)
    if random.random() < nothing_chance:
        return None
    
    # We got something! Roll for which outcome
    available_outcomes = OUTCOMES_BY_TIER.get(tier, OUTCOMES_BY_TIER[1])
    
    # Build weighted list from available outcomes
    weights = [OUTCOME_WEIGHTS.get(outcome, 10) for outcome in available_outcomes]
    
    # Weighted random choice
    total = sum(weights)
    roll = random.random() * total
    cumulative = 0
    
    for i, outcome in enumerate(available_outcomes):
        cumulative += weights[i]
        if roll <= cumulative:
            return outcome
    
    return available_outcomes[0]  # Fallback


# ============================================================
# MAIN ENDPOINT
# ============================================================

@router.post("/scout")
def scout_enemy_kingdom(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Scout an enemy kingdom for intelligence.
    
    Requirements:
    - Must be checked into an enemy kingdom (not your hometown)
    - Intelligence T1+ required
    - Costs food only
    - 30 minute cooldown
    
    Success chance: base_success[tier] - (patrol_coverage × multiplier)
    
    Outcomes scale with tier:
    - T1: Basic intel (population)
    - T2: + Military intel (attack/defense, walls)
    - T3: + Building levels
    - T4: + Disruption (delay contracts)
    - T5: + Vault heist (steal gold)
    """
    state = user.player_state
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Must be checked into a kingdom
    if not state.current_kingdom_id:
        raise HTTPException(status_code=400, detail="Must be checked into a kingdom")
    
    target_kingdom_id = state.current_kingdom_id
    
    # Cannot scout your hometown
    if state.hometown_kingdom_id == target_kingdom_id:
        raise HTTPException(status_code=400, detail="Cannot scout your own kingdom")
    
    # Must have a hometown
    if not state.hometown_kingdom_id:
        raise HTTPException(status_code=400, detail="Must have a home kingdom")
    
    # Get target kingdom early to check if it has a ruler
    kingdom = db.query(Kingdom).filter(Kingdom.id == target_kingdom_id).first()
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    # Can only scout kingdoms with rulers (unclaimed kingdoms have no secrets)
    if not kingdom.ruler_id:
        raise HTTPException(status_code=400, detail="Cannot scout unclaimed kingdoms")
    
    # Intelligence T1+ required
    if state.intelligence < 1:
        raise HTTPException(
            status_code=400,
            detail=f"Intelligence T1+ required (you have T{state.intelligence})"
        )
    
    # Check cooldown
    cooldown_check = check_cooldown_from_table(db, user.id, "scout", SCOUT_COOLDOWN_MINUTES)
    if not cooldown_check["ready"]:
        remaining = cooldown_check["seconds_remaining"]
        mins = int(remaining / 60)
        secs = int(remaining % 60)
        raise HTTPException(
            status_code=429,
            detail=f"Scout on cooldown. Wait {mins}m {secs}s."
        )
    
    # Check and deduct food cost
    food_result = check_and_deduct_food_cost(db, user.id, SCOUT_COOLDOWN_MINUTES, "scouting")
    if not food_result["success"]:
        raise HTTPException(status_code=400, detail=food_result["error"])
    
    # Cannot spy on allies
    home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
    if home_kingdom and are_empires_allied(
        db,
        home_kingdom.empire_id or home_kingdom.id,
        kingdom.empire_id or kingdom.id
    ):
        raise HTTPException(status_code=400, detail="Cannot spy on allies!")
    
    # Set cooldown
    cooldown_expires = datetime.utcnow() + timedelta(minutes=SCOUT_COOLDOWN_MINUTES)
    set_cooldown(db, user.id, "scout", cooldown_expires)
    
    # =====================================================
    # UPDATE INTELLIGENCE STATS - Operations Attempted
    # =====================================================
    db.execute(sql_text("""
        INSERT INTO player_intelligence_stats (user_id, operations_attempted)
        VALUES (:user_id, 1)
        ON CONFLICT (user_id) DO UPDATE SET
            operations_attempted = player_intelligence_stats.operations_attempted + 1,
            updated_at = NOW()
    """), {"user_id": user.id})
    
    # Calculate patrol coverage and success chance
    patrol_coverage, active_patrols, total_citizens = get_patrol_coverage(db, target_kingdom_id)
    success_chance = calculate_success_chance(state.intelligence, patrol_coverage)
    
    # Roll for success
    roll = random.random()
    success = roll < success_chance
    
    if not success:
        # CAUGHT! Small rep penalty in target kingdom
        _apply_caught_penalties(db, user, state)
        db.commit()
        
        return {
            "success": False,
            "caught": True,
            "message": f"Caught by {kingdom.name}'s patrols! -{CAUGHT_REP_LOSS_TARGET} rep in {kingdom.name}.",
            "food_spent": food_result["food_cost"],
            "reputation_lost": CAUGHT_REP_LOSS_TARGET,
            "success_chance": round(success_chance * 100, 1),
            "roll": round(roll * 100, 1),
            "patrol_coverage": round(patrol_coverage * 100, 1),
            "active_patrols": active_patrols,
            "kingdom_citizens": total_citizens,
            "intelligence_tier": state.intelligence,
        }
    
    # SUCCESS! Roll for outcome
    outcome = roll_for_outcome(state.intelligence)
    
    # Handle "nothing" outcome - treat it same as caught (player doesn't know the difference)
    if outcome is None:
        _apply_caught_penalties(db, user, state)
        db.commit()
        
        return {
            "success": False,
            "caught": True,
            "message": f"The enemy patrol was too strong. -{CAUGHT_REP_LOSS_TARGET} rep in {kingdom.name}.",
            "food_spent": food_result["food_cost"],
            "reputation_lost": CAUGHT_REP_LOSS_TARGET,
            "intelligence_tier": state.intelligence,
        }
    
    # Got something! Award rep, store intel and apply effects
    rep_reward = SUCCESS_REP_REWARD
    _award_home_reputation(db, state, rep_reward)
    _store_intel(db, user.id, state, kingdom, outcome)
    outcome_result = _apply_outcome(db, user, state, kingdom, outcome)
    
    # =====================================================
    # UPDATE INTELLIGENCE STATS - Successful Outcomes
    # =====================================================
    if outcome in ("basic_intel", "military_intel", "building_intel"):
        db.execute(sql_text("""
            INSERT INTO player_intelligence_stats (user_id, operations_succeeded, intel_gathered)
            VALUES (:user_id, 1, 1)
            ON CONFLICT (user_id) DO UPDATE SET
                operations_succeeded = player_intelligence_stats.operations_succeeded + 1,
                intel_gathered = player_intelligence_stats.intel_gathered + 1,
                updated_at = NOW()
        """), {"user_id": user.id})
    elif outcome == "disruption":
        db.execute(sql_text("""
            INSERT INTO player_intelligence_stats (user_id, operations_succeeded, sabotages_completed)
            VALUES (:user_id, 1, 1)
            ON CONFLICT (user_id) DO UPDATE SET
                operations_succeeded = player_intelligence_stats.operations_succeeded + 1,
                sabotages_completed = player_intelligence_stats.sabotages_completed + 1,
                updated_at = NOW()
        """), {"user_id": user.id})
    elif outcome == "vault_heist":
        db.execute(sql_text("""
            INSERT INTO player_intelligence_stats (user_id, operations_succeeded, heists_completed)
            VALUES (:user_id, 1, 1)
            ON CONFLICT (user_id) DO UPDATE SET
                operations_succeeded = player_intelligence_stats.operations_succeeded + 1,
                heists_completed = player_intelligence_stats.heists_completed + 1,
                updated_at = NOW()
        """), {"user_id": user.id})
    
    # Log activity (successful scout) - to home kingdom feed
    log_activity(
        db=db,
        user_id=user.id,
        action_type="scout",
        action_category="espionage",
        description=f"Scouted {kingdom.name}",
        kingdom_id=state.hometown_kingdom_id,
        amount=rep_reward,
        details={
            "target_kingdom": kingdom.name,
            "target_kingdom_id": target_kingdom_id,
            "outcome": outcome,
            "outcome_type": outcome_result.get("type"),
        }
    )
    
    # Alert TARGET kingdom they're being scouted (kingdom event)
    kingdom_event = KingdomEvent(
        kingdom_id=target_kingdom_id,
        title="Intelligence Operation Detected",
        description=f"Foreign agents have been gathering intelligence on your kingdom."
    )
    db.add(kingdom_event)
    
    db.commit()
    
    # Build success message with hometown rep gain
    success_message = f"{outcome_result['message']} +{rep_reward} rep in {home_kingdom.name}."
    
    return {
        "success": True,
        "caught": False,
        "message": success_message,
        "outcome": outcome_result,
        "food_spent": food_result["food_cost"],
        "reputation_gained": rep_reward,
        "hometown_kingdom_name": home_kingdom.name,
        "intel_expires_hours": INTEL_EXPIRY_HOURS,
        "success_chance": round(success_chance * 100, 1),
        "roll": round(roll * 100, 1),
        "patrol_coverage": round(patrol_coverage * 100, 1),
        "active_patrols": active_patrols,
        "kingdom_citizens": total_citizens,
        "intelligence_tier": state.intelligence,
    }


# ============================================================
# HELPER FUNCTIONS FOR OUTCOMES
# ============================================================

def _apply_caught_penalties(db: Session, user: User, state: PlayerState):
    """Apply penalties when caught scouting. Uses state.current_kingdom_id as target.
    
    Philosophy reduces reputation loss.
    """
    from .utils import deduct_reputation
    
    target_kingdom_id = state.current_kingdom_id
    
    # Lose reputation in target kingdom (philosophy reduces loss)
    deduct_reputation(
        db=db,
        user_id=user.id,
        kingdom_id=target_kingdom_id,
        base_amount=CAUGHT_REP_LOSS_TARGET,
        philosophy_level=state.philosophy or 0
    )
    


def _store_intel(db: Session, user_id: int, state: PlayerState, kingdom: Kingdom, outcome: str):
    """
    Store intel per (home_kingdom, target_kingdom, tier).
    
    - If same tier already exists → extend expiry (+1 hour from now)
    - If tier doesn't exist → create new record
    - Different tiers are separate records (T1, T2, T3 can coexist)
    
    outcome -> intel_level mapping:
    - basic_intel = 1
    - military_intel = 2  
    - building_intel = 3
    """
    outcome_to_level = {
        "basic_intel": 1,
        "military_intel": 2,
        "building_intel": 3,
    }
    intel_level = outcome_to_level.get(outcome, 0)
    
    # If outcome doesn't store intel (disruption, vault_heist), skip
    if intel_level == 0:
        return
    
    # Look for existing record with SAME tier
    existing_intel = db.query(KingdomIntelligence).filter(
        KingdomIntelligence.kingdom_id == kingdom.id,
        KingdomIntelligence.gatherer_kingdom_id == state.hometown_kingdom_id,
        KingdomIntelligence.intelligence_level == intel_level
    ).first()
    
    if existing_intel:
        # Same tier exists - extend expiry and update gatherer
        existing_intel.gatherer_id = user_id
        existing_intel.gathered_at = datetime.utcnow()
        existing_intel.expires_at = datetime.utcnow() + timedelta(hours=INTEL_EXPIRY_HOURS)
    else:
        # New tier - create record (minimal data, we fetch live when displaying)
        new_intel = KingdomIntelligence(
            kingdom_id=kingdom.id,
            gatherer_kingdom_id=state.hometown_kingdom_id,
            gatherer_id=user_id,
            intelligence_level=intel_level,
            gathered_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(hours=INTEL_EXPIRY_HOURS)
        )
        db.add(new_intel)


def _apply_outcome(db: Session, user: User, state: PlayerState, kingdom: Kingdom, outcome: str) -> dict:
    """Apply the outcome effect and return result details."""
    
    if outcome == "basic_intel":
        return {
            "type": "basic_intel",
            "message": f"Gathered basic intel on {kingdom.name}!",
        }
    
    elif outcome == "military_intel":
        return {
            "type": "military_intel",
            "message": f"Discovered {kingdom.name}'s military strength!",
        }
    
    elif outcome == "building_intel":
        return {
            "type": "building_intel",
            "message": f"Mapped out {kingdom.name}'s infrastructure!",
        }
    
    elif outcome == "disruption":
        # Delay active contract
        active_contract = db.query(Contract).filter(
            Contract.kingdom_id == kingdom.id,
            Contract.completed_at.is_(None)
        ).first()
        
        if active_contract:
            delay_actions = max(1, int(active_contract.actions_required * DISRUPTION_CONTRACT_DELAY_PERCENT))
            active_contract.actions_required += delay_actions
            return {
                "type": "disruption",
                "message": f"Sabotaged {kingdom.name}'s construction! Delayed by {delay_actions} actions.",
                "contract_delayed": True,
                "actions_added": delay_actions,
            }
        else:
            # No active contract, store basic intel instead
            _store_intel(db, user.id, state, kingdom, "basic_intel")
            return {
                "type": "basic_intel",
                "message": f"No active projects to disrupt. Gathered basic intel instead.",
            }
    
    elif outcome == "vault_heist":
        vault_gold = kingdom.vault_gold or 0
        steal_amount = int(vault_gold * HEIST_VAULT_PERCENT)
        steal_amount = max(HEIST_MIN_GOLD, min(HEIST_MAX_GOLD, steal_amount))
        
        if vault_gold >= steal_amount:
            kingdom.vault_gold = vault_gold - steal_amount
            state.gold += steal_amount
            return {
                "type": "vault_heist",
                "message": f"Vault heist successful! Stole {steal_amount}g from {kingdom.name}!",
                "gold_stolen": steal_amount,
            }
        else:
            # Vault too empty, store basic intel instead
            _store_intel(db, user.id, state, kingdom, "basic_intel")
            return {
                "type": "basic_intel",
                "message": f"Vault nearly empty. Gathered basic intel instead.",
            }
    
    # Fallback
    return {
        "type": "basic_intel",
        "message": f"Gathered intel on {kingdom.name}.",
    }


def _award_home_reputation(db: Session, state: PlayerState, rep_amount: int):
    """Award reputation at player's home kingdom with philosophy bonus."""
    from .utils import award_reputation
    
    award_reputation(
        db=db,
        user_id=state.user_id,
        kingdom_id=state.hometown_kingdom_id,
        base_amount=rep_amount,
        philosophy_level=state.philosophy or 0
    )


# ============================================================
# CONFIG ENDPOINT
# ============================================================

@router.get("/scout/config")
def get_scout_config():
    """Get scout configuration for frontend display."""
    return {
        "cooldown_minutes": SCOUT_COOLDOWN_MINUTES,
        "base_success_by_tier": {f"T{k}": f"{int(v*100)}%" for k, v in BASE_SUCCESS_BY_TIER.items()},
        "patrol_coverage_multiplier": PATROL_COVERAGE_MULTIPLIER,
        "min_success": f"{int(MIN_SUCCESS_CHANCE*100)}%",
        "max_success": f"{int(MAX_SUCCESS_CHANCE*100)}%",
        # Outcomes mapping - which tier unlocks which outcomes
        "outcomes_by_tier": {
            f"T{tier}": outcomes for tier, outcomes in OUTCOMES_BY_TIER.items()
        },
        "outcome_descriptions": OUTCOME_DESCRIPTIONS,
        "outcome_unlock_tier": OUTCOME_UNLOCK_TIER,
        "outcome_weights": OUTCOME_WEIGHTS,
        "intel_duration_hours": INTEL_EXPIRY_HOURS,
        "caught_penalty_rep": CAUGHT_REP_LOSS_TARGET,
        "success_reward_rep": SUCCESS_REP_REWARD,
    }
