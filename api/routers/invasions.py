"""
Invasion system - External conquest between cities
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict

from db import get_db, User, PlayerState, Kingdom, InvasionEvent, KingdomHistory, Alliance
from routers.alliances import are_empires_allied
from schemas.invasion import (
    InvasionDeclareRequest,
    InvasionDeclareResponse,
    InvasionJoinRequest,
    InvasionJoinResponse,
    InvasionEventResponse,
    InvasionResolveResponse,
    InvasionParticipant,
    ActiveInvasionsResponse,
)
from routers.auth import get_current_user

router = APIRouter(prefix="/invasions", tags=["Invasions"])

# Constants
INVASION_COST_PER_ATTACKER = 500  # High risk, high reward
INVASION_WARNING_HOURS = 2
ATTACKER_ADVANTAGE_REQUIRED = 1.25
WALL_DEFENSE_PER_LEVEL = 5
RULER_PROTECTION_DAYS = 30  # Rulers must be in power for 30 days before kingdom can be invaded


def _get_player_state(db: Session, user: User) -> PlayerState:
    state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
    if not state:
        state = PlayerState(user_id=user.id)
        db.add(state)
        db.commit()
        db.refresh(state)
    return state


def _calculate_combat_strength(db: Session, player_ids: List[int]) -> tuple:
    """Calculate attack and defense power for a list of players"""
    total_attack = 0
    total_defense = 0
    participants = []
    
    for player_id in player_ids:
        user = db.query(User).filter(User.id == player_id).first()
        if not user:
            continue
        state = _get_player_state(db, user)
        
        attack = state.attack_power
        if state.attack_debuff and state.debuff_expires_at:
            if datetime.utcnow() < state.debuff_expires_at:
                attack = max(1, attack - state.attack_debuff)
        
        total_attack += attack
        total_defense += state.defense_power
        
        participants.append(InvasionParticipant(
            player_id=player_id,
            player_name=user.username,
            attack_power=attack,
            defense_power=state.defense_power
        ))
    
    return total_attack, total_defense, participants


def _record_history(db: Session, kingdom: Kingdom, ruler_id: int, ruler_name: str, 
                    event_type: str, invasion_id: int = None, coup_id: int = None):
    """Record ruler change in history"""
    # End previous ruler's reign
    db.query(KingdomHistory).filter(
        KingdomHistory.kingdom_id == kingdom.id,
        KingdomHistory.ended_at.is_(None)
    ).update({"ended_at": datetime.utcnow()})
    
    # Record new ruler
    history = KingdomHistory(
        kingdom_id=kingdom.id,
        ruler_id=ruler_id,
        ruler_name=ruler_name,
        empire_id=kingdom.empire_id or kingdom.id,
        event_type=event_type,
        started_at=datetime.utcnow(),
        invasion_id=invasion_id,
        coup_id=coup_id
    )
    db.add(history)


@router.post("/declare", response_model=InvasionDeclareResponse)
def declare_invasion(
    request: InvasionDeclareRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Declare invasion from one city to another.
    Initiator must rule the attacking city.
    Target must be nearby (we trust client for now).
    """
    state = _get_player_state(db, current_user)
    
    # Check initiator rules the attacking city
    attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == request.attacking_from_kingdom_id).first()
    if not attacking_kingdom:
        raise HTTPException(status_code=404, detail="Attacking kingdom not found")
    
    if attacking_kingdom.ruler_id != current_user.id:
        raise HTTPException(status_code=400, detail="You don't rule this city")
    
    # Must be AT the target city to declare invasion
    if state.current_kingdom_id != request.target_kingdom_id:
        raise HTTPException(status_code=400, detail="Must be at target city to declare invasion")
    
    # Check target exists and is not same empire
    target_kingdom = db.query(Kingdom).filter(Kingdom.id == request.target_kingdom_id).first()
    if not target_kingdom:
        raise HTTPException(status_code=404, detail="Target kingdom not found")
    
    # Check ruler has been in power for at least 30 days
    if target_kingdom.ruler_started_at:
        ruler_tenure = datetime.utcnow() - target_kingdom.ruler_started_at
        if ruler_tenure.days < RULER_PROTECTION_DAYS:
            days_remaining = RULER_PROTECTION_DAYS - ruler_tenure.days
            raise HTTPException(
                status_code=400, 
                detail=f"Cannot invade: Ruler has only been in power for {ruler_tenure.days} days. Must wait at least {RULER_PROTECTION_DAYS} days ({days_remaining} days remaining)."
            )
    
    if target_kingdom.empire_id == attacking_kingdom.empire_id:
        raise HTTPException(status_code=400, detail="Cannot invade your own empire")
    
    # Check alliance - cannot attack allies
    if are_empires_allied(db, attacking_kingdom.empire_id or attacking_kingdom.id, 
                          target_kingdom.empire_id or target_kingdom.id):
        raise HTTPException(
            status_code=400, 
            detail="Cannot invade allied empire! Alliance must expire first."
        )
    
    # Check no active invasion on target
    existing = db.query(InvasionEvent).filter(
        InvasionEvent.target_kingdom_id == request.target_kingdom_id,
        InvasionEvent.status == 'declared'
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Invasion already in progress on this city")
    
    # Check gold (only initiator pays)
    if state.gold < INVASION_COST_PER_ATTACKER:
        raise HTTPException(status_code=400, detail=f"Need {INVASION_COST_PER_ATTACKER}g to declare invasion")
    
    # Deduct gold
    state.gold -= INVASION_COST_PER_ATTACKER
    state.last_invasion_attempt = datetime.utcnow()
    
    # Create invasion
    battle_time = datetime.utcnow() + timedelta(hours=INVASION_WARNING_HOURS)
    invasion = InvasionEvent(
        attacking_from_kingdom_id=request.attacking_from_kingdom_id,
        target_kingdom_id=request.target_kingdom_id,
        initiator_id=current_user.id,
        initiator_name=current_user.username,
        status='declared',
        declared_at=datetime.utcnow(),
        battle_time=battle_time,
        attackers=[current_user.id],
        defenders=[],
        cost_per_attacker=INVASION_COST_PER_ATTACKER,
        total_cost_paid=INVASION_COST_PER_ATTACKER
    )
    
    db.add(invasion)
    db.commit()
    db.refresh(invasion)
    
    return InvasionDeclareResponse(
        success=True,
        message=f"Invasion declared! Battle in {INVASION_WARNING_HOURS} hours.",
        invasion_id=invasion.id,
        battle_time=battle_time,
        cost_paid=INVASION_COST_PER_ATTACKER
    )


@router.post("/{invasion_id}/join", response_model=InvasionJoinResponse)
def join_invasion(
    invasion_id: int,
    request: InvasionJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Join an invasion as attacker or defender"""
    invasion = db.query(InvasionEvent).filter(InvasionEvent.id == invasion_id).first()
    if not invasion:
        raise HTTPException(status_code=404, detail="Invasion not found")
    
    if not invasion.can_join:
        raise HTTPException(status_code=400, detail="Cannot join - battle already resolved or started")
    
    state = _get_player_state(db, current_user)
    
    attacker_ids = invasion.get_attacker_ids()
    defender_ids = invasion.get_defender_ids()
    
    if current_user.id in attacker_ids or current_user.id in defender_ids:
        raise HTTPException(status_code=400, detail="Already joined")
    
    if request.side == 'attackers':
        # Must be AT the target city to invade it
        if state.current_kingdom_id != invasion.target_kingdom_id:
            raise HTTPException(status_code=400, detail="Must be at target city to join invasion")
        invasion.add_attacker(current_user.id)
    elif request.side == 'defenders':
        # Must be checked in to target city
        if state.current_kingdom_id != invasion.target_kingdom_id:
            raise HTTPException(status_code=400, detail="Must be checked in to target city to defend")
        
        # Check if player can defend: must be from target kingdom, same empire, or allied empire
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.target_kingdom_id).first()
        player_home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first() if state.hometown_kingdom_id else None
        
        is_local = state.hometown_kingdom_id == invasion.target_kingdom_id
        is_same_empire = (player_home_kingdom and target_kingdom and 
                         (player_home_kingdom.empire_id or player_home_kingdom.id) == (target_kingdom.empire_id or target_kingdom.id))
        is_allied = (player_home_kingdom and target_kingdom and 
                    are_empires_allied(db, 
                                      player_home_kingdom.empire_id or player_home_kingdom.id,
                                      target_kingdom.empire_id or target_kingdom.id))
        
        if not (is_local or is_same_empire or is_allied):
            raise HTTPException(
                status_code=400, 
                detail="Must be from target kingdom, same empire, or allied empire to defend"
            )
        
        invasion.add_defender(current_user.id)
    else:
        raise HTTPException(status_code=400, detail="Side must be 'attackers' or 'defenders'")
    
    db.commit()
    db.refresh(invasion)
    
    return InvasionJoinResponse(
        success=True,
        message=f"Joined {request.side}!",
        side=request.side,
        attacker_count=len(invasion.get_attacker_ids()),
        defender_count=len(invasion.get_defender_ids())
    )


@router.get("/active", response_model=ActiveInvasionsResponse)
def get_active_invasions(
    kingdom_id: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get active invasions, optionally filtered by kingdom"""
    query = db.query(InvasionEvent).filter(InvasionEvent.status == 'declared')
    
    if kingdom_id:
        query = query.filter(
            (InvasionEvent.target_kingdom_id == kingdom_id) |
            (InvasionEvent.attacking_from_kingdom_id == kingdom_id)
        )
    
    invasions = query.order_by(InvasionEvent.battle_time.asc()).all()
    state = _get_player_state(db, current_user)
    
    responses = []
    for inv in invasions:
        attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == inv.attacking_from_kingdom_id).first()
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == inv.target_kingdom_id).first()
        
        attacker_ids = inv.get_attacker_ids()
        defender_ids = inv.get_defender_ids()
        
        user_side = None
        if current_user.id in attacker_ids:
            user_side = 'attackers'
        elif current_user.id in defender_ids:
            user_side = 'defenders'
        
        # Check if user can join each side based on location
        # Both attackers and defenders need to be AT the target city
        not_already_joined = current_user.id not in attacker_ids and current_user.id not in defender_ids
        at_target = state.current_kingdom_id == inv.target_kingdom_id
        can_join_attackers = inv.can_join and not_already_joined and at_target
        can_join_defenders = inv.can_join and not_already_joined and at_target
        
        responses.append(InvasionEventResponse(
            id=inv.id,
            attacking_from_kingdom_id=inv.attacking_from_kingdom_id,
            attacking_from_kingdom_name=attacking_kingdom.name if attacking_kingdom else None,
            target_kingdom_id=inv.target_kingdom_id,
            target_kingdom_name=target_kingdom.name if target_kingdom else None,
            initiator_id=inv.initiator_id,
            initiator_name=inv.initiator_name,
            status=inv.status,
            declared_at=inv.declared_at,
            battle_time=inv.battle_time,
            time_remaining_seconds=inv.time_remaining_seconds,
            attacker_ids=attacker_ids,
            defender_ids=defender_ids,
            attacker_count=len(attacker_ids),
            defender_count=len(defender_ids),
            user_side=user_side,
            can_join_attackers=can_join_attackers,
            can_join_defenders=can_join_defenders,
            user_current_kingdom_id=state.current_kingdom_id,
            is_resolved=inv.is_resolved,
            attacker_victory=inv.attacker_victory,
            attacker_strength=inv.attacker_strength,
            defender_strength=inv.defender_strength,
            total_defense_with_walls=inv.total_defense_with_walls,
            resolved_at=inv.resolved_at
        ))
    
    return ActiveInvasionsResponse(active_invasions=responses, count=len(responses))


@router.get("/{invasion_id}", response_model=InvasionEventResponse)
def get_invasion(
    invasion_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get invasion details"""
    inv = db.query(InvasionEvent).filter(InvasionEvent.id == invasion_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="Invasion not found")
    
    attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == inv.attacking_from_kingdom_id).first()
    target_kingdom = db.query(Kingdom).filter(Kingdom.id == inv.target_kingdom_id).first()
    
    attacker_ids = inv.get_attacker_ids()
    defender_ids = inv.get_defender_ids()
    
    state = _get_player_state(db, current_user)
    
    user_side = None
    if current_user.id in attacker_ids:
        user_side = 'attackers'
    elif current_user.id in defender_ids:
        user_side = 'defenders'
    
    # Check if user can join each side based on location
    # Both attackers and defenders need to be AT the target city
    not_already_joined = current_user.id not in attacker_ids and current_user.id not in defender_ids
    at_target = state.current_kingdom_id == inv.target_kingdom_id
    can_join_attackers = inv.can_join and not_already_joined and at_target
    can_join_defenders = inv.can_join and not_already_joined and at_target
    
    return InvasionEventResponse(
        id=inv.id,
        attacking_from_kingdom_id=inv.attacking_from_kingdom_id,
        attacking_from_kingdom_name=attacking_kingdom.name if attacking_kingdom else None,
        target_kingdom_id=inv.target_kingdom_id,
        target_kingdom_name=target_kingdom.name if target_kingdom else None,
        initiator_id=inv.initiator_id,
        initiator_name=inv.initiator_name,
        status=inv.status,
        declared_at=inv.declared_at,
        battle_time=inv.battle_time,
        time_remaining_seconds=inv.time_remaining_seconds,
        attacker_ids=attacker_ids,
        defender_ids=defender_ids,
        attacker_count=len(attacker_ids),
        defender_count=len(defender_ids),
        user_side=user_side,
        can_join_attackers=can_join_attackers,
        can_join_defenders=can_join_defenders,
        user_current_kingdom_id=state.current_kingdom_id,
        is_resolved=inv.is_resolved,
        attacker_victory=inv.attacker_victory,
        attacker_strength=inv.attacker_strength,
        defender_strength=inv.defender_strength,
        total_defense_with_walls=inv.total_defense_with_walls,
        resolved_at=inv.resolved_at
    )


@router.post("/{invasion_id}/resolve", response_model=InvasionResolveResponse)
def resolve_invasion(
    invasion_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Resolve invasion battle after timer expires"""
    inv = db.query(InvasionEvent).filter(InvasionEvent.id == invasion_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="Invasion not found")
    
    if inv.is_resolved:
        raise HTTPException(status_code=400, detail="Already resolved")
    
    if not inv.should_resolve:
        raise HTTPException(status_code=400, detail=f"Battle not ready. {inv.time_remaining_seconds}s remaining")
    
    target = db.query(Kingdom).filter(Kingdom.id == inv.target_kingdom_id).first()
    attacking = db.query(Kingdom).filter(Kingdom.id == inv.attacking_from_kingdom_id).first()
    
    # Calculate combat
    attacker_attack, _, attackers = _calculate_combat_strength(db, inv.get_attacker_ids())
    _, defender_defense, defenders = _calculate_combat_strength(db, inv.get_defender_ids())
    
    wall_defense = (target.wall_level or 0) * WALL_DEFENSE_PER_LEVEL
    total_defense = defender_defense + wall_defense
    required_attack = int(total_defense * ATTACKER_ADVANTAGE_REQUIRED)
    
    attacker_victory = attacker_attack > required_attack
    
    # Update invasion record
    inv.status = 'resolved'
    inv.attacker_victory = attacker_victory
    inv.attacker_strength = attacker_attack
    inv.defender_strength = defender_defense
    inv.total_defense_with_walls = total_defense
    inv.resolved_at = datetime.utcnow()
    
    old_ruler_id = target.ruler_id
    old_ruler_name = None
    new_ruler_id = None
    new_ruler_name = None
    loot_per_attacker = 0
    wall_damage = 0
    
    if attacker_victory:
        # Get old ruler
        if old_ruler_id:
            old_ruler = db.query(User).filter(User.id == old_ruler_id).first()
            old_ruler_name = old_ruler.username if old_ruler else None
            if old_ruler:
                old_state = _get_player_state(db, old_ruler)
                old_state.kingdoms_ruled = max(0, old_state.kingdoms_ruled - 1)
                if old_state.fiefs_ruled and target.id in old_state.fiefs_ruled:
                    fiefs = old_state.fiefs_ruled.copy()
                    fiefs.remove(target.id)
                    old_state.fiefs_ruled = fiefs
        
        # Transfer city to attacker's empire
        initiator = db.query(User).filter(User.id == inv.initiator_id).first()
        initiator_state = _get_player_state(db, initiator)
        
        target.ruler_id = initiator.id
        target.empire_id = attacking.empire_id or attacking.id
        
        new_ruler_id = initiator.id
        new_ruler_name = initiator.username
        
        # Add to initiator's fiefs
        fiefs = initiator_state.fiefs_ruled.copy() if initiator_state.fiefs_ruled else []
        if target.id not in fiefs:
            fiefs.append(target.id)
        initiator_state.fiefs_ruled = fiefs
        initiator_state.kingdoms_ruled += 1
        initiator_state.total_conquests += 1
        
        # Loot treasury (vault protects some)
        vault_protection = min(0.8, (target.vault_level or 0) * 0.2)
        lootable = int((target.treasury_gold or 0) * (1 - vault_protection))
        
        # Each attacker gets their share of loot + big rep boost
        if lootable > 0 and len(attackers) > 0:
            loot_per_attacker = lootable // len(attackers)
        else:
            loot_per_attacker = 0
            
        for attacker in attackers:
            user = db.query(User).filter(User.id == attacker.player_id).first()
            if user:
                s = _get_player_state(db, user)
                s.gold += loot_per_attacker
                s.reputation += 100  # Big reward for successful invasion
                
        if lootable > 0:
            target.treasury_gold = (target.treasury_gold or 0) - lootable
        
        inv.loot_distributed = lootable
        
        # Damage walls
        wall_damage = min(2, target.wall_level or 0)
        target.wall_level = max(0, (target.wall_level or 0) - wall_damage)
        
        # Record history
        _record_history(db, target, initiator.id, initiator.username, 'invasion', invasion_id=inv.id)
        
        message = f"🏴 INVASION SUCCESS! {attacking.name} conquered {target.name}!"
    else:
        # Attackers lose - 50% treasury transfer + 10% gold to defenders
        
        # 1. 50% of attacking kingdom's treasury → defending kingdom
        if attacking and attacking.treasury_gold:
            treasury_transfer = attacking.treasury_gold // 2
            attacking.treasury_gold -= treasury_transfer
            target.treasury_gold = (target.treasury_gold or 0) + treasury_transfer
        
        # 2. 10% from each attacker's gold → split among defenders
        attacker_gold_pool = 0
        for attacker in attackers:
            user = db.query(User).filter(User.id == attacker.player_id).first()
            if user:
                s = _get_player_state(db, user)
                
                # Take 10% of gold for defender pool
                gold_for_defenders = s.gold // 10
                s.gold -= gold_for_defenders
                attacker_gold_pool += gold_for_defenders
                
                # Reputation loss
                s.reputation = max(0, s.reputation - 100)
                
                # Skill loss for failed invasion
                s.attack_power = max(1, s.attack_power - 1)
                s.defense_power = max(1, s.defense_power - 1)
                s.leadership = max(0, s.leadership - 1)
        
        # Distribute attacker gold to defenders
        gold_per_defender = attacker_gold_pool // len(defenders) if defenders else 0
        for defender in defenders:
            user = db.query(User).filter(User.id == defender.player_id).first()
            if user:
                s = _get_player_state(db, user)
                s.gold += gold_per_defender
                s.reputation += 100
        
        message = f"🛡️ INVASION FAILED! {target.name} defended successfully!"
    
    db.commit()
    
    return InvasionResolveResponse(
        success=True,
        invasion_id=inv.id,
        attacker_victory=attacker_victory,
        attacker_strength=attacker_attack,
        defender_strength=defender_defense,
        total_defense_with_walls=total_defense,
        required_attack_strength=required_attack,
        attackers=attackers,
        defenders=defenders,
        old_ruler_id=old_ruler_id,
        old_ruler_name=old_ruler_name,
        new_ruler_id=new_ruler_id,
        new_ruler_name=new_ruler_name,
        loot_per_attacker=loot_per_attacker,
        wall_damage=wall_damage,
        message=message
    )


@router.post("/auto-resolve")
def auto_resolve_invasions(db: Session = Depends(get_db)):
    """Background job to auto-resolve expired invasions"""
    expired = db.query(InvasionEvent).filter(
        InvasionEvent.status == 'declared',
        InvasionEvent.battle_time <= datetime.utcnow()
    ).all()
    
    results = []
    for inv in expired:
        try:
            # Fake a user for resolution
            initiator = db.query(User).filter(User.id == inv.initiator_id).first()
            if initiator:
                result = resolve_invasion(inv.id, initiator, db)
                results.append({"invasion_id": inv.id, "success": True, "attacker_victory": result.attacker_victory})
        except Exception as e:
            results.append({"invasion_id": inv.id, "error": str(e)})
    
    return {"resolved_count": len(results), "results": results}

