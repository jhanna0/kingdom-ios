"""
Authentication service - Handles user auth, JWT tokens, password hashing
"""
from datetime import datetime, timedelta
from typing import Optional
import os

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from db import User, UserKingdom, PlayerState
from models.auth_schemas import AppleSignIn
from utils.validation import validate_username, sanitize_username


# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT configuration
# SECURITY: Secret key MUST be set via environment variable in production
# This key signs all JWT tokens - if compromised, attackers can forge tokens
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-this-in-production")
if SECRET_KEY == "your-secret-key-change-this-in-production":
    import warnings
    warnings.warn("⚠️  SECURITY WARNING: Using default JWT secret key! Set JWT_SECRET_KEY environment variable!")
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
    
    print(f"🔐 [SIGNUP] Apple Sign In attempt:")
    print(f"   - apple_user_id: {apple_data.apple_user_id}")
    print(f"   - email: {apple_data.email}")
    print(f"   - display_name: {apple_data.display_name}")
    
    # Check if user already exists with this Apple ID
    existing_user = db.query(User).filter(User.apple_user_id == apple_data.apple_user_id).first()
    
    if existing_user:
        print(f"✅ [SIGNUP] Existing user found: user_id={existing_user.id}, display_name={existing_user.display_name}")
        # Update last login
        existing_user.last_login = datetime.utcnow()
        db.commit()
        db.refresh(existing_user)
        
        # Log player state
        if existing_user.player_state:
            print(f"   - Player state: hometown_kingdom_id={existing_user.player_state.hometown_kingdom_id}")
        else:
            print(f"   - ⚠️ WARNING: User has no player_state!")
        
        return existing_user
    
    # Sanitize and validate display name
    display_name = apple_data.display_name or "Player"
    print(f"📝 [SIGNUP] Creating new user with display_name: {display_name}")
    
    if display_name != "Player":  # Don't validate default name
        display_name = sanitize_username(display_name)
        is_valid, error_msg = validate_username(display_name)
        if not is_valid:
            print(f"❌ [SIGNUP] Display name validation failed: {error_msg}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error_msg
            )
    
    # Check if display name is already taken (globally unique)
    existing_display_name = db.query(User).filter(User.display_name == display_name).first()
    if existing_display_name:
        print(f"❌ [SIGNUP] Display name already taken: {display_name}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Display name '{display_name}' is already taken"
        )
    
    # Create new user - PostgreSQL will auto-generate the ID
    user = User(
        email=apple_data.email,
        apple_user_id=apple_data.apple_user_id,
        display_name=display_name,
    )
    
    db.add(user)
    db.flush()  # Flush to get the auto-generated ID
    
    print(f"✅ [SIGNUP] User created: user_id={user.id}, display_name={user.display_name}")
    
    # Create player state with default values
    player_state = PlayerState(
        user_id=user.id,  # Now this is a Postgres-generated integer
        hometown_kingdom_id=None,  # Will be set on first check-in
        gold=100,
        level=1,
        experience=0,
    )
    
    db.add(player_state)
    db.commit()
    db.refresh(user)
    
    print(f"✅ [SIGNUP] PlayerState created: hometown_kingdom_id={player_state.hometown_kingdom_id} (should be None)")
    
    return user


def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    """Get user by ID"""
    # EAGER LOAD player_state to avoid N+1 query problem
    from sqlalchemy.orm import joinedload
    return db.query(User).options(joinedload(User.player_state)).filter(User.id == user_id).first()

def update_user_profile(db: Session, user_id: int, updates: dict) -> User:
    """Update user profile"""
    print(f"📝 [UPDATE_PROFILE] Updating user profile:")
    print(f"   - user_id: {user_id}")
    print(f"   - updates: {updates}")
    
    user = get_user_by_id(db, user_id)
    
    if not user:
        print(f"❌ [UPDATE_PROFILE] User not found: {user_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    print(f"✅ [UPDATE_PROFILE] User found: display_name={user.display_name}")
    
    # Special handling for display_name updates
    if "display_name" in updates and updates["display_name"] is not None:
        display_name = sanitize_username(updates["display_name"])
        is_valid, error_msg = validate_username(display_name)
        if not is_valid:
            print(f"❌ [UPDATE_PROFILE] Display name validation failed: {error_msg}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error_msg
            )
        
        # Check if new name is taken (globally unique)
        name_taken = db.query(User).filter(
            User.display_name == display_name,
            User.id != user_id  # Exclude current user
        ).first()
        
        if name_taken:
            print(f"❌ [UPDATE_PROFILE] Display name already taken: {display_name}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Display name '{display_name}' is already taken"
            )
        
        updates["display_name"] = display_name
        print(f"✅ [UPDATE_PROFILE] Display name validated: {display_name}")
    
    # Fields that belong on player_state, not user
    player_state_fields = {"hometown_kingdom_id", "current_kingdom_id"}
    
    # Update user fields
    for key, value in updates.items():
        if key in player_state_fields:
            continue  # Handle separately
        if value is not None and hasattr(user, key):
            print(f"   - Setting user.{key} = {value}")
            setattr(user, key, value)
    
    # Update player_state fields
    player_state = user.player_state
    if not player_state:
        print(f"⚠️ [UPDATE_PROFILE] No player_state found, creating new one")
        player_state = PlayerState(user_id=user.id)
        db.add(player_state)
        db.flush()
    else:
        print(f"✅ [UPDATE_PROFILE] Player state found: current hometown_kingdom_id={player_state.hometown_kingdom_id}")
    
    for key, value in updates.items():
        if key in player_state_fields and value is not None:
            print(f"   - Setting player_state.{key} = {value}")
            setattr(player_state, key, value)
    
    user.updated_at = datetime.utcnow()
    db.commit()
    
    print(f"💾 [UPDATE_PROFILE] Changes committed to database")
    
    db.refresh(user)
    db.refresh(player_state)  # Refresh player_state explicitly
    
    print(f"✅ [UPDATE_PROFILE] Final state (after refresh):")
    print(f"   - user.display_name: {user.display_name}")
    print(f"   - player_state.hometown_kingdom_id: {player_state.hometown_kingdom_id}")
    
    # Double-check by querying directly from DB
    from db.models.player_state import PlayerState as DBPlayerState
    db_check = db.query(DBPlayerState).filter(DBPlayerState.user_id == user.id).first()
    if db_check:
        print(f"🔍 [UPDATE_PROFILE] DB verification query:")
        print(f"   - DB row hometown_kingdom_id: {db_check.hometown_kingdom_id}")
    else:
        print(f"⚠️ [UPDATE_PROFILE] WARNING: Could not find player_state in DB for verification!")
    
    return user


def user_to_private_response(user: User) -> dict:
    """Convert User model to UserPrivate response"""
    # Get player state if it exists
    player_state = user.player_state
    
    print(f"🔄 [user_to_private_response] Converting user to response:")
    print(f"   - user.id: {user.id}")
    print(f"   - user.display_name: {user.display_name}")
    print(f"   - player_state exists: {player_state is not None}")
    
    if player_state:
        print(f"   - player_state.id: {player_state.id}")
        print(f"   - player_state.user_id: {player_state.user_id}")
        print(f"   - player_state.hometown_kingdom_id: {player_state.hometown_kingdom_id}")
        hometown_id = player_state.hometown_kingdom_id
    else:
        print(f"   - ⚠️ WARNING: No player_state found for user!")
        hometown_id = None
    
    print(f"   - hometown_kingdom_id for response: {hometown_id}")
    
    # NOTE: After schema migration, the following fields are no longer on player_state:
    # - reputation: now per-kingdom in user_kingdoms table (using 0 for now)
    # - honor: removed (dead code, defaulting to 100)
    # - total_checkins: computed from user_kingdoms table (TODO)
    # - total_conquests: computed from kingdom_history table (TODO)
    # - kingdoms_ruled: computed from kingdoms table (TODO)
    
    return {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "hometown_kingdom_id": hometown_id,
        "gold": player_state.gold if player_state else 0,
        "level": player_state.level if player_state else 1,
        "experience": player_state.experience if player_state else 0,
        "reputation": 0,  # TODO: compute from user_kingdoms for current kingdom
        "honor": 100,  # Deprecated field, defaulting to 100
        "total_checkins": 0,  # TODO: compute from SUM(checkins_count) in user_kingdoms
        "total_conquests": 0,  # TODO: compute from kingdom_history
        "kingdoms_ruled": 0,  # TODO: compute from COUNT(*) kingdoms WHERE ruler_id = user_id
        "is_verified": user.is_verified,
        "last_login": user.last_login,
        "created_at": user.created_at,
    }


# ===== User Kingdoms =====

def get_user_kingdoms(db: Session, user_id: int) -> dict:
    """Get all kingdoms associated with a user"""
    from db.models import Kingdom
    
    # Get all user-kingdom records (visit history and stats)
    user_kingdoms = db.query(UserKingdom).filter(UserKingdom.user_id == user_id).all()
    
    # Get kingdoms where user is the ruler (source of truth)
    ruled_kingdom_ids = {
        k.id for k in db.query(Kingdom).filter(Kingdom.ruler_id == user_id).all()
    }
    
    ruled = []
    visited = []
    
    for uk in user_kingdoms:
        is_ruler = uk.kingdom_id in ruled_kingdom_ids
        
        kingdom_info = {
            "kingdom_id": uk.kingdom_id,
            "kingdom_name": uk.kingdom.name if uk.kingdom else "Unknown",
            "times_conquered": uk.times_conquered,
            "local_reputation": uk.local_reputation,
            "checkins_count": uk.checkins_count,
            "last_checkin": uk.last_checkin,
            "first_visited": uk.first_visited,
        }
        
        if is_ruler:
            ruled.append(kingdom_info)
        else:
            visited.append(kingdom_info)
    
    return {
        "ruled_kingdoms": ruled,
        "visited_kingdoms": visited,
    }


def add_experience(db: Session, user_id: int, exp_amount: int) -> User:
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
        state = PlayerState(user_id=user.id, hometown_kingdom_id=None)
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


def add_gold(db: Session, user_id: int, gold_amount: int) -> User:
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
        state = PlayerState(user_id=user.id, hometown_kingdom_id=None)
        db.add(state)
    
    state.gold += gold_amount
    db.commit()
    db.refresh(user)
    
    return user


def spend_gold(db: Session, user_id: int, gold_amount: int) -> User:
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

