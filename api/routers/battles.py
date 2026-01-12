"""
Unified Battle System - Coups and Invasions

Both use the same territory-based tug-of-war combat mechanics.
Differences are handled via the battle.type field.

Coup: Internal power struggle (3 territories, no walls)
Invasion: External conquest (5 territories, walls apply)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Tuple, Optional
import random

from db import get_db, User, PlayerState, Kingdom, ActionCooldown
from db.models import (
    Battle, BattleType, BattleParticipant, BattleTerritory,
    BattleAction, BattleInjury, FightSession, BattleRollOutcome,
    KingdomHistory, CheckInHistory, UserKingdom,
)
from systems.battle.config import (
    # Timing
    COUP_PLEDGE_DURATION_HOURS,
    INVASION_DECLARATION_HOURS,
    # Eligibility
    COUP_REPUTATION_REQUIREMENT,
    COUP_LEADERSHIP_REQUIREMENT,
    COUP_JOIN_REPUTATION_REQUIREMENT,
    # Cooldowns
    COUP_PLAYER_COOLDOWN_DAYS,
    COUP_KINGDOM_COOLDOWN_DAYS,
    INVASION_KINGDOM_COOLDOWN_DAYS,
    INVASION_AFTER_COUP_COOLDOWN_DAYS,
    BATTLE_BUFFER_DAYS,
    BATTLE_ACTION_COOLDOWN_MINUTES,
    INJURY_DURATION_MINUTES,
    # Territories
    get_territories_for_type,
    get_starting_bars_for_type,
    get_win_threshold_for_type,
    get_display_names_for_type,
    get_icons_for_type,
    # Combat
    calculate_roll_chances,
    calculate_push_per_hit,
    calculate_max_rolls,
    calculate_wall_defense,
    INJURE_PUSH_MULTIPLIER,
    WALL_DEFENSE_PER_LEVEL,
    # Rewards
    LOSER_GOLD_PERCENT,
    WINNER_REP_GAIN,
    LOSER_REP_LOSS,
    LOSER_ATTACK_LOSS,
    LOSER_DEFENSE_LOSS,
    LOSER_LEADERSHIP_LOSS,
    # Invasion-specific
    INVASION_TREASURY_TRANSFER_PERCENT,
    INVASION_ATTACKER_GOLD_TO_DEFENDERS_PERCENT,
)
from schemas.battle import (
    CoupInitiateRequest,
    InvasionDeclareRequest,
    BattleInitiateResponse,
    BattleJoinRequest,
    BattleJoinResponse,
    BattleEventResponse,
    BattleResolveResponse,
    BattleParticipantSchema,
    InitiatorStats,
    FightRequest,
    FightResponse,
    FightSessionResponse,
    FightRollResponse,
    FightResolveResponse,
    BattleTerritoryResponse,
    RollResult,
    ActiveBattlesResponse,
    BattleEligibilityResponse,
)
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso

router = APIRouter(prefix="/battles", tags=["Battles"])


# ===== Helper Functions =====

def _get_player_state(db: Session, user: User) -> PlayerState:
    """Get or create player state"""
    state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not state:
        state = PlayerState(user_id=user.id)
        db.add(state)
        db.commit()
        db.refresh(state)
    return state


def _get_kingdom_reputation(db: Session, user_id: int, kingdom_id: str) -> int:
    """Get player's reputation in a specific kingdom"""
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == user_id,
        UserKingdom.kingdom_id == kingdom_id
    ).first()
    return user_kingdom.local_reputation if user_kingdom else 0


def _has_visited_kingdom(db: Session, user_id: int, kingdom_id: str) -> bool:
    """Check if player has ever checked into a kingdom"""
    visit = db.query(CheckInHistory).filter(
        CheckInHistory.user_id == user_id,
        CheckInHistory.kingdom_id == kingdom_id
    ).first()
    return visit is not None


def _get_initiator_stats(db: Session, initiator_id: int, kingdom_id: str) -> Optional[InitiatorStats]:
    """Get full character sheet for the battle initiator"""
    user = db.query(User).filter(User.id == initiator_id).first()
    if not user:
        return None
    
    state = _get_player_state(db, user)
    kingdom_rep = _get_kingdom_reputation(db, user.id, kingdom_id)
    
    return InitiatorStats(
        level=state.level,
        kingdom_reputation=kingdom_rep,
        attack_power=state.attack_power,
        defense_power=state.defense_power,
        leadership=state.leadership,
        building_skill=state.building_skill,
        intelligence=state.intelligence,
        contracts_completed=state.contracts_completed,
        total_work_contributed=state.total_work_contributed,
        coups_won=state.coups_won,
        coups_failed=state.coups_failed
    )


def _get_participants_sorted(
    db: Session,
    player_ids: List[int],
    kingdom_id: str
) -> List[BattleParticipantSchema]:
    """Get participant list with stats, sorted by kingdom reputation descending."""
    participants = []
    
    for player_id in player_ids:
        user = db.query(User).filter(User.id == player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        kingdom_rep = _get_kingdom_reputation(db, user.id, kingdom_id)
        
        participants.append(BattleParticipantSchema(
            player_id=player_id,
            player_name=user.display_name,
            kingdom_reputation=kingdom_rep,
            attack_power=state.attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            level=state.level
        ))
    
    participants.sort(key=lambda p: p.kingdom_reputation, reverse=True)
    return participants


# ===== Cooldown Helpers =====

def _check_coup_player_cooldown(db: Session, user_id: int) -> Tuple[bool, str]:
    """Check if player can initiate coup (30 day cooldown)"""
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == 'coup'
    ).first()
    
    if cooldown_record and cooldown_record.last_performed:
        time_since = datetime.utcnow() - cooldown_record.last_performed
        cooldown = timedelta(days=COUP_PLAYER_COOLDOWN_DAYS)
        if time_since < cooldown:
            days_remaining = (cooldown - time_since).days + 1
            return False, f"You must wait {days_remaining} more days before starting another coup."
    return True, ""


def _check_kingdom_coup_cooldown(db: Session, kingdom_id: str) -> Tuple[bool, str]:
    """Check if kingdom has had a recent coup or is involved in any battle"""
    # Check for active battle (coup or invasion) targeting this kingdom
    active = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.resolved_at.is_(None)
    ).first()
    
    if active:
        return False, f"A {'coup' if active.is_coup else 'invasion'} is already in progress in this kingdom."
    
    # Check if this kingdom is currently ATTACKING another kingdom
    active_as_attacker = db.query(Battle).filter(
        Battle.attacking_from_kingdom_id == kingdom_id,
        Battle.resolved_at.is_(None)
    ).first()
    
    if active_as_attacker:
        return False, "This kingdom is currently invading another kingdom."
    
    # Check for recent resolved coup
    recent_coup = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.type == BattleType.COUP.value,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_coup:
        days_since = (datetime.utcnow() - recent_coup.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom had a coup recently. Wait {days_remaining} more days."
    
    # Check for recent resolved invasion (as target)
    recent_invasion = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.type == BattleType.INVASION.value,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_invasion:
        days_since = (datetime.utcnow() - recent_invasion.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom was invaded recently. Wait {days_remaining} more days."
    
    # Check for recent resolved invasion (as attacker)
    recent_as_attacker = db.query(Battle).filter(
        Battle.attacking_from_kingdom_id == kingdom_id,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_as_attacker:
        days_since = (datetime.utcnow() - recent_as_attacker.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom recently invaded another kingdom. Wait {days_remaining} more days."
    
    return True, ""


def _check_kingdom_invasion_cooldown(db: Session, kingdom_id: str) -> Tuple[bool, str]:
    """Check if kingdom can be invaded (no active battle, 7 day buffer for any battle involvement)"""
    # Check for active battle targeting this kingdom
    active = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.resolved_at.is_(None)
    ).first()
    
    if active:
        return False, f"A {'coup' if active.is_coup else 'invasion'} is already in progress in this kingdom."
    
    # Check if this kingdom is currently ATTACKING another kingdom
    active_as_attacker = db.query(Battle).filter(
        Battle.attacking_from_kingdom_id == kingdom_id,
        Battle.resolved_at.is_(None)
    ).first()
    
    if active_as_attacker:
        return False, "This kingdom is currently invading another kingdom."
    
    # Check for recent invasion (as target) - 7 day buffer
    recent_invasion = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.type == BattleType.INVASION.value,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_invasion:
        days_since = (datetime.utcnow() - recent_invasion.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom was invaded recently. Wait {days_remaining} more days."
    
    # Check for recent coup - 7 day buffer
    recent_coup = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.type == BattleType.COUP.value,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_coup:
        days_since = (datetime.utcnow() - recent_coup.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom had a coup recently. Wait {days_remaining} more days before invading."
    
    # Check for recent invasion (as attacker) - 7 day buffer
    recent_as_attacker = db.query(Battle).filter(
        Battle.attacking_from_kingdom_id == kingdom_id,
        Battle.resolved_at.isnot(None),
        Battle.resolved_at >= datetime.utcnow() - timedelta(days=BATTLE_BUFFER_DAYS)
    ).first()
    
    if recent_as_attacker:
        days_since = (datetime.utcnow() - recent_as_attacker.resolved_at).days
        days_remaining = BATTLE_BUFFER_DAYS - days_since
        return False, f"This kingdom recently invaded another kingdom. Wait {days_remaining} more days."
    
    return True, ""


# ===== Battle Phase Helpers =====

def _ensure_territories_exist(db: Session, battle: Battle) -> List[BattleTerritory]:
    """Create territories for a battle if they don't exist."""
    territories = db.query(BattleTerritory).filter(
        BattleTerritory.battle_id == battle.id
    ).all()
    
    expected_territories = get_territories_for_type(battle.type)
    starting_bars = get_starting_bars_for_type(battle.type)
    
    if len(territories) == len(expected_territories):
        return territories
    
    existing_names = {t.territory_name for t in territories}
    
    for territory_name in expected_territories:
        if territory_name not in existing_names:
            territory = BattleTerritory(
                battle_id=battle.id,
                territory_name=territory_name,
                control_bar=starting_bars.get(territory_name, 50.0)
            )
            db.add(territory)
            territories.append(territory)
    
    db.commit()
    
    return db.query(BattleTerritory).filter(
        BattleTerritory.battle_id == battle.id
    ).all()


def _get_battle_cooldown_seconds(db: Session, user_id: int, battle_id: int) -> int:
    """Get remaining cooldown seconds for battle action"""
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == f'battle_{battle_id}'
    ).first()
    
    if not cooldown_record or not cooldown_record.last_performed:
        return 0
    
    cooldown = timedelta(minutes=BATTLE_ACTION_COOLDOWN_MINUTES)
    time_since = datetime.utcnow() - cooldown_record.last_performed
    
    if time_since >= cooldown:
        return 0
    
    return int((cooldown - time_since).total_seconds())


def _set_battle_cooldown(db: Session, user_id: int, battle_id: int) -> None:
    """Set battle action cooldown for user"""
    action_type = f'battle_{battle_id}'
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == action_type
    ).first()
    
    if cooldown_record:
        cooldown_record.last_performed = datetime.utcnow()
    else:
        cooldown_record = ActionCooldown(
            user_id=user_id,
            action_type=action_type,
            last_performed=datetime.utcnow()
        )
        db.add(cooldown_record)


def _get_active_injury(db: Session, user_id: int, battle_id: int) -> Optional[BattleInjury]:
    """Get active injury for a player in a battle"""
    return db.query(BattleInjury).filter(
        BattleInjury.battle_id == battle_id,
        BattleInjury.player_id == user_id,
        BattleInjury.cleared_at.is_(None),
        BattleInjury.expires_at > datetime.utcnow()
    ).first()


def _get_side_avg_stat(db: Session, player_ids: List[int], stat: str) -> float:
    """Get average stat value for a side"""
    if not player_ids:
        return 1.0
    
    total = 0
    count = 0
    for player_id in player_ids:
        state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
        if state:
            total += getattr(state, stat, 1)
            count += 1
    
    return total / count if count > 0 else 1.0


def _perform_roll(attack: int, enemy_avg_defense: float) -> Tuple[float, str]:
    """Perform a single roll and return (roll_value, outcome)."""
    miss_chance, hit_chance, injure_chance = calculate_roll_chances(attack, enemy_avg_defense)
    
    roll = random.random()
    
    if roll < injure_chance:
        return roll, BattleRollOutcome.INJURE.value
    elif roll < injure_chance + hit_chance:
        return roll, BattleRollOutcome.HIT.value
    else:
        return roll, BattleRollOutcome.MISS.value


def _get_best_outcome(rolls: List[dict]) -> str:
    """Get the best outcome from multiple rolls."""
    outcomes = [r['outcome'] for r in rolls]
    
    if BattleRollOutcome.INJURE.value in outcomes:
        return BattleRollOutcome.INJURE.value
    elif BattleRollOutcome.HIT.value in outcomes:
        return BattleRollOutcome.HIT.value
    else:
        return BattleRollOutcome.MISS.value


def _pick_random_injury_target(
    db: Session, 
    battle: Battle, 
    enemy_side: str
) -> Optional[int]:
    """Pick a random enemy player to injure."""
    if enemy_side == "attackers":
        enemy_ids = battle.get_attacker_ids()
    else:
        enemy_ids = battle.get_defender_ids()
    
    if not enemy_ids:
        return None
    
    # Filter out already injured players
    already_injured = db.query(BattleInjury.player_id).filter(
        BattleInjury.battle_id == battle.id,
        BattleInjury.player_id.in_(enemy_ids),
        BattleInjury.cleared_at.is_(None),
        BattleInjury.expires_at > datetime.utcnow()
    ).all()
    
    already_injured_ids = {i[0] for i in already_injured}
    available_targets = [pid for pid in enemy_ids if pid not in already_injured_ids]
    
    if not available_targets:
        return None
    
    return random.choice(available_targets)


def _check_win_condition(db: Session, battle: Battle) -> Optional[str]:
    """Check if the battle is won. Returns 'attackers', 'defenders', or None."""
    territories = db.query(BattleTerritory).filter(
        BattleTerritory.battle_id == battle.id
    ).all()
    
    win_threshold = get_win_threshold_for_type(battle.type)
    
    attacker_captures = sum(1 for t in territories if t.captured_by == "attackers")
    defender_captures = sum(1 for t in territories if t.captured_by == "defenders")
    
    if attacker_captures >= win_threshold:
        return "attackers"
    if defender_captures >= win_threshold:
        return "defenders"
    
    return None


def _atomic_push_territory(
    db: Session,
    territory_id: int,
    side: str,
    push_amount: float
) -> dict:
    """
    Atomically push a territory bar and capture if threshold crossed.
    
    Uses a single UPDATE with RETURNING to prevent race conditions.
    Two players pushing simultaneously will each get correct results.
    
    Returns: {"bar_before": float, "bar_after": float, "captured_by": str|None, "newly_captured": bool}
    """
    from sqlalchemy import text
    
    # Attackers push toward 0, defenders push toward 100
    if side == "attackers":
        # Push down: bar = bar - push, capture if <= 0
        result = db.execute(text("""
            UPDATE battle_territories
            SET 
                control_bar = GREATEST(0.0, LEAST(100.0, control_bar - :push_amount)),
                captured_by = CASE 
                    WHEN captured_by IS NOT NULL THEN captured_by  -- Already captured
                    WHEN control_bar - :push_amount <= 0 THEN 'attackers'
                    ELSE NULL
                END,
                captured_at = CASE
                    WHEN captured_by IS NOT NULL THEN captured_at  -- Already captured
                    WHEN control_bar - :push_amount <= 0 THEN NOW()
                    ELSE NULL
                END,
                updated_at = NOW()
            WHERE id = :territory_id
            RETURNING 
                control_bar + :push_amount as bar_before,  -- Reconstruct original
                control_bar as bar_after,
                captured_by,
                (captured_by = 'attackers' AND captured_at >= NOW() - INTERVAL '1 second') as newly_captured
        """), {"territory_id": territory_id, "push_amount": push_amount}).fetchone()
    else:
        # Push up: bar = bar + push, capture if >= 100
        result = db.execute(text("""
            UPDATE battle_territories
            SET 
                control_bar = GREATEST(0.0, LEAST(100.0, control_bar + :push_amount)),
                captured_by = CASE 
                    WHEN captured_by IS NOT NULL THEN captured_by  -- Already captured
                    WHEN control_bar + :push_amount >= 100 THEN 'defenders'
                    ELSE NULL
                END,
                captured_at = CASE
                    WHEN captured_by IS NOT NULL THEN captured_at  -- Already captured
                    WHEN control_bar + :push_amount >= 100 THEN NOW()
                    ELSE NULL
                END,
                updated_at = NOW()
            WHERE id = :territory_id
            RETURNING 
                control_bar - :push_amount as bar_before,  -- Reconstruct original
                control_bar as bar_after,
                captured_by,
                (captured_by = 'defenders' AND captured_at >= NOW() - INTERVAL '1 second') as newly_captured
        """), {"territory_id": territory_id, "push_amount": push_amount}).fetchone()
    
    if not result:
        return {"bar_before": 0, "bar_after": 0, "captured_by": None, "newly_captured": False}
    
    return {
        "bar_before": result[0],
        "bar_after": result[1],
        "captured_by": result[2],
        "newly_captured": result[3] or False
    }


def _try_resolve_battle(db: Session, battle_id: int, winner_side: str) -> bool:
    """
    Atomically try to claim and resolve a battle.
    
    Uses SELECT FOR UPDATE SKIP LOCKED to:
    1. Lock the battle row (or skip if already locked)
    2. Check if already resolved
    3. Claim it if not
    
    Returns True if THIS call resolved it, False if already resolved or locked.
    """
    from sqlalchemy import text
    
    # Atomic claim: UPDATE only if not resolved, returns whether we got it
    result = db.execute(text("""
        UPDATE battles
        SET resolved_at = NOW(),
            attacker_victory = :attacker_victory,
            winner_side = :winner_side
        WHERE id = :battle_id
          AND resolved_at IS NULL
        RETURNING id
    """), {
        "battle_id": battle_id,
        "attacker_victory": winner_side == "attackers",
        "winner_side": winner_side
    }).fetchone()
    
    return result is not None


def _calculate_combat_strength(
    db: Session,
    player_ids: List[int],
    kingdom_id: str,
    include_wall_defense: bool = False,
    wall_level: int = 0
) -> Tuple[int, int, List[BattleParticipantSchema]]:
    """Calculate total attack and defense power for a list of players."""
    total_attack = 0
    total_defense = 0
    participants = []
    
    for player_id in player_ids:
        user = db.query(User).filter(User.id == player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        kingdom_rep = _get_kingdom_reputation(db, user.id, kingdom_id)
        
        attack_power = state.attack_power
        if state.attack_debuff and state.debuff_expires_at:
            if datetime.utcnow() < state.debuff_expires_at:
                attack_power = max(1, attack_power - state.attack_debuff)
        
        total_attack += attack_power
        total_defense += state.defense_power
        
        participants.append(BattleParticipantSchema(
            player_id=player_id,
            player_name=user.display_name,
            kingdom_reputation=kingdom_rep,
            attack_power=attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            level=state.level
        ))
    
    # Add wall defense for invasions
    if include_wall_defense:
        total_defense += calculate_wall_defense(wall_level)
    
    return total_attack, total_defense, participants


# ===== Resolution Helpers =====

def _apply_battle_outcome_bulk(
    db: Session,
    battle: Battle,
    kingdom: Kingdom,
    attacker_ids: List[int],
    defender_ids: List[int],
    attacker_victory: bool
) -> dict:
    """
    Apply rewards and penalties using bulk SQL operations.
    Handles 10k+ participants without timeout.
    
    COUP penalties (loser side):
    - 50% gold loss (redistributed to winners)
    - 100 reputation loss
    - NO skill loss
    
    INVASION penalties (attackers lose):
    - 50% of attacking kingdom's treasury → defending kingdom
    - 10% from each attacker's gold → split among defenders
    - 100 reputation loss
    - Skill loss (attack, defense, leadership -1 each)
    """
    from sqlalchemy import text
    
    winner_ids = attacker_ids if attacker_victory else defender_ids
    loser_ids = defender_ids if attacker_victory else attacker_ids
    
    if not winner_ids and not loser_ids:
        return {"old_ruler_id": kingdom.ruler_id, "old_ruler_name": None, "new_ruler_id": None, "new_ruler_name": None}
    
    gold_per_winner = 0
    
    if battle.is_coup:
        # COUP: Bulk operations for gold + rep, NO skill loss
        if loser_ids:
            # Step 1: Calculate total gold to redistribute (50% from each loser)
            total_gold_result = db.execute(text("""
                SELECT COALESCE(SUM(gold / 2), 0) as total_gold
                FROM player_states
                WHERE user_id = ANY(:loser_ids)
            """), {"loser_ids": loser_ids}).fetchone()
            total_gold = total_gold_result[0] if total_gold_result else 0
            
            # Step 2: Deduct 50% gold from losers
            db.execute(text("""
                UPDATE player_states
                SET gold = gold - (gold / 2),
                    updated_at = NOW()
                WHERE user_id = ANY(:loser_ids)
            """), {"loser_ids": loser_ids})
            
            # Step 3: Deduct reputation from losers
            db.execute(text("""
                UPDATE user_kingdoms
                SET local_reputation = GREATEST(0, local_reputation - :rep_loss)
                WHERE user_id = ANY(:loser_ids) AND kingdom_id = :kingdom_id
            """), {"loser_ids": loser_ids, "rep_loss": LOSER_REP_LOSS, "kingdom_id": kingdom.id})
            
            # Step 4: Distribute gold to winners
            if winner_ids and total_gold > 0:
                gold_per_winner = total_gold // len(winner_ids)
                db.execute(text("""
                    UPDATE player_states
                    SET gold = gold + :gold_share,
                        updated_at = NOW()
                    WHERE user_id = ANY(:winner_ids)
                """), {"gold_share": gold_per_winner, "winner_ids": winner_ids})
            
            # Step 5: Add reputation to winners (upsert)
            if winner_ids:
                db.execute(text("""
                    INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation)
                    SELECT unnest(:winner_ids::bigint[]), :kingdom_id, :rep_gain
                    ON CONFLICT (user_id, kingdom_id)
                    DO UPDATE SET local_reputation = user_kingdoms.local_reputation + :rep_gain
                """), {"winner_ids": winner_ids, "kingdom_id": kingdom.id, "rep_gain": WINNER_REP_GAIN})
    
    elif battle.is_invasion:
        if attacker_victory:
            # INVASION SUCCESS: Defenders lose - 50% gold, rep, skills
            if loser_ids:
                # Calculate total gold
                total_gold_result = db.execute(text("""
                    SELECT COALESCE(SUM(gold / 2), 0) as total_gold
                    FROM player_states
                    WHERE user_id = ANY(:loser_ids)
                """), {"loser_ids": loser_ids}).fetchone()
                total_gold = total_gold_result[0] if total_gold_result else 0
                
                # Deduct gold + skills from losers
                db.execute(text("""
                    UPDATE player_states
                    SET gold = gold - (gold / 2),
                        attack_power = GREATEST(1, attack_power - :atk_loss),
                        defense_power = GREATEST(1, defense_power - :def_loss),
                        leadership = GREATEST(0, leadership - :lead_loss),
                        updated_at = NOW()
                    WHERE user_id = ANY(:loser_ids)
                """), {
                    "loser_ids": loser_ids,
                    "atk_loss": LOSER_ATTACK_LOSS,
                    "def_loss": LOSER_DEFENSE_LOSS,
                    "lead_loss": LOSER_LEADERSHIP_LOSS
                })
                
                # Deduct reputation
                db.execute(text("""
                    UPDATE user_kingdoms
                    SET local_reputation = GREATEST(0, local_reputation - :rep_loss)
                    WHERE user_id = ANY(:loser_ids) AND kingdom_id = :kingdom_id
                """), {"loser_ids": loser_ids, "rep_loss": LOSER_REP_LOSS, "kingdom_id": kingdom.id})
                
                # Distribute gold to winners
                if winner_ids and total_gold > 0:
                    gold_per_winner = total_gold // len(winner_ids)
                    db.execute(text("""
                        UPDATE player_states
                        SET gold = gold + :gold_share,
                            updated_at = NOW()
                        WHERE user_id = ANY(:winner_ids)
                    """), {"gold_share": gold_per_winner, "winner_ids": winner_ids})
                
                # Add reputation to winners
                if winner_ids:
                    db.execute(text("""
                        INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation)
                        SELECT unnest(:winner_ids::bigint[]), :kingdom_id, :rep_gain
                        ON CONFLICT (user_id, kingdom_id)
                        DO UPDATE SET local_reputation = user_kingdoms.local_reputation + :rep_gain
                    """), {"winner_ids": winner_ids, "kingdom_id": kingdom.id, "rep_gain": WINNER_REP_GAIN})
        
        else:
            # INVASION FAILED: Attackers lose
            # 1. 50% of attacking kingdom's treasury → defending kingdom
            if battle.attacking_from_kingdom_id:
                # Single atomic operation: transfer 50% treasury from attacker to defender
                db.execute(text("""
                    WITH transfer AS (
                        SELECT COALESCE(treasury_gold, 0) / 2 as amount
                        FROM kingdoms WHERE id = :attacking_id
                    )
                    UPDATE kingdoms AS k
                    SET treasury_gold = CASE 
                        WHEN k.id = :attacking_id THEN COALESCE(k.treasury_gold, 0) - (SELECT amount FROM transfer)
                        WHEN k.id = :defending_id THEN COALESCE(k.treasury_gold, 0) + (SELECT amount FROM transfer)
                    END
                    WHERE k.id IN (:attacking_id, :defending_id)
                """), {"attacking_id": battle.attacking_from_kingdom_id, "defending_id": kingdom.id})
            
            # 2. Calculate 10% from attackers' gold for defenders
            if attacker_ids:
                total_for_defenders_result = db.execute(text("""
                    SELECT COALESCE(SUM(gold / 10), 0) as total_gold
                    FROM player_states
                    WHERE user_id = ANY(:attacker_ids)
                """), {"attacker_ids": attacker_ids}).fetchone()
                total_for_defenders = total_for_defenders_result[0] if total_for_defenders_result else 0
                
                # Deduct 10% gold + skills from attackers
                db.execute(text("""
                    UPDATE player_states
                    SET gold = gold - (gold / 10),
                        attack_power = GREATEST(1, attack_power - :atk_loss),
                        defense_power = GREATEST(1, defense_power - :def_loss),
                        leadership = GREATEST(0, leadership - :lead_loss),
                        updated_at = NOW()
                    WHERE user_id = ANY(:attacker_ids)
                """), {
                    "attacker_ids": attacker_ids,
                    "atk_loss": LOSER_ATTACK_LOSS,
                    "def_loss": LOSER_DEFENSE_LOSS,
                    "lead_loss": LOSER_LEADERSHIP_LOSS
                })
                
                # Deduct reputation from attackers
                db.execute(text("""
                    UPDATE user_kingdoms
                    SET local_reputation = GREATEST(0, local_reputation - :rep_loss)
                    WHERE user_id = ANY(:attacker_ids) AND kingdom_id = :kingdom_id
                """), {"attacker_ids": attacker_ids, "rep_loss": LOSER_REP_LOSS, "kingdom_id": kingdom.id})
                
                # Distribute gold to defenders
                if defender_ids and total_for_defenders > 0:
                    gold_per_winner = total_for_defenders // len(defender_ids)
                    db.execute(text("""
                        UPDATE player_states
                        SET gold = gold + :gold_share,
                            updated_at = NOW()
                        WHERE user_id = ANY(:defender_ids)
                    """), {"gold_share": gold_per_winner, "defender_ids": defender_ids})
                
                # Add reputation to defenders
                if defender_ids:
                    db.execute(text("""
                        INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation)
                        SELECT unnest(:defender_ids::bigint[]), :kingdom_id, :rep_gain
                        ON CONFLICT (user_id, kingdom_id)
                        DO UPDATE SET local_reputation = user_kingdoms.local_reputation + :rep_gain
                    """), {"defender_ids": defender_ids, "kingdom_id": kingdom.id, "rep_gain": WINNER_REP_GAIN})
    
    battle.gold_per_winner = gold_per_winner
    
    # Handle ruler change if attackers won
    old_ruler_id = kingdom.ruler_id
    old_ruler_name = None
    new_ruler_id = None
    new_ruler_name = None
    now = datetime.utcnow()
    
    battle.old_ruler_id = old_ruler_id
    
    if attacker_victory:
        initiator = db.query(User).filter(User.id == battle.initiator_id).first()
        if initiator:
            if old_ruler_id:
                old_ruler = db.query(User).filter(User.id == old_ruler_id).first()
                if old_ruler:
                    old_ruler_name = old_ruler.display_name
                
                db.execute(text("""
                    UPDATE kingdom_history
                    SET ended_at = :now
                    WHERE kingdom_id = :kingdom_id AND ruler_id = :ruler_id AND ended_at IS NULL
                """), {"now": now, "kingdom_id": kingdom.id, "ruler_id": old_ruler_id})
            
            kingdom.ruler_id = initiator.id
            kingdom.ruler_started_at = now
            kingdom.last_activity = now
            new_ruler_id = initiator.id
            new_ruler_name = initiator.display_name
            
            # For invasions, also change the empire
            if battle.is_invasion and battle.attacking_from_kingdom_id:
                attacking_kingdom = db.query(Kingdom).filter(
                    Kingdom.id == battle.attacking_from_kingdom_id
                ).first()
                if attacking_kingdom:
                    kingdom.empire_id = attacking_kingdom.empire_id or attacking_kingdom.id
            
            new_history = KingdomHistory(
                kingdom_id=kingdom.id,
                ruler_id=initiator.id,
                ruler_name=initiator.display_name,
                empire_id=kingdom.empire_id or kingdom.id,
                event_type='coup' if battle.is_coup else 'invasion',
                started_at=now,
                battle_id=battle.id
            )
            db.add(new_history)
    
    db.commit()
    
    return {
        "old_ruler_id": old_ruler_id,
        "old_ruler_name": old_ruler_name,
        "new_ruler_id": new_ruler_id,
        "new_ruler_name": new_ruler_name
    }


def _resolve_battle_victory(db: Session, battle: Battle, winner_side: str) -> bool:
    """
    Resolve the battle when a side wins via territory capture.
    
    Uses atomic database operation to prevent race conditions.
    Only ONE caller can successfully resolve - all others get False.
    
    Returns: True if this call resolved the battle, False if already resolved.
    """
    from db.models.kingdom_event import KingdomEvent
    
    # ATOMIC CLAIM: Only one request can win this race
    if not _try_resolve_battle(db, battle.id, winner_side):
        return False
    
    # We won the race - proceed with resolution
    attacker_victory = (winner_side == "attackers")
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == battle.kingdom_id).first()
    if not kingdom:
        db.commit()
        return True
    
    wall_level = kingdom.wall_level or 0 if battle.is_invasion else 0
    
    # Get participant IDs
    attacker_ids = battle.get_attacker_ids()
    defender_ids = battle.get_defender_ids()
    
    # Calculate strength for record-keeping only
    attacker_attack, _, _ = _calculate_combat_strength(
        db, attacker_ids, battle.kingdom_id
    )
    _, defender_defense, _ = _calculate_combat_strength(
        db, defender_ids, battle.kingdom_id,
        include_wall_defense=battle.is_invasion,
        wall_level=wall_level
    )
    
    # Update battle stats (the resolved_at, winner_side, attacker_victory already set by _try_resolve_battle)
    from sqlalchemy import text
    db.execute(text("""
        UPDATE battles
        SET attacker_strength = :atk_str,
            defender_strength = :def_str,
            total_defense_with_walls = :total_def,
            wall_defense_applied = :wall_def
        WHERE id = :battle_id
    """), {
        "battle_id": battle.id,
        "atk_str": attacker_attack,
        "def_str": defender_defense,
        "total_def": defender_defense,
        "wall_def": calculate_wall_defense(wall_level) if battle.is_invasion else None
    })
    
    # Use bulk SQL operations - handles 10k+ participants efficiently
    _apply_battle_outcome_bulk(db, battle, kingdom, attacker_ids, defender_ids, attacker_victory)
    
    battle_type_name = "Coup" if battle.is_coup else "Invasion"
    if attacker_victory:
        title = f"⚔️ {battle_type_name} Successful!"
        description = f"{battle.initiator_name} has overthrown the ruler and now controls {kingdom.name}!"
    else:
        title = f"🛡️ {battle_type_name} Defeated!"
        description = f"The defenders have crushed {battle.initiator_name}'s rebellion in {kingdom.name}!"
    
    event = KingdomEvent(
        kingdom_id=kingdom.id,
        title=title,
        description=description
    )
    db.add(event)
    
    db.commit()
    return True


# ===== Build Response Helper =====

def _build_battle_response(
    db: Session,
    battle: Battle,
    current_user: User,
    state: PlayerState
) -> BattleEventResponse:
    """Build a BattleEventResponse with full participant data"""
    kingdom = db.query(Kingdom).filter(Kingdom.id == battle.kingdom_id).first()
    
    ruler_id = kingdom.ruler_id if kingdom else None
    ruler_name = None
    ruler_stats = None
    if ruler_id:
        ruler = db.query(User).filter(User.id == ruler_id).first()
        if ruler:
            ruler_name = ruler.display_name
            ruler_stats = _get_initiator_stats(db, ruler_id, battle.kingdom_id)
    
    attacker_ids = battle.get_attacker_ids()
    defender_ids = battle.get_defender_ids()
    
    attackers = _get_participants_sorted(db, attacker_ids, battle.kingdom_id)
    defenders = _get_participants_sorted(db, defender_ids, battle.kingdom_id)
    
    user_side = None
    if current_user.id in attacker_ids:
        user_side = 'attackers'
    elif current_user.id in defender_ids:
        user_side = 'defenders'
    
    # Check if user can join
    can_join_battle = False
    if battle.can_join and current_user.id not in attacker_ids and current_user.id not in defender_ids:
        if battle.is_coup:
            rep = _get_kingdom_reputation(db, current_user.id, battle.kingdom_id)
            can_join_battle = rep >= COUP_JOIN_REPUTATION_REQUIREMENT
        else:
            can_join_battle = _has_visited_kingdom(db, current_user.id, battle.kingdom_id)
    
    initiator_stats = _get_initiator_stats(db, battle.initiator_id, battle.kingdom_id)
    
    # Battle phase data
    territories = []
    battle_cooldown_seconds = 0
    is_injured = False
    injury_expires_seconds = 0
    
    if battle.is_battle_phase or battle.is_resolved:
        territory_records = db.query(BattleTerritory).filter(
            BattleTerritory.battle_id == battle.id
        ).all()
        
        if battle.is_battle_phase and len(territory_records) < len(get_territories_for_type(battle.type)):
            territory_records = _ensure_territories_exist(db, battle)
        
        display_names = get_display_names_for_type(battle.type)
        icons = get_icons_for_type(battle.type)
        
        territories = [
            BattleTerritoryResponse(
                name=t.territory_name,
                display_name=display_names.get(t.territory_name, t.territory_name),
                icon=icons.get(t.territory_name, "mappin"),
                control_bar=round(t.control_bar, 2),
                captured_by=t.captured_by,
                captured_at=t.captured_at
            )
            for t in territory_records
        ]
        
        battle_cooldown_seconds = _get_battle_cooldown_seconds(db, current_user.id, battle.id)
        
        injury = _get_active_injury(db, current_user.id, battle.id)
        if injury:
            is_injured = True
            injury_expires_seconds = max(0, int((injury.expires_at - datetime.utcnow()).total_seconds()))
    
    winner_side = _check_win_condition(db, battle) if not battle.is_resolved else battle.winner_side
    
    # Attacking kingdom info for invasions
    attacking_from_name = None
    if battle.is_invasion and battle.attacking_from_kingdom_id:
        attacking_kingdom = db.query(Kingdom).filter(
            Kingdom.id == battle.attacking_from_kingdom_id
        ).first()
        if attacking_kingdom:
            attacking_from_name = attacking_kingdom.name
    
    return BattleEventResponse(
        id=battle.id,
        type=battle.type,
        kingdom_id=battle.kingdom_id,
        kingdom_name=kingdom.name if kingdom else None,
        attacking_from_kingdom_id=battle.attacking_from_kingdom_id,
        attacking_from_kingdom_name=attacking_from_name,
        initiator_id=battle.initiator_id,
        initiator_name=battle.initiator_name,
        initiator_stats=initiator_stats,
        ruler_id=ruler_id,
        ruler_name=ruler_name,
        ruler_stats=ruler_stats,
        status=battle.current_phase,
        start_time=battle.start_time,
        pledge_end_time=battle.pledge_end_time,
        time_remaining_seconds=battle.time_remaining_seconds,
        attackers=attackers,
        defenders=defenders,
        attacker_count=len(attacker_ids),
        defender_count=len(defender_ids),
        user_side=user_side,
        can_join=can_join_battle,
        territories=territories,
        battle_cooldown_seconds=battle_cooldown_seconds,
        is_injured=is_injured,
        injury_expires_seconds=injury_expires_seconds,
        wall_defense_applied=battle.wall_defense_applied,
        is_resolved=battle.is_resolved,
        attacker_victory=battle.attacker_victory,
        resolved_at=battle.resolved_at,
        winner_side=winner_side
    )


# ============================================================
# API ENDPOINTS
# ============================================================

# ----- Initiate Coup -----

@router.post("/coup/initiate", response_model=BattleInitiateResponse)
def initiate_coup(
    request: CoupInitiateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Initiate a coup in a kingdom."""
    state = _get_player_state(db, current_user)
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    if kingdom.ruler_id == current_user.id:
        raise HTTPException(status_code=400, detail="You already rule this kingdom")
    
    if state.current_kingdom_id != kingdom.id:
        raise HTTPException(status_code=400, detail="You must be checked in to this kingdom to initiate a coup")
    
    if state.leadership < COUP_LEADERSHIP_REQUIREMENT:
        raise HTTPException(
            status_code=400,
            detail=f"Need leadership tier {COUP_LEADERSHIP_REQUIREMENT} to initiate coup (you have tier {state.leadership})"
        )
    
    kingdom_rep = _get_kingdom_reputation(db, current_user.id, kingdom.id)
    if kingdom_rep < COUP_REPUTATION_REQUIREMENT:
        raise HTTPException(
            status_code=400,
            detail=f"Need {COUP_REPUTATION_REQUIREMENT} reputation in this kingdom (you have {kingdom_rep})"
        )
    
    can_coup, cooldown_msg = _check_coup_player_cooldown(db, current_user.id)
    if not can_coup:
        raise HTTPException(status_code=400, detail=cooldown_msg)
    
    can_coup_kingdom, kingdom_msg = _check_kingdom_coup_cooldown(db, kingdom.id)
    if not can_coup_kingdom:
        raise HTTPException(status_code=400, detail=kingdom_msg)
    
    # Record attempt time
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == current_user.id,
        ActionCooldown.action_type == 'coup'
    ).first()
    if cooldown_record:
        cooldown_record.last_performed = datetime.utcnow()
    else:
        cooldown_record = ActionCooldown(
            user_id=current_user.id,
            action_type='coup',
            last_performed=datetime.utcnow()
        )
        db.add(cooldown_record)
    
    now = datetime.utcnow()
    pledge_end_time = now + timedelta(hours=COUP_PLEDGE_DURATION_HOURS)
    
    battle = Battle(
        type=BattleType.COUP.value,
        kingdom_id=kingdom.id,
        initiator_id=current_user.id,
        initiator_name=current_user.display_name,
        start_time=now,
        pledge_end_time=pledge_end_time,
        attackers=[current_user.id],
        defenders=[]
    )
    
    db.add(battle)
    db.commit()
    db.refresh(battle)
    
    # Add initiator as participant
    battle.add_attacker(current_user.id)
    db.commit()
    
    return BattleInitiateResponse(
        success=True,
        message=f"Coup initiated in {kingdom.name}! Citizens have {COUP_PLEDGE_DURATION_HOURS} hours to choose sides.",
        battle_id=battle.id,
        battle_type="coup",
        pledge_end_time=pledge_end_time
    )


# ----- Declare Invasion -----

@router.post("/invasion/declare", response_model=BattleInitiateResponse)
def declare_invasion(
    request: InvasionDeclareRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Declare an invasion of a kingdom. Ruler must be present at target kingdom."""
    state = _get_player_state(db, current_user)
    
    # Check user is a ruler
    if not state.fiefs_ruled or len(state.fiefs_ruled) == 0:
        raise HTTPException(status_code=400, detail="You must rule a kingdom to declare an invasion")
    
    # Must be at the target kingdom
    if state.current_kingdom_id != request.target_kingdom_id:
        raise HTTPException(status_code=400, detail="You must be at the target kingdom to declare invasion")
    
    target_kingdom = db.query(Kingdom).filter(Kingdom.id == request.target_kingdom_id).first()
    if not target_kingdom:
        raise HTTPException(status_code=404, detail="Target kingdom not found")
    
    # Target must have a ruler
    if not target_kingdom.ruler_id:
        raise HTTPException(status_code=400, detail="Cannot invade a kingdom with no ruler")
    
    # Can't invade yourself
    if target_kingdom.ruler_id == current_user.id:
        raise HTTPException(status_code=400, detail="You already rule this kingdom")
    
    # Get attacking kingdom (one of the kingdoms the user rules)
    # Use the first one for now - could make this selectable
    attacking_from_id = state.fiefs_ruled[0]
    attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == attacking_from_id).first()
    
    if not attacking_kingdom:
        raise HTTPException(status_code=400, detail="Your kingdom not found")
    
    # Can't invade same empire
    attacker_empire = attacking_kingdom.empire_id or attacking_kingdom.id
    target_empire = target_kingdom.empire_id or target_kingdom.id
    if attacker_empire == target_empire:
        raise HTTPException(status_code=400, detail="Cannot invade your own empire")
    
    # Check cooldowns
    can_invade, msg = _check_kingdom_invasion_cooldown(db, target_kingdom.id)
    if not can_invade:
        raise HTTPException(status_code=400, detail=msg)
    
    now = datetime.utcnow()
    pledge_end_time = now + timedelta(hours=INVASION_DECLARATION_HOURS)
    
    battle = Battle(
        type=BattleType.INVASION.value,
        kingdom_id=target_kingdom.id,
        attacking_from_kingdom_id=attacking_from_id,
        initiator_id=current_user.id,
        initiator_name=current_user.display_name,
        start_time=now,
        pledge_end_time=pledge_end_time,
        attackers=[current_user.id],
        defenders=[]
    )
    
    db.add(battle)
    db.commit()
    db.refresh(battle)
    
    battle.add_attacker(current_user.id)
    db.commit()
    
    return BattleInitiateResponse(
        success=True,
        message=f"Invasion declared! {attacking_kingdom.name} will attack {target_kingdom.name} in {INVASION_DECLARATION_HOURS} hours.",
        battle_id=battle.id,
        battle_type="invasion",
        pledge_end_time=pledge_end_time
    )


# ----- Join Battle -----

@router.post("/{battle_id}/join", response_model=BattleJoinResponse)
def join_battle(
    battle_id: int,
    request: BattleJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Join a battle as attacker or defender."""
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    
    if not battle:
        raise HTTPException(status_code=404, detail="Battle not found")
    
    if not battle.can_join:
        raise HTTPException(status_code=400, detail="This battle has already been resolved")
    
    state = _get_player_state(db, current_user)
    
    attacker_ids = battle.get_attacker_ids()
    defender_ids = battle.get_defender_ids()
    
    if current_user.id in attacker_ids or current_user.id in defender_ids:
        raise HTTPException(status_code=400, detail="You have already joined this battle")
    
    if request.side not in ['attackers', 'defenders']:
        raise HTTPException(status_code=400, detail="Side must be 'attackers' or 'defenders'")
    
    # Check join requirements based on battle type
    if battle.is_coup:
        rep = _get_kingdom_reputation(db, current_user.id, battle.kingdom_id)
        if rep < COUP_JOIN_REPUTATION_REQUIREMENT:
            raise HTTPException(
                status_code=400,
                detail=f"Need {COUP_JOIN_REPUTATION_REQUIREMENT} reputation in this kingdom to join (you have {rep})"
            )
    else:  # Invasion
        if not _has_visited_kingdom(db, current_user.id, battle.kingdom_id):
            raise HTTPException(
                status_code=400,
                detail="You must have visited this kingdom at least once to join"
            )
    
    if request.side == 'attackers':
        battle.add_attacker(current_user.id)
    else:
        battle.add_defender(current_user.id)
    
    db.commit()
    db.refresh(battle)
    
    return BattleJoinResponse(
        success=True,
        message=f"You have joined the {request.side}!",
        side=request.side,
        attacker_count=len(battle.get_attacker_ids()),
        defender_count=len(battle.get_defender_ids())
    )


# ----- Get Active Battles -----

@router.get("/active", response_model=ActiveBattlesResponse)
def get_active_battles(
    kingdom_id: str = None,
    battle_type: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all active battles, optionally filtered."""
    query = db.query(Battle).filter(Battle.resolved_at.is_(None))
    
    if kingdom_id:
        query = query.filter(Battle.kingdom_id == kingdom_id)
    
    if battle_type:
        query = query.filter(Battle.type == battle_type)
    
    battles = query.order_by(Battle.start_time.desc()).all()
    
    state = _get_player_state(db, current_user)
    
    responses = [_build_battle_response(db, b, current_user, state) for b in battles]
    
    return ActiveBattlesResponse(
        active_battles=responses,
        count=len(responses)
    )


# ----- Get Battle Details -----

@router.get("/{battle_id}", response_model=BattleEventResponse)
def get_battle(
    battle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get details of a specific battle."""
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    
    if not battle:
        raise HTTPException(status_code=404, detail="Battle not found")
    
    state = _get_player_state(db, current_user)
    return _build_battle_response(db, battle, current_user, state)


# ----- Check Eligibility -----

@router.get("/eligibility/{kingdom_id}", response_model=BattleEligibilityResponse)
def check_battle_eligibility(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check if user can initiate a coup or invasion in a kingdom."""
    state = _get_player_state(db, current_user)
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    # Check for active battle
    active_battle = db.query(Battle).filter(
        Battle.kingdom_id == kingdom_id,
        Battle.resolved_at.is_(None)
    ).first()
    
    # Coup eligibility
    can_coup = True
    coup_reason = None
    
    if kingdom.ruler_id == current_user.id:
        can_coup = False
        coup_reason = "You already rule this kingdom"
    elif state.current_kingdom_id != kingdom_id:
        can_coup = False
        coup_reason = "Must be checked in to this kingdom"
    elif state.leadership < COUP_LEADERSHIP_REQUIREMENT:
        can_coup = False
        coup_reason = f"Need T{COUP_LEADERSHIP_REQUIREMENT} leadership"
    elif _get_kingdom_reputation(db, current_user.id, kingdom_id) < COUP_REPUTATION_REQUIREMENT:
        can_coup = False
        coup_reason = f"Need {COUP_REPUTATION_REQUIREMENT} reputation"
    else:
        ok, msg = _check_coup_player_cooldown(db, current_user.id)
        if not ok:
            can_coup = False
            coup_reason = msg
        else:
            ok, msg = _check_kingdom_coup_cooldown(db, kingdom_id)
            if not ok:
                can_coup = False
                coup_reason = msg
    
    # Invasion eligibility
    can_invade = True
    invasion_reason = None
    
    if not state.fiefs_ruled or len(state.fiefs_ruled) == 0:
        can_invade = False
        invasion_reason = "Must rule a kingdom to invade"
    elif kingdom.ruler_id == current_user.id:
        can_invade = False
        invasion_reason = "You already rule this kingdom"
    elif state.current_kingdom_id != kingdom_id:
        can_invade = False
        invasion_reason = "Must be at target kingdom to declare invasion"
    elif not kingdom.ruler_id:
        can_invade = False
        invasion_reason = "Cannot invade a kingdom with no ruler"
    else:
        # Check empire
        my_kingdom_id = state.fiefs_ruled[0]
        my_kingdom = db.query(Kingdom).filter(Kingdom.id == my_kingdom_id).first()
        if my_kingdom:
            my_empire = my_kingdom.empire_id or my_kingdom.id
            target_empire = kingdom.empire_id or kingdom.id
            if my_empire == target_empire:
                can_invade = False
                invasion_reason = "Cannot invade your own empire"
        
        if can_invade:
            ok, msg = _check_kingdom_invasion_cooldown(db, kingdom_id)
            if not ok:
                can_invade = False
                invasion_reason = msg
    
    # Can join active battle?
    can_join = False
    join_reason = None
    
    if active_battle:
        attacker_ids = active_battle.get_attacker_ids()
        defender_ids = active_battle.get_defender_ids()
        
        if current_user.id in attacker_ids or current_user.id in defender_ids:
            can_join = False
            join_reason = "Already joined"
        elif active_battle.is_coup:
            rep = _get_kingdom_reputation(db, current_user.id, kingdom_id)
            if rep >= COUP_JOIN_REPUTATION_REQUIREMENT:
                can_join = True
            else:
                join_reason = f"Need {COUP_JOIN_REPUTATION_REQUIREMENT} reputation"
        else:
            if _has_visited_kingdom(db, current_user.id, kingdom_id):
                can_join = True
            else:
                join_reason = "Must have visited this kingdom"
    
    return BattleEligibilityResponse(
        can_initiate_coup=can_coup,
        coup_reason=coup_reason,
        can_declare_invasion=can_invade,
        invasion_reason=invasion_reason,
        can_join_active_battle=can_join,
        active_battle_id=active_battle.id if active_battle else None,
        active_battle_type=active_battle.type if active_battle else None,
        join_reason=join_reason
    )


# ============================================================
# FIGHT SESSION ENDPOINTS
# ============================================================

@router.post("/{battle_id}/fight/start", response_model=FightSessionResponse)
def start_fight_session(
    battle_id: int,
    request: FightRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start a fight session on a territory."""
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if not battle:
        raise HTTPException(status_code=404, detail="Battle not found")
    
    if not battle.is_battle_phase:
        raise HTTPException(status_code=400, detail="Not in battle phase")
    
    attacker_ids = battle.get_attacker_ids()
    defender_ids = battle.get_defender_ids()
    
    if current_user.id in attacker_ids:
        user_side = "attackers"
        enemy_ids = defender_ids
    elif current_user.id in defender_ids:
        user_side = "defenders"
        enemy_ids = attacker_ids
    else:
        raise HTTPException(status_code=400, detail="You haven't joined this battle")
    
    # Check for existing session
    existing_session = db.query(FightSession).filter(
        FightSession.battle_id == battle_id,
        FightSession.player_id == current_user.id
    ).first()
    
    if existing_session:
        state = _get_player_state(db, current_user)
        attack_power = state.attack_power or 0
        miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, existing_session.enemy_avg_defense)
        
        display_names = get_display_names_for_type(battle.type)
        icons = get_icons_for_type(battle.type)
        
        return FightSessionResponse(
            success=True,
            message="Resuming existing fight",
            territory_name=existing_session.territory_name,
            territory_display_name=display_names.get(existing_session.territory_name, existing_session.territory_name),
            territory_icon=icons.get(existing_session.territory_name, "mappin"),
            side=existing_session.side,
            max_rolls=existing_session.max_rolls,
            rolls_completed=existing_session.rolls_completed,
            rolls_remaining=existing_session.rolls_remaining,
            rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in (existing_session.rolls or [])],
            miss_chance=int(miss_pct * 100),
            hit_chance=int(hit_pct * 100),
            injure_chance=int(injure_pct * 100),
            best_outcome=existing_session.best_outcome,
            can_roll=existing_session.can_roll,
            bar_before=existing_session.bar_before
        )
    
    # Check injury
    injury = _get_active_injury(db, current_user.id, battle_id)
    if injury:
        seconds_remaining = max(0, int((injury.expires_at - datetime.utcnow()).total_seconds()))
        raise HTTPException(status_code=400, detail=f"You are injured. {seconds_remaining}s remaining.")
    
    # Check cooldown
    cooldown_remaining = _get_battle_cooldown_seconds(db, current_user.id, battle_id)
    if cooldown_remaining > 0:
        raise HTTPException(status_code=400, detail=f"On cooldown. {cooldown_remaining}s remaining.")
    
    # Validate territory
    valid_territories = get_territories_for_type(battle.type)
    if request.territory not in valid_territories:
        raise HTTPException(status_code=400, detail=f"Invalid territory. Must be one of: {', '.join(valid_territories)}")
    
    # Get territory
    _ensure_territories_exist(db, battle)
    territory = db.query(BattleTerritory).filter(
        BattleTerritory.battle_id == battle_id,
        BattleTerritory.territory_name == request.territory
    ).first()
    
    if territory.is_captured:
        raise HTTPException(status_code=400, detail="Territory already captured")
    
    state = _get_player_state(db, current_user)
    attack_power = state.attack_power or 0
    max_rolls = calculate_max_rolls(attack_power)
    
    enemy_defense = _get_side_avg_stat(db, enemy_ids, 'defense_power')
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, enemy_defense)
    
    session = FightSession(
        battle_id=battle_id,
        player_id=current_user.id,
        territory_name=request.territory,
        side=user_side,
        max_rolls=max_rolls,
        rolls=[],
        hit_chance=int((hit_pct + injure_pct) * 100),
        enemy_avg_defense=enemy_defense,
        bar_before=territory.control_bar
    )
    db.add(session)
    db.commit()
    
    display_names = get_display_names_for_type(battle.type)
    icons = get_icons_for_type(battle.type)
    
    return FightSessionResponse(
        success=True,
        message="Fight started! Roll to attack.",
        territory_name=request.territory,
        territory_display_name=display_names.get(request.territory, request.territory),
        territory_icon=icons.get(request.territory, "mappin"),
        side=user_side,
        max_rolls=max_rolls,
        rolls_completed=0,
        rolls_remaining=max_rolls,
        rolls=[],
        miss_chance=int(miss_pct * 100),
        hit_chance=int(hit_pct * 100),
        injure_chance=int(injure_pct * 100),
        best_outcome="miss",
        can_roll=True,
        bar_before=territory.control_bar
    )


@router.post("/{battle_id}/fight/roll", response_model=FightRollResponse)
def execute_fight_roll(
    battle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Execute a single roll in the fight session."""
    session = db.query(FightSession).filter(
        FightSession.battle_id == battle_id,
        FightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=400, detail="No active fight. Start a fight first.")
    
    if not session.can_roll:
        raise HTTPException(status_code=400, detail="No rolls remaining. Resolve the fight.")
    
    state = _get_player_state(db, current_user)
    attack_power = state.attack_power or 0
    
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, session.enemy_avg_defense)
    
    roll = random.random()
    
    if roll < injure_pct:
        outcome = "injure"
    elif roll < injure_pct + hit_pct:
        outcome = "hit"
    else:
        outcome = "miss"
    
    roll_value = roll * 100
    
    session.add_roll(roll_value, outcome)
    db.commit()
    db.refresh(session)
    
    messages = {
        "injure": "CRITICAL HIT! Enemy injured!",
        "hit": "Direct hit!",
        "miss": "Miss..."
    }
    
    return FightRollResponse(
        success=True,
        message=messages.get(outcome, ""),
        roll=RollResult(value=roll_value, outcome=outcome),
        roll_number=session.rolls_completed,
        rolls_completed=session.rolls_completed,
        rolls_remaining=session.rolls_remaining,
        best_outcome=session.best_outcome,
        can_roll=session.can_roll
    )


@router.post("/{battle_id}/fight/resolve", response_model=FightResolveResponse)
def resolve_fight_session(
    battle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Resolve the fight session - apply push and set cooldown."""
    session = db.query(FightSession).filter(
        FightSession.battle_id == battle_id,
        FightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=400, detail="No active fight to resolve")
    
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    territory = db.query(BattleTerritory).filter(
        BattleTerritory.battle_id == battle_id,
        BattleTerritory.territory_name == session.territory_name
    ).first()
    
    if not battle or not territory:
        raise HTTPException(status_code=404, detail="Battle or territory not found")
    
    display_names = get_display_names_for_type(battle.type)
    icons = get_icons_for_type(battle.type)
    
    # Handle already captured territory
    if territory.is_captured:
        winner_side = _check_win_condition(db, battle)
        battle_won = winner_side is not None
        
        db.delete(session)
        _set_battle_cooldown(db, current_user.id, battle_id)
        db.commit()
        
        return FightResolveResponse(
            success=True,
            message=f"Territory captured by {territory.captured_by}!",
            roll_count=session.rolls_completed,
            rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in (session.rolls or [])],
            best_outcome=session.best_outcome,
            push_amount=0.0,
            bar_before=session.bar_before,
            bar_after=territory.control_bar,
            territory=BattleTerritoryResponse(
                name=territory.territory_name,
                display_name=display_names.get(territory.territory_name, territory.territory_name),
                icon=icons.get(territory.territory_name, "mappin"),
                control_bar=round(territory.control_bar, 2),
                captured_by=territory.captured_by,
                captured_at=territory.captured_at
            ),
            injured_player_name=None,
            battle_won=battle_won,
            winner_side=winner_side,
            cooldown_seconds=BATTLE_ACTION_COOLDOWN_MINUTES * 60
        )
    
    # Calculate push
    best_outcome = session.best_outcome
    push_amount = 0.0
    
    if best_outcome != "miss":
        if session.side == "attackers":
            side_ids = battle.get_attacker_ids()
        else:
            side_ids = battle.get_defender_ids()
        
        side_size = len(side_ids)
        avg_leadership = _get_side_avg_stat(db, side_ids, 'leadership')
        base_push = calculate_push_per_hit(side_size, avg_leadership)
        
        if best_outcome == "injure":
            push_amount = base_push * INJURE_PUSH_MULTIPLIER
        else:
            push_amount = base_push
    
    # ATOMIC territory push - prevents race conditions with 1000 concurrent Lambdas
    push_result = _atomic_push_territory(db, territory.id, session.side, push_amount)
    bar_before = push_result["bar_before"]
    bar_after = push_result["bar_after"]
    newly_captured = push_result["newly_captured"]
    
    # Handle injury
    injured_player_name = None
    if best_outcome == "injure":
        enemy_side = "defenders" if session.side == "attackers" else "attackers"
        injured_id = _pick_random_injury_target(db, battle, enemy_side)
        if injured_id:
            injured_user = db.query(User).filter(User.id == injured_id).first()
            if injured_user:
                injured_player_name = injured_user.display_name
                injury = BattleInjury(
                    battle_id=battle_id,
                    player_id=injured_id,
                    injured_by_id=current_user.id,
                    expires_at=datetime.utcnow() + timedelta(minutes=INJURY_DURATION_MINUTES)
                )
                db.add(injury)
    
    # Log action
    action = BattleAction(
        battle_id=battle_id,
        player_id=current_user.id,
        territory_name=session.territory_name,
        side=session.side,
        roll_count=session.rolls_completed,
        rolls=session.rolls,
        best_outcome=best_outcome,
        push_amount=push_amount,
        bar_before=bar_before,
        bar_after=bar_after
    )
    db.add(action)
    
    _set_battle_cooldown(db, current_user.id, battle_id)
    
    # Check win - only if THIS push captured a territory
    battle_won = False
    winner_side = None
    
    if newly_captured:
        winner_side = _check_win_condition(db, battle)
        if winner_side:
            # ATOMIC resolution - only ONE Lambda wins this race
            battle_won = _resolve_battle_victory(db, battle, winner_side)
    
    # Save session data before deleting
    session_rolls = session.rolls or []
    session_rolls_completed = session.rolls_completed
    
    db.delete(session)
    db.commit()
    
    # Refresh territory to get current state
    db.refresh(territory)
    
    # Build message
    if battle_won:
        message = f"VICTORY! {winner_side.upper()} have won!"
    elif newly_captured:
        message = f"Territory captured by {push_result['captured_by']}!"
    elif best_outcome == "miss":
        message = "All attacks missed. No progress."
    else:
        message = f"Pushed the bar by {push_amount:.2f}!"
    
    return FightResolveResponse(
        success=True,
        message=message,
        roll_count=session_rolls_completed,
        rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in session_rolls],
        best_outcome=best_outcome,
        push_amount=push_amount,
        bar_before=bar_before,
        bar_after=bar_after,
        territory=BattleTerritoryResponse(
            name=territory.territory_name,
            display_name=display_names.get(territory.territory_name, territory.territory_name),
            icon=icons.get(territory.territory_name, "mappin"),
            control_bar=round(territory.control_bar, 2),
            captured_by=territory.captured_by,
            captured_at=territory.captured_at
        ),
        injured_player_name=injured_player_name,
        battle_won=battle_won,
        winner_side=winner_side,
        cooldown_seconds=BATTLE_ACTION_COOLDOWN_MINUTES * 60
    )


@router.get("/{battle_id}/fight/session", response_model=FightSessionResponse)
def get_fight_session(
    battle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current fight session if one exists."""
    session = db.query(FightSession).filter(
        FightSession.battle_id == battle_id,
        FightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="No active fight session")
    
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    display_names = get_display_names_for_type(battle.type) if battle else {}
    icons = get_icons_for_type(battle.type) if battle else {}
    
    state = _get_player_state(db, current_user)
    attack_power = state.attack_power or 0
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, session.enemy_avg_defense)
    
    return FightSessionResponse(
        success=True,
        message="Active fight session",
        territory_name=session.territory_name,
        territory_display_name=display_names.get(session.territory_name, session.territory_name),
        territory_icon=icons.get(session.territory_name, "mappin"),
        side=session.side,
        max_rolls=session.max_rolls,
        rolls_completed=session.rolls_completed,
        rolls_remaining=session.rolls_remaining,
        rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in (session.rolls or [])],
        miss_chance=int(miss_pct * 100),
        hit_chance=int(hit_pct * 100),
        injure_chance=int(injure_pct * 100),
        best_outcome=session.best_outcome,
        can_roll=session.can_roll,
        bar_before=session.bar_before
    )


@router.delete("/{battle_id}/fight/session")
def cancel_fight_session(
    battle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a fight session without resolving."""
    session = db.query(FightSession).filter(
        FightSession.battle_id == battle_id,
        FightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="No active fight session")
    
    db.delete(session)
    db.commit()
    
    return {"success": True, "message": "Fight cancelled"}
