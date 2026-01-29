"""
DUEL API ROUTER - Swing-by-Swing PvP Combat
=============================================

Endpoints:
- POST /duels/create - Challenge a friend
- GET /duels/invitations - Get pending challenges
- POST /duels/invitations/{id}/accept - Accept challenge
- POST /duels/invitations/{id}/decline - Decline challenge
- POST /duels/{id}/start - Start the match
- POST /duels/{id}/lock-style - Lock attack style
- POST /duels/{id}/swing - Execute ONE swing
- POST /duels/{id}/stop - Stop swinging, lock in best
- POST /duels/{id}/forfeit - Forfeit match
- POST /duels/{id}/claim-timeout - Claim timeout victory
- POST /duels/{id}/cancel - Cancel waiting match
- GET /duels/{id} - Get match status
- GET /duels/active - Get active match
- GET /duels/stats - Get duel stats
- GET /duels/leaderboard - Top duelists
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List

from db import get_db
from db.models import User, DuelMatch, DuelInvitation, DuelStatus, Friend
from routers.auth import get_current_user
from systems.duel import DuelManager
from websocket.broadcast import broadcast_duel_event, DuelEvents
from sqlalchemy import or_, and_

router = APIRouter(prefix="/duels", tags=["duels"])
_duel_manager = DuelManager()


def get_duel_manager() -> DuelManager:
    return _duel_manager


def _get_apple_user_ids(db: Session, user_ids: List[int]) -> List[str]:
    """Convert DB user IDs to Apple user IDs for WebSocket."""
    valid_ids = [uid for uid in user_ids if uid is not None]
    if not valid_ids:
        return []
    users = db.query(User).filter(User.id.in_(valid_ids)).all()
    return [u.apple_user_id for u in users if u.apple_user_id]


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class CreateDuelRequest(BaseModel):
    kingdom_id: str
    opponent_id: int
    wager_gold: int = 0


class DuelResponse(BaseModel):
    success: bool
    message: str
    match: Optional[dict] = None


class SwingResponse(BaseModel):
    """Response for a single swing."""
    success: bool
    message: str
    roll: Optional[dict] = None
    outcome: Optional[str] = None
    swing_number: Optional[int] = None
    swings_remaining: Optional[int] = None
    max_swings: Optional[int] = None
    best_outcome: Optional[str] = None
    can_swing: Optional[bool] = None
    can_stop: Optional[bool] = None
    auto_submitted: Optional[bool] = None
    round_resolved: Optional[bool] = None
    resolution: Optional[dict] = None
    match: Optional[dict] = None
    miss_chance: Optional[int] = None
    hit_chance_pct: Optional[int] = None
    crit_chance: Optional[int] = None


class StopResponse(BaseModel):
    """Response for stopping (locking in best roll)."""
    success: bool
    message: str
    submitted: Optional[bool] = None
    best_outcome: Optional[str] = None
    waiting_for_opponent: Optional[bool] = None
    round_resolved: Optional[bool] = None
    resolution: Optional[dict] = None
    match: Optional[dict] = None


class LockStyleRequest(BaseModel):
    style: str


class LockStyleResponse(BaseModel):
    success: bool
    message: str
    style: Optional[str] = None
    both_styles_locked: Optional[bool] = None
    match: Optional[dict] = None


class InvitationsResponse(BaseModel):
    success: bool
    invitations: List[dict]


class StatsResponse(BaseModel):
    success: bool
    stats: Optional[dict] = None


class LeaderboardResponse(BaseModel):
    success: bool
    leaderboard: List[dict]


# ============================================================
# STATIC ROUTES
# ============================================================

@router.get("/invitations", response_model=InvitationsResponse)
def get_invitations(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get pending duel invitations."""
    invitations = manager.get_pending_invitations(db, user.id)
    return InvitationsResponse(success=True, invitations=invitations)


@router.get("/active", response_model=DuelResponse)
def get_active_match(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get player's active match."""
    match = manager.get_active_match_for_player(db, user.id)
    if match:
        return DuelResponse(
            success=True,
            message="Active match found",
            match=match.to_dict_for_player(user.id, include_actions=True)
        )
    return DuelResponse(success=True, message="No active match", match=None)


@router.get("/stats", response_model=StatsResponse)
def get_my_stats(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get duel statistics."""
    stats = manager.get_player_stats(db, user.id)
    if stats:
        return StatsResponse(success=True, stats=stats.to_dict())
    return StatsResponse(success=True, stats={
        "user_id": user.id, "wins": 0, "losses": 0, "draws": 0,
        "total_matches": 0, "win_rate": 0.0, "win_streak": 0, "best_win_streak": 0,
    })


@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    limit: int = 10,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get top duelists."""
    leaderboard = manager.get_leaderboard(db, limit=min(limit, 50))
    return LeaderboardResponse(success=True, leaderboard=leaderboard)


@router.get("/kingdom/{kingdom_id}/recent")
def get_recent_matches(
    kingdom_id: str,
    limit: int = 10,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get recent matches in a kingdom."""
    matches = manager.get_recent_matches(db, kingdom_id, limit=min(limit, 25))
    return {"success": True, "matches": matches}


@router.get("/pending-count")
def get_pending_duel_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get count of pending invitations."""
    count = db.query(DuelInvitation).filter(
        DuelInvitation.invitee_id == user.id,
        DuelInvitation.status == "pending"
    ).count()
    return {"count": count}


# ============================================================
# MATCH CREATION
# ============================================================

def are_friends(db: Session, user_id_1: int, user_id_2: int) -> bool:
    """Check if two users are friends."""
    friendship = db.query(Friend).filter(
        or_(
            and_(Friend.user_id == user_id_1, Friend.friend_user_id == user_id_2),
            and_(Friend.user_id == user_id_2, Friend.friend_user_id == user_id_1)
        ),
        Friend.status == 'accepted'
    ).first()
    return friendship is not None


@router.post("/create", response_model=DuelResponse)
def create_duel(
    request: CreateDuelRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Challenge a friend to a duel."""
    if request.opponent_id == user.id:
        return DuelResponse(success=False, message="Cannot challenge yourself")
    
    existing = manager.get_active_match_for_player(db, user.id)
    if existing:
        return DuelResponse(success=False, message="You already have an active duel", match=existing.to_dict())
    
    opponent = db.query(User).filter(User.id == request.opponent_id).first()
    if not opponent:
        return DuelResponse(success=False, message="Opponent not found")
    
    if not are_friends(db, user.id, request.opponent_id):
        return DuelResponse(success=False, message="You can only challenge friends")
    
    opponent_match = manager.get_active_match_for_player(db, request.opponent_id)
    if opponent_match:
        return DuelResponse(success=False, message=f"{opponent.display_name} is already in a duel")
    
    try:
        match, invitation = manager.create_challenge(
            db=db,
            challenger_id=user.id,
            opponent_id=request.opponent_id,
            kingdom_id=request.kingdom_id,
            wager_gold=request.wager_gold
        )
        
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_INVITATION,
            match=match.to_dict(),
            target_user_ids=_get_apple_user_ids(db, [request.opponent_id]),
            data={"inviter_name": user.display_name, "invitation_id": invitation.id, "wager_gold": request.wager_gold}
        )
        
        return DuelResponse(
            success=True,
            message=f"Challenge sent to {opponent.display_name}!",
            match=match.to_dict_for_player(user.id)
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/invitations/{invitation_id}/accept", response_model=DuelResponse)
def accept_invitation(
    invitation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Accept a duel invitation."""
    try:
        match = manager.join_by_invitation(db, invitation_id, user.id)
        
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_OPPONENT_JOINED,
            match=match.to_dict_for_player(match.challenger_id),
            target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
            data={"opponent_name": user.display_name}
        )
        
        return DuelResponse(success=True, message="Joined the duel!", match=match.to_dict_for_player(user.id))
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/invitations/{invitation_id}/decline")
def decline_invitation(
    invitation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Decline a duel invitation."""
    try:
        match = manager.decline_invitation(db, invitation_id, user.id)
        if match:
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_CANCELLED,
                match=match.to_dict(),
                target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
                data={"message": f"{user.display_name} declined your challenge."}
            )
        return {"success": True, "message": "Challenge declined"}
    except ValueError as e:
        return {"success": False, "message": str(e)}


# ============================================================
# MATCH FLOW
# ============================================================

@router.post("/{match_id}/start", response_model=DuelResponse)
def start_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Start the duel."""
    try:
        match = manager.start_match(db, match_id, user.id)
        
        # Notify both with their perspective
        for pid in [match.challenger_id, match.opponent_id]:
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_STARTED,
                match=match.to_dict_for_player(pid),
                target_user_ids=_get_apple_user_ids(db, [pid]),
                data={"message": "The duel begins!", "round_number": 1, "phase": "style_selection"}
            )
        
        return DuelResponse(success=True, message="The duel begins!", match=match.to_dict_for_player(user.id))
    except ValueError as e:
        match = manager.get_match(db, match_id)
        return DuelResponse(success=False, message=str(e), match=match.to_dict_for_player(user.id) if match else None)


@router.post("/{match_id}/lock-style", response_model=LockStyleResponse)
def lock_style(
    match_id: int,
    request: LockStyleRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Lock in an attack style."""
    try:
        result = manager.lock_style(db, match_id, user.id, request.style)
        db_match = manager.get_match(db, match_id)
        
        if db_match:
            opponent_id = db_match.opponent_id if db_match.challenger_id == user.id else db_match.challenger_id
            both_locked = result.get("both_styles_locked", False)
            
            if both_locked:
                # ONLY broadcast when BOTH have locked - reveals styles to both simultaneously
                for pid in [db_match.challenger_id, db_match.opponent_id]:
                    broadcast_duel_event(
                        event_type=DuelEvents.DUEL_STYLES_REVEALED,
                        match=db_match.to_dict_for_player(pid),
                        target_user_ids=_get_apple_user_ids(db, [pid]),
                        data={
                            "challenger_style": db_match.challenger_style,
                            "opponent_style": db_match.opponent_style,
                            "phase": "style_reveal",
                        }
                    )
            else:
                # Notify opponent that we locked (not WHICH style - just that they locked)
                broadcast_duel_event(
                    event_type=DuelEvents.DUEL_STYLE_LOCKED,
                    match=db_match.to_dict_for_player(opponent_id),
                    target_user_ids=_get_apple_user_ids(db, [opponent_id]),
                    data={
                        "locker_id": user.id,
                        "locker_name": user.display_name,
                    }
                )
        
        return LockStyleResponse(
            success=True,
            message=f"Locked in {request.style}!",
            style=result.get("style"),
            both_styles_locked=result.get("both_styles_locked"),
            match=db_match.to_dict_for_player(user.id) if db_match else None,
        )
    except ValueError as e:
        return LockStyleResponse(success=False, message=str(e))


# ============================================================
# SWING PHASE - THE CORE MECHANIC
# ============================================================

@router.post("/{match_id}/swing", response_model=SwingResponse)
def execute_swing(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Execute ONE swing.
    
    This is the core mechanic. Player clicks, gets one roll result,
    then decides to swing again or stop.
    """
    try:
        result = manager.swing(db, match_id, user.id)
        db_match = manager.get_match(db, match_id)
        
        if db_match:
            my_name = db_match.challenger_name if db_match.challenger_id == user.id else db_match.opponent_name
            opponent_id = db_match.opponent_id if db_match.challenger_id == user.id else db_match.challenger_id
            
            # Broadcast swing to opponent (real-time feedback)
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_SWING,
                match=db_match.to_dict_for_player(opponent_id),
                target_user_ids=_get_apple_user_ids(db, [opponent_id]),
                data={
                    "swinger_id": user.id,
                    "swinger_name": my_name,
                    "roll": result.get("roll"),
                    "outcome": result.get("outcome"),
                    "swing_number": result.get("swing_number"),
                    "swings_remaining": result.get("swings_remaining"),
                    "best_outcome": result.get("best_outcome"),
                }
            )
            
            # If auto-submitted (used all swings), notify opponent
            if result.get("auto_submitted"):
                broadcast_duel_event(
                    event_type=DuelEvents.DUEL_PLAYER_SUBMITTED,
                    match=db_match.to_dict_for_player(opponent_id),
                    target_user_ids=_get_apple_user_ids(db, [opponent_id]),
                    data={
                        "submitter_id": user.id,
                        "submitter_name": my_name,
                        "best_outcome": result.get("best_outcome"),
                    }
                )
            
            # If round resolved, broadcast to both
            if result.get("round_resolved"):
                resolution = result.get("resolution", {})
                winner_side = resolution.get("winner_side")
                raw_push = resolution.get("push_amount", 0)
                parried = resolution.get("parried", False)
                
                for pid in [db_match.challenger_id, db_match.opponent_id]:
                    # Calculate YOUR push amount with correct sign for this player's perspective
                    # Positive = you won/pushed forward, Negative = you lost/got pushed back
                    is_challenger = (pid == db_match.challenger_id)
                    if parried:
                        your_push_amount = 0.0
                        you_won = False
                    elif winner_side == "challenger":
                        your_push_amount = raw_push if is_challenger else -raw_push
                        you_won = is_challenger
                    elif winner_side == "opponent":
                        your_push_amount = -raw_push if is_challenger else raw_push
                        you_won = not is_challenger
                    else:
                        your_push_amount = 0.0
                        you_won = False
                    
                    event_type = DuelEvents.DUEL_ENDED if resolution.get("game_over") else DuelEvents.DUEL_ROUND_RESOLVED
                    broadcast_duel_event(
                        event_type=event_type,
                        match=db_match.to_dict_for_player(pid),
                        target_user_ids=_get_apple_user_ids(db, [pid]),
                        data={
                            "result": resolution,  # iOS reads "result"
                            "resolution": resolution,
                            "round_number": resolution.get("round_number"),
                            "winner_side": resolution.get("winner_side"),
                            "challenger_rolls": resolution.get("challenger_rolls"),
                            "opponent_rolls": resolution.get("opponent_rolls"),
                            "challenger_style": resolution.get("challenger_style"),
                            "opponent_style": resolution.get("opponent_style"),
                            "challenger_best": resolution.get("challenger_best"),
                            "opponent_best": resolution.get("opponent_best"),
                            "push_amount": resolution.get("push_amount"),
                            "your_push_amount": your_push_amount,
                            "you_won": you_won,
                            "bar_before": resolution.get("bar_before"),
                            "bar_after": resolution.get("bar_after"),
                            "parried": resolution.get("parried"),
                            "feint_winner": resolution.get("feint_winner"),
                            "game_over": resolution.get("game_over"),
                            "challenger_won": resolution.get("challenger_won"),
                            "opponent_won": resolution.get("opponent_won"),
                        }
                    )
        
        # Build message
        outcome = result.get("outcome", "miss")
        swings_remaining = result.get("swings_remaining", 0)
        
        if result.get("round_resolved"):
            resolution = result.get("resolution", {})
            if resolution.get("game_over"):
                message = "Match complete!"
            elif resolution.get("parried"):
                message = "Parried! No push."
            else:
                push = resolution.get("push_amount", 0)
                message = f"Round resolved! Push: {push:.1f}%"
        elif result.get("auto_submitted"):
            message = f"Final swing: {outcome.upper()}! Best: {result.get('best_outcome', 'miss').upper()}"
        else:
            message = f"{outcome.upper()}! {swings_remaining} swing{'s' if swings_remaining != 1 else ''} left"
        
        return SwingResponse(
            success=True,
            message=message,
            roll=result.get("roll"),
            outcome=result.get("outcome"),
            swing_number=result.get("swing_number"),
            swings_remaining=result.get("swings_remaining"),
            max_swings=result.get("max_swings"),
            best_outcome=result.get("best_outcome"),
            can_swing=result.get("can_swing"),
            can_stop=result.get("can_stop"),
            auto_submitted=result.get("auto_submitted"),
            round_resolved=result.get("round_resolved"),
            resolution=result.get("resolution"),
            match=db_match.to_dict_for_player(user.id) if db_match else None,
            miss_chance=result.get("miss_chance"),
            hit_chance_pct=result.get("hit_chance_pct"),
            crit_chance=result.get("crit_chance"),
        )
    except ValueError as e:
        return SwingResponse(success=False, message=str(e))


@router.post("/{match_id}/stop", response_model=StopResponse)
def stop_swinging(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Stop swinging and lock in current best roll.
    
    Player chooses to stop early after at least 1 swing.
    """
    try:
        result = manager.stop(db, match_id, user.id)
        db_match = manager.get_match(db, match_id)
        
        if db_match:
            my_name = db_match.challenger_name if db_match.challenger_id == user.id else db_match.opponent_name
            opponent_id = db_match.opponent_id if db_match.challenger_id == user.id else db_match.challenger_id
            
            # Notify opponent
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_PLAYER_SUBMITTED,
                match=db_match.to_dict_for_player(opponent_id),
                target_user_ids=_get_apple_user_ids(db, [opponent_id]),
                data={
                    "submitter_id": user.id,
                    "submitter_name": my_name,
                    "best_outcome": result.get("best_outcome"),
                }
            )
            
            # If round resolved, broadcast to both
            if result.get("round_resolved"):
                resolution = result.get("resolution", {})
                winner_side = resolution.get("winner_side")
                raw_push = resolution.get("push_amount", 0)
                parried = resolution.get("parried", False)
                
                print(f"DUEL_DEBUG STOP ROUTER: winner_side={winner_side!r}, raw_push={raw_push}, parried={parried}")
                print(f"DUEL_DEBUG STOP ROUTER: ch_best={resolution.get('challenger_best')!r}, op_best={resolution.get('opponent_best')!r}")
                
                for pid in [db_match.challenger_id, db_match.opponent_id]:
                    # Calculate YOUR push amount with correct sign for this player's perspective
                    # Positive = you won/pushed forward, Negative = you lost/got pushed back
                    is_challenger = (pid == db_match.challenger_id)
                    if parried:
                        your_push_amount = 0.0
                        you_won = False
                    elif winner_side == "challenger":
                        your_push_amount = raw_push if is_challenger else -raw_push
                        you_won = is_challenger
                    elif winner_side == "opponent":
                        your_push_amount = -raw_push if is_challenger else raw_push
                        you_won = not is_challenger
                    else:
                        your_push_amount = 0.0
                        you_won = False
                    
                    print(f"DUEL_DEBUG STOP ROUTER: pid={pid}, is_challenger={is_challenger}, your_push={your_push_amount}, you_won={you_won}")
                    
                    event_type = DuelEvents.DUEL_ENDED if resolution.get("game_over") else DuelEvents.DUEL_ROUND_RESOLVED
                    broadcast_duel_event(
                        event_type=event_type,
                        match=db_match.to_dict_for_player(pid),
                        target_user_ids=_get_apple_user_ids(db, [pid]),
                        data={
                            "result": resolution,  # iOS reads "result"
                            "resolution": resolution,
                            "round_number": resolution.get("round_number"),
                            "winner_side": resolution.get("winner_side"),
                            "challenger_rolls": resolution.get("challenger_rolls"),
                            "opponent_rolls": resolution.get("opponent_rolls"),
                            "challenger_style": resolution.get("challenger_style"),
                            "opponent_style": resolution.get("opponent_style"),
                            "challenger_best": resolution.get("challenger_best"),
                            "opponent_best": resolution.get("opponent_best"),
                            "push_amount": resolution.get("push_amount"),
                            "your_push_amount": your_push_amount,
                            "you_won": you_won,
                            "bar_before": resolution.get("bar_before"),
                            "bar_after": resolution.get("bar_after"),
                            "parried": resolution.get("parried"),
                            "feint_winner": resolution.get("feint_winner"),
                            "game_over": resolution.get("game_over"),
                            "challenger_won": resolution.get("challenger_won"),
                            "opponent_won": resolution.get("opponent_won"),
                        }
                    )
        
        # Build message
        if result.get("round_resolved"):
            resolution = result.get("resolution", {})
            if resolution.get("game_over"):
                message = "Match complete!"
            elif resolution.get("parried"):
                message = "Parried! No push."
            else:
                push = resolution.get("push_amount", 0)
                message = f"Round resolved! Push: {push:.1f}%"
        else:
            best = result.get('best_outcome') or 'miss'
            message = f"Submitted! Best: {best.upper()}. Waiting for opponent..."
        
        return StopResponse(
            success=True,
            message=message,
            submitted=result.get("submitted"),
            best_outcome=result.get("best_outcome"),
            waiting_for_opponent=result.get("waiting_for_opponent"),
            round_resolved=result.get("round_resolved"),
            resolution=result.get("resolution"),
            match=db_match.to_dict_for_player(user.id) if db_match else None,
        )
    except ValueError as e:
        return StopResponse(success=False, message=str(e))


# ============================================================
# LEGACY ENDPOINTS (for backwards compat)
# ============================================================

@router.post("/{match_id}/attack")
def execute_attack(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Legacy: Maps to /swing."""
    return execute_swing(match_id, user, db, manager)


@router.post("/{match_id}/round-swing")
def submit_round_swing(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Legacy: Auto-swings all and stops."""
    try:
        result = manager.submit_round_swing(db, match_id, user.id)
        db_match = manager.get_match(db, match_id)
        return {
            "success": True,
            "status": "resolved" if result.get("round_resolved") else "waiting_for_opponent",
            "message": "Submitted",
            "match": db_match.to_dict_for_player(user.id) if db_match else None,
            **result
        }
    except ValueError as e:
        return {"success": False, "message": str(e)}


# ============================================================
# FORFEIT / CANCEL / TIMEOUT
# ============================================================

@router.post("/{match_id}/forfeit", response_model=DuelResponse)
def forfeit_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Forfeit the match."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        match = manager.forfeit_match(db, match_id, user.id)
        
        # Broadcast to both players
        for pid in [match.challenger_id, match.opponent_id]:
            apple_ids = _get_apple_user_ids(db, [pid])
            logger.info(f"[Forfeit] Broadcasting DUEL_ENDED to player {pid}, apple_ids: {apple_ids}")
            
            sent = broadcast_duel_event(
                event_type=DuelEvents.DUEL_ENDED,
                match=match.to_dict_for_player(pid),
                target_user_ids=apple_ids,
                data={"forfeit_by": user.id, "reason": "forfeit"}
            )
            logger.info(f"[Forfeit] Broadcast result for player {pid}: {sent} connections notified")
        
        return DuelResponse(success=True, message="You forfeited.", match=match.to_dict_for_player(user.id))
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/claim-timeout", response_model=DuelResponse)
def claim_timeout(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Claim victory due to opponent timeout."""
    try:
        match = manager.claim_swing_timeout(db, match_id, user.id)
        
        for pid in [match.challenger_id, match.opponent_id]:
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_TIMEOUT,
                match=match.to_dict_for_player(pid),
                target_user_ids=_get_apple_user_ids(db, [pid]),
                data={"reason": "timeout"}
            )
        
        return DuelResponse(success=True, message="Victory! Opponent timed out.", match=match.to_dict_for_player(user.id))
    except ValueError as e:
        match = manager.get_match(db, match_id)
        return DuelResponse(success=False, message=str(e), match=match.to_dict_for_player(user.id) if match else None)


@router.post("/{match_id}/cancel", response_model=DuelResponse)
def cancel_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Cancel a waiting match."""
    try:
        match = manager.cancel_match(db, match_id, user.id)
        return DuelResponse(success=True, message="Match cancelled", match=match.to_dict_for_player(user.id))
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


# ============================================================
# MATCH INFO
# ============================================================

@router.get("/{match_id}", response_model=DuelResponse)
def get_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get match status."""
    match = manager.get_match(db, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    return DuelResponse(
        success=True,
        message="Match found",
        match=match.to_dict_for_player(user.id, include_actions=True)
    )
