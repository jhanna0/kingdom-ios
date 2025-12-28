"""
Authentication endpoints - Registration, login, profile management
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from database import get_db
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

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Dependency to get the current authenticated user"""
    token = credentials.credentials
    payload = decode_access_token(token)
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    user = get_user_by_id(db, user_id)
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


# ===== Apple Sign In =====

@router.post("/apple-signin", response_model=TokenResponse)
def apple_signin(apple_data: AppleSignIn, db: Session = Depends(get_db)):
    """
    Sign in with Apple
    
    Creates a new account if this is the first time, or logs in existing user
    """
    user = create_user_with_apple(db, apple_data)
    
    # Generate token
    access_token = create_access_token(data={"sub": user.id})
    
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
    
    return UserStats(
        user_id=current_user.id,
        username=current_user.display_name,  # Use display_name as username
        display_name=current_user.display_name,
        total_conquests=current_user.total_conquests,
        kingdoms_ruled=current_user.kingdoms_ruled,
        current_kingdoms_count=current_user.kingdoms_ruled,  # TODO: Calculate actual current count
        total_checkins=current_user.total_checkins,
        gold=current_user.gold,
        reputation=current_user.reputation,
        honor=current_user.honor,
        level=current_user.level,
        experience=current_user.experience,
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

