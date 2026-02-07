"""
Coup system - Internal power struggles
Players can initiate coups to overthrow rulers using attack vs defense combat

Battle Phase:
- 3 territories with tug-of-war bars (0-100)
- Players fight every 10 minutes (cooldown-based)
- Win condition: First to capture 2 of 3 territories
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Tuple, Dict, Optional
import random

from db import get_db, User, PlayerState, Kingdom, CoupEvent, ActionCooldown
from db.models import (
    CoupTerritory, CoupBattleAction, CoupInjury, CoupFightSession, RollOutcome,
    TERRITORY_COUPERS, TERRITORY_CROWNS, TERRITORY_THRONE,
    TERRITORY_STARTING_BARS, TERRITORY_DISPLAY_NAMES, TERRITORY_ICONS,
)
from systems.coup.config import (
    SIZE_EXPONENT_BASE, LEADERSHIP_DAMPENING_PER_TIER,
    HIT_MULTIPLIER, INJURE_MULTIPLIER, INJURE_PUSH_MULTIPLIER,
    BATTLE_ACTION_COOLDOWN_MINUTES, INJURY_DURATION_MINUTES,
    calculate_roll_chances, calculate_push_per_hit, calculate_max_rolls,
)
from schemas.coup import (
    CoupInitiateRequest,
    CoupInitiateResponse,
    CoupJoinRequest,
    CoupJoinResponse,
    CoupEventResponse,
    CoupResolveResponse,
    CoupParticipant,
    ActiveCoupsResponse,
    InitiatorStats,
    CoupFightRequest,
    CoupFightResponse,
    CoupTerritoryResponse,
    RollResult,
    FightSessionResponse,
    FightRollResponse,
    FightResolveResponse,
)
from routers.auth import get_current_user
from routers.actions.utils import format_datetime_iso
from websocket.broadcast import notify_kingdom, KingdomEvents
from routers.alliances import get_allied_kingdom_ids
from db.models.kingdom_event import KingdomEvent

router = APIRouter(prefix="/coups", tags=["Coups"])


# ===== Constants =====
# Eligibility
COUP_REPUTATION_REQUIREMENT = 1000  # Kingdom reputation needed
COUP_LEADERSHIP_REQUIREMENT = 3    # T3 leadership needed

# Timing
PLEDGE_DURATION_HOURS = 12         # Phase 1: citizens pick sides (fixed 12h)
# Battle phase has no fixed duration - continues until resolution

# Cooldowns
PLAYER_COOLDOWN_DAYS = 30          # 30 days between coup attempts per player
KINGDOM_COOLDOWN_DAYS = 7          # 7 days between coups in same kingdom

# Legacy (keeping for resolution logic)

# Valid territory names
VALID_TERRITORIES = [TERRITORY_COUPERS, TERRITORY_CROWNS, TERRITORY_THRONE]


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


def _check_player_cooldown(db: Session, user_id: int) -> Tuple[bool, str]:
    """Check if player can initiate coup (30 day cooldown)"""
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == 'coup'
    ).first()
    
    if cooldown_record and cooldown_record.last_performed:
        time_since = datetime.utcnow() - cooldown_record.last_performed
        cooldown = timedelta(days=PLAYER_COOLDOWN_DAYS)
        if time_since < cooldown:
            days_remaining = (cooldown - time_since).days + 1
            return False, f"You must wait {days_remaining} more days before starting another coup."
    return True, ""


def _check_kingdom_cooldown(db: Session, kingdom_id: str) -> Tuple[bool, str]:
    """Check if kingdom has had a recent coup (7 day cooldown, no overlapping)"""
    # Check for active coup (not resolved)
    active_coup = db.query(CoupEvent).filter(
        CoupEvent.kingdom_id == kingdom_id,
        CoupEvent.resolved_at.is_(None)
    ).first()
    
    if active_coup:
        return False, "A coup is already in progress in this kingdom."
    
    # Check for recent resolved coup
    recent_coup = db.query(CoupEvent).filter(
        CoupEvent.kingdom_id == kingdom_id,
        CoupEvent.resolved_at.isnot(None),
        CoupEvent.resolved_at >= datetime.utcnow() - timedelta(days=KINGDOM_COOLDOWN_DAYS)
    ).first()
    
    if recent_coup:
        days_since = (datetime.utcnow() - recent_coup.resolved_at).days
        days_remaining = KINGDOM_COOLDOWN_DAYS - days_since
        return False, f"This kingdom had a coup recently. Wait {days_remaining} more days."
    
    return True, ""


def _get_kingdom_reputation(db: Session, user_id: int, kingdom_id: str) -> int:
    """Get player's reputation in a specific kingdom from user_kingdoms table"""
    from db.models import UserKingdom
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == user_id,
        UserKingdom.kingdom_id == kingdom_id
    ).first()
    return user_kingdom.local_reputation if user_kingdom else 0


def _get_initiator_stats(db: Session, initiator_id: int, kingdom_id: str) -> InitiatorStats:
    """Get full character sheet for the coup initiator"""
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
) -> List[CoupParticipant]:
    """
    Get participant list with stats, sorted by kingdom reputation descending.
    Used for display in the pledge UI.
    """
    participants = []
    
    for player_id in player_ids:
        user = db.query(User).filter(User.id == player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        kingdom_rep = _get_kingdom_reputation(db, user.id, kingdom_id)
        
        participants.append(CoupParticipant(
            player_id=player_id,
            player_name=user.display_name,
            kingdom_reputation=kingdom_rep,
            attack_power=state.attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            level=state.level
        ))
    
    # Sort by kingdom reputation descending
    participants.sort(key=lambda p: p.kingdom_reputation, reverse=True)
    return participants


def _calculate_combat_strength(
    db: Session,
    player_ids: List[int],
    kingdom_id: str
) -> Tuple[int, int, List[CoupParticipant]]:
    """
    Calculate total attack and defense power for a list of players
    Returns: (total_attack, total_defense, participants)
    """
    total_attack = 0
    total_defense = 0
    participants = []
    
    for player_id in player_ids:
        user = db.query(User).filter(User.id == player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        kingdom_rep = _get_kingdom_reputation(db, user.id, kingdom_id)
        
        # Apply debuffs if active
        attack_power = state.attack_power
        if state.attack_debuff and state.debuff_expires_at:
            if datetime.utcnow() < state.debuff_expires_at:
                attack_power = max(1, attack_power - state.attack_debuff)
        
        total_attack += attack_power
        total_defense += state.defense_power
        
        participants.append(CoupParticipant(
            player_id=player_id,
            player_name=user.display_name,
            kingdom_reputation=kingdom_rep,
            attack_power=attack_power,
            defense_power=state.defense_power,
            leadership=state.leadership,
            level=state.level
        ))
    
    return total_attack, total_defense, participants


def _apply_coup_outcome(
    db: Session,
    coup: CoupEvent,
    kingdom: Kingdom,
    attackers: List[CoupParticipant],
    defenders: List[CoupParticipant],
    attacker_victory: bool
) -> Dict:
    """
    Apply rewards and penalties based on coup outcome.
    
    Losers:
    - Lose 50% gold (pooled and given to winners)
    - Lose 100 reputation
    - NO skill loss (coups don't cause skill loss)
    
    Winners:
    - Split loser gold pool evenly
    - Gain 100 reputation
    
    If attackers win:
    - Initiator becomes ruler
    - KingdomHistory updated (old ruler ended, new ruler started)
    """
    from db.models import UserKingdom, KingdomHistory
    from systems.coup.config import (
        LOSER_GOLD_PERCENT,
        WINNER_REP_GAIN,
        LOSER_REP_LOSS,
    )
    
    winners = attackers if attacker_victory else defenders
    losers = defenders if attacker_victory else attackers
    
    # Collect gold from losers
    gold_pool = 0
    for loser in losers:
        user = db.query(User).filter(User.id == loser.player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        
        # Take 50% gold
        gold_taken = int(state.gold * LOSER_GOLD_PERCENT)
        state.gold -= gold_taken
        gold_pool += gold_taken
        
        # Lose reputation
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        if user_kingdom:
            user_kingdom.local_reputation = max(0, user_kingdom.local_reputation - LOSER_REP_LOSS)
        
        # NO skill loss for coups - only gold and rep
    
    # Distribute gold to winners
    gold_per_winner = gold_pool // len(winners) if winners else 0
    coup.gold_per_winner = gold_per_winner  # Store for notifications
    for winner in winners:
        user = db.query(User).filter(User.id == winner.player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        
        # Get share of loser gold
        state.gold += gold_per_winner
        
        # Gain reputation
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        if not user_kingdom:
            user_kingdom = UserKingdom(
                user_id=user.id,
                kingdom_id=kingdom.id,
                local_reputation=WINNER_REP_GAIN
            )
            db.add(user_kingdom)
        else:
            user_kingdom.local_reputation += WINNER_REP_GAIN
    
    # Handle ruler change if attackers won
    old_ruler_id = kingdom.ruler_id
    old_ruler_name = None
    new_ruler_id = None
    new_ruler_name = None
    now = datetime.utcnow()
    
    # Store old ruler on coup for notifications (before we change it)
    coup.old_ruler_id = old_ruler_id
    
    if attacker_victory:
        initiator = db.query(User).filter(User.id == coup.initiator_id).first()
        if initiator:
            if old_ruler_id:
                old_ruler = db.query(User).filter(User.id == old_ruler_id).first()
                if old_ruler:
                    old_ruler_name = old_ruler.display_name
                
                # Close old ruler's KingdomHistory entry
                old_history = db.query(KingdomHistory).filter(
                    KingdomHistory.kingdom_id == kingdom.id,
                    KingdomHistory.ruler_id == old_ruler_id,
                    KingdomHistory.ended_at.is_(None)
                ).first()
                if old_history:
                    old_history.ended_at = now
            
            # Set new ruler on kingdom
            kingdom.ruler_id = initiator.id
            kingdom.ruler_started_at = now
            kingdom.last_activity = now
            new_ruler_id = initiator.id
            new_ruler_name = initiator.display_name
            
            # Set empire to initiator's hometown kingdom
            # Since coups are internal (only locals can coup), this restores independence
            # e.g., if kingdom 123 was conquered by empire 456, a local (hometown=123) 
            # couping will restore empire_id to 123
            initiator_state = _get_player_state(db, initiator)
            new_empire_id = initiator_state.hometown_kingdom_id or kingdom.id
            kingdom.empire_id = new_empire_id
            
            # Create new KingdomHistory entry for the new ruler
            new_history = KingdomHistory(
                kingdom_id=kingdom.id,
                ruler_id=initiator.id,
                ruler_name=initiator.display_name,
                empire_id=new_empire_id,
                event_type='coup',
                started_at=now,
                coup_id=coup.id
            )
            db.add(new_history)
    
    db.commit()
    
    return {
        "old_ruler_id": old_ruler_id,
        "old_ruler_name": old_ruler_name,
        "new_ruler_id": new_ruler_id,
        "new_ruler_name": new_ruler_name
    }


# ===== Battle Phase Helper Functions =====

def _ensure_territories_exist(db: Session, coup: CoupEvent) -> List[CoupTerritory]:
    """
    Create territories for a coup if they don't exist (lazy init on first battle action).
    Returns list of all 3 territories.
    """
    territories = db.query(CoupTerritory).filter(
        CoupTerritory.coup_id == coup.id
    ).all()
    
    if len(territories) == 3:
        return territories
    
    # Create missing territories
    existing_names = {t.territory_name for t in territories}
    
    for territory_name in VALID_TERRITORIES:
        if territory_name not in existing_names:
            territory = CoupTerritory(
                coup_id=coup.id,
                territory_name=territory_name,
                control_bar=TERRITORY_STARTING_BARS.get(territory_name, 50.0)
            )
            db.add(territory)
            territories.append(territory)
    
    db.commit()
    
    # Reload to get fresh objects
    return db.query(CoupTerritory).filter(
        CoupTerritory.coup_id == coup.id
    ).all()


def _get_battle_cooldown_seconds(db: Session, user_id: int, coup_id: int) -> int:
    """Get remaining cooldown seconds for battle action"""
    cooldown_record = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == user_id,
        ActionCooldown.action_type == f'coup_battle_{coup_id}'
    ).first()
    
    if not cooldown_record or not cooldown_record.last_performed:
        return 0
    
    cooldown = timedelta(minutes=BATTLE_ACTION_COOLDOWN_MINUTES)
    time_since = datetime.utcnow() - cooldown_record.last_performed
    
    if time_since >= cooldown:
        return 0
    
    return int((cooldown - time_since).total_seconds())


def _set_battle_cooldown(db: Session, user_id: int, coup_id: int) -> None:
    """Set battle action cooldown for user"""
    action_type = f'coup_battle_{coup_id}'
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


def _get_active_injury(db: Session, user_id: int, coup_id: int) -> Optional[CoupInjury]:
    """Get active injury for a player in a coup (if any)"""
    return db.query(CoupInjury).filter(
        CoupInjury.coup_id == coup_id,
        CoupInjury.player_id == user_id,
        CoupInjury.cleared_at.is_(None),
        CoupInjury.expires_at > datetime.utcnow()
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
    """
    Perform a single roll and return (roll_value, outcome).
    
    Returns one of: 'miss', 'hit', 'injure'
    Uses calculate_roll_chances from systems/coup/config.py
    """
    miss_chance, hit_chance, injure_chance = calculate_roll_chances(attack, enemy_avg_defense)
    
    roll = random.random()
    
    if roll < injure_chance:
        return roll, RollOutcome.INJURE.value
    elif roll < injure_chance + hit_chance:
        return roll, RollOutcome.HIT.value
    else:
        return roll, RollOutcome.MISS.value


def _get_best_outcome(rolls: List[dict]) -> str:
    """
    Get the best outcome from multiple rolls.
    Priority: injure > hit > miss
    """
    outcomes = [r['outcome'] for r in rolls]
    
    if RollOutcome.INJURE.value in outcomes:
        return RollOutcome.INJURE.value
    elif RollOutcome.HIT.value in outcomes:
        return RollOutcome.HIT.value
    else:
        return RollOutcome.MISS.value


def _get_side_average_defense(db: Session, player_ids: List[int]) -> float:
    """Get average defense power for a list of players"""
    if not player_ids:
        return 1.0
    
    total_defense = 0
    count = 0
    
    for pid in player_ids:
        state = db.query(PlayerState).filter(PlayerState.user_id == pid).first()
        if state:
            total_defense += state.defense_power or 0
            count += 1
    
    if count == 0:
        return 1.0
    
    return total_defense / count


def _get_side_average_leadership(db: Session, player_ids: List[int]) -> float:
    """Get average leadership for a list of players"""
    if not player_ids:
        return 0.0
    
    total_leadership = 0
    count = 0
    
    for pid in player_ids:
        state = db.query(PlayerState).filter(PlayerState.user_id == pid).first()
        if state:
            total_leadership += state.leadership or 0
            count += 1
    
    if count == 0:
        return 0.0
    
    return total_leadership / count


def _pick_random_injury_target(
    db: Session, 
    coup: CoupEvent, 
    enemy_side: str
) -> Optional[int]:
    """
    Pick a random enemy player to injure.
    
    Picks from players who:
    - Are on the enemy side
    - Are NOT already injured
    """
    if enemy_side == "attackers":
        enemy_ids = coup.get_attacker_ids()
    else:
        enemy_ids = coup.get_defender_ids()
    
    if not enemy_ids:
        return None
    
    # Filter out already injured players
    already_injured = db.query(CoupInjury.player_id).filter(
        CoupInjury.coup_id == coup.id,
        CoupInjury.player_id.in_(enemy_ids),
        CoupInjury.cleared_at.is_(None),
        CoupInjury.expires_at > datetime.utcnow()
    ).all()
    
    already_injured_ids = {i[0] for i in already_injured}
    available_targets = [pid for pid in enemy_ids if pid not in already_injured_ids]
    
    if not available_targets:
        return None
    
    return random.choice(available_targets)


def _apply_injury(
    db: Session,
    coup: CoupEvent,
    injured_player_id: int,
    injured_by_id: int,
    action_id: int
) -> CoupInjury:
    """Create an injury record for a player"""
    injury = CoupInjury(
        coup_id=coup.id,
        player_id=injured_player_id,
        injured_by_id=injured_by_id,
        injury_action_id=action_id,
        injured_at=datetime.utcnow(),
        expires_at=datetime.utcnow() + timedelta(minutes=INJURY_DURATION_MINUTES)
    )
    db.add(injury)
    return injury


def _check_win_condition(db: Session, coup: CoupEvent) -> Optional[str]:
    """
    Check if the battle is won.
    
    Win condition: First to capture 2 of 3 territories
    
    Returns: 'attackers', 'defenders', or None
    """
    territories = db.query(CoupTerritory).filter(
        CoupTerritory.coup_id == coup.id
    ).all()
    
    attacker_captures = 0
    defender_captures = 0
    
    for t in territories:
        if t.captured_by == "attackers":
            attacker_captures += 1
        elif t.captured_by == "defenders":
            defender_captures += 1
    
    # Win condition: First to 2 territories
    if attacker_captures >= 2:
        return "attackers"
    if defender_captures >= 2:
        return "defenders"
    
    return None


def _try_resolve_coup(db: Session, coup_id: int, winner_side: str) -> bool:
    """
    Atomically try to claim and resolve a coup.
    
    Uses UPDATE WHERE resolved_at IS NULL to prevent race conditions.
    Only ONE Lambda wins this race - all others get False.
    """
    from sqlalchemy import text
    
    result = db.execute(text("""
        UPDATE coup_events
        SET resolved_at = NOW(),
            attacker_victory = :attacker_victory
        WHERE id = :coup_id
          AND resolved_at IS NULL
        RETURNING id
    """), {
        "coup_id": coup_id,
        "attacker_victory": winner_side == "attackers"
    }).fetchone()
    
    return result is not None


def _atomic_push_coup_territory(
    db: Session,
    territory_id: int,
    side: str,
    push_amount: float
) -> dict:
    """
    Atomically push a coup territory bar.
    Prevents race conditions with concurrent Lambda requests.
    """
    from sqlalchemy import text
    
    if side == "attackers":
        result = db.execute(text("""
            UPDATE coup_territories
            SET 
                control_bar = GREATEST(0.0, LEAST(100.0, control_bar - :push_amount)),
                captured_by = CASE 
                    WHEN captured_by IS NOT NULL THEN captured_by
                    WHEN control_bar - :push_amount <= 0 THEN 'attackers'
                    ELSE NULL
                END,
                captured_at = CASE
                    WHEN captured_by IS NOT NULL THEN captured_at
                    WHEN control_bar - :push_amount <= 0 THEN NOW()
                    ELSE NULL
                END,
                updated_at = NOW()
            WHERE id = :territory_id
            RETURNING 
                control_bar + :push_amount as bar_before,
                control_bar as bar_after,
                captured_by,
                (captured_by = 'attackers' AND captured_at >= NOW() - INTERVAL '1 second') as newly_captured
        """), {"territory_id": territory_id, "push_amount": push_amount}).fetchone()
    else:
        result = db.execute(text("""
            UPDATE coup_territories
            SET 
                control_bar = GREATEST(0.0, LEAST(100.0, control_bar + :push_amount)),
                captured_by = CASE 
                    WHEN captured_by IS NOT NULL THEN captured_by
                    WHEN control_bar + :push_amount >= 100 THEN 'defenders'
                    ELSE NULL
                END,
                captured_at = CASE
                    WHEN captured_by IS NOT NULL THEN captured_at
                    WHEN control_bar + :push_amount >= 100 THEN NOW()
                    ELSE NULL
                END,
                updated_at = NOW()
            WHERE id = :territory_id
            RETURNING 
                control_bar - :push_amount as bar_before,
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


def _resolve_battle_victory(db: Session, coup: CoupEvent, winner_side: str) -> bool:
    """
    Resolve the battle when a side wins via territory capture.
    
    Uses atomic database operation to prevent race conditions.
    Only ONE Lambda wins this race - all others get False.
    
    Returns: True if this call resolved it, False if already resolved.
    """
    from db.models.kingdom_event import KingdomEvent
    
    # ATOMIC CLAIM: Only one Lambda wins this race
    if not _try_resolve_coup(db, coup.id, winner_side):
        return False
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
    if not kingdom:
        db.commit()
        return True
    
    # Calculate combat strength for record keeping
    attacker_attack, _, attackers = _calculate_combat_strength(
        db, coup.get_attacker_ids(), coup.kingdom_id
    )
    _, defender_defense, defenders = _calculate_combat_strength(
        db, coup.get_defender_ids(), coup.kingdom_id
    )
    
    attacker_victory = (winner_side == "attackers")
    
    # Update coup record stats (resolved_at already set by _try_resolve_coup)
    coup.attacker_strength = attacker_attack
    coup.defender_strength = defender_defense
    coup.total_defense_with_walls = defender_defense
    
    # Apply rewards/penalties (also updates ruler if attackers won)
    outcome = _apply_coup_outcome(db, coup, kingdom, attackers, defenders, attacker_victory)
    
    # Create KingdomEvent for the activity feed
    if attacker_victory:
        title = f"⚔️ Coup Successful!"
        description = f"{coup.initiator_name} has overthrown the ruler and now controls {kingdom.name}!"
    else:
        title = f"🛡️ Coup Defeated!"
        description = f"The defenders have crushed {coup.initiator_name}'s rebellion in {kingdom.name}!"
    
    event = KingdomEvent(
        kingdom_id=kingdom.id,
        title=title,
        description=description
    )
    db.add(event)
    
    db.commit()
    return True


# ===== API Endpoints =====

@router.post("/initiate", response_model=CoupInitiateResponse)
def initiate_coup(
    request: CoupInitiateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Initiate a coup in a kingdom (V2)
    
    Requirements:
    - T3 leadership
    - 1000+ reputation in target kingdom
    - Must be your hometown kingdom
    - Checked in to kingdom
    - Not the current ruler
    - 30 day cooldown between attempts (per player)
    - 7 day cooldown between coups (per kingdom)
    """
    state = _get_player_state(db, current_user)
    kingdom = db.query(Kingdom).filter(Kingdom.id == request.kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Check if already ruler
    if kingdom.ruler_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already rule this kingdom"
        )
    
    # Check if checked in
    if state.current_kingdom_id != kingdom.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be checked in to this kingdom to initiate a coup"
        )
    
    # Must be in hometown kingdom
    if state.hometown_kingdom_id != kingdom.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can only stage a coup in your hometown kingdom"
        )
    
    # Check leadership requirement (T3+)
    if state.leadership < COUP_LEADERSHIP_REQUIREMENT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need leadership tier {COUP_LEADERSHIP_REQUIREMENT} to initiate coup (you have tier {state.leadership})"
        )
    
    # Check reputation
    kingdom_rep = _get_kingdom_reputation(db, current_user.id, kingdom.id)
    if kingdom_rep < COUP_REPUTATION_REQUIREMENT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need {COUP_REPUTATION_REQUIREMENT} reputation in this kingdom (you have {kingdom_rep})"
        )
    
    # Check player cooldown (30 days)
    can_coup, cooldown_msg = _check_player_cooldown(db, current_user.id)
    if not can_coup:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=cooldown_msg
        )
    
    # Check kingdom cooldown (7 days, no overlapping)
    can_coup_kingdom, kingdom_msg = _check_kingdom_cooldown(db, kingdom.id)
    if not can_coup_kingdom:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=kingdom_msg
        )
    
    # Record attempt time in action_cooldowns table
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
    
    # Create coup - phase is computed from pledge_end_time, not stored
    now = datetime.utcnow()
    coup = CoupEvent(
        kingdom_id=kingdom.id,
        initiator_id=current_user.id,
        initiator_name=current_user.display_name,
        start_time=now,
        pledge_end_time=now + timedelta(hours=PLEDGE_DURATION_HOURS),
        attackers=[current_user.id],
        defenders=[]
    )
    
    db.add(coup)
    db.commit()
    db.refresh(coup)
    
    # Broadcast to the kingdom
    notify_kingdom(
        kingdom_id=kingdom.id,
        event_type=KingdomEvents.COUP_STARTED,
        data={
            "coup_id": coup.id,
            "initiator_name": current_user.display_name,
            "pledge_end_time": coup.pledge_end_time.isoformat()
        }
    )
    
    # Notify allied kingdoms - "Your ally is under attack!"
    kingdom_empire_id = kingdom.empire_id or kingdom.id
    allied_kingdom_ids = get_allied_kingdom_ids(db, kingdom_empire_id)
    for allied_kingdom_id in allied_kingdom_ids:
        event = KingdomEvent(
            kingdom_id=allied_kingdom_id,
            title="Ally Under Attack!",
            description=f"A coup has been initiated in {kingdom.name} by {current_user.display_name}!"
        )
        db.add(event)
    
    if allied_kingdom_ids:
        db.commit()
    
    return CoupInitiateResponse(
        success=True,
        message=f"Coup initiated in {kingdom.name}! Citizens have {PLEDGE_DURATION_HOURS} hours to choose sides.",
        coup_id=coup.id,
        pledge_end_time=coup.pledge_end_time
    )


@router.post("/{coup_id}/join", response_model=CoupJoinResponse)
def join_coup(
    coup_id: int,
    request: CoupJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Pledge to a side in a coup (one-time choice)
    
    Requirements:
    - Must be checked in to kingdom
    - Cannot have already pledged
    - Pledge phase must be active
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    if not coup.is_pledge_open:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pledge phase has ended"
        )
    
    state = _get_player_state(db, current_user)
    
    # Check if checked in to kingdom
    if state.current_kingdom_id != coup.kingdom_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be checked in to this kingdom to join the coup"
        )
    
    # Check if already joined
    attacker_ids = coup.get_attacker_ids()
    defender_ids = coup.get_defender_ids()
    
    if current_user.id in attacker_ids or current_user.id in defender_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already joined this coup"
        )
    
    # Validate side
    if request.side not in ['attackers', 'defenders']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Side must be 'attackers' or 'defenders'"
        )
    
    # Add to appropriate side
    if request.side == 'attackers':
        coup.add_attacker(current_user.id)
    else:
        coup.add_defender(current_user.id)
    
    db.commit()
    db.refresh(coup)
    
    return CoupJoinResponse(
        success=True,
        message=f"You have joined the {request.side}!",
        side=request.side,
        attacker_count=len(coup.get_attacker_ids()),
        defender_count=len(coup.get_defender_ids())
    )


@router.post("/{coup_id}/fight", response_model=CoupFightResponse)
def fight_in_territory(
    coup_id: int,
    request: CoupFightRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Fight in a territory during battle phase.
    
    Mechanics:
    - Player gets (1 + attack_level) rolls, takes best outcome
    - Outcomes: miss, hit, injure
    - Hit: Push territory bar toward your side
    - Injure: Push bar AND injure random enemy (they sit out 20 min)
    
    Requirements:
    - Coup must be in battle phase
    - Player must have pledged to a side
    - 10 minute cooldown between actions
    - Cannot fight if injured (sitting out)
    """
    # Get coup
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    # Check battle phase
    if not coup.is_battle_phase:
        if coup.is_pledge_phase:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Battle hasn't started yet - still in pledge phase"
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This coup has already been resolved"
            )
    
    # Check player has pledged
    attacker_ids = coup.get_attacker_ids()
    defender_ids = coup.get_defender_ids()
    
    if current_user.id in attacker_ids:
        user_side = "attackers"
        enemy_side = "defenders"
        enemy_ids = defender_ids
    elif current_user.id in defender_ids:
        user_side = "defenders"
        enemy_side = "attackers"
        enemy_ids = attacker_ids
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must pledge to a side before fighting"
        )
    
    # Check territory is valid
    if request.territory not in VALID_TERRITORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid territory. Must be one of: {', '.join(VALID_TERRITORIES)}"
        )
    
    # Check for injury (sitting out)
    injury = _get_active_injury(db, current_user.id, coup_id)
    if injury:
        seconds_remaining = int((injury.expires_at - datetime.utcnow()).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You are injured and must sit out. {seconds_remaining} seconds remaining."
        )
    
    # Check cooldown
    cooldown_remaining = _get_battle_cooldown_seconds(db, current_user.id, coup_id)
    if cooldown_remaining > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Action on cooldown. {cooldown_remaining} seconds remaining."
        )
    
    # Ensure territories exist
    territories = _ensure_territories_exist(db, coup)
    
    # Get the target territory
    territory = next((t for t in territories if t.territory_name == request.territory), None)
    if not territory:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Territory not found"
        )
    
    # Check territory not already captured
    if territory.is_captured:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{territory.display_name} has already been captured by {territory.captured_by}"
        )
    
    # Get player stats
    state = _get_player_state(db, current_user)
    player_attack = state.attack_power
    
    # Get enemy average defense
    enemy_avg_defense = _get_side_avg_stat(db, enemy_ids, 'defense_power')
    
    # Calculate number of rolls: 1 + attack_level
    roll_count = 1 + player_attack
    
    # Perform rolls
    rolls = []
    for _ in range(roll_count):
        roll_value, outcome = _perform_roll(player_attack, enemy_avg_defense)
        rolls.append({"value": round(roll_value, 4), "outcome": outcome})
    
    # Get best outcome
    best_outcome = _get_best_outcome(rolls)
    
    # Calculate push amount (only if hit or injure)
    push_amount = 0.0
    injured_player_id = None
    injured_player_name = None
    newly_captured = False
    
    if best_outcome in [RollOutcome.HIT.value, RollOutcome.INJURE.value]:
        # Get side stats for push calculation
        if user_side == "attackers":
            side_size = len(attacker_ids)
            side_avg_leadership = _get_side_avg_stat(db, attacker_ids, 'leadership')
        else:
            side_size = len(defender_ids)
            side_avg_leadership = _get_side_avg_stat(db, defender_ids, 'leadership')
        
        push_amount = calculate_push_per_hit(side_size, side_avg_leadership)
        
        # ATOMIC territory push - prevents race conditions
        push_result = _atomic_push_coup_territory(db, territory.id, user_side, push_amount)
        bar_before = push_result["bar_before"]
        bar_after = push_result["bar_after"]
        newly_captured = push_result["newly_captured"]
    else:
        bar_before = territory.control_bar
        bar_after = territory.control_bar
    
    # Record the action
    action = CoupBattleAction(
        coup_id=coup_id,
        player_id=current_user.id,
        territory_name=request.territory,
        side=user_side,
        roll_count=roll_count,
        rolls=rolls,
        best_outcome=best_outcome,
        push_amount=push_amount,
        bar_before=bar_before,
        bar_after=bar_after
    )
    db.add(action)
    db.flush()  # Get action ID for injury reference
    
    # Handle injury
    if best_outcome == RollOutcome.INJURE.value:
        target_id = _pick_random_injury_target(db, coup, enemy_side)
        if target_id:
            _apply_injury(db, coup, target_id, current_user.id, action.id)
            action.injured_player_id = target_id
            
            # Get injured player name
            injured_user = db.query(User).filter(User.id == target_id).first()
            if injured_user:
                injured_player_name = injured_user.display_name
    
    # Set cooldown
    _set_battle_cooldown(db, current_user.id, coup_id)
    
    # Check win condition - only if THIS push captured a territory
    battle_won = False
    winner_side = None
    
    if newly_captured:
        winner_side = _check_win_condition(db, coup)
        if winner_side:
            # ATOMIC resolution - only ONE Lambda wins this race
            battle_won = _resolve_battle_victory(db, coup, winner_side)
    
    db.commit()
    
    # Refresh territory for response
    db.refresh(territory)
    
    # Build message
    if best_outcome == RollOutcome.MISS.value:
        message = f"Your attack missed! No progress on {territory.display_name}."
    elif best_outcome == RollOutcome.HIT.value:
        message = f"Direct hit! Pushed {territory.display_name} by {push_amount:.2f} points."
    else:  # injure
        if injured_player_name:
            message = f"Critical strike! Pushed {territory.display_name} and injured {injured_player_name}!"
        else:
            message = f"Critical strike! Pushed {territory.display_name} (no enemy to injure)."
    
    if territory.is_captured:
        message += f" 🏴 {territory.display_name} captured by {territory.captured_by}!"
    
    if battle_won:
        message = f"VICTORY! {winner_side.upper()} have won the coup!"
    
    # Get new cooldown
    new_cooldown = BATTLE_ACTION_COOLDOWN_MINUTES * 60
    
    return CoupFightResponse(
        success=True,
        message=message,
        roll_count=roll_count,
        rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in rolls],
        best_outcome=best_outcome,
        push_amount=round(push_amount, 4),
        bar_before=round(bar_before, 2),
        bar_after=round(bar_after, 2),
        territory=CoupTerritoryResponse(
            name=territory.territory_name,
            display_name=territory.display_name,
            icon=territory.icon,
            control_bar=round(territory.control_bar, 2),
            captured_by=territory.captured_by,
            captured_at=territory.captured_at
        ),
        injured_player_name=injured_player_name,
        battle_won=battle_won,
        winner_side=winner_side,
        cooldown_seconds=new_cooldown
    )


def _build_coup_response(
    db: Session,
    coup: CoupEvent,
    current_user: User,
    state: PlayerState
) -> CoupEventResponse:
    """Build a CoupEventResponse with full participant data"""
    kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
    
    # Get current ruler info and stats
    ruler_id = kingdom.ruler_id if kingdom else None
    ruler_name = None
    ruler_stats = None
    if ruler_id:
        ruler = db.query(User).filter(User.id == ruler_id).first()
        if ruler:
            ruler_name = ruler.display_name
            # Get ruler's stats using same function as initiator
            ruler_stats = _get_initiator_stats(db, ruler_id, coup.kingdom_id)
    
    attacker_ids = coup.get_attacker_ids()
    defender_ids = coup.get_defender_ids()
    
    # Get full participant lists, sorted by kingdom reputation
    attackers = _get_participants_sorted(db, attacker_ids, coup.kingdom_id)
    defenders = _get_participants_sorted(db, defender_ids, coup.kingdom_id)
    
    # Determine user's side
    user_side = None
    if current_user.id in attacker_ids:
        user_side = 'attackers'
    elif current_user.id in defender_ids:
        user_side = 'defenders'
    
    # Check if user can pledge (only during pledge phase)
    can_pledge = (
        state.current_kingdom_id == coup.kingdom_id and
        current_user.id not in attacker_ids and
        current_user.id not in defender_ids and
        coup.is_pledge_open
    )
    
    # Get initiator character sheet
    initiator_stats = _get_initiator_stats(db, coup.initiator_id, coup.kingdom_id)
    
    # Battle phase data
    territories = []
    battle_cooldown_seconds = 0
    is_injured = False
    injury_expires_seconds = 0
    winner_side = None
    
    if coup.is_battle_phase or coup.is_resolved:
        # Get territories (create if needed during battle phase)
        territory_records = db.query(CoupTerritory).filter(
            CoupTerritory.coup_id == coup.id
        ).all()
        
        # If in battle phase and territories don't exist, create them
        if coup.is_battle_phase and len(territory_records) < 3:
            territory_records = _ensure_territories_exist(db, coup)
        
        territories = [
            CoupTerritoryResponse(
                name=t.territory_name,
                display_name=t.display_name,
                icon=t.icon,
                control_bar=round(t.control_bar, 2),
                captured_by=t.captured_by,
                captured_at=t.captured_at
            )
            for t in territory_records
        ]
        
        # Get user's battle cooldown
        battle_cooldown_seconds = _get_battle_cooldown_seconds(db, current_user.id, coup.id)
        
        # Check if user is injured
        injury = _get_active_injury(db, current_user.id, coup.id)
        if injury:
            is_injured = True
            injury_expires_seconds = max(0, int((injury.expires_at - datetime.utcnow()).total_seconds()))
        
        # Determine winner from territory captures
        winner_side = _check_win_condition(db, coup)
    
    # If resolved, get winner from attacker_victory
    if coup.is_resolved:
        winner_side = "attackers" if coup.attacker_victory else "defenders"
    
    return CoupEventResponse(
        id=coup.id,
        kingdom_id=coup.kingdom_id,
        kingdom_name=kingdom.name if kingdom else None,
        initiator_id=coup.initiator_id,
        initiator_name=coup.initiator_name,
        initiator_stats=initiator_stats,
        ruler_id=ruler_id,
        ruler_name=ruler_name,
        ruler_stats=ruler_stats,
        status=coup.current_phase,  # Computed from time, not stored
        start_time=coup.start_time,
        pledge_end_time=coup.pledge_end_time,
        battle_end_time=None,  # Battle has no fixed end time
        time_remaining_seconds=coup.time_remaining_seconds,
        attackers=attackers,
        defenders=defenders,
        attacker_count=len(attacker_ids),
        defender_count=len(defender_ids),
        user_side=user_side,
        can_pledge=can_pledge,
        # Battle phase data
        territories=territories,
        battle_cooldown_seconds=battle_cooldown_seconds,
        is_injured=is_injured,
        injury_expires_seconds=injury_expires_seconds,
        # Resolution
        is_resolved=coup.is_resolved,
        attacker_victory=coup.attacker_victory,
        resolved_at=coup.resolved_at,
        winner_side=winner_side
    )


@router.get("/active", response_model=ActiveCoupsResponse)
def get_active_coups(
    kingdom_id: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all active coups (not yet resolved), optionally filtered by kingdom.
    Phase (pledge/battle) is computed from time, not stored.
    """
    query = db.query(CoupEvent).filter(
        CoupEvent.resolved_at.is_(None)
    )
    
    if kingdom_id:
        query = query.filter(CoupEvent.kingdom_id == kingdom_id)
    
    coups = query.order_by(CoupEvent.start_time.desc()).all()
    
    state = _get_player_state(db, current_user)
    
    coup_responses = [
        _build_coup_response(db, coup, current_user, state)
        for coup in coups
    ]
    
    return ActiveCoupsResponse(
        active_coups=coup_responses,
        count=len(coup_responses)
    )


@router.get("/{coup_id}", response_model=CoupEventResponse)
def get_coup_details(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get details of a specific coup with full participant lists"""
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    state = _get_player_state(db, current_user)
    return _build_coup_response(db, coup, current_user, state)


@router.post("/{coup_id}/resolve", response_model=CoupResolveResponse)
def resolve_coup(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Check if coup is resolved (by territory capture).
    
    Coups are resolved when one side captures 2 of 3 territories.
    This endpoint just returns current status - it doesn't force resolution.
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
    _, _, attackers = _calculate_combat_strength(db, coup.get_attacker_ids(), coup.kingdom_id)
    _, _, defenders = _calculate_combat_strength(db, coup.get_defender_ids(), coup.kingdom_id)
    
    if coup.is_resolved:
        # Already resolved - return result
        return CoupResolveResponse(
            success=True,
            coup_id=coup.id,
            attacker_victory=coup.attacker_victory,
            attacker_strength=coup.attacker_strength,
            defender_strength=coup.defender_strength,
            total_defense_with_walls=coup.total_defense_with_walls,
            required_attack_strength=0,
            attackers=attackers,
            defenders=defenders,
            old_ruler_id=None,
            old_ruler_name=None,
            new_ruler_id=kingdom.ruler_id if kingdom else None,
            new_ruler_name=None,
            message="Coup was already resolved"
        )
    
    if not coup.can_resolve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Coup cannot be resolved yet - still in pledge phase. {coup.time_remaining_seconds} seconds remaining."
        )
    
    # Check if someone has won via territory capture
    winner_side = _check_win_condition(db, coup)
    if winner_side:
        _resolve_battle_victory(db, coup, winner_side)
        return CoupResolveResponse(
            success=True,
            coup_id=coup.id,
            attacker_victory=coup.attacker_victory,
            attacker_strength=coup.attacker_strength,
            defender_strength=coup.defender_strength,
            total_defense_with_walls=coup.total_defense_with_walls,
            required_attack_strength=0,
            attackers=attackers,
            defenders=defenders,
            old_ruler_id=None,
            old_ruler_name=None,
            new_ruler_id=kingdom.ruler_id if kingdom else None,
            new_ruler_name=None,
            message=f"VICTORY! {winner_side.upper()} have won the coup!"
        )
    
    # Not resolved yet - battle still in progress
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Coup not yet resolved. Capture 2 of 3 territories to win."
    )


@router.get("/{coup_id}/phase")
def get_coup_phase(
    coup_id: int,
    db: Session = Depends(get_db)
):
    """
    Get the current phase of a coup (computed from time).
    
    Phase is determined automatically:
    - First 12h after creation: 'pledge' phase
    - After 12h until resolved: 'battle' phase
    - After resolution: 'resolved'
    
    No cronjob or manual advancement needed - phase is always computed fresh.
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    return {
        "coup_id": coup.id,
        "phase": coup.current_phase,
        "is_pledge_phase": coup.is_pledge_phase,
        "is_battle_phase": coup.is_battle_phase,
        "is_resolved": coup.is_resolved,
        "can_resolve": coup.can_resolve,
        "time_remaining_seconds": coup.time_remaining_seconds,
        "pledge_end_time": format_datetime_iso(coup.pledge_end_time),
        "resolved_at": format_datetime_iso(coup.resolved_at) if coup.resolved_at else None
    }


@router.post("/{coup_id}/advance-phase")
def advance_coup_phase(
    coup_id: int,
    db: Session = Depends(get_db)
):
    """
    DEPRECATED: Phase is now computed from time, no advancement needed.
    
    This endpoint is kept for backward compatibility.
    It returns the current computed phase without modifying anything.
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    # Just return the current computed phase - no state change needed
    return {
        "success": True,
        "message": f"Phase is computed from time, currently in {coup.current_phase} phase",
        "phase": coup.current_phase,
        "can_resolve": coup.can_resolve,
        "time_remaining_seconds": coup.time_remaining_seconds
    }


@router.post("/process-expired")
def process_expired_coups(db: Session = Depends(get_db)):
    """
    DEPRECATED: Phase advancement is no longer needed - phase is computed from time.
    
    This endpoint now just returns the status of all active coups.
    Resolution must be triggered explicitly via POST /{coup_id}/resolve.
    
    Battle phase continues indefinitely until someone calls resolve.
    """
    # Find all active coups
    active_coups = db.query(CoupEvent).filter(
        CoupEvent.resolved_at.is_(None)
    ).all()
    
    results = []
    for coup in active_coups:
        results.append({
            "coup_id": coup.id,
            "kingdom_id": coup.kingdom_id,
            "phase": coup.current_phase,
            "can_resolve": coup.can_resolve,
            "time_remaining_seconds": coup.time_remaining_seconds
        })
    
    return {
        "success": True,
        "message": "Phase is computed from time, no processing needed. Call /{coup_id}/resolve to end a battle.",
        "active_count": len(results),
        "active_coups": results
    }


# ============================================================
# FIGHT SESSION ENDPOINTS (roll-by-roll like hunting)
# ============================================================

@router.post("/{coup_id}/fight/start", response_model=FightSessionResponse)
def start_fight_session(
    coup_id: int,
    request: CoupFightRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Start a fight session on a territory.
    
    Creates a fight session that persists until the player resolves it.
    If player already has an active session for this coup, returns it.
    
    This does NOT set cooldown - cooldown is set on resolve.
    """
    # Get coup
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    if not coup:
        raise HTTPException(status_code=404, detail="Coup not found")
    
    # Check battle phase
    if not coup.is_battle_phase:
        raise HTTPException(status_code=400, detail="Not in battle phase")
    
    # Check player has pledged
    attacker_ids = coup.get_attacker_ids()
    defender_ids = coup.get_defender_ids()
    
    if current_user.id in attacker_ids:
        user_side = "attackers"
        enemy_ids = defender_ids
    elif current_user.id in defender_ids:
        user_side = "defenders"
        enemy_ids = attacker_ids
    else:
        raise HTTPException(status_code=400, detail="You haven't pledged to a side")
    
    # Check for existing session
    existing_session = db.query(CoupFightSession).filter(
        CoupFightSession.coup_id == coup_id,
        CoupFightSession.player_id == current_user.id
    ).first()
    
    if existing_session:
        # Return existing session (player can resume)
        territory = db.query(CoupTerritory).filter(
            CoupTerritory.coup_id == coup_id,
            CoupTerritory.territory_name == existing_session.territory_name
        ).first()
        
        # Recalculate percentages for display
        state = _get_player_state(db, current_user)
        attack_power = state.attack_power or 0
        miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, existing_session.enemy_avg_defense)
        
        return FightSessionResponse(
            success=True,
            message="Resuming existing fight",
            territory_name=existing_session.territory_name,
            territory_display_name=TERRITORY_DISPLAY_NAMES.get(existing_session.territory_name, existing_session.territory_name),
            territory_icon=TERRITORY_ICONS.get(existing_session.territory_name, "mappin"),
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
    injury = _get_active_injury(db, current_user.id, coup_id)
    if injury:
        seconds_remaining = max(0, int((injury.expires_at - datetime.utcnow()).total_seconds()))
        raise HTTPException(status_code=400, detail=f"You are injured. {seconds_remaining}s remaining.")
    
    # Check cooldown
    cooldown_remaining = _get_battle_cooldown_seconds(db, current_user.id, coup_id)
    if cooldown_remaining > 0:
        raise HTTPException(status_code=400, detail=f"On cooldown. {cooldown_remaining}s remaining.")
    
    # Validate territory
    territory_name = request.territory
    if territory_name not in [TERRITORY_COUPERS, TERRITORY_CROWNS, TERRITORY_THRONE]:
        raise HTTPException(status_code=400, detail="Invalid territory")
    
    # Get territory
    _ensure_territories_exist(db, coup)
    territory = db.query(CoupTerritory).filter(
        CoupTerritory.coup_id == coup_id,
        CoupTerritory.territory_name == territory_name
    ).first()
    
    if territory.is_captured:
        raise HTTPException(status_code=400, detail="Territory already captured")
    
    # Get player's attack power for roll count
    state = _get_player_state(db, current_user)
    attack_power = state.attack_power or 0
    max_rolls = calculate_max_rolls(attack_power)
    
    # Calculate roll bar percentages using centralized config
    enemy_defense = _get_side_average_defense(db, enemy_ids)
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, enemy_defense)
    miss_chance = int(miss_pct * 100)
    hit_chance = int(hit_pct * 100)
    injure_chance = int(injure_pct * 100)
    
    # Create fight session (store combined success for roll logic)
    session = CoupFightSession(
        coup_id=coup_id,
        player_id=current_user.id,
        territory_name=territory_name,
        side=user_side,
        max_rolls=max_rolls,
        rolls=[],
        hit_chance=hit_chance + injure_chance,  # Combined for roll threshold
        enemy_avg_defense=enemy_defense,
        bar_before=territory.control_bar
    )
    db.add(session)
    db.commit()
    
    return FightSessionResponse(
        success=True,
        message="Fight started! Roll to attack.",
        territory_name=territory_name,
        territory_display_name=TERRITORY_DISPLAY_NAMES.get(territory_name, territory_name),
        territory_icon=TERRITORY_ICONS.get(territory_name, "mappin"),
        side=user_side,
        max_rolls=max_rolls,
        rolls_completed=0,
        rolls_remaining=max_rolls,
        rolls=[],
        miss_chance=miss_chance,
        hit_chance=hit_chance,
        injure_chance=injure_chance,
        best_outcome="miss",
        can_roll=True,
        bar_before=territory.control_bar
    )


@router.post("/{coup_id}/fight/roll", response_model=FightRollResponse)
def execute_fight_roll(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Execute a single roll in the fight session.
    
    Each call does ONE roll and persists it.
    Player can exit and resume - their progress is saved.
    """
    # Get existing session
    session = db.query(CoupFightSession).filter(
        CoupFightSession.coup_id == coup_id,
        CoupFightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=400, detail="No active fight. Start a fight first.")
    
    if not session.can_roll:
        raise HTTPException(status_code=400, detail="No rolls remaining. Resolve the fight.")
    
    # Get player's attack to calculate roll chances
    state = _get_player_state(db, current_user)
    attack_power = state.attack_power or 0
    
    # Use centralized config for roll calculation
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack_power, session.enemy_avg_defense)
    
    # Do one roll (0-1 range to match percentages)
    roll = random.random()
    
    # Layout: [0, injure] = INJURE, [injure, injure+hit] = HIT, [injure+hit, 1] = MISS
    if roll < injure_pct:
        outcome = "injure"
        roll_value = roll * 100  # Convert to 0-100 for display
    elif roll < injure_pct + hit_pct:
        outcome = "hit"
        roll_value = roll * 100
    else:
        outcome = "miss"
        roll_value = roll * 100
    
    # Add roll to session
    session.add_roll(roll_value, outcome)
    db.commit()
    db.refresh(session)
    
    return FightRollResponse(
        success=True,
        message=_get_roll_message(outcome),
        roll=RollResult(value=roll_value, outcome=outcome),
        roll_number=session.rolls_completed,
        rolls_completed=session.rolls_completed,
        rolls_remaining=session.rolls_remaining,
        best_outcome=session.best_outcome,
        can_roll=session.can_roll
    )


def _get_roll_message(outcome: str) -> str:
    """Get a message for a roll outcome"""
    if outcome == "injure":
        return "CRITICAL HIT! Enemy injured!"
    elif outcome == "hit":
        return "Direct hit!"
    else:
        return "Miss..."


@router.post("/{coup_id}/fight/resolve", response_model=FightResolveResponse)
def resolve_fight_session(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Resolve the fight session - apply push and set cooldown.
    
    This is when the actual damage is applied to the territory bar.
    Cooldown is set ONLY when this is called.
    """
    # Get session
    session = db.query(CoupFightSession).filter(
        CoupFightSession.coup_id == coup_id,
        CoupFightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=400, detail="No active fight to resolve")
    
    # Get coup and territory
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    territory = db.query(CoupTerritory).filter(
        CoupTerritory.coup_id == coup_id,
        CoupTerritory.territory_name == session.territory_name
    ).first()
    
    if not coup or not territory:
        raise HTTPException(status_code=404, detail="Coup or territory not found")
    
    # If territory was already captured (race condition - someone else captured it 
    # while this player was fighting), just clean up and return same response shape
    if territory.is_captured:
        # Check if battle was won
        winner_side = _check_win_condition(db, coup)
        battle_won = winner_side is not None
        
        # Delete the session and set cooldown
        db.delete(session)
        _set_battle_cooldown(db, current_user.id, coup_id)
        db.commit()
        
        territory_response = CoupTerritoryResponse(
            name=territory.territory_name,
            display_name=territory.display_name,
            icon=territory.icon,
            control_bar=round(territory.control_bar, 2),
            captured_by=territory.captured_by,
            captured_at=territory.captured_at
        )
        
        if battle_won:
            message = f"VICTORY! {winner_side.upper()} have won the coup!"
        else:
            message = f"Territory captured by {territory.captured_by}!"
        
        return FightResolveResponse(
            success=True,
            message=message,
            roll_count=session.rolls_completed,
            rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in (session.rolls or [])],
            best_outcome=session.best_outcome,
            push_amount=0.0,
            bar_before=session.bar_before,
            bar_after=territory.control_bar,
            territory=territory_response,
            injured_player_name=None,
            battle_won=battle_won,
            winner_side=winner_side,
            cooldown_seconds=BATTLE_ACTION_COOLDOWN_MINUTES * 60
        )
    
    # Calculate push amount based on best outcome
    best_outcome = session.best_outcome
    push_amount = 0.0
    
    if best_outcome != "miss":
        # Get player's side count for push calculation
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        
        if session.side == "attackers":
            side_ids = attacker_ids
        else:
            side_ids = defender_ids
        
        side_size = len(side_ids)
        avg_leadership = _get_side_average_leadership(db, side_ids)
        
        # Use centralized formula from systems/coup/config.py
        base_push = calculate_push_per_hit(side_size, avg_leadership)
        
        if best_outcome == "injure":
            push_amount = base_push * INJURE_PUSH_MULTIPLIER
        else:
            push_amount = base_push
    
    # ATOMIC territory push - prevents race conditions with 1000 concurrent Lambdas
    push_result = _atomic_push_coup_territory(db, territory.id, session.side, push_amount)
    bar_before = push_result["bar_before"]
    bar_after = push_result["bar_after"]
    newly_captured = push_result["newly_captured"]
    
    # Handle injury if critical hit
    injured_player_name = None
    if best_outcome == "injure":
        if session.side == "attackers":
            enemy_ids = coup.get_defender_ids()
        else:
            enemy_ids = coup.get_attacker_ids()
        
        if enemy_ids:
            injured_id = random.choice(enemy_ids)
            injured_user = db.query(User).filter(User.id == injured_id).first()
            if injured_user:
                injured_player_name = injured_user.display_name
                
                # Create injury record
                injury = CoupInjury(
                    coup_id=coup_id,
                    player_id=injured_id,
                    injured_by_id=current_user.id,
                    expires_at=datetime.utcnow() + timedelta(minutes=INJURY_DURATION_MINUTES)
                )
                db.add(injury)
    
    # Log the battle action
    action = CoupBattleAction(
        coup_id=coup_id,
        player_id=current_user.id,
        territory_name=session.territory_name,
        side=session.side,
        roll_count=session.rolls_completed,
        rolls=session.rolls,
        best_outcome=best_outcome,
        push_amount=push_amount,
        bar_before=bar_before,
        bar_after=bar_after,
        injured_player_id=None
    )
    db.add(action)
    
    # Set cooldown NOW (not before)
    _set_battle_cooldown(db, current_user.id, coup_id)
    
    # Check win condition - only if THIS push captured a territory
    battle_won = False
    winner_side = None
    
    if newly_captured:
        winner_side = _check_win_condition(db, coup)
        if winner_side:
            # ATOMIC resolution - only ONE Lambda wins this race
            battle_won = _resolve_battle_victory(db, coup, winner_side)
    
    # Save session data before deleting
    session_rolls = session.rolls or []
    session_rolls_completed = session.rolls_completed
    
    # Delete the session (fight is complete)
    db.delete(session)
    db.commit()
    
    # Refresh territory to get current state
    db.refresh(territory)
    
    # Build territory response
    territory_response = CoupTerritoryResponse(
        name=territory.territory_name,
        display_name=territory.display_name,
        icon=territory.icon,
        control_bar=round(territory.control_bar, 2),
        captured_by=territory.captured_by,
        captured_at=territory.captured_at
    )
    
    # Build message
    if battle_won:
        message = f"VICTORY! {winner_side.upper()} have won the coup!"
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
        territory=territory_response,
        injured_player_name=injured_player_name,
        battle_won=battle_won,
        winner_side=winner_side,
        cooldown_seconds=BATTLE_ACTION_COOLDOWN_MINUTES * 60
    )


@router.get("/{coup_id}/fight/session", response_model=FightSessionResponse)
def get_fight_session(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current fight session if one exists.
    
    Returns the session state so player can resume a fight.
    """
    session = db.query(CoupFightSession).filter(
        CoupFightSession.coup_id == coup_id,
        CoupFightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="No active fight session")
    
    return FightSessionResponse(
        success=True,
        message="Active fight session",
        territory_name=session.territory_name,
        territory_display_name=TERRITORY_DISPLAY_NAMES.get(session.territory_name, session.territory_name),
        territory_icon=TERRITORY_ICONS.get(session.territory_name, "mappin"),
        side=session.side,
        max_rolls=session.max_rolls,
        rolls_completed=session.rolls_completed,
        rolls_remaining=session.rolls_remaining,
        rolls=[RollResult(value=r["value"], outcome=r["outcome"]) for r in (session.rolls or [])],
        hit_chance=session.hit_chance,
        best_outcome=session.best_outcome,
        can_roll=session.can_roll,
        bar_before=session.bar_before
    )


@router.delete("/{coup_id}/fight/session")
def cancel_fight_session(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Cancel a fight session without resolving.
    
    Use this if player wants to abandon a fight without applying damage.
    No cooldown is set.
    """
    session = db.query(CoupFightSession).filter(
        CoupFightSession.coup_id == coup_id,
        CoupFightSession.player_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="No active fight session")
    
    db.delete(session)
    db.commit()
    
    return {"success": True, "message": "Fight cancelled"}

