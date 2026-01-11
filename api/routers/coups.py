"""
Coup system - Internal power struggles
Players can initiate coups to overthrow rulers using attack vs defense combat
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Tuple, Dict

from db import get_db, User, PlayerState, Kingdom, CoupEvent, ActionCooldown
from schemas.coup import (
    CoupInitiateRequest,
    CoupInitiateResponse,
    CoupJoinRequest,
    CoupJoinResponse,
    CoupEventResponse,
    CoupResolveResponse,
    CoupParticipant,
    ActiveCoupsResponse,
    InitiatorStats
)
from routers.auth import get_current_user

router = APIRouter(prefix="/coups", tags=["Coups"])


# ===== Constants =====
# Eligibility
COUP_REPUTATION_REQUIREMENT = 500  # Kingdom reputation needed
COUP_LEADERSHIP_REQUIREMENT = 3    # T3 leadership needed

# Timing
PLEDGE_DURATION_HOURS = 12         # Phase 1: citizens pick sides (fixed 12h)
# Battle phase has no fixed duration - continues until resolution

# Cooldowns
PLAYER_COOLDOWN_DAYS = 30          # 30 days between coup attempts per player
KINGDOM_COOLDOWN_DAYS = 7          # 7 days between coups in same kingdom

# Legacy (keeping for resolution logic)
ATTACKER_ADVANTAGE_REQUIRED = 1.25  # Attackers need 25% more power to win


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


def _apply_coup_victory_rewards(
    db: Session,
    coup: CoupEvent,
    kingdom: Kingdom,
    attackers: List[CoupParticipant],
    defenders: List[CoupParticipant]
) -> Dict:
    """
    Apply rewards and penalties when attackers win
    
    Attackers win:
    - Initiator becomes ruler, +1000g, +50 rep
    - Old ruler loses kingdom
    
    Defenders lose:
    - No rewards (they lost)
    """
    initiator = db.query(User).filter(User.id == coup.initiator_id).first()
    initiator_state = _get_player_state(db, initiator)
    
    old_ruler_id = kingdom.ruler_id
    old_ruler_name = None
    
    if old_ruler_id:
        old_ruler = db.query(User).filter(User.id == old_ruler_id).first()
        if old_ruler:
            old_ruler_name = old_ruler.display_name
            old_ruler_state = _get_player_state(db, old_ruler)
            
            # Old ruler loses rulership
            old_ruler_state.kingdoms_ruled = max(0, old_ruler_state.kingdoms_ruled - 1)
    
    # Initiator becomes ruler
    kingdom.ruler_id = initiator.id
    kingdom.last_activity = datetime.utcnow()
    
    # Coup rewards are NOT taxed (you're taking over the kingdom!)
    initiator_state.gold += 1000
    
    # Update per-kingdom reputation in user_kingdoms table
    from db.models import UserKingdom
    user_kingdom = db.query(UserKingdom).filter(
        UserKingdom.user_id == initiator.id,
        UserKingdom.kingdom_id == kingdom.id
    ).first()
    
    if not user_kingdom:
        user_kingdom = UserKingdom(
            user_id=initiator.id,
            kingdom_id=kingdom.id,
            local_reputation=50
        )
        db.add(user_kingdom)
    else:
        user_kingdom.local_reputation += 50
    
    # NOTE: coups_won and kingdoms_ruled are now computed from other tables:
    # - coups_won: COUNT from coup_events WHERE initiator_id = ? AND attacker_victory = true
    # - kingdoms_ruled: COUNT from kingdoms WHERE ruler_id = ?
    
    db.commit()
    
    return {
        "old_ruler_id": old_ruler_id,
        "old_ruler_name": old_ruler_name,
        "new_ruler_id": initiator.id,
        "new_ruler_name": initiator.display_name
    }


def _apply_coup_failure_penalties(
    db: Session,
    coup: CoupEvent,
    kingdom: Kingdom,
    attackers: List[CoupParticipant],
    defenders: List[CoupParticipant]
) -> None:
    """
    Apply harsh penalties when attackers lose
    
    Attackers lose (HARSH):
    - Lose 100% gold (ruler takes it)
    - Lose 100 reputation (traitor!)
    - Lose ALL attack + defense stats (executed)
    - Get "Traitor" badge
    
    Defenders win:
    - Each gets +200g, +30 rep
    """
    ruler = db.query(User).filter(User.id == kingdom.ruler_id).first()
    ruler_state = _get_player_state(db, ruler) if ruler else None
    
    total_gold_seized = 0
    
    # Punish attackers harshly
    for attacker in attackers:
        user = db.query(User).filter(User.id == attacker.player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        
        # Seize ALL gold
        gold_lost = state.gold
        total_gold_seized += gold_lost
        state.gold = 0
        
        # MAJOR reputation loss in this kingdom
        from db.models import UserKingdom
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        
        if user_kingdom:
            user_kingdom.local_reputation = max(0, user_kingdom.local_reputation - 100)
        
        # Lose ALL combat stats (executed)
        state.attack_power = 1
        state.defense_power = 1
        
        # NOTE: coups_failed and times_executed are now tracked in coup_events table
    
    # Ruler gets all seized gold
    if ruler_state:
        ruler_state.gold += total_gold_seized
        
        # Increase ruler's reputation in this kingdom
        from db.models import UserKingdom
        ruler_user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == ruler.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        
        if not ruler_user_kingdom:
            ruler_user_kingdom = UserKingdom(
                user_id=ruler.id,
                kingdom_id=kingdom.id,
                local_reputation=50
            )
            db.add(ruler_user_kingdom)
        else:
            ruler_user_kingdom.local_reputation += 50
    
    # Reward defenders
    for defender in defenders:
        user = db.query(User).filter(User.id == defender.player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        state.gold += 200
        
        # Boost kingdom reputation
        from db.models import UserKingdom
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == user.id,
            UserKingdom.kingdom_id == kingdom.id
        ).first()
        
        if not user_kingdom:
            user_kingdom = UserKingdom(
                user_id=user.id,
                kingdom_id=kingdom.id,
                local_reputation=30
            )
            db.add(user_kingdom)
        else:
            user_kingdom.local_reputation += 30
    
    db.commit()


def _resolve_coup_battle(db: Session, coup: CoupEvent) -> CoupResolveResponse:
    """
    Resolve a coup battle using attack vs defense
    
    Formula:
    - Attacker strength = sum of all attacker attack_power
    - Defender strength = sum of all defender defense_power
    - NO WALLS for coups (internal rebellion)
    - Attackers need 25% advantage to win
    """
    kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
    
    if not kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kingdom not found"
        )
    
    # Calculate attacker strength
    attacker_attack, _, attackers = _calculate_combat_strength(
        db, coup.get_attacker_ids(), coup.kingdom_id
    )
    
    # Calculate defender strength
    _, defender_defense, defenders = _calculate_combat_strength(
        db, coup.get_defender_ids(), coup.kingdom_id
    )
    
    # NO WALLS for coups (internal rebellion)
    total_defense = defender_defense
    
    # Determine victory (attackers need 25% advantage)
    required_attack = int(total_defense * ATTACKER_ADVANTAGE_REQUIRED)
    attacker_victory = attacker_attack > required_attack
    
    # Update coup record - resolved_at is the source of truth
    coup.attacker_victory = attacker_victory
    coup.attacker_strength = attacker_attack
    coup.defender_strength = defender_defense
    coup.total_defense_with_walls = total_defense
    coup.resolved_at = datetime.utcnow()
    
    # Apply rewards/penalties
    ruler_change = {}
    if attacker_victory:
        ruler_change = _apply_coup_victory_rewards(db, coup, kingdom, attackers, defenders)
        message = f"🎉 COUP SUCCEEDED! {coup.initiator_name} has seized power in {kingdom.name}!"
    else:
        _apply_coup_failure_penalties(db, coup, kingdom, attackers, defenders)
        message = f"💀 COUP FAILED! The rebellion in {kingdom.name} has been crushed!"
        ruler_change = {
            "old_ruler_id": None,
            "old_ruler_name": None,
            "new_ruler_id": None,
            "new_ruler_name": None
        }
    
    db.commit()
    
    return CoupResolveResponse(
        success=True,
        coup_id=coup.id,
        attacker_victory=attacker_victory,
        attacker_strength=attacker_attack,
        defender_strength=defender_defense,
        total_defense_with_walls=total_defense,
        required_attack_strength=required_attack,
        attackers=attackers,
        defenders=defenders,
        old_ruler_id=ruler_change.get("old_ruler_id"),
        old_ruler_name=ruler_change.get("old_ruler_name"),
        new_ruler_id=ruler_change.get("new_ruler_id"),
        new_ruler_name=ruler_change.get("new_ruler_name"),
        message=message
    )


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
    - 500+ reputation in target kingdom
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
    
    return CoupInitiateResponse(
        success=True,
        message=f"Coup initiated in {kingdom.name}! Citizens have {PLEDGE_DURATION_HOURS} hours to choose sides.",
        coup_id=coup.id,
        pledge_end_time=pledge_end_time
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
        is_resolved=coup.is_resolved,
        attacker_victory=coup.attacker_victory,
        resolved_at=coup.resolved_at
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
    Resolve a coup - can be called by anyone after the pledge phase ends.
    Idempotent - safe to call multiple times.
    
    Phase is computed from time:
    - During pledge phase (first 12h): cannot resolve
    - During battle phase (after 12h): can resolve anytime
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    if coup.is_resolved:
        # Idempotent - return the existing result
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        _, _, attackers = _calculate_combat_strength(db, coup.get_attacker_ids(), coup.kingdom_id)
        _, _, defenders = _calculate_combat_strength(db, coup.get_defender_ids(), coup.kingdom_id)
        return CoupResolveResponse(
            success=True,
            coup_id=coup.id,
            attacker_victory=coup.attacker_victory,
            attacker_strength=coup.attacker_strength,
            defender_strength=coup.defender_strength,
            total_defense_with_walls=coup.total_defense_with_walls,
            required_attack_strength=int(coup.total_defense_with_walls * ATTACKER_ADVANTAGE_REQUIRED) if coup.total_defense_with_walls else 0,
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
    
    return _resolve_coup_battle(db, coup)


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
        "pledge_end_time": coup.pledge_end_time.isoformat(),
        "resolved_at": coup.resolved_at.isoformat() if coup.resolved_at else None
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

