"""
Apple Sign In Token Verification

Verifies Apple identity tokens by:
1. Fetching Apple's public keys from https://appleid.apple.com/auth/keys
2. Verifying the JWT signature
3. Validating claims (issuer, audience, expiration)

Reference: https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/verifying_a_user
"""
import os
from typing import Optional, Tuple

import httpx
from jose import jwt, JWTError
from fastapi import HTTPException, status


# Apple's public keys endpoint
APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"

# Your app's bundle ID (audience claim)
# This should match your iOS app's bundle identifier
APPLE_APP_ID = os.getenv("APPLE_APP_ID", "com.kingdom.app")


def get_apple_public_keys() -> dict:
    """
    Fetch Apple's public keys for JWT verification.
    
    Called on every sign-in. Apple's endpoint is fast and reliable.
    This is the only correct approach in Lambda (stateless).
    """
    try:
        response = httpx.get(APPLE_KEYS_URL, timeout=10.0)
        response.raise_for_status()
        keys_data = response.json()
        print(f"🍎 [Apple Auth] Fetched {len(keys_data.get('keys', []))} public keys from Apple")
        return keys_data
        
    except Exception as e:
        print(f"❌ [Apple Auth] Failed to fetch Apple public keys: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to verify Apple credentials. Please try again."
        )


def get_apple_public_key(kid: str) -> dict:
    """
    Get a specific public key from Apple by key ID (kid).
    """
    keys_data = get_apple_public_keys()
    
    for key in keys_data.get("keys", []):
        if key.get("kid") == kid:
            return key
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid Apple credentials - key not found"
    )


def verify_apple_identity_token(identity_token: str) -> Tuple[str, Optional[str], Optional[str]]:
    """
    Verify an Apple identity token and extract user information.
    
    Args:
        identity_token: The JWT identity token from Apple Sign In
        
    Returns:
        Tuple of (apple_user_id, email, email_verified)
        
    Raises:
        HTTPException: If token is invalid or verification fails
    """
    try:
        # Decode header to get key ID (kid)
        unverified_header = jwt.get_unverified_header(identity_token)
        kid = unverified_header.get("kid")
        
        if not kid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Apple token - missing key ID"
            )
        
        # Get the public key
        apple_key = get_apple_public_key(kid)
        
        # Verify and decode the token
        # Apple tokens use RS256 algorithm
        payload = jwt.decode(
            identity_token,
            apple_key,
            algorithms=["RS256"],
            audience=APPLE_APP_ID,
            issuer="https://appleid.apple.com",
            options={
                "verify_aud": True,
                "verify_iss": True,
                "verify_exp": True,
            }
        )
        
        # Extract user information
        apple_user_id = payload.get("sub")
        email = payload.get("email")
        email_verified = payload.get("email_verified", False)
        
        if not apple_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Apple token - missing user ID"
            )
        
        print(f"✅ [Apple Auth] Token verified successfully")
        print(f"   - apple_user_id: {apple_user_id[:20]}...")
        print(f"   - email: {email}")
        print(f"   - email_verified: {email_verified}")
        
        return apple_user_id, email, email_verified
        
    except JWTError as e:
        print(f"❌ [Apple Auth] JWT verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Apple credentials: {str(e)}"
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Apple Auth] Unexpected error verifying Apple token: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Failed to verify Apple credentials"
        )


def verify_identity_token(
    identity_token: Optional[str],
    apple_user_id: str,
    email: Optional[str] = None
) -> Tuple[str, Optional[str], Optional[bool]]:
    """
    Verify Apple/Google identity token.
    
    ALWAYS requires identity_token. No dev mode bypass.
    
    Args:
        identity_token: The JWT from Apple (REQUIRED)
        apple_user_id: Ignored - only used for error messages
        email: Ignored - extracted from verified token
        
    Returns:
        Tuple of (apple_user_id, email, email_verified)
    """
    if not identity_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identity token is required"
        )
    
    return verify_apple_identity_token(identity_token)
