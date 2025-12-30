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
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from db import get_db
from db.models.user import User
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
    user = db.query(User).filter(User.apple_user_id == apple_user_id).first()
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
        
        user = db.query(User).filter(User.apple_user_id == apple_user_id).first()
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
    user = create_user_with_apple(db, apple_data)
    
    # Generate token with apple_user_id (stable identifier)
    access_token = create_access_token(data={"sub": user.apple_user_id})
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=60 * 60 * 24 * 7  # 7 days
    )


# ===== User Profile =====

@router.get("/me", response_model=UserPrivate)
def get_my_profile(current_user = Depends(get_current_user)):
    """
    Get current user's private profile
    
    Includes sensitive information like email, gold, etc.
    """
    return user_to_private_response(current_user)




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
    
    # Convert to dict and filter out None values
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}
    
    user = update_user_profile(db, current_user.id, update_data)
    return user_to_private_response(user)




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
def get_my_stats(current_user = Depends(get_current_user)):
    """Get detailed statistics for current user"""
    
    state = current_user.player_state
    return UserStats(
        user_id=current_user.id,
        username=current_user.display_name,  # Use display_name as username
        display_name=current_user.display_name,
        total_conquests=state.total_conquests if state else 0,
        kingdoms_ruled=state.kingdoms_ruled if state else 0,
        current_kingdoms_count=state.kingdoms_ruled if state else 0,
        total_checkins=state.total_checkins if state else 0,
        gold=state.gold if state else 0,
        reputation=state.reputation if state else 0,
        honor=state.honor if state else 100,
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


# ===== Health Check =====

@router.get("/health")
def auth_health():
    """Check if auth service is working"""
    return {"status": "ok", "service": "authentication"}

