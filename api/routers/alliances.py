"""
Alliance system - Formal pacts between empires
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from datetime import datetime, timedelta
from typing import List, Optional

from db import get_db, User, PlayerState, Kingdom, Alliance
from schemas.alliance import (
    AllianceProposeRequest,
    AllianceProposeResponse,
    AllianceAcceptResponse,
    AllianceDeclineResponse,
    AllianceResponse,
    AllianceListResponse,
    PendingAlliancesResponse,
)
from routers.auth import get_current_user

router = APIRouter(prefix="/alliances", tags=["Alliances"])

# Constants
PROPOSAL_EXPIRY_DAYS = 7
ALLIANCE_DURATION_DAYS = 30


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


def _get_player_empire_id(db: Session, user: User, state: PlayerState) -> Optional[str]:
    """Get the empire ID that a player rules (if any)"""
    # Check if player rules any kingdom
    ruled_kingdom = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).first()
    if ruled_kingdom:
        return ruled_kingdom.empire_id or ruled_kingdom.id
    return None


def _get_empire_name(db: Session, empire_id: str) -> str:
    """Get a display name for an empire"""
    kingdom = db.query(Kingdom).filter(
        or_(Kingdom.empire_id == empire_id, Kingdom.id == empire_id)
    ).first()
    if kingdom:
        return kingdom.name
    return empire_id


def _count_active_alliances(db: Session, empire_id: str) -> int:
    """Count active alliances for an empire"""
    return db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            Alliance.initiator_empire_id == empire_id,
            Alliance.target_empire_id == empire_id
        )
    ).count()


def _expire_old_alliances(db: Session):
    """
    Expire alliances past their expiry date and create kingdom events.
    
    Uses SELECT FOR UPDATE SKIP LOCKED to safely handle concurrent serverless requests.
    Each expired alliance is processed exactly once across all Lambda invocations.
    """
    from db.models.kingdom_event import KingdomEvent
    
    # Find expired active alliances that haven't been notified yet
    # SKIP LOCKED ensures concurrent requests don't process the same row
    expired_alliances = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at <= datetime.utcnow(),
        Alliance.expiry_notified == False
    ).with_for_update(skip_locked=True).all()
    
    for alliance in expired_alliances:
        # Mark as notified FIRST (before status change) to prevent double notifications
        # Even if this request crashes after, another request won't re-notify
        alliance.expiry_notified = True
        alliance.status = 'expired'
        db.flush()  # Write to DB immediately while we hold the lock
        
        # Get empire names for the notification
        initiator_name = _get_empire_name(db, alliance.initiator_empire_id)
        target_name = _get_empire_name(db, alliance.target_empire_id)
        
        # Create kingdom events for both empires
        _create_alliance_expired_events(db, alliance.initiator_empire_id, target_name)
        _create_alliance_expired_events(db, alliance.target_empire_id, initiator_name)
    
    # Expire pending proposals (no notification needed for these)
    db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at <= datetime.utcnow()
    ).update({"status": "expired"})
    
    db.commit()


def _create_alliance_expired_events(db: Session, empire_id: str, ally_name: str):
    """Create alliance expiry events for all kingdoms in an empire"""
    from db.models.kingdom_event import KingdomEvent
    
    # Get all kingdoms in this empire
    kingdoms = db.query(Kingdom).filter(
        or_(Kingdom.empire_id == empire_id, Kingdom.id == empire_id)
    ).all()
    
    for kingdom in kingdoms:
        event = KingdomEvent(
            kingdom_id=kingdom.id,
            title="Alliance Expired",
            description=f"Your alliance with {ally_name} has expired after 30 days."
        )
        db.add(event)


def are_empires_allied(db: Session, empire_a_id: str, empire_b_id: str) -> bool:
    """
    Check if two empires have an active alliance.
    This is the main helper used by other systems.
    """
    if not empire_a_id or not empire_b_id:
        return False
    
    if empire_a_id == empire_b_id:
        return True  # Same empire = always "allied"
    
    alliance = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            and_(Alliance.initiator_empire_id == empire_a_id, Alliance.target_empire_id == empire_b_id),
            and_(Alliance.initiator_empire_id == empire_b_id, Alliance.target_empire_id == empire_a_id)
        )
    ).first()
    
    return alliance is not None


def get_alliance_between(db: Session, empire_a_id: str, empire_b_id: str) -> Optional[Alliance]:
    """Get active alliance between two empires if it exists"""
    return db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            and_(Alliance.initiator_empire_id == empire_a_id, Alliance.target_empire_id == empire_b_id),
            and_(Alliance.initiator_empire_id == empire_b_id, Alliance.target_empire_id == empire_a_id)
        )
    ).first()


def get_allied_empire_ids(db: Session, empire_id: str) -> List[str]:
    """
    Get all empire IDs that are actively allied with the given empire.
    Used for broadcasting alliance-wide news.
    """
    if not empire_id:
        return []
    
    alliances = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            Alliance.initiator_empire_id == empire_id,
            Alliance.target_empire_id == empire_id
        )
    ).all()
    
    allied_ids = []
    for alliance in alliances:
        if alliance.initiator_empire_id == empire_id:
            allied_ids.append(alliance.target_empire_id)
        else:
            allied_ids.append(alliance.initiator_empire_id)
    
    return allied_ids


def get_allied_kingdom_ids(db: Session, empire_id: str) -> List[str]:
    """
    Get all kingdom IDs in allied empires.
    Used for broadcasting alliance-wide news to all kingdoms in the alliance network.
    
    Returns kingdom IDs (not empire IDs) for broadcasting to alliance network.
    """
    if not empire_id:
        return []
    
    allied_empire_ids = get_allied_empire_ids(db, empire_id)
    if not allied_empire_ids:
        return []
    
    # Get all kingdoms belonging to allied empires
    allied_kingdoms = db.query(Kingdom).filter(
        or_(
            Kingdom.empire_id.in_(allied_empire_ids),
            Kingdom.id.in_(allied_empire_ids)  # For single-city empires
        )
    ).all()
    
    return [k.id for k in allied_kingdoms]


def get_active_alliances_for_empire(db: Session, empire_id: str) -> List[dict]:
    """
    Get all active alliances for an empire with details about allied kingdoms.
    Used for displaying alliances in the hometown KingdomInfoSheet.
    
    Returns list of dicts with:
    - id: alliance ID
    - allied_kingdom_id: the other kingdom's ID
    - allied_kingdom_name: the other kingdom's name
    - allied_ruler_name: the other kingdom's ruler name
    - days_remaining: days until expiry
    - expires_at: ISO timestamp
    """
    if not empire_id:
        return []
    
    alliances = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            Alliance.initiator_empire_id == empire_id,
            Alliance.target_empire_id == empire_id
        )
    ).order_by(Alliance.expires_at.asc()).all()
    
    result = []
    for alliance in alliances:
        # Determine which side is the "other" empire
        if alliance.initiator_empire_id == empire_id:
            other_empire_id = alliance.target_empire_id
            other_ruler_name = alliance.target_ruler_name
        else:
            other_empire_id = alliance.initiator_empire_id
            other_ruler_name = alliance.initiator_ruler_name
        
        # Get the other kingdom's name
        other_kingdom = db.query(Kingdom).filter(
            or_(Kingdom.empire_id == other_empire_id, Kingdom.id == other_empire_id)
        ).first()
        other_kingdom_name = other_kingdom.name if other_kingdom else other_empire_id
        other_kingdom_id = other_kingdom.id if other_kingdom else other_empire_id
        
        result.append({
            "id": alliance.id,
            "allied_kingdom_id": other_kingdom_id,
            "allied_kingdom_name": other_kingdom_name,
            "allied_ruler_name": other_ruler_name,
            "days_remaining": alliance.days_remaining,
            "expires_at": alliance.expires_at.isoformat() if alliance.expires_at else None
        })
    
    return result


def _alliance_to_response(alliance: Alliance) -> AllianceResponse:
    """Convert Alliance model to response schema"""
    return AllianceResponse(
        id=alliance.id,
        initiator_empire_id=alliance.initiator_empire_id,
        target_empire_id=alliance.target_empire_id,
        initiator_ruler_id=alliance.initiator_ruler_id,
        target_ruler_id=alliance.target_ruler_id,
        initiator_ruler_name=alliance.initiator_ruler_name,
        target_ruler_name=alliance.target_ruler_name,
        status=alliance.status,
        created_at=alliance.created_at,
        proposal_expires_at=alliance.proposal_expires_at,
        accepted_at=alliance.accepted_at,
        expires_at=alliance.expires_at,
        days_remaining=alliance.days_remaining,
        hours_to_respond=alliance.hours_to_respond,
        is_active=alliance.is_active
    )


# ===== API Endpoints =====

@router.post("/propose", response_model=AllianceProposeResponse)
def propose_alliance(
    request: AllianceProposeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Propose an alliance to another empire.
    
    Requirements:
    - Must be a ruler of at least one city
    - Cannot propose to your own empire
    - Cannot have existing pending/active alliance with target
    """
    state = _get_player_state(db, current_user)
    
    # Expire old alliances first
    _expire_old_alliances(db)
    
    # Check if player is a ruler
    my_empire_id = _get_player_empire_id(db, current_user, state)
    if not my_empire_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must rule a city to propose alliances"
        )
    
    # Check not proposing to self
    if request.target_empire_id == my_empire_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot propose alliance with your own empire"
        )
    
    # Check target empire exists
    target_kingdom = db.query(Kingdom).filter(
        or_(Kingdom.empire_id == request.target_empire_id, Kingdom.id == request.target_empire_id)
    ).first()
    if not target_kingdom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target empire not found"
        )
    
    # Check target has a ruler
    if not target_kingdom.ruler_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Target empire has no ruler to accept alliance"
        )
    
    # Check no existing alliance or pending proposal
    existing = db.query(Alliance).filter(
        Alliance.status.in_(['pending', 'active']),
        or_(
            and_(Alliance.initiator_empire_id == my_empire_id, Alliance.target_empire_id == request.target_empire_id),
            and_(Alliance.initiator_empire_id == request.target_empire_id, Alliance.target_empire_id == my_empire_id)
        )
    ).first()
    
    if existing:
        if existing.status == 'active':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already have an active alliance with this empire"
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Alliance proposal already pending with this empire"
            )
    
    # Create alliance proposal
    proposal_expires = datetime.utcnow() + timedelta(days=PROPOSAL_EXPIRY_DAYS)
    
    alliance = Alliance(
        initiator_empire_id=my_empire_id,
        target_empire_id=request.target_empire_id,
        initiator_ruler_id=current_user.id,
        initiator_ruler_name=current_user.display_name,
        status='pending',
        created_at=datetime.utcnow(),
        proposal_expires_at=proposal_expires
    )
    
    db.add(alliance)
    db.commit()
    db.refresh(alliance)
    
    target_name = _get_empire_name(db, request.target_empire_id)
    
    return AllianceProposeResponse(
        success=True,
        message=f"Alliance proposed to {target_name}! They have {PROPOSAL_EXPIRY_DAYS} days to accept.",
        alliance_id=alliance.id,
        proposal_expires_at=proposal_expires
    )


@router.post("/{alliance_id}/accept", response_model=AllianceAcceptResponse)
def accept_alliance(
    alliance_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Accept a pending alliance proposal.
    
    Requirements:
    - Must be a ruler in the target empire
    - Proposal must still be pending
    """
    state = _get_player_state(db, current_user)
    
    # Expire old alliances first
    _expire_old_alliances(db)
    
    # Get the alliance
    alliance = db.query(Alliance).filter(Alliance.id == alliance_id).first()
    if not alliance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alliance not found"
        )
    
    # Check it's pending
    if not alliance.is_pending:
        if alliance.status == 'expired':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This proposal has expired"
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Alliance is {alliance.status}, not pending"
        )
    
    # Check player is a ruler in target empire
    my_empire_id = _get_player_empire_id(db, current_user, state)
    if my_empire_id != alliance.target_empire_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a ruler of the target empire can accept this alliance"
        )
    
    # Accept the alliance
    alliance.accept(current_user.id, current_user.display_name)
    db.commit()
    
    initiator_name = _get_empire_name(db, alliance.initiator_empire_id)
    
    return AllianceAcceptResponse(
        success=True,
        message=f"Alliance with {initiator_name} is now active!",
        alliance_id=alliance.id,
        expires_at=alliance.expires_at,
        benefits=[
            "🛡️ Cannot attack each other",
            "🔒 Cannot spy on each other",
            "🚫 Cannot sabotage each other",
            "🎫 No travel fees in allied cities",
            "⚔️ Can help defend against invasions"
        ]
    )


@router.post("/{alliance_id}/decline", response_model=AllianceDeclineResponse)
def decline_alliance(
    alliance_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Decline a pending alliance proposal.
    
    Requirements:
    - Must be a ruler in the target empire
    - Proposal must still be pending
    """
    state = _get_player_state(db, current_user)
    
    # Get the alliance
    alliance = db.query(Alliance).filter(Alliance.id == alliance_id).first()
    if not alliance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alliance not found"
        )
    
    # Check it's pending
    if alliance.status != 'pending':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Alliance is {alliance.status}, not pending"
        )
    
    # Check player is a ruler in target empire
    my_empire_id = _get_player_empire_id(db, current_user, state)
    if my_empire_id != alliance.target_empire_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a ruler of the target empire can decline this alliance"
        )
    
    # Decline the alliance
    alliance.decline()
    db.commit()
    
    initiator_name = _get_empire_name(db, alliance.initiator_empire_id)
    
    return AllianceDeclineResponse(
        success=True,
        message=f"Alliance proposal from {initiator_name} declined."
    )


@router.get("/active", response_model=AllianceListResponse)
def get_active_alliances(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all active alliances for your empire"""
    state = _get_player_state(db, current_user)
    
    # Expire old alliances first
    _expire_old_alliances(db)
    
    # Get player's empire
    my_empire_id = _get_player_empire_id(db, current_user, state)
    if not my_empire_id:
        # Not a ruler, check hometown
        if state.hometown_kingdom_id:
            home_kingdom = db.query(Kingdom).filter(Kingdom.id == state.hometown_kingdom_id).first()
            if home_kingdom:
                my_empire_id = home_kingdom.empire_id or home_kingdom.id
    
    if not my_empire_id:
        return AllianceListResponse(alliances=[], count=0)
    
    # Get active alliances
    alliances = db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at > datetime.utcnow(),
        or_(
            Alliance.initiator_empire_id == my_empire_id,
            Alliance.target_empire_id == my_empire_id
        )
    ).order_by(Alliance.expires_at.asc()).all()
    
    return AllianceListResponse(
        alliances=[_alliance_to_response(a) for a in alliances],
        count=len(alliances)
    )


@router.get("/pending", response_model=PendingAlliancesResponse)
def get_pending_alliances(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get pending alliance proposals (sent and received)"""
    state = _get_player_state(db, current_user)
    
    # Expire old alliances first
    _expire_old_alliances(db)
    
    # Get player's empire
    my_empire_id = _get_player_empire_id(db, current_user, state)
    if not my_empire_id:
        return PendingAlliancesResponse(
            sent=[], received=[], sent_count=0, received_count=0
        )
    
    # Get sent proposals
    sent = db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at > datetime.utcnow(),
        Alliance.initiator_empire_id == my_empire_id
    ).all()
    
    # Get received proposals
    received = db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at > datetime.utcnow(),
        Alliance.target_empire_id == my_empire_id
    ).all()
    
    return PendingAlliancesResponse(
        sent=[_alliance_to_response(a) for a in sent],
        received=[_alliance_to_response(a) for a in received],
        sent_count=len(sent),
        received_count=len(received)
    )


@router.get("/{alliance_id}", response_model=AllianceResponse)
def get_alliance(
    alliance_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get alliance details"""
    alliance = db.query(Alliance).filter(Alliance.id == alliance_id).first()
    if not alliance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alliance not found"
        )
    
    return _alliance_to_response(alliance)



