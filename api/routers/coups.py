"""
Coup system - Internal power struggles
Players can initiate coups to overthrow rulers using attack vs defense combat
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Tuple, Dict

from db import get_db, User, PlayerState, Kingdom, CoupEvent
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
COUP_BASE_COST = 50
COUP_REPUTATION_REQUIREMENT = 300
COUP_COOLDOWN_HOURS = 24
COUP_VOTING_DURATION_HOURS = 2
ATTACKER_ADVANTAGE_REQUIRED = 1.25  # Attackers need 25% more power to win
COUP_LEADERSHIP_REQUIREMENT = 3  # Need T3 leadership to initiate


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


def _check_coup_cooldown(state: PlayerState) -> Tuple[bool, str]:
    """Check if player can initiate coup (24h cooldown)"""
    if state.last_coup_attempt:
        time_since = datetime.utcnow() - state.last_coup_attempt
        if time_since < timedelta(hours=COUP_COOLDOWN_HOURS):
            hours_remaining = COUP_COOLDOWN_HOURS - (time_since.total_seconds() / 3600)
            return False, f"Coup cooldown active. {hours_remaining:.1f} hours remaining."
    return True, ""


def _get_kingdom_reputation(state: PlayerState, kingdom_id: str) -> int:
    """Get player's reputation in a specific kingdom"""
    if not state.kingdom_reputation:
        return 0
    return state.kingdom_reputation.get(kingdom_id, 0)


def _get_initiator_stats(db: Session, initiator_id: int, kingdom_id: str) -> InitiatorStats:
    """Get comprehensive stats about the coup initiator"""
    user = db.query(User).filter(User.id == initiator_id).first()
    if not user:
        return None
    
    state = _get_player_state(db, user)
    kingdom_rep = _get_kingdom_reputation(state, kingdom_id)
    
    return InitiatorStats(
        reputation=state.reputation,
        kingdom_reputation=kingdom_rep,
        attack_power=state.attack_power,
        defense_power=state.defense_power,
        leadership=state.leadership,
        building_skill=state.building_skill,
        intelligence=state.intelligence,
        contracts_completed=state.contracts_completed,
        total_work_contributed=state.total_work_contributed,
        level=state.level
    )


def _calculate_combat_strength(
    db: Session,
    player_ids: List[int]
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
        
        # Apply debuffs if active
        attack_power = state.attack_power
        if state.attack_debuff and state.debuff_expires_at:
            if datetime.utcnow() < state.debuff_expires_at:
                attack_power = max(1, attack_power - state.attack_debuff)
        
        total_attack += attack_power
        total_defense += state.defense_power
        
        participants.append(CoupParticipant(
            player_id=player_id,
            player_name=user.username,
            attack_power=attack_power,
            defense_power=state.defense_power
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
            old_ruler_name = old_ruler.username
            old_ruler_state = _get_player_state(db, old_ruler)
            
            # Old ruler loses rulership
            old_ruler_state.kingdoms_ruled = max(0, old_ruler_state.kingdoms_ruled - 1)
            old_ruler_state.is_ruler = False
            
            # Remove from fiefs
            if old_ruler_state.fiefs_ruled and kingdom.id in old_ruler_state.fiefs_ruled:
                fiefs = old_ruler_state.fiefs_ruled.copy()
                fiefs.remove(kingdom.id)
                old_ruler_state.fiefs_ruled = fiefs
    
    # Initiator becomes ruler
    kingdom.ruler_id = initiator.id
    kingdom.last_activity = datetime.utcnow()
    
    initiator_state.gold += 1000
    initiator_state.reputation += 50
    initiator_state.kingdoms_ruled += 1
    initiator_state.coups_won += 1
    initiator_state.is_ruler = True
    
    # Add to fiefs
    fiefs = initiator_state.fiefs_ruled.copy() if initiator_state.fiefs_ruled else []
    if kingdom.id not in fiefs:
        fiefs.append(kingdom.id)
    initiator_state.fiefs_ruled = fiefs
    
    # Update kingdom reputation
    kingdom_rep = initiator_state.kingdom_reputation.copy() if initiator_state.kingdom_reputation else {}
    kingdom_rep[kingdom.id] = kingdom_rep.get(kingdom.id, 0) + 50
    initiator_state.kingdom_reputation = kingdom_rep
    
    db.commit()
    
    return {
        "old_ruler_id": old_ruler_id,
        "old_ruler_name": old_ruler_name,
        "new_ruler_id": initiator.id,
        "new_ruler_name": initiator.username
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
        
        # MAJOR reputation loss
        state.reputation = max(0, state.reputation - 100)
        
        # Lose reputation in this kingdom
        kingdom_rep = state.kingdom_reputation.copy() if state.kingdom_reputation else {}
        kingdom_rep[kingdom.id] = max(0, kingdom_rep.get(kingdom.id, 0) - 100)
        state.kingdom_reputation = kingdom_rep
        
        # Lose ALL combat stats (executed)
        state.attack_power = 1
        state.defense_power = 1
        
        # Track failed coup
        state.coups_failed += 1
        state.times_executed += 1
    
    # Ruler gets all seized gold
    if ruler_state:
        ruler_state.gold += total_gold_seized
        ruler_state.reputation += 50
    
    # Reward defenders
    for defender in defenders:
        user = db.query(User).filter(User.id == defender.player_id).first()
        if not user:
            continue
        
        state = _get_player_state(db, user)
        state.gold += 200
        state.reputation += 30
        
        # Boost kingdom reputation
        kingdom_rep = state.kingdom_reputation.copy() if state.kingdom_reputation else {}
        kingdom_rep[kingdom.id] = kingdom_rep.get(kingdom.id, 0) + 30
        state.kingdom_reputation = kingdom_rep
    
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
        db, coup.get_attacker_ids()
    )
    
    # Calculate defender strength
    _, defender_defense, defenders = _calculate_combat_strength(
        db, coup.get_defender_ids()
    )
    
    # NO WALLS for coups (internal rebellion)
    total_defense = defender_defense
    
    # Determine victory (attackers need 25% advantage)
    required_attack = int(total_defense * ATTACKER_ADVANTAGE_REQUIRED)
    attacker_victory = attacker_attack > required_attack
    
    # Update coup record
    coup.status = 'resolved'
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
    Initiate a coup in a kingdom
    
    Requirements:
    - 300+ reputation in target kingdom
    - 50 gold
    - Checked in to kingdom
    - 24h cooldown between attempts
    - Cannot already be the ruler
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
    kingdom_rep = _get_kingdom_reputation(state, kingdom.id)
    if kingdom_rep < COUP_REPUTATION_REQUIREMENT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need {COUP_REPUTATION_REQUIREMENT} reputation in this kingdom (you have {kingdom_rep})"
        )
    
    # Calculate coup cost (T5 leadership = 50% off)
    coup_cost = COUP_BASE_COST
    if state.leadership >= 5:
        coup_cost = COUP_BASE_COST // 2  # 50% discount at T5
    
    # Check gold
    if state.gold < coup_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need {coup_cost} gold to initiate coup (you have {state.gold})"
        )
    
    # Check cooldown
    can_coup, cooldown_msg = _check_coup_cooldown(state)
    if not can_coup:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=cooldown_msg
        )
    
    # Check for existing active coup
    existing_coup = db.query(CoupEvent).filter(
        CoupEvent.kingdom_id == kingdom.id,
        CoupEvent.status == 'voting'
    ).first()
    
    if existing_coup:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A coup is already in progress in this kingdom"
        )
    
    # Deduct gold
    state.gold -= coup_cost
    state.last_coup_attempt = datetime.utcnow()
    
    # Create coup event
    end_time = datetime.utcnow() + timedelta(hours=COUP_VOTING_DURATION_HOURS)
    coup = CoupEvent(
        kingdom_id=kingdom.id,
        initiator_id=current_user.id,
        initiator_name=current_user.username,
        status='voting',
        start_time=datetime.utcnow(),
        end_time=end_time,
        attackers=[current_user.id],  # Initiator automatically joins attackers
        defenders=[]
    )
    
    db.add(coup)
    db.commit()
    db.refresh(coup)
    
    return CoupInitiateResponse(
        success=True,
        message=f"Coup initiated in {kingdom.name}! You have {COUP_VOTING_DURATION_HOURS} hours to gather support.",
        coup_id=coup.id,
        cost_paid=coup_cost,
        end_time=end_time
    )


@router.post("/{coup_id}/join", response_model=CoupJoinResponse)
def join_coup(
    coup_id: int,
    request: CoupJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Join a coup on either attackers or defenders side
    
    Requirements:
    - Must be checked in to kingdom
    - Cannot have already joined
    - Voting period must be active
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    if not coup.is_voting_open:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Voting period has ended"
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


@router.get("/active", response_model=ActiveCoupsResponse)
def get_active_coups(
    kingdom_id: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all active coups, optionally filtered by kingdom
    """
    query = db.query(CoupEvent).filter(CoupEvent.status == 'voting')
    
    if kingdom_id:
        query = query.filter(CoupEvent.kingdom_id == kingdom_id)
    
    coups = query.order_by(CoupEvent.start_time.desc()).all()
    
    state = _get_player_state(db, current_user)
    
    coup_responses = []
    for coup in coups:
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        
        attacker_ids = coup.get_attacker_ids()
        defender_ids = coup.get_defender_ids()
        
        # Determine user's side
        user_side = None
        if current_user.id in attacker_ids:
            user_side = 'attackers'
        elif current_user.id in defender_ids:
            user_side = 'defenders'
        
        # Check if user can join
        can_join = (
            state.current_kingdom_id == coup.kingdom_id and
            current_user.id not in attacker_ids and
            current_user.id not in defender_ids and
            coup.is_voting_open
        )
        
        # Get initiator stats
        initiator_stats = _get_initiator_stats(db, coup.initiator_id, coup.kingdom_id)
        
        coup_responses.append(CoupEventResponse(
            id=coup.id,
            kingdom_id=coup.kingdom_id,
            kingdom_name=kingdom.name if kingdom else None,
            initiator_id=coup.initiator_id,
            initiator_name=coup.initiator_name,
            initiator_stats=initiator_stats,
            status=coup.status,
            start_time=coup.start_time,
            end_time=coup.end_time,
            time_remaining_seconds=coup.time_remaining_seconds,
            attacker_ids=attacker_ids,
            defender_ids=defender_ids,
            attacker_count=len(attacker_ids),
            defender_count=len(defender_ids),
            user_side=user_side,
            can_join=can_join,
            is_resolved=coup.is_resolved,
            attacker_victory=coup.attacker_victory,
            attacker_strength=coup.attacker_strength,
            defender_strength=coup.defender_strength,
            total_defense_with_walls=coup.total_defense_with_walls,
            resolved_at=coup.resolved_at
        ))
    
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
    """Get details of a specific coup"""
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
    state = _get_player_state(db, current_user)
    
    attacker_ids = coup.get_attacker_ids()
    defender_ids = coup.get_defender_ids()
    
    # Determine user's side
    user_side = None
    if current_user.id in attacker_ids:
        user_side = 'attackers'
    elif current_user.id in defender_ids:
        user_side = 'defenders'
    
    # Check if user can join
    can_join = (
        state.current_kingdom_id == coup.kingdom_id and
        current_user.id not in attacker_ids and
        current_user.id not in defender_ids and
        coup.is_voting_open
    )
    
    # Get initiator stats
    initiator_stats = _get_initiator_stats(db, coup.initiator_id, coup.kingdom_id)
    
    return CoupEventResponse(
        id=coup.id,
        kingdom_id=coup.kingdom_id,
        kingdom_name=kingdom.name if kingdom else None,
        initiator_id=coup.initiator_id,
        initiator_name=coup.initiator_name,
        initiator_stats=initiator_stats,
        status=coup.status,
        start_time=coup.start_time,
        end_time=coup.end_time,
        time_remaining_seconds=coup.time_remaining_seconds,
        attacker_ids=attacker_ids,
        defender_ids=defender_ids,
        attacker_count=len(attacker_ids),
        defender_count=len(defender_ids),
        user_side=user_side,
        can_join=can_join,
        is_resolved=coup.is_resolved,
        attacker_victory=coup.attacker_victory,
        attacker_strength=coup.attacker_strength,
        defender_strength=coup.defender_strength,
        total_defense_with_walls=coup.total_defense_with_walls,
        resolved_at=coup.resolved_at
    )


@router.post("/{coup_id}/resolve", response_model=CoupResolveResponse)
def resolve_coup(
    coup_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Manually resolve a coup (or auto-resolve after timer expires)
    Anyone can call this after the voting period ends
    """
    coup = db.query(CoupEvent).filter(CoupEvent.id == coup_id).first()
    
    if not coup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Coup not found"
        )
    
    if coup.is_resolved:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Coup has already been resolved"
        )
    
    if not coup.should_resolve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Coup cannot be resolved yet. {coup.time_remaining_seconds} seconds remaining."
        )
    
    return _resolve_coup_battle(db, coup)


@router.post("/auto-resolve-expired")
def auto_resolve_expired_coups(db: Session = Depends(get_db)):
    """
    Background task endpoint to auto-resolve all expired coups
    Should be called periodically (e.g., every minute by a cron job)
    """
    # Find all coups that should be resolved
    expired_coups = db.query(CoupEvent).filter(
        CoupEvent.status == 'voting',
        CoupEvent.end_time <= datetime.utcnow()
    ).all()
    
    resolved_count = 0
    results = []
    
    for coup in expired_coups:
        try:
            result = _resolve_coup_battle(db, coup)
            results.append({
                "coup_id": coup.id,
                "kingdom_id": coup.kingdom_id,
                "attacker_victory": result.attacker_victory
            })
            resolved_count += 1
        except Exception as e:
            results.append({
                "coup_id": coup.id,
                "error": str(e)
            })
    
    return {
        "success": True,
        "resolved_count": resolved_count,
        "results": results
    }

