"""
Player Activity Feed - Aggregate activity from existing tables
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc
from typing import List, Optional
from datetime import datetime, timedelta

from db.base import get_db
from db.models import User, PlayerState, Contract, CoupEvent, InvasionEvent, Property, Kingdom, UnifiedContract, ContractContribution
from db.models.activity_log import PlayerActivityLog
from sqlalchemy import func
from routers.auth import get_current_user
from schemas.activity import ActivityLogEntry, PlayerActivityResponse


router = APIRouter(prefix="/activity", tags=["activity"])


def _get_contract_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get building/construction activities from contracts"""
    activities = []
    
    # Find all contracts where user has contributed
    user_id_str = str(user_id)
    contracts = db.query(Contract).filter(
        Contract.action_contributions.contains({user_id_str: 1})  # User has at least 1 action
    ).order_by(desc(Contract.created_at)).limit(limit).all()
    
    for contract in contracts:
        contributions = contract.action_contributions.get(user_id_str, 0) if contract.action_contributions else 0
        if contributions > 0:
            activities.append(ActivityLogEntry(
                id=contract.id,
                user_id=user_id,
                action_type="build",
                action_category="kingdom",
                description=f"Contributed {contributions} actions to {contract.building_type} L{contract.building_level}",
                kingdom_id=contract.kingdom_id,
                kingdom_name=contract.kingdom_name,
                amount=contributions,
                details={
                    "contract_id": str(contract.id),
                    "building_type": contract.building_type,
                    "building_level": contract.building_level,
                    "actions_contributed": contributions,
                    "status": "completed" if contract.completed_at else "open"
                },
                created_at=contract.work_started_at or contract.created_at
            ))
    
    return activities


def _get_coup_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get voting activities from coup events"""
    activities = []
    
    # Find coups where user participated
    coups = db.query(CoupEvent).filter(
        or_(
            CoupEvent.attackers.contains([user_id]),
            CoupEvent.defenders.contains([user_id])
        )
    ).order_by(desc(CoupEvent.created_at)).limit(limit).all()
    
    for coup in coups:
        # Determine which side they voted for
        side = "attacker" if user_id in (coup.attackers or []) else "defender"
        
        # Get kingdom info
        kingdom = db.query(Kingdom).filter(Kingdom.id == coup.kingdom_id).first()
        kingdom_name = kingdom.name if kingdom else coup.kingdom_id
        
        activities.append(ActivityLogEntry(
            id=coup.id + 1000000,  # Offset to avoid ID collision with contracts
            user_id=user_id,
            action_type="vote",
            action_category="combat",
            description=f"Voted as {side} in coup against {coup.initiator_name}",
            kingdom_id=coup.kingdom_id,
            kingdom_name=kingdom_name,
            details={
                "coup_id": coup.id,
                "side": side,
                "initiator": coup.initiator_name,
                "status": coup.current_phase,
                "victory": coup.attacker_victory if coup.is_resolved else None
            },
            created_at=coup.start_time
        ))
    
    return activities


def _get_invasion_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get invasion participation activities"""
    activities = []
    
    invasions = db.query(InvasionEvent).filter(
        or_(
            InvasionEvent.attackers.contains([user_id]),
            InvasionEvent.defenders.contains([user_id])
        )
    ).order_by(desc(InvasionEvent.created_at)).limit(limit).all()
    
    for invasion in invasions:
        side = "attacker" if user_id in (invasion.attackers or []) else "defender"
        
        # Get kingdom names
        target_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.target_kingdom_id).first()
        attacking_kingdom = db.query(Kingdom).filter(Kingdom.id == invasion.attacking_from_kingdom_id).first()
        
        target_name = target_kingdom.name if target_kingdom else invasion.target_kingdom_id
        attacking_name = attacking_kingdom.name if attacking_kingdom else invasion.attacking_from_kingdom_id
        
        description = f"Joined invasion as {side}"
        if side == "attacker":
            description += f" from {attacking_name} to {target_name}"
        else:
            description += f" defending {target_name}"
        
        activities.append(ActivityLogEntry(
            id=invasion.id + 2000000,  # Offset to avoid ID collision
            user_id=user_id,
            action_type="invasion",
            action_category="combat",
            description=description,
            kingdom_id=invasion.target_kingdom_id,
            kingdom_name=target_name,
            amount=invasion.cost_per_attacker if side == "attacker" else None,
            details={
                "invasion_id": invasion.id,
                "side": side,
                "attacking_from": attacking_name,
                "target": target_name,
                "status": invasion.status,
                "victory": invasion.attacker_victory if invasion.status == 'resolved' else None
            },
            created_at=invasion.declared_at
        ))
    
    return activities


def _get_property_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get property purchase/upgrade activities"""
    activities = []
    
    properties = db.query(Property).filter(
        Property.owner_id == user_id
    ).order_by(desc(Property.purchased_at)).limit(limit).all()
    
    for prop in properties:
        # Property purchase
        activities.append(ActivityLogEntry(
            id=hash(prop.id) % 1000000 + 3000000,  # Offset to avoid ID collision
            user_id=user_id,
            action_type="property_purchase",
            action_category="economy",
            description=f"Purchased T{prop.tier} property in {prop.kingdom_name}",
            kingdom_id=prop.kingdom_id,
            kingdom_name=prop.kingdom_name,
            details={
                "property_id": prop.id,
                "tier": prop.tier,
                "location": prop.location
            },
            created_at=prop.purchased_at
        ))
        
        # Property upgrades (if upgraded)
        if prop.last_upgraded and prop.tier > 1:
            activities.append(ActivityLogEntry(
                id=hash(prop.id) % 1000000 + 4000000,  # Offset to avoid ID collision
                user_id=user_id,
                action_type="property_upgrade",
                action_category="economy",
                description=f"Upgraded property to T{prop.tier} in {prop.kingdom_name}",
                kingdom_id=prop.kingdom_id,
                kingdom_name=prop.kingdom_name,
                details={
                    "property_id": prop.id,
                    "tier": prop.tier,
                    "location": prop.location
                },
                created_at=prop.last_upgraded
            ))
    
    return activities


def _get_training_activities(db: Session, user_id: int, state: PlayerState, limit: int = 20) -> List[ActivityLogEntry]:
    """Get training activities from unified_contracts table - show individual training actions"""
    activities = []
    
    # Import centralized skill types
    from routers.tiers import SKILL_TYPES
    training_types = SKILL_TYPES
    
    # Query individual training contributions (each action performed)
    contributions = db.query(ContractContribution, UnifiedContract).join(
        UnifiedContract,
        ContractContribution.contract_id == UnifiedContract.id
    ).filter(
        ContractContribution.user_id == user_id,
        UnifiedContract.type.in_(training_types)
    ).order_by(desc(ContractContribution.performed_at)).limit(limit).all()
    
    for contribution, contract in contributions:
        # Check if this completed the contract
        actions_completed = db.query(func.count(ContractContribution.id)).filter(
            ContractContribution.contract_id == contract.id,
            ContractContribution.performed_at <= contribution.performed_at
        ).scalar()
        
        completed_contract = actions_completed >= contract.actions_required
        
        if completed_contract:
            # This action completed the training!
            description = f"Leveled up {contract.type.capitalize()}"
        else:
            description = f"Training {contract.type.capitalize()} ({actions_completed}/{contract.actions_required})"
        
        activities.append(ActivityLogEntry(
            id=contribution.id + 5000000,  # Offset to avoid ID collisions
            user_id=user_id,
            action_type="train",
            action_category="combat",
            description=description,
            kingdom_id=contract.kingdom_id,
            kingdom_name=contract.kingdom_name,
            amount=contribution.gold_earned if contribution.gold_earned > 0 else None,
            details={
                "training_type": contract.type,
                "tier": contract.tier,
                "progress": f"{actions_completed}/{contract.actions_required}",
                "completed": completed_contract
            },
            created_at=contribution.performed_at  # Use the action's timestamp, not the contract's!
        ))
    
    return activities


def _get_kingdom_visit_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get kingdom visit statistics from user_kingdoms table"""
    activities = []
    
    from db.models.kingdom import UserKingdom
    
    # Get all kingdoms user has visited, ordered by most recent visit
    user_kingdoms = db.query(UserKingdom).filter(
        UserKingdom.user_id == user_id,
        UserKingdom.checkins_count > 0
    ).order_by(desc(UserKingdom.last_checkin)).limit(limit).all()
    
    for uk in user_kingdoms:
        # Get kingdom info
        kingdom = db.query(Kingdom).filter(Kingdom.id == uk.kingdom_id).first()
        kingdom_name = kingdom.name if kingdom else uk.kingdom_id
        
        activities.append(ActivityLogEntry(
            id=hash(f"{user_id}-{uk.kingdom_id}") % 1000000 + 7000000,  # Offset to avoid ID collision
            user_id=user_id,
            action_type="kingdom_visits",
            action_category="kingdom",
            description=f"Visited {kingdom_name}",
            kingdom_id=uk.kingdom_id,
            kingdom_name=kingdom_name,
            amount=uk.checkins_count,
            details={
                "total_visits": uk.checkins_count,
                "gold_earned": uk.gold_earned,
                "reputation": uk.local_reputation
            },
            created_at=uk.last_checkin or uk.first_visited
        ))
    
    return activities


def _get_action_log_activities(db: Session, user_id: int, limit: int = 50) -> List[ActivityLogEntry]:
    """Get logged activities from PlayerActivityLog (farm, patrol, scout, etc.)"""
    activities = []
    
    logs = db.query(PlayerActivityLog).filter(
        PlayerActivityLog.user_id == user_id
    ).order_by(desc(PlayerActivityLog.created_at)).limit(limit).all()
    
    for log in logs:
        # Use the description as-is, amount will be shown separately on the right
        activities.append(ActivityLogEntry(
            id=log.id,
            user_id=user_id,
            action_type=log.action_type,
            action_category=log.action_category,
            description=log.description,
            kingdom_id=log.kingdom_id,
            kingdom_name=log.kingdom_name,
            amount=log.amount,
            details=log.details or {},
            created_at=log.created_at
        ))
    
    return activities


@router.get("/my-activities", response_model=PlayerActivityResponse)
def get_my_activities(
    limit: int = 50,
    days: Optional[int] = 7,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get my own activity history
    
    Shows:
    - Building contributions
    - Coup votes
    - Invasion participation
    - Property purchases/upgrades
    - Training sessions
    - Check-ins
    - Income actions (farming, patrol, scouting)
    
    Parameters:
    - limit: Max activities to return (default 50)
    - days: Filter to activities within last N days (default 7, use 0 for all time)
    """
    user_id = current_user.id
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    
    if not state:
        raise HTTPException(status_code=404, detail="Player state not found")
    
    # Collect all activities
    all_activities = []
    
    # Get activities from different sources
    all_activities.extend(_get_contract_activities(db, user_id, limit))
    all_activities.extend(_get_coup_activities(db, user_id, limit))
    all_activities.extend(_get_invasion_activities(db, user_id, limit))
    all_activities.extend(_get_property_activities(db, user_id, limit))
    all_activities.extend(_get_training_activities(db, user_id, state, limit))
    all_activities.extend(_get_action_log_activities(db, user_id, limit))
    
    # Filter by date if specified
    if days and days > 0:
        cutoff = datetime.utcnow() - timedelta(days=days)
        all_activities = [a for a in all_activities if a.created_at >= cutoff]
    
    # Sort by date (most recent first)
    all_activities.sort(key=lambda x: x.created_at, reverse=True)
    
    # Limit results
    all_activities = all_activities[:limit]
    
    return PlayerActivityResponse(
        success=True,
        total=len(all_activities),
        activities=all_activities
    )


@router.get("/friend-activities", response_model=PlayerActivityResponse)
def get_friend_activities(
    limit: int = 50,
    days: Optional[int] = 7,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get activity feed for all my friends AND my own broadcasts
    
    Shows combined activity from all accepted friends plus the current user's activities
    
    Parameters:
    - limit: Max activities to return (default 50)
    - days: Filter to activities within last N days (default 7)
    """
    from db.models import Friend
    
    user_id = current_user.id
    
    # Get all accepted friendships
    friendships = db.query(Friend).filter(
        or_(
            Friend.user_id == user_id,
            Friend.friend_user_id == user_id
        ),
        Friend.status == 'accepted'
    ).all()
    
    # Get friend user IDs
    friend_ids = []
    for friendship in friendships:
        friend_id = friendship.friend_user_id if friendship.user_id == user_id else friendship.user_id
        friend_ids.append(friend_id)
    
    # Include the current user's own activities too
    all_user_ids = friend_ids + [user_id]
    
    # Collect activities from all users (friends + self)
    all_activities = []
    
    for uid in all_user_ids:
        # Get user info
        the_user = db.query(User).filter(User.id == uid).first()
        if not the_user:
            continue
        
        user_state = db.query(PlayerState).filter(PlayerState.user_id == uid).first()
        if not user_state:
            continue
        
        # Get activities from different sources
        user_activities = []
        user_activities.extend(_get_contract_activities(db, uid, 20))
        user_activities.extend(_get_coup_activities(db, uid, 20))
        user_activities.extend(_get_invasion_activities(db, uid, 20))
        user_activities.extend(_get_property_activities(db, uid, 20))
        user_activities.extend(_get_training_activities(db, uid, user_state, 10))
        user_activities.extend(_get_action_log_activities(db, uid, 20))
        
        # Add user info to activities
        for activity in user_activities:
            activity.username = the_user.display_name
            activity.display_name = the_user.display_name
            activity.user_level = user_state.level
        
        all_activities.extend(user_activities)
    
    # Filter by date if specified
    if days and days > 0:
        cutoff = datetime.utcnow() - timedelta(days=days)
        all_activities = [a for a in all_activities if a.created_at >= cutoff]
    
    # Sort by date (most recent first)
    all_activities.sort(key=lambda x: x.created_at, reverse=True)
    
    # Limit results
    all_activities = all_activities[:limit]
    
    return PlayerActivityResponse(
        success=True,
        total=len(all_activities),
        activities=all_activities
    )

