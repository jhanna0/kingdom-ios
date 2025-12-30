from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from typing import List
from datetime import datetime, timedelta

from db.base import get_db
from db.models import User, Friend, PlayerState
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


router = APIRouter(prefix="/friends", tags=["friends"])


# ===== Helper Functions =====

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
    
    # Check if online (active in last 10 minutes)
    is_online = False
    last_seen = None
    if friend_state and friend_state.last_action_at:
        last_action = friend_state.last_action_at
        if isinstance(last_action, str):
            last_action = datetime.fromisoformat(last_action.replace('Z', '+00:00'))
        time_since_action = datetime.utcnow() - last_action
        is_online = time_since_action < timedelta(minutes=10)
        last_seen = last_action.isoformat()
    
    # Get activity data
    activity = None
    current_kingdom_name = None
    if friend_state and friendship.status == 'accepted':
        activity = _get_player_activity(db, friend_user_id, friend_state)
        if friend_state.current_kingdom_id:
            from db.models import Kingdom
            kingdom = db.query(Kingdom).filter(Kingdom.id == friend_state.current_kingdom_id).first()
            if kingdom:
                current_kingdom_name = kingdom.name
    
    return FriendResponse(
        id=friendship.id,
        user_id=friendship.user_id,
        friend_user_id=friend_user_id,
        friend_username=friend_user.username,
        friend_display_name=friend_user.display_name or friend_user.username,
        status=friendship.status,
        created_at=friendship.created_at.isoformat(),
        updated_at=friendship.updated_at.isoformat(),
        is_online=is_online if friendship.status == 'accepted' else None,
        level=friend_state.level if friend_state and friendship.status == 'accepted' else None,
        current_kingdom_id=friend_state.current_kingdom_id if friend_state and friendship.status == 'accepted' else None,
        current_kingdom_name=current_kingdom_name,
        last_seen=last_seen if friendship.status == 'accepted' else None,
        activity=activity if friendship.status == 'accepted' else None
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
    
    return FriendListResponse(
        success=True,
        friends=friends,
        pending_received=pending_received,
        pending_sent=pending_sent
    )


@router.post("/add", response_model=AddFriendResponse)
def add_friend(
    request: FriendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Send a friend request to another user by username or user_id
    """
    # Find the target user
    target_user = None
    if request.username:
        target_user = db.query(User).filter(User.username == request.username).first()
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
                    message=f"Accepted friend request from {target_user.username}",
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
        message=f"Friend request sent to {target_user.username}",
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
    Search for users by username or display name
    """
    if len(query) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query must be at least 2 characters"
        )
    
    # Search users (case-insensitive)
    users = db.query(User).filter(
        or_(
            User.username.ilike(f"%{query}%"),
            User.display_name.ilike(f"%{query}%")
        )
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
            "username": user.username,
            "display_name": user.display_name or user.username,
            "level": player_state.level if player_state else 1,
            "friendship_status": friendship_status
        })
    
    return SearchUsersResponse(
        success=True,
        users=user_data
    )

