from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from typing import List
from datetime import datetime, timedelta

from db.base import get_db
from db.models import User, Friend, PlayerState, ActionCooldown
from schemas.friend import (
    FriendRequest,
    FriendResponse,
    FriendListResponse,
    AddFriendResponse,
    FriendActionResponse,
    SearchUsersResponse
)
from routers.auth import get_current_user
from routers.players import _get_player_activity
from routers.actions.utils import format_datetime_iso


router = APIRouter(prefix="/friends", tags=["friends"])


# ===== Dashboard Response Schema =====

from pydantic import BaseModel
from typing import Any

class FriendsDashboardResponse(BaseModel):
    """Consolidated response for FriendsView - all data in one call"""
    success: bool
    # Friends
    friends: List[Any]
    pending_received: List[Any]
    pending_sent: List[Any]
    # Trades
    incoming_trades: List[Any]
    outgoing_trades: List[Any]
    trade_history: List[Any]
    has_merchant_skill: bool
    # Alliances
    pending_alliances_sent: List[Any]
    pending_alliances_received: List[Any]
    is_ruler: bool
    # Friend Activity
    friend_activities: List[Any]


# ===== Helper Functions =====

def _convert_to_friend_activity(activity) -> dict:
    """Convert PlayerActivity to FriendActivity format for iOS"""
    # Get the activity type
    activity_type = activity.type if hasattr(activity, 'type') else 'idle'
    
    # Default icon and color
    icon = 'circle'
    color = 'gray'
    
    # Handle skill-based training activities
    if activity_type == 'training' and hasattr(activity, 'training_type') and activity.training_type:
        # Map skill types to icons (must match SkillConfig)
        skill_icon_map = {
            'attack': 'bolt.fill',
            'defense': 'shield.fill',
            'leadership': 'crown.fill',
            'building': 'hammer.fill',
            'intelligence': 'eye.fill',
            'science': 'flask.fill',
            'faith': 'hands.sparkles.fill'
        }
        # Map skill types to colors (only valid: blue, green, purple, orange, yellow, red)
        skill_color_map = {
            'attack': 'red',
            'defense': 'blue',
            'leadership': 'purple',
            'building': 'orange',
            'intelligence': 'green',
            'science': 'blue',
            'faith': 'purple'
        }
        icon = skill_icon_map.get(activity.training_type, 'figure.strengthtraining.traditional')
        color = skill_color_map.get(activity.training_type, 'purple')
    
    # Handle equipment-based crafting activities
    elif activity_type == 'crafting' and hasattr(activity, 'equipment_type') and activity.equipment_type:
        if activity.equipment_type == 'weapon':
            icon = 'bolt.fill'
            color = 'red'
        elif activity.equipment_type == 'armor':
            icon = 'shield.fill'
            color = 'blue'
        else:
            icon = 'hammer.circle.fill'
            color = 'orange'
    
    # Default icon/color for other activity types
    else:
        icon_map = {
            'working': 'hammer.fill',
            'patrolling': 'figure.walk',
            'training': 'figure.strengthtraining.traditional',
            'crafting': 'hammer.circle.fill',
            'scouting': 'eye.fill',
            'sabotage': 'exclamationmark.triangle.fill',
            'idle': 'circle'
        }
        color_map = {
            'working': 'blue',
            'patrolling': 'green',
            'training': 'purple',
            'crafting': 'orange',
            'scouting': 'yellow',
            'sabotage': 'red',
            'idle': 'gray'
        }
        icon = icon_map.get(activity_type, 'circle')
        color = color_map.get(activity_type, 'gray')
    
    return {
        'icon': icon,
        'display_text': activity.details if hasattr(activity, 'details') and activity.details else activity_type.capitalize(),
        'color': color
    }


def _get_friend_response(db: Session, friendship: Friend, current_user_id: int) -> FriendResponse:
    """Convert Friend model to FriendResponse with activity data"""
    # Determine which user is the friend
    friend_user_id = friendship.friend_user_id if friendship.user_id == current_user_id else friendship.user_id
    
    # Get friend's user info
    friend_user = db.query(User).filter(User.id == friend_user_id).first()
    if not friend_user:
        raise HTTPException(status_code=404, detail="Friend user not found")
    
    # Get friend's player state for activity
    friend_state = db.query(PlayerState).filter(PlayerState.user_id == friend_user_id).first()
    
    # Check if online (active in last 10 minutes) by checking most recent action from action_cooldowns
    is_online = False
    last_seen = None
    
    # Get most recent action from action_cooldowns table
    most_recent_action = db.query(ActionCooldown).filter(
        ActionCooldown.user_id == friend_user_id
    ).order_by(ActionCooldown.last_performed.desc()).first()
    
    if most_recent_action:
        last_action = most_recent_action.last_performed
        if isinstance(last_action, str):
            last_action = datetime.fromisoformat(last_action.replace('Z', '+00:00'))
        time_since_action = datetime.utcnow() - last_action
        is_online = time_since_action < timedelta(minutes=10)
        last_seen = format_datetime_iso(last_action)
    elif friend_state and friend_state.updated_at:
        # Fallback to player_state updated_at if no actions recorded
        last_action = friend_state.updated_at
        if isinstance(last_action, str):
            last_action = datetime.fromisoformat(last_action.replace('Z', '+00:00'))
        time_since_action = datetime.utcnow() - last_action
        is_online = time_since_action < timedelta(minutes=10)
        last_seen = format_datetime_iso(last_action)
    
    # Get activity data
    activity_dict = None
    current_kingdom_name = None
    if friend_state and friendship.status == 'accepted':
        activity_obj = _get_player_activity(db, friend_state)
        # Convert PlayerActivity to FriendActivity format (with icon, display_text, color)
        activity_dict = _convert_to_friend_activity(activity_obj)
        if friend_state.current_kingdom_id:
            from db.models import Kingdom
            kingdom = db.query(Kingdom).filter(Kingdom.id == friend_state.current_kingdom_id).first()
            if kingdom:
                current_kingdom_name = kingdom.name
    
    return FriendResponse(
        id=friendship.id,
        user_id=friendship.user_id,
        friend_user_id=friend_user_id,
        friend_username=friend_user.display_name,
        friend_display_name=friend_user.display_name,
        status=friendship.status,
        created_at=format_datetime_iso(friendship.created_at),
        updated_at=format_datetime_iso(friendship.updated_at),
        is_online=is_online if friendship.status == 'accepted' else None,
        level=friend_state.level if friend_state and friendship.status == 'accepted' else None,
        current_kingdom_id=friend_state.current_kingdom_id if friend_state and friendship.status == 'accepted' else None,
        current_kingdom_name=current_kingdom_name,
        last_seen=last_seen if friendship.status == 'accepted' else None,
        activity=activity_dict if friendship.status == 'accepted' else None
    )


# ===== API Endpoints =====

@router.get("/list", response_model=FriendListResponse)
def list_friends(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get list of all friends and pending requests
    """
    user_id = current_user.id
    
    # Get all friendships involving this user
    friendships = db.query(Friend).filter(
        or_(
            Friend.user_id == user_id,
            Friend.friend_user_id == user_id
        )
    ).all()
    
    friends = []
    pending_received = []
    pending_sent = []
    
    for friendship in friendships:
        friend_response = _get_friend_response(db, friendship, user_id)
        
        if friendship.status == 'accepted':
            friends.append(friend_response)
        elif friendship.status == 'pending':
            # If I sent the request
            if friendship.user_id == user_id:
                pending_sent.append(friend_response)
            # If I received the request
            else:
                pending_received.append(friend_response)
    
    # Sort friends by last activity (most recent first)
    friends.sort(key=lambda f: f.last_seen or '', reverse=True)
    
    return FriendListResponse(
        success=True,
        friends=friends,
        pending_received=pending_received,
        pending_sent=pending_sent
    )


@router.get("/dashboard", response_model=FriendsDashboardResponse)
def get_friends_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all data needed for FriendsView in a single call.
    
    Returns:
    - Friends list (accepted, pending received, pending sent)
    - Trade offers (incoming, outgoing, history)
    - Alliance proposals (sent, received)
    - Friend activity feed
    """
    user_id = current_user.id
    
    # ===== FRIENDS =====
    friendships = db.query(Friend).filter(
        or_(
            Friend.user_id == user_id,
            Friend.friend_user_id == user_id
        )
    ).all()
    
    friends = []
    pending_received = []
    pending_sent = []
    
    for friendship in friendships:
        friend_response = _get_friend_response(db, friendship, user_id)
        
        if friendship.status == 'accepted':
            friends.append(friend_response)
        elif friendship.status == 'pending':
            if friendship.user_id == user_id:
                pending_sent.append(friend_response)
            else:
                pending_received.append(friend_response)
    
    friends.sort(key=lambda f: f.last_seen or '', reverse=True)
    
    # ===== TRADES =====
    from db import TradeOffer, TradeOfferStatus
    from routers.trades import (
        trade_offer_to_response, 
        check_merchant_skill, 
        TRADE_OFFER_EXPIRY_HOURS,
        modify_player_resource
    )
    
    state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
    has_merchant_skill = False
    incoming_trades = []
    outgoing_trades = []
    trade_history = []
    
    if state and check_merchant_skill(state):
        has_merchant_skill = True
        
        # Expire old pending offers
        expire_threshold = datetime.utcnow() - timedelta(hours=TRADE_OFFER_EXPIRY_HOURS)
        expired_offers = db.query(TradeOffer).filter(
            TradeOffer.status == TradeOfferStatus.PENDING.value,
            TradeOffer.created_at < expire_threshold
        ).all()
        
        for offer in expired_offers:
            sender_state = db.query(PlayerState).filter(PlayerState.user_id == offer.sender_id).first()
            if sender_state:
                if offer.offer_type == "item" and offer.item_type:
                    modify_player_resource(db, sender_state, offer.item_type, offer.item_quantity)
                elif offer.offer_type == "gold":
                    sender_state.gold += offer.gold_amount
            offer.status = TradeOfferStatus.EXPIRED.value
        
        db.commit()
        
        # Get trades
        incoming = db.query(TradeOffer).filter(
            TradeOffer.recipient_id == user_id,
            TradeOffer.status == TradeOfferStatus.PENDING.value
        ).order_by(TradeOffer.created_at.desc()).all()
        
        outgoing = db.query(TradeOffer).filter(
            TradeOffer.sender_id == user_id,
            TradeOffer.status == TradeOfferStatus.PENDING.value
        ).order_by(TradeOffer.created_at.desc()).all()
        
        history = db.query(TradeOffer).filter(
            or_(TradeOffer.sender_id == user_id, TradeOffer.recipient_id == user_id),
            TradeOffer.status != TradeOfferStatus.PENDING.value
        ).order_by(TradeOffer.updated_at.desc()).limit(20).all()
        
        incoming_trades = [trade_offer_to_response(db, o, user_id).model_dump() for o in incoming]
        outgoing_trades = [trade_offer_to_response(db, o, user_id).model_dump() for o in outgoing]
        trade_history = [trade_offer_to_response(db, o, user_id).model_dump() for o in history]
    
    # ===== ALLIANCES =====
    from db import Kingdom, Alliance
    from routers.alliances import _get_player_empire_id, _expire_old_alliances, _alliance_to_response
    
    _expire_old_alliances(db)
    
    is_ruler = False
    pending_alliances_sent = []
    pending_alliances_received = []
    
    my_empire_id = _get_player_empire_id(db, current_user, state) if state else None
    
    if my_empire_id:
        is_ruler = True
        
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
        
        pending_alliances_sent = [_alliance_to_response(a).model_dump() for a in sent]
        pending_alliances_received = [_alliance_to_response(a).model_dump() for a in received]
    
    # ===== FRIEND ACTIVITY =====
    from routers.activity import (
        _get_contract_activities,
        _get_coup_activities,
        _get_invasion_activities,
        _get_property_activities,
        _get_training_activities,
        _get_action_log_activities
    )
    
    # Get friend IDs
    friend_ids = []
    for friendship in friendships:
        if friendship.status == 'accepted':
            friend_id = friendship.friend_user_id if friendship.user_id == user_id else friendship.user_id
            friend_ids.append(friend_id)
    
    # Include self
    all_user_ids = friend_ids + [user_id]
    all_activities = []
    
    for uid in all_user_ids:
        the_user = db.query(User).filter(User.id == uid).first()
        if not the_user:
            continue
        
        user_state = db.query(PlayerState).filter(PlayerState.user_id == uid).first()
        if not user_state:
            continue
        
        user_activities = []
        user_activities.extend(_get_contract_activities(db, uid, 20))
        user_activities.extend(_get_coup_activities(db, uid, 20))
        user_activities.extend(_get_invasion_activities(db, uid, 20))
        user_activities.extend(_get_property_activities(db, uid, 20))
        user_activities.extend(_get_training_activities(db, uid, user_state, 10))
        user_activities.extend(_get_action_log_activities(db, uid, 20, exclude_types=["travel_fee"]))
        
        for activity in user_activities:
            activity.username = the_user.display_name
            activity.display_name = the_user.display_name
            activity.user_level = user_state.level
        
        all_activities.extend(user_activities)
    
    # Filter to last 7 days
    cutoff = datetime.utcnow() - timedelta(days=7)
    all_activities = [a for a in all_activities if a.created_at >= cutoff]
    all_activities.sort(key=lambda x: x.created_at, reverse=True)
    all_activities = all_activities[:50]
    
    friend_activities = [a.model_dump() for a in all_activities]
    
    return FriendsDashboardResponse(
        success=True,
        friends=[f.model_dump() for f in friends],
        pending_received=[f.model_dump() for f in pending_received],
        pending_sent=[f.model_dump() for f in pending_sent],
        incoming_trades=incoming_trades,
        outgoing_trades=outgoing_trades,
        trade_history=trade_history,
        has_merchant_skill=has_merchant_skill,
        pending_alliances_sent=pending_alliances_sent,
        pending_alliances_received=pending_alliances_received,
        is_ruler=is_ruler,
        friend_activities=friend_activities
    )


@router.post("/add", response_model=AddFriendResponse)
def add_friend(
    request: FriendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Send a friend request to another user by username (display_name) or user_id
    """
    # Find the target user
    target_user = None
    if request.username:
        target_user = db.query(User).filter(User.display_name == request.username).first()
    elif request.user_id:
        target_user = db.query(User).filter(User.id == request.user_id).first()
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must provide either username or user_id"
        )
    
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Can't add yourself
    if target_user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot add yourself as a friend"
        )
    
    # Check if friendship already exists
    existing = db.query(Friend).filter(
        or_(
            and_(Friend.user_id == current_user.id, Friend.friend_user_id == target_user.id),
            and_(Friend.user_id == target_user.id, Friend.friend_user_id == current_user.id)
        )
    ).first()
    
    if existing:
        if existing.status == 'accepted':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already friends with this user"
            )
        elif existing.status == 'pending':
            # If they sent you a request, accept it
            if existing.user_id == target_user.id:
                existing.status = 'accepted'
                existing.updated_at = datetime.utcnow()
                db.commit()
                db.refresh(existing)
                
                return AddFriendResponse(
                    success=True,
                    message=f"Accepted friend request from {target_user.display_name}",
                    friend=_get_friend_response(db, existing, current_user.id)
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Friend request already sent"
                )
        elif existing.status == 'blocked':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot send friend request to this user"
            )
    
    # Create new friend request
    friendship = Friend(
        user_id=current_user.id,
        friend_user_id=target_user.id,
        status='pending',
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    
    db.add(friendship)
    db.commit()
    db.refresh(friendship)
    
    return AddFriendResponse(
        success=True,
        message=f"Friend request sent to {target_user.display_name}",
        friend=_get_friend_response(db, friendship, current_user.id)
    )


@router.post("/{friend_id}/accept", response_model=FriendActionResponse)
def accept_friend_request(
    friend_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Accept a pending friend request
    """
    friendship = db.query(Friend).filter(Friend.id == friend_id).first()
    
    if not friendship:
        raise HTTPException(status_code=404, detail="Friend request not found")
    
    # Must be the recipient of the request
    if friendship.friend_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only accept requests sent to you"
        )
    
    if friendship.status != 'pending':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Request is not pending"
        )
    
    friendship.status = 'accepted'
    friendship.updated_at = datetime.utcnow()
    db.commit()
    
    return FriendActionResponse(
        success=True,
        message="Friend request accepted"
    )


@router.post("/{friend_id}/reject", response_model=FriendActionResponse)
def reject_friend_request(
    friend_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Reject a pending friend request
    """
    friendship = db.query(Friend).filter(Friend.id == friend_id).first()
    
    if not friendship:
        raise HTTPException(status_code=404, detail="Friend request not found")
    
    # Must be the recipient of the request
    if friendship.friend_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only reject requests sent to you"
        )
    
    if friendship.status != 'pending':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Request is not pending"
        )
    
    # Delete the request
    db.delete(friendship)
    db.commit()
    
    return FriendActionResponse(
        success=True,
        message="Friend request rejected"
    )


@router.delete("/{friend_id}", response_model=FriendActionResponse)
def remove_friend(
    friend_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Remove a friend or cancel a sent request
    """
    friendship = db.query(Friend).filter(Friend.id == friend_id).first()
    
    if not friendship:
        raise HTTPException(status_code=404, detail="Friendship not found")
    
    # Must be involved in the friendship
    if friendship.user_id != current_user.id and friendship.friend_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    db.delete(friendship)
    db.commit()
    
    return FriendActionResponse(
        success=True,
        message="Friend removed"
    )


@router.get("/search", response_model=SearchUsersResponse)
def search_users(
    query: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Search for users by display name
    """
    if len(query) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query must be at least 2 characters"
        )
    
    # Search users by display_name (case-insensitive)
    users = db.query(User).filter(
        User.display_name.ilike(f"%{query}%")
    ).limit(20).all()
    
    # Get player states for levels
    user_data = []
    for user in users:
        if user.id == current_user.id:
            continue  # Skip self
        
        player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
        
        # Check friendship status
        friendship = db.query(Friend).filter(
            or_(
                and_(Friend.user_id == current_user.id, Friend.friend_user_id == user.id),
                and_(Friend.user_id == user.id, Friend.friend_user_id == current_user.id)
            )
        ).first()
        
        friendship_status = friendship.status if friendship else None
        
        user_data.append({
            "id": user.id,
            "username": user.display_name,  # Use display_name as username
            "display_name": user.display_name,
            "level": player_state.level if player_state else 1,
            "friendship_status": friendship_status
        })
    
    return SearchUsersResponse(
        success=True,
        users=user_data
    )

