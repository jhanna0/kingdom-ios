"""
DUEL API ROUTER
===============
Endpoints for PvP Arena duels in the Town Hall.

Endpoints:
- POST /duels/create - Create a new duel match
- POST /duels/{match_id}/invite - Invite a friend
- GET /duels/invitations - Get pending invitations
- POST /duels/join/{code} - Join by match code
- POST /duels/invitations/{invitation_id}/accept - Accept invitation
- POST /duels/invitations/{invitation_id}/decline - Decline invitation
- POST /duels/{match_id}/start - Start the match
- POST /duels/{match_id}/attack - Execute an attack
- POST /duels/{match_id}/forfeit - Forfeit the match
- POST /duels/{match_id}/cancel - Cancel (only if waiting)
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
from db.models import User, PlayerState
from routers.auth import get_current_user
from systems.duel import DuelManager
from websocket.broadcast import broadcast_duel_event, DuelEvents

router = APIRouter(prefix="/duels", tags=["duels"])

# Global duel manager
_duel_manager = DuelManager()


def get_duel_manager() -> DuelManager:
    return _duel_manager


# ============================================================
# REQUEST/RESPONSE MODELS
# ============================================================

class CreateDuelRequest(BaseModel):
    kingdom_id: str
    wager_gold: int = 0


class InviteFriendRequest(BaseModel):
    friend_user_id: int


class JoinByCodeRequest(BaseModel):
    match_code: str


class DuelResponse(BaseModel):
    success: bool
    message: str
    match: Optional[dict] = None


class AttackResponse(BaseModel):
    success: bool
    message: str
    action: Optional[dict] = None
    match: Optional[dict] = None
    winner: Optional[dict] = None


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
    """Get the player's current active match (if any)"""
    match = manager.get_active_match_for_player(db, user.id)
    if match:
        return DuelResponse(
            success=True,
            message="Active match found",
            match=match.to_dict(include_actions=True)
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


# ============================================================
# MATCH CREATION AND INVITATIONS
# ============================================================

@router.post("/create", response_model=DuelResponse)
def create_duel(
    request: CreateDuelRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Create a new duel match in the Town Hall arena.
    
    Returns a match_code that can be shared with friends.
    """
    # Check if player already has an active match
    existing = manager.get_active_match_for_player(db, user.id)
    if existing:
        return DuelResponse(
            success=False,
            message="You already have an active duel",
            match=existing.to_dict()
        )
    
    try:
        match = manager.create_match(
            db=db,
            challenger_id=user.id,
            kingdom_id=request.kingdom_id,
            wager_gold=request.wager_gold
        )
        
        return DuelResponse(
            success=True,
            message=f"Duel created! Share code: {match.match_code}",
            match=match.to_dict()
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/invite", response_model=DuelResponse)
def invite_friend(
    match_id: int,
    request: InviteFriendRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Invite a friend to the duel"""
    try:
        invitation = manager.invite_friend(
            db=db,
            match_id=match_id,
            inviter_id=user.id,
            friend_user_id=request.friend_user_id
        )
        
        match = manager.get_match(db, match_id)
        
        # Notify the invited friend via WebSocket
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_INVITATION,
            match=match.to_dict() if match else None,
            target_user_ids=[request.friend_user_id],
            data={
                "inviter_name": user.display_name,
                "invitation_id": invitation.id,
            }
        )
        
        return DuelResponse(
            success=True,
            message="Invitation sent!",
            match=match.to_dict() if match else None
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/join/{code}", response_model=DuelResponse)
def join_by_code(
    code: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Join a duel match using the match code"""
    try:
        match = manager.join_by_code(db, code, user.id)
        
        # Notify the challenger
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_OPPONENT_JOINED,
            match=match.to_dict(),
            target_user_ids=[match.challenger_id],
            data={"opponent_name": user.display_name}
        )
        
        return DuelResponse(
            success=True,
            message="Joined the duel!",
            match=match.to_dict()
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
    """Accept a duel invitation"""
    try:
        match = manager.join_by_invitation(db, invitation_id, user.id)
        
        # Notify the challenger
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_OPPONENT_JOINED,
            match=match.to_dict(),
            target_user_ids=[match.challenger_id],
            data={"opponent_name": user.display_name}
        )
        
        return DuelResponse(
            success=True,
            message="Joined the duel!",
            match=match.to_dict()
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
    """Decline a duel invitation"""
    try:
        manager.decline_invitation(db, invitation_id, user.id)
        return {"success": True, "message": "Invitation declined"}
    except ValueError as e:
        return {"success": False, "message": str(e)}


# ============================================================
# MATCH FLOW
# ============================================================

@router.post("/{match_id}/confirm", response_model=DuelResponse)
def confirm_opponent(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Challenger confirms they want to fight the opponent.
    Call this after opponent joins and match is 'pending_acceptance'.
    """
    try:
        match = manager.confirm_opponent(db, match_id, user.id)

        # Notify opponent that they've been accepted
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_UPDATED,
            match=match.to_dict(),
            target_user_ids=[match.opponent_id],
            data={"message": "Your challenge was accepted! Ready to fight."}
        )

        return DuelResponse(
            success=True,
            message="Opponent confirmed. Ready to fight!",
            match=match.to_dict()
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/decline", response_model=DuelResponse)
def decline_opponent(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """
    Challenger declines the opponent.
    Match is cancelled, no gold is taken from either player.
    """
    try:
        match = manager.decline_opponent(db, match_id, user.id)

        # Notify opponent they were declined
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_CANCELLED,
            match=match.to_dict(),
            target_user_ids=[match.opponent_id],
            data={"message": "The challenger declined your request."}
        )

        return DuelResponse(
            success=True,
            message="Opponent declined. Match cancelled.",
            match=match.to_dict()
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


@router.post("/{match_id}/start", response_model=DuelResponse)
def start_match(
    match_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Start the duel (once opponent has joined)"""
    try:
        match = manager.start_match(db, match_id, user.id)
        
        # Notify both players
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_STARTED,
            match=match.to_dict(),
            target_user_ids=[match.challenger_id, match.opponent_id],
            data={"message": "The duel begins!"}
        )
        
        return DuelResponse(
            success=True,
            message="The duel begins!",
            match=match.to_dict()
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
    Execute an attack during your turn.
    
    This is the core combat action - rolls dice, calculates hit,
    pushes the bar, and potentially determines a winner.
    """
    try:
        result = manager.execute_attack(db, match_id, user.id)
        
        match = result.get("match", {})
        
        # Notify both players of the action
        other_player_id = match.get("opponent", {}).get("id") if match.get("challenger", {}).get("id") == user.id else match.get("challenger", {}).get("id")
        
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_ATTACK if not result.get("winner") else DuelEvents.DUEL_ENDED,
            match=match,
            target_user_ids=[user.id, other_player_id] if other_player_id else [user.id],
            data={
                "action": result.get("action"),
                "winner": result.get("winner"),
            }
        )
        
        action = result.get("action", {})
        outcome = action.get("outcome", "miss")
        
        if result.get("winner"):
            message = f"VICTORY! You win the duel!" if result["winner"]["player_id"] == user.id else "Defeat... Better luck next time."
        elif outcome == "critical":
            message = f"CRITICAL HIT! Bar pushed {action.get('push_amount', 0):.1f}"
        elif outcome == "hit":
            message = f"Hit! Bar pushed {action.get('push_amount', 0):.1f}"
        else:
            message = "Miss! No push."
        
        return AttackResponse(
            success=True,
            message=message,
            action=result.get("action"),
            match=match,
            winner=result.get("winner")
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
    """Forfeit the match (opponent wins)"""
    try:
        match = manager.forfeit_match(db, match_id, user.id)
        
        # Notify both players
        broadcast_duel_event(
            event_type=DuelEvents.DUEL_ENDED,
            match=match.to_dict(),
            target_user_ids=[match.challenger_id, match.opponent_id],
            data={
                "forfeit_by": user.id,
                "winner": {
                    "side": match.winner_side,
                    "player_id": match.winner_id,
                }
            }
        )
        
        return DuelResponse(
            success=True,
            message="You forfeited the match.",
            match=match.to_dict()
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
    """Cancel a waiting match (only challenger can do this)"""
    try:
        match = manager.cancel_match(db, match_id, user.id)
        return DuelResponse(
            success=True,
            message="Match cancelled",
            match=match.to_dict()
        )
    except ValueError as e:
        return DuelResponse(success=False, message=str(e))


# ============================================================
# MATCH INFO
# ============================================================

@router.get("/{match_id}", response_model=DuelResponse)
def get_match(
    match_id: int,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get match status by ID"""
    match = manager.get_match(db, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    return DuelResponse(
        success=True,
        message="Match found",
        match=match.to_dict(include_actions=True)
    )


@router.get("/code/{code}", response_model=DuelResponse)
def get_match_by_code(
    code: str,
    db: Session = Depends(get_db),
    manager: DuelManager = Depends(get_duel_manager),
):
    """Get match status by code"""
    match = manager.get_match_by_code(db, code)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    return DuelResponse(
        success=True,
        message="Match found",
        match=match.to_dict()
    )
