"""
Authentication endpoints - Registration, login, profile management

SECURITY MODEL:
1. Frontend sends ONLY the JWT token in Authorization header
2. Backend validates JWT signature (prevents tampering)
3. Backend extracts apple_user_id from token's 'sub' claim
4. Backend looks up user in database by apple_user_id (source of truth)
5. ALL user data comes from database, NEVER from frontend

This ensures:
- Frontend cannot forge identity (JWT is cryptographically signed)
- Frontend cannot manipulate user_id or other fields
- Database is single source of truth for all user data
- Token contains only stable identifier (apple_user_id), not mutable data
"""
from typing import Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func

from db import get_db
from db.models.user import User
from db.models.kingdom import UserKingdom, Kingdom
from utils.validation import validate_username, sanitize_username
from models.auth_schemas import (
    AppleSignIn,
    TokenResponse,
    UserProfile,
    UserPrivate,
    UserUpdate,
    UserKingdomsList,
    UserStats,
)
from services.auth_service import (
    create_user_with_apple,
    create_access_token,
    decode_access_token,
    get_user_by_id,
    update_user_profile,
    user_to_private_response,
    get_user_kingdoms,
)


router = APIRouter(prefix="/auth", tags=["authentication"])
security = HTTPBearer()


# ===== Dependency: Get Current User =====
# CRITICAL: This is the ONLY way to get authenticated user - NEVER bypass this!

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """
    Dependency to get the current authenticated user
    
    SECURITY:
    1. Extracts JWT token from Authorization header
    2. Validates JWT signature (ensures token wasn't forged)
    3. Extracts apple_user_id from token's 'sub' claim
    4. Looks up user in database (source of truth)
    5. Returns authenticated User object
    
    ALL protected endpoints MUST use this dependency to get user identity.
    NEVER accept user_id or similar from request body/params - ONLY from this dependency.
    """
    token = credentials.credentials
    payload = decode_access_token(token)  # Validates signature!
    
    apple_user_id = payload.get("sub")
    if not apple_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    # Look up user by apple_user_id (stable identifier, survives DB migrations)
    # EAGER LOAD player_state to avoid N+1 query and improve /auth/me performance
    from sqlalchemy.orm import joinedload
    user = db.query(User).options(joinedload(User.player_state)).filter(User.apple_user_id == apple_user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive"
        )
    
    print(f"🔐 [get_current_user] User authenticated:")
    print(f"   - user.id: {user.id}")
    print(f"   - apple_user_id: {apple_user_id}")
    print(f"   - player_state loaded: {user.player_state is not None}")
    if user.player_state:
        print(f"   - player_state.hometown_kingdom_id: {user.player_state.hometown_kingdom_id}")
    
    return user


def get_current_user_optional(
    db: Session = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
) -> Optional[User]:
    """
    Optional authentication - returns User if authenticated, None if not
    Use for endpoints that behave differently for authenticated users but don't require auth
    """
    if not credentials:
        return None
    
    try:
        token = credentials.credentials
        payload = decode_access_token(token)
        apple_user_id = payload.get("sub")
        
        if not apple_user_id:
            return None
        
        # EAGER LOAD player_state for better performance
        from sqlalchemy.orm import joinedload
        user = db.query(User).options(joinedload(User.player_state)).filter(User.apple_user_id == apple_user_id).first()
        if not user or not user.is_active:
            return None
        
        return user
    except:
        return None


# ===== Apple Sign In =====

@router.post("/apple-signin", response_model=TokenResponse)
def apple_signin(apple_data: AppleSignIn, db: Session = Depends(get_db)):
    """
    Sign in with Apple
    
    Creates a new account if this is the first time, or logs in existing user
    """
    print(f"\n{'='*80}")
    print(f"🍎 [POST /auth/apple-signin] Request received")
    print(f"{'='*80}\n")
    
    user = create_user_with_apple(db, apple_data)
    
    # Generate token with apple_user_id (stable identifier)
    access_token = create_access_token(data={"sub": user.apple_user_id})
    
    print(f"\n✅ [POST /auth/apple-signin] Token generated for user_id={user.id}")
    print(f"{'='*80}\n")
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=60 * 60 * 24 * 7  # 7 days
    )


# ===== User Profile =====

@router.get("/me", response_model=UserPrivate)
def get_my_profile(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current user's private profile
    
    Includes sensitive information like email, gold, etc.
    Also updates last_login for online status tracking.
    """
    from datetime import datetime
    
    # Update last_login for online status (called on every app load)
    current_user.last_login = datetime.utcnow()
    db.commit()
    
    response = user_to_private_response(current_user)
    return response




@router.put("/me", response_model=UserPrivate)
def update_my_profile(
    updates: UserUpdate,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update current user's profile"""
    
    # Convert to dict and filter out None values
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}
    
    user = update_user_profile(db, current_user.id, update_data)
    return user_to_private_response(user)


@router.patch("/me", response_model=UserPrivate)
def patch_my_profile(
    updates: UserUpdate,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Partially update current user's profile (PATCH)"""
    
    print(f"\n{'='*80}")
    print(f"🔄 [PATCH /auth/me] Request received:")
    print(f"   - current_user.id: {current_user.id}")
    print(f"   - current_user.display_name: {current_user.display_name}")
    print(f"   - updates raw: {updates}")
    print(f"{'='*80}\n")
    
    # Convert to dict and filter out None values
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}
    
    print(f"📦 [PATCH /auth/me] Filtered update_data: {update_data}")
    
    user = update_user_profile(db, current_user.id, update_data)
    
    response = user_to_private_response(user)
    print(f"\n✅ [PATCH /auth/me] Response prepared:")
    print(f"   - hometown_kingdom_id in response: {response.get('hometown_kingdom_id')}")
    print(f"{'='*80}\n")
    
    return response




# ===== User Kingdoms =====

@router.get("/me/kingdoms", response_model=UserKingdomsList)
def get_my_kingdoms(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all kingdoms associated with the current user
    
    Includes:
    - Kingdoms they currently rule
    - Kingdoms where they are a subject
    - Kingdoms they've visited
    """
    kingdoms_data = get_user_kingdoms(db, current_user.id)
    return UserKingdomsList(**kingdoms_data)


@router.get("/me/stats", response_model=UserStats)
def get_my_stats(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get detailed statistics for current user"""
    
    state = current_user.player_state
    
    # Get total checkins across all kingdoms from user_kingdoms table
    from sqlalchemy import func
    total_checkins = db.query(func.sum(UserKingdom.checkins_count)).filter(
        UserKingdom.user_id == current_user.id
    ).scalar() or 0
    
    # Get reputation from hometown kingdom (or 0 if not available)
    # NOTE: Reputation is now per-kingdom in user_kingdoms table (convert float to int)
    hometown_reputation = 0
    if state and state.hometown_kingdom_id:
        user_kingdom = db.query(UserKingdom).filter(
            UserKingdom.user_id == current_user.id,
            UserKingdom.kingdom_id == state.hometown_kingdom_id
        ).first()
        hometown_reputation = int(user_kingdom.local_reputation) if user_kingdom else 0
    
    return UserStats(
        user_id=current_user.id,
        username=current_user.display_name,  # Use display_name as username
        display_name=current_user.display_name,
        total_conquests=state.total_conquests if state else 0,
        kingdoms_ruled=state.kingdoms_ruled if state else 0,
        current_kingdoms_count=state.kingdoms_ruled if state else 0,
        total_checkins=total_checkins,
        gold=state.gold if state else 0,
        reputation=hometown_reputation,
        level=state.level if state else 1,
        experience=state.experience if state else 0,
    )


# ===== Account Management =====

@router.delete("/me")
def delete_my_account(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete current user's account
    
    This is a soft delete - sets is_active to False
    """
    current_user.is_active = False
    db.commit()
    
    return {"message": "Account deleted successfully"}


# ===== Username Change =====

USERNAME_CHANGE_COOLDOWN_DAYS = 30


class UsernameStatusResponse(BaseModel):
    """Username change status"""
    current_username: str
    can_change: bool
    is_ruler: bool
    days_until_available: int
    cooldown_days: int = USERNAME_CHANGE_COOLDOWN_DAYS
    last_changed: Optional[datetime] = None
    message: Optional[str] = None


class UsernameChangeRequest(BaseModel):
    """Request to change username"""
    new_username: str


class UsernameChangeResponse(BaseModel):
    """Response after username change"""
    success: bool
    new_username: str
    message: str
    next_change_available: datetime


@router.get("/username", response_model=UsernameStatusResponse)
def get_username_status(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current username and change eligibility status.
    
    Rules:
    - Must be a subscriber
    - Rulers cannot change their username (their name is public)
    - Non-rulers can change once every 30 days
    """
    from routers.store import is_user_subscriber
    
    # Check subscriber status first
    if not is_user_subscriber(db, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Username changes are a subscriber-only feature."
        )
    
    # Check if user is a ruler of any kingdom
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).count()
    is_ruler = ruled_kingdoms > 0
    
    # Calculate cooldown status
    can_change = True
    days_until_available = 0
    message = None
    
    if is_ruler:
        can_change = False
        message = "Rulers cannot change their username."
    elif current_user.last_username_change:
        cooldown_end = current_user.last_username_change + timedelta(days=USERNAME_CHANGE_COOLDOWN_DAYS)
        if datetime.utcnow() < cooldown_end:
            can_change = False
            days_until_available = (cooldown_end - datetime.utcnow()).days + 1
            message = f"You can change your username again in {days_until_available} days."
    
    return UsernameStatusResponse(
        current_username=current_user.display_name,
        can_change=can_change,
        is_ruler=is_ruler,
        days_until_available=days_until_available,
        last_changed=current_user.last_username_change,
        message=message
    )


@router.put("/username", response_model=UsernameChangeResponse)
def change_username(
    request: UsernameChangeRequest,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Change the current user's username.
    
    Rules:
    - Must be a subscriber
    - Rulers cannot change their username
    - Must wait 30 days between changes
    - Username must be 3-20 characters
    - Only letters, numbers, and single spaces allowed
    - Username must be unique (case-insensitive)
    """
    from routers.store import is_user_subscriber
    
    # Check subscriber status first
    if not is_user_subscriber(db, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Username changes are a subscriber-only feature."
        )
    
    # Check if user is a ruler
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == current_user.id).count()
    if ruled_kingdoms > 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Rulers cannot change their username. Your name is known throughout the realm!"
        )
    
    # Check cooldown
    if current_user.last_username_change:
        cooldown_end = current_user.last_username_change + timedelta(days=USERNAME_CHANGE_COOLDOWN_DAYS)
        if datetime.utcnow() < cooldown_end:
            days_left = (cooldown_end - datetime.utcnow()).days + 1
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"You can change your username again in {days_left} days."
            )
    
    # Sanitize and validate new username
    new_username = sanitize_username(request.new_username)
    is_valid, error_msg = validate_username(new_username)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_msg
        )
    
    # Check if username is taken (case-insensitive)
    existing = db.query(User).filter(
        func.lower(User.display_name) == func.lower(new_username),
        User.id != current_user.id
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"The name '{new_username}' is already taken."
        )
    
    # Update username
    old_username = current_user.display_name
    current_user.display_name = new_username
    current_user.last_username_change = datetime.utcnow()
    current_user.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(current_user)
    
    next_change = current_user.last_username_change + timedelta(days=USERNAME_CHANGE_COOLDOWN_DAYS)
    
    print(f"📝 [USERNAME] User {current_user.id} changed name: '{old_username}' -> '{new_username}'")
    
    return UsernameChangeResponse(
        success=True,
        new_username=new_username,
        message=f"Your name has been changed to '{new_username}'!",
        next_change_available=next_change
    )


# ===== Health Check =====

@router.get("/health")
def auth_health():
    """Check if auth service is working"""
    return {"status": "ok", "service": "authentication"}


# ===== Client Debug Logging =====

from pydantic import BaseModel

class ClientLogRequest(BaseModel):
    """Client-side log entry for debugging"""
    step: str  # e.g., "signInWithApple_start", "signInWithApple_token_received"
    message: str
    device_id: Optional[str] = None
    extra: Optional[dict] = None

@router.post("/client-log")
def client_log(log_entry: ClientLogRequest):
    """
    Receive debug logs from iOS client during sign-up flow.
    
    This helps debug crashes that happen before the user is fully authenticated.
    No authentication required since it's used during sign-up.
    """
    device_info = f"[device:{log_entry.device_id}]" if log_entry.device_id else ""
    extra_info = f" | extra: {log_entry.extra}" if log_entry.extra else ""
    
    print(f"📱 [CLIENT LOG] {device_info} [{log_entry.step}] {log_entry.message}{extra_info}")
    
    return {"status": "logged"}


# ===== Demo Login for App Review =====

from config import DEMO_LOGIN_SECRET

class DemoLoginRequest(BaseModel):
    """Demo login request for App Store review"""
    secret: str

@router.post("/demo-login", response_model=TokenResponse)
def demo_login(request: DemoLoginRequest, db: Session = Depends(get_db)):
    """
    Demo login for App Store reviewers.
    
    Logs into a pre-seeded demo account without requiring Apple Sign In.
    Protected by a secret code provided in App Review notes.
    """
    if request.secret != DEMO_LOGIN_SECRET:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid demo code"
        )
    
    # Find or create the demo user
    demo_apple_id = "demo_reviewer_account"
    user = db.query(User).filter(User.apple_user_id == demo_apple_id).first()
    
    if not user:
        # Create demo user with pre-seeded content
        from db.models.player_state import PlayerState
        
        user = User(
            email="demo@review.apple.com",
            apple_user_id=demo_apple_id,
            display_name="AppleReviewer",
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        db.flush()
        
        # Create player state with good starting resources
        player_state = PlayerState(
            user_id=user.id,
            hometown_kingdom_id=None,
            gold=5000,
            level=5,
            experience=0,
            attack_power=3,
            defense_power=3,
            leadership=2,
            building_skill=2,
        )
        db.add(player_state)
        db.commit()
        db.refresh(user)
        
        print(f"✅ [DEMO] Created demo user: user_id={user.id}")
    else:
        print(f"✅ [DEMO] Existing demo user: user_id={user.id}")
    
    # Generate token
    access_token = create_access_token(data={"sub": user.apple_user_id})
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=60 * 60 * 24 * 7
    )


