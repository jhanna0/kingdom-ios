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
ALLIANCE_PROPOSAL_COST = 500
MAX_ACTIVE_ALLIANCES = 3
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
    """Expire any alliances past their expiry date"""
    # Expire active alliances
    db.query(Alliance).filter(
        Alliance.status == 'active',
        Alliance.expires_at <= datetime.utcnow()
    ).update({"status": "expired"})
    
    # Expire pending proposals
    db.query(Alliance).filter(
        Alliance.status == 'pending',
        Alliance.proposal_expires_at <= datetime.utcnow()
    ).update({"status": "expired"})
    
    db.commit()


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
    - Max 3 active alliances per empire
    - Costs 500g
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
    
    # Check max alliances
    active_count = _count_active_alliances(db, my_empire_id)
    if active_count >= MAX_ACTIVE_ALLIANCES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {MAX_ACTIVE_ALLIANCES} active alliances allowed"
        )
    
    # Check gold
    if state.gold < ALLIANCE_PROPOSAL_COST:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Need {ALLIANCE_PROPOSAL_COST}g to propose alliance. Have {state.gold}g"
        )
    
    # Deduct gold
    state.gold -= ALLIANCE_PROPOSAL_COST
    
    # Create alliance proposal
    proposal_expires = datetime.utcnow() + timedelta(days=PROPOSAL_EXPIRY_DAYS)
    
    alliance = Alliance(
        initiator_empire_id=my_empire_id,
        target_empire_id=request.target_empire_id,
        initiator_ruler_id=current_user.id,
        initiator_ruler_name=current_user.username,
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
        cost_paid=ALLIANCE_PROPOSAL_COST,
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
    
    # Check max alliances for acceptor
    active_count = _count_active_alliances(db, my_empire_id)
    if active_count >= MAX_ACTIVE_ALLIANCES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {MAX_ACTIVE_ALLIANCES} active alliances allowed. Decline or wait for one to expire."
        )
    
    # Accept the alliance
    alliance.accept(current_user.id, current_user.username)
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

