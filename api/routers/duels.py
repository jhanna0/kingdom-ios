"""
DUEL API ROUTER
===============
Endpoints for PvP Arena duels in the Town Hall.

Simplified flow (like trades):
1. Challenger picks a friend and creates duel -> friend gets notification
2. Friend accepts/declines
3. Both players start fighting

Endpoints:
- POST /duels/create - Challenge a friend to a duel
- GET /duels/invitations - Get pending duel challenges
- GET /duels/pending-count - Get count of pending challenges (for badge)
- POST /duels/invitations/{invitation_id}/accept - Accept a challenge
- POST /duels/invitations/{invitation_id}/decline - Decline a challenge
- POST /duels/{match_id}/start - Start the match
- POST /duels/{match_id}/attack - Execute an attack
- POST /duels/{match_id}/forfeit - Forfeit the match
- POST /duels/{match_id}/cancel - Cancel (only if pending)
- GET /duels/{match_id} - Get match status
- GET /duels/active - Get player's active match
- GET /duels/stats - Get player's duel stats
- GET /duels/leaderboard - Get top duelists
- GET /duels/kingdom/{kingdom_id}/recent - Get recent matches
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List

from db import get_db
from db.models import User, PlayerState, Friend, DuelMatch, DuelInvitation, DuelStatus
from routers.auth import get_current_user
from systems.duel import DuelManager
from websocket.broadcast import broadcast_duel_event, DuelEvents
from sqlalchemy import or_, and_

router = APIRouter(prefix="/duels", tags=["duels"])

# Global duel manager
_duel_manager = DuelManager()


def get_duel_manager() -> DuelManager:
    return _duel_manager


def _get_apple_user_ids(db: Session, user_ids: List[int]) -> List[str]:
    """Convert database user IDs to Apple user IDs for WebSocket broadcast."""
    if not user_ids:
        return []
    # Filter out None values
    valid_ids = [uid for uid in user_ids if uid is not None]
    if not valid_ids:
        return []
    users = db.query(User).filter(User.id.in_(valid_ids)).all()
    return [u.apple_user_id for u in users if u.apple_user_id]


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class CreateDuelRequest(BaseModel):
    """Challenge a friend to a duel"""
    kingdom_id: str
    opponent_id: int  # Required: friend to challenge
    wager_gold: int = 0


class DuelResponse(BaseModel):
    success: bool
    message: str
    match: Optional[dict] = None


class AttackResponse(BaseModel):
    success: bool
    message: str
    # Single swing data
    roll: Optional[dict] = None
    swing_number: Optional[int] = None
    swings_remaining: Optional[int] = None
    max_swings: Optional[int] = None
    current_best_outcome: Optional[str] = None
    current_best_push: Optional[float] = None
    all_rolls: Optional[List[dict]] = None
    is_last_swing: Optional[bool] = None
    turn_complete: Optional[bool] = None
    # Final action (only on last swing)
    action: Optional[dict] = None
    match: Optional[dict] = None
    winner: Optional[dict] = None
    next_turn: Optional[dict] = None
    game_over: Optional[bool] = None
    # Odds
    miss_chance: Optional[int] = None
    hit_chance_pct: Optional[int] = None
    crit_chance: Optional[int] = None


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
# STATIC ROUTES (before dynamic routes)
# ============================================================

@router.get("/invitations", response_model=InvitationsResponse)
def get_invitations(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get pending duel invitations for the current user"""
    invitations = manager.get_pending_invitations(db, user.id)
    return InvitationsResponse(success=True, invitations=invitations)


@router.get("/active", response_model=DuelResponse)
def get_active_match(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get the player's current active match (if any) - returns player-perspective view"""
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
    """Get the current user's duel statistics"""
    stats = manager.get_player_stats(db, user.id)
    if stats:
        return StatsResponse(success=True, stats=stats.to_dict())
    return StatsResponse(success=True, stats={
        "user_id": user.id,
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "total_matches": 0,
        "win_rate": 0.0,
        "win_streak": 0,
        "best_win_streak": 0,
    })


@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    limit: int = 10,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get the duel leaderboard (top players by wins)"""
    leaderboard = manager.get_leaderboard(db, limit=min(limit, 50))
    return LeaderboardResponse(success=True, leaderboard=leaderboard)


@router.get("/kingdom/{kingdom_id}/recent")
def get_recent_matches(
    kingdom_id: str,
    limit: int = 10,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get recent completed duels in a kingdom"""
    matches = manager.get_recent_matches(db, kingdom_id, limit=min(limit, 25))
    return {"success": True, "matches": matches}


@router.get("/pending-count")
def get_pending_duel_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get count of pending duel invitations (for badge display)"""
    count = db.query(DuelInvitation).filter(
        DuelInvitation.invitee_id == user.id,
        DuelInvitation.status == "pending"
    ).count()
    
    return {"count": count}


# ============================================================
# MATCH CREATION AND INVITATIONS
# ============================================================

def are_friends(db: Session, user_id_1: int, user_id_2: int) -> bool:
    """Check if two users are friends (accepted friendship)"""
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
    """
    Challenge a friend to a duel.
    
    Like trades: picks a friend directly and sends them a challenge.
    The friend will see the invitation and can accept/decline.
    """
    # Can't challenge yourself
    if request.opponent_id == user.id:
        return DuelResponse(success=False, message="You cannot challenge yourself")
    
    # Check if player already has an active match
    existing = manager.get_active_match_for_player(db, user.id)
    if existing:
        return DuelResponse(
            success=False,
            message="You already have an active duel",
            match=existing.to_dict()
        )
    
    # Check opponent exists
    opponent = db.query(User).filter(User.id == request.opponent_id).first()
    if not opponent:
        return DuelResponse(success=False, message="Opponent not found")
    
    # Check they're friends
    if not are_friends(db, user.id, request.opponent_id):
        return DuelResponse(success=False, message="You can only challenge friends to duels")
    
    # Check opponent doesn't have an active match
    opponent_match = manager.get_active_match_for_player(db, request.opponent_id)
    if opponent_match:
        return DuelResponse(
            success=False,
            message=f"{opponent.display_name} is already in a duel"
        )
    
    try:
        # Create match with opponent already set (pending their acceptance)
        match, invitation = manager.create_challenge(
            db=db,
            challenger_id=user.id,
            opponent_id=request.opponent_id,
            kingdom_id=request.kingdom_id,
            wager_gold=request.wager_gold
        )
        
        # Notify the opponent via WebSocket (use generic dict for notification)
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_INVITATION,
            match=match.to_dict() if match else None,
            target_user_ids=_get_apple_user_ids(db, [request.opponent_id]),
            data={
                "inviter_name": user.display_name,
                "invitation_id": invitation.id,
                "wager_gold": request.wager_gold,
            }
        )
        
        # Return player-perspective view for the challenger
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
    """Accept a duel invitation - returns player-perspective view"""
    try:
        match = manager.join_by_invitation(db, invitation_id, user.id)
        
        # Notify the challenger with their perspective
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_OPPONENT_JOINED,
            match=match.to_dict_for_player(match.challenger_id),
            target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
            data={"opponent_name": user.display_name}
        )
        
        # Return accepter's perspective
        return DuelResponse(
            success=True,
            message="Joined the duel!",
            match=match.to_dict_for_player(user.id)
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/invitations/{invitation_id}/decline")
def decline_invitation(
    invitation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Decline a duel challenge - cancels the associated match"""
    try:
        match = manager.decline_invitation(db, invitation_id, user.id)
        
        # Notify the challenger that their challenge was declined
        if match:
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_CANCELLED,
                match=match.to_dict() if match else None,
                target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
                data={"message": f"{user.display_name} declined your duel challenge."}
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
    """
    Start the duel (once opponent has joined).
    
    BACKEND DETERMINES WHO GOES FIRST:
    - Checks pairing history between these two players
    - If they've dueled before, the OTHER player goes first this time
    - This ensures fairness across rematches
    
    Returns player-perspective view for each client.
    """
    try:
        match = manager.start_match(db, match_id, user.id)
        
        from systems.duel.config import DUEL_TURN_TIMEOUT_SECONDS
        
        # Notify challenger with THEIR perspective
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_STARTED,
            match=match.to_dict_for_player(match.challenger_id),
            target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
            data={"message": "The duel begins!"}
        )
        
        # Notify opponent with THEIR perspective
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_STARTED,
            match=match.to_dict_for_player(match.opponent_id),
            target_user_ids=_get_apple_user_ids(db, [match.opponent_id]),
            data={"message": "The duel begins!"}
        )
        
        # Return starter's perspective
        return DuelResponse(
            success=True,
            message="The duel begins!",
            match=match.to_dict_for_player(user.id)
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/attack", response_model=AttackResponse)
def execute_attack(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Execute a SINGLE SWING during your turn.
    
    Multi-swing system:
    - Each call = one swing (not all swings at once)
    - Player gets (1 + attack) swings per turn
    - Best outcome across all swings is used
    - Turn only switches after all swings are used
    
    REAL-TIME: Each swing is broadcast immediately so opponent sees it live.
    """
    try:
        result = manager.execute_attack(db, match_id, user.id)
        
        # Get the actual match object for player-perspective serialization
        db_match = manager.get_match(db, match_id)
        
        roll = result.get("roll", {})
        is_last_swing = result.get("is_last_swing", False)
        
        # Odds for the response
        odds = {
            "miss": result.get("miss_chance", 50),
            "hit": result.get("hit_chance_pct", 40),
            "crit": result.get("crit_chance", 10),
        }
        
        if db_match:
            # Get attacker name for the roll display
            attacker_name = db_match.challenger_name if db_match.challenger_id == user.id else db_match.opponent_name
            
            # Get opponent ID (the one NOT attacking)
            opponent_id = db_match.opponent_id if db_match.challenger_id == user.id else db_match.challenger_id
            
            # === REAL-TIME: Broadcast EVERY swing to opponent immediately ===
            swing_data = {
                "attacker_id": user.id,
                "attacker_name": attacker_name,
                "roll": roll,
                "swing_number": result.get("swing_number"),
                "swings_remaining": result.get("swings_remaining"),
                "max_swings": result.get("max_swings"),
                "is_last_swing": is_last_swing,
            }
            
            # Broadcast swing to opponent so they see it in real-time
            broadcast_duel_event(
                event_type=DuelEvents.DUEL_SWING,
                match=db_match.to_dict_for_player(opponent_id, odds=odds),
                target_user_ids=_get_apple_user_ids(db, [opponent_id]),
                data=swing_data
            )
            
            # === On LAST swing, also send turn complete with final results ===
            if is_last_swing:
                event_type = DuelEvents.DUEL_TURN_COMPLETE if not result.get("winner") else DuelEvents.DUEL_ENDED
                
                # Common event data
                event_data = {
                    "attacker_id": user.id,
                    "attacker_name": attacker_name,
                    "all_rolls": result.get("all_rolls"),
                    "action": result.get("action"),
                    "game_over": result.get("game_over", False),
                }
                
                # Broadcast to challenger with their perspective
                broadcast_duel_event(
                    event_type=event_type,
                    match=db_match.to_dict_for_player(db_match.challenger_id, odds=odds),
                    target_user_ids=_get_apple_user_ids(db, [db_match.challenger_id]),
                    data=event_data
                )
                
                # Broadcast to opponent with their perspective
                broadcast_duel_event(
                    event_type=event_type,
                    match=db_match.to_dict_for_player(db_match.opponent_id, odds=odds),
                    target_user_ids=_get_apple_user_ids(db, [db_match.opponent_id]),
                    data=event_data
                )
        
        # Build response message
        outcome = roll.get("outcome", "miss")
        swings_remaining = result.get("swings_remaining", 0)
        
        if result.get("winner"):
            message = "VICTORY! You win the duel!" if result["winner"]["player_id"] == user.id else "Defeat..."
        elif is_last_swing:
            best = result.get("current_best_outcome", "miss")
            push = result.get("action", {}).get("push_amount", 0)
            if best == "critical":
                message = f"CRITICAL HIT! Pushed {push:.1f}%"
            elif best == "hit":
                message = f"Hit! Pushed {push:.1f}%"
            else:
                message = "All misses! No push."
        else:
            if outcome == "critical":
                message = f"CRIT! {swings_remaining} swing{'s' if swings_remaining != 1 else ''} left"
            elif outcome == "hit":
                message = f"Hit! {swings_remaining} swing{'s' if swings_remaining != 1 else ''} left"
            else:
                message = f"Miss! {swings_remaining} swing{'s' if swings_remaining != 1 else ''} left"
        
        # Return attacker's perspective
        match_dict = db_match.to_dict_for_player(user.id, odds=odds) if db_match else result.get("match", {})
        
        return AttackResponse(
            success=True,
            message=message,
            roll=roll,
            swing_number=result.get("swing_number"),
            swings_remaining=result.get("swings_remaining"),
            max_swings=result.get("max_swings"),
            current_best_outcome=result.get("current_best_outcome"),
            current_best_push=result.get("current_best_push"),
            all_rolls=result.get("all_rolls"),
            is_last_swing=is_last_swing,
            turn_complete=result.get("turn_complete"),
            action=result.get("action"),
            match=match_dict,
            winner=result.get("winner"),
            next_turn=result.get("next_turn"),
            game_over=result.get("game_over"),
            miss_chance=result.get("miss_chance"),
            hit_chance_pct=result.get("hit_chance_pct"),
            crit_chance=result.get("crit_chance"),
        )
    except ValueError as e:
        return AttackResponse(success=False, message=str(e))


@router.post("/{match_id}/forfeit", response_model=DuelResponse)
def forfeit_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Forfeit the match (opponent wins) - returns player-perspective view"""
    try:
        match = manager.forfeit_match(db, match_id, user.id)
        
        # Notify each player with their perspective
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_ENDED,
            match=match.to_dict_for_player(match.challenger_id),
            target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
            data={"forfeit_by": user.id}
        )
        
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_ENDED,
            match=match.to_dict_for_player(match.opponent_id),
            target_user_ids=_get_apple_user_ids(db, [match.opponent_id]),
            data={"forfeit_by": user.id}
        )
        
        return DuelResponse(
            success=True,
            message="You forfeited the match.",
            match=match.to_dict_for_player(user.id)
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/claim-timeout", response_model=DuelResponse)
def claim_timeout(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Claim victory due to opponent timeout.
    
    If it's the opponent's turn and their turn has expired (30s),
    the calling player wins by timeout.
    
    BACKEND ENFORCES:
    - Must be opponent's turn (not yours)
    - Turn must actually be expired
    - Match must be in FIGHTING status
    
    Returns player-perspective view.
    """
    try:
        # Get current turn player before resolving (for broadcast)
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        timed_out_player_id = match.get_current_turn_player_id() if match else None
        
        # Use manager to validate and resolve timeout
        match = manager.forfeit_by_timeout(db, match_id, user.id)
        
        # Notify each player with their perspective
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_TIMEOUT,
            match=match.to_dict_for_player(match.challenger_id),
            target_user_ids=_get_apple_user_ids(db, [match.challenger_id]),
            data={"timed_out_player_id": timed_out_player_id, "reason": "timeout"}
        )
        
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_TIMEOUT,
            match=match.to_dict_for_player(match.opponent_id),
            target_user_ids=_get_apple_user_ids(db, [match.opponent_id]),
            data={"timed_out_player_id": timed_out_player_id, "reason": "timeout"}
        )
        
        return DuelResponse(
            success=True,
            message="Victory! Opponent timed out.",
            match=match.to_dict_for_player(user.id)
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/cancel", response_model=DuelResponse)
def cancel_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Cancel a waiting match (only challenger can do this) - returns player-perspective view"""
    try:
        match = manager.cancel_match(db, match_id, user.id)
        return DuelResponse(
            success=True,
            message="Match cancelled",
            match=match.to_dict_for_player(user.id)
        )
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
    """Get match status by ID - returns player-perspective view"""
    match = manager.get_match(db, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    return DuelResponse(
        success=True,
        message="Match found",
        match=match.to_dict_for_player(user.id, include_actions=True)
    )
