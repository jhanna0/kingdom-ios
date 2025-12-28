"""
Authentication service - Handles user auth, JWT tokens, password hashing
"""
from datetime import datetime, timedelta
from typing import Optional
import uuid
import os

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from db import User, UserKingdom, PlayerState
from models.auth_schemas import AppleSignIn


# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-this-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> dict:
    """Decode and verify a JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ===== User Management =====

def create_user_with_apple(db: Session, apple_data: AppleSignIn) -> User:
    """Create or get user from Apple Sign In"""
    
    # Check if user already exists with this Apple ID
    existing_user = db.query(User).filter(User.apple_user_id == apple_data.apple_user_id).first()
    
    if existing_user:
        # Update last login
        existing_user.last_login = datetime.utcnow()
        db.commit()
        db.refresh(existing_user)
        return existing_user
    
    # Check if display name is taken in this hometown
    if apple_data.hometown_kingdom_id and apple_data.display_name:
        name_taken = db.query(User).filter(
            User.display_name == apple_data.display_name,
            User.hometown_kingdom_id == apple_data.hometown_kingdom_id
        ).first()
        
        if name_taken:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Name '{apple_data.display_name}' is already taken in this city"
            )
    
    # Create new user
    user_id = str(uuid.uuid4())
    user = User(
        id=user_id,
        email=apple_data.email,
        apple_user_id=apple_data.apple_user_id,
        display_name=apple_data.display_name or "Player",
        hometown_kingdom_id=apple_data.hometown_kingdom_id,
    )
    
    db.add(user)
    
    # Create player state with default values
    player_state = PlayerState(
        user_id=user_id,
        hometown_kingdom_id=apple_data.hometown_kingdom_id,
        gold=100,
        level=1,
        experience=0,
        reputation=0,
        honor=100,
    )
    
    db.add(player_state)
    db.commit()
    db.refresh(user)
    
    return user


def get_user_by_id(db: Session, user_id: str) -> Optional[User]:
    """Get user by ID"""
    return db.query(User).filter(User.id == user_id).first()




def update_user_profile(db: Session, user_id: str, updates: dict) -> User:
    """Update user profile"""
    user = get_user_by_id(db, user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Update allowed fields
    for key, value in updates.items():
        if value is not None and hasattr(user, key):
            setattr(user, key, value)
    
    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    
    return user


def user_to_private_response(user: User) -> dict:
    """Convert User model to UserPrivate response"""
    # Get player state if it exists
    player_state = user.player_state
    
    return {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "hometown_kingdom_id": user.hometown_kingdom_id,
        "gold": player_state.gold if player_state else 0,
        "level": player_state.level if player_state else 1,
        "experience": player_state.experience if player_state else 0,
        "reputation": player_state.reputation if player_state else 0,
        "honor": player_state.honor if player_state else 100,
        "total_checkins": player_state.total_checkins if player_state else 0,
        "total_conquests": player_state.total_conquests if player_state else 0,
        "kingdoms_ruled": player_state.kingdoms_ruled if player_state else 0,
        "is_premium": user.is_premium,
        "premium_expires_at": user.premium_expires_at,
        "is_verified": user.is_verified,
        "last_login": user.last_login,
        "created_at": user.created_at,
    }


# ===== User Kingdoms =====

def get_user_kingdoms(db: Session, user_id: str) -> dict:
    """Get all kingdoms associated with a user"""
    
    user_kingdoms = db.query(UserKingdom).filter(UserKingdom.user_id == user_id).all()
    
    ruled = []
    subject = []
    visited = []
    
    for uk in user_kingdoms:
        kingdom_info = {
            "kingdom_id": uk.kingdom_id,
            "kingdom_name": uk.kingdom.name if uk.kingdom else "Unknown",
            "is_ruler": uk.is_ruler,
            "is_subject": uk.is_subject,
            "times_conquered": uk.times_conquered,
            "local_reputation": uk.local_reputation,
            "checkins_count": uk.checkins_count,
            "last_checkin": uk.last_checkin,
            "first_visited": uk.first_visited,
            "became_ruler_at": uk.became_ruler_at,
        }
        
        if uk.is_ruler:
            ruled.append(kingdom_info)
        elif uk.is_subject:
            subject.append(kingdom_info)
        else:
            visited.append(kingdom_info)
    
    return {
        "ruled_kingdoms": ruled,
        "subject_kingdoms": subject,
        "visited_kingdoms": visited,
    }


def add_experience(db: Session, user_id: str, exp_amount: int) -> User:
    """Add experience to user and handle level ups"""
    user = get_user_by_id(db, user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get or create player state
    state = user.player_state
    if not state:
        state = PlayerState(user_id=user.id, hometown_kingdom_id=user.hometown_kingdom_id)
        db.add(state)
        db.flush()
    
    state.experience += exp_amount
    
    # Simple level up formula: 100 exp per level
    required_exp = state.level * 100
    
    while state.experience >= required_exp:
        state.level += 1
        state.experience -= required_exp
        required_exp = state.level * 100
        
        # Give rewards on level up
        state.gold += 50 * state.level
    
    db.commit()
    db.refresh(user)
    
    return user


def add_gold(db: Session, user_id: str, gold_amount: int) -> User:
    """Add gold to user"""
    user = get_user_by_id(db, user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get or create player state
    state = user.player_state
    if not state:
        state = PlayerState(user_id=user.id, hometown_kingdom_id=user.hometown_kingdom_id)
        db.add(state)
    
    state.gold += gold_amount
    db.commit()
    db.refresh(user)
    
    return user


def spend_gold(db: Session, user_id: str, gold_amount: int) -> User:
    """Spend gold (with validation)"""
    user = get_user_by_id(db, user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get or create player state
    state = user.player_state
    if not state:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Player state not initialized"
        )
    
    if state.gold < gold_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient gold"
        )
    
    state.gold -= gold_amount
    db.commit()
    db.refresh(user)
    
    return user

