"""
Identity Token Verification (Apple & Google)

Verifies identity tokens from Apple Sign In and Google Sign In by:
1. Auto-detecting the provider from the JWT's issuer claim
2. Fetching the provider's public keys
3. Verifying the JWT signature
4. Validating claims (issuer, audience, expiration)

References:
- Apple: https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/verifying_a_user
- Google: https://developers.google.com/identity/sign-in/android/backend-auth
"""
import os
from typing import Optional, Tuple

import httpx
from jose import jwt, JWTError
from fastapi import HTTPException, status


# ===== Apple Configuration =====
APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
# Your app's bundle ID (audience claim) - should match iOS app's bundle identifier
APPLE_APP_ID = os.getenv("APPLE_APP_ID", "com.kingdom.app")

# ===== Google Configuration =====
GOOGLE_KEYS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"]
# Web OAuth client ID from Google Cloud Console (used by Android app)
GOOGLE_CLIENT_ID = os.getenv(
    "GOOGLE_CLIENT_ID",
    "488870387298-8idlf5hsu0no8j20h13n4totg2u6mat6.apps.googleusercontent.com"
)


def get_public_keys(keys_url: str, provider: str) -> dict:
    """
    Fetch public keys for JWT verification from a provider.
    
    Called on every sign-in. Provider endpoints are fast and reliable.
    This is the only correct approach in Lambda (stateless).
    """
    try:
        response = httpx.get(keys_url, timeout=10.0)
        response.raise_for_status()
        keys_data = response.json()
        print(f"🔐 [{provider} Auth] Fetched {len(keys_data.get('keys', []))} public keys")
        return keys_data
        
    except Exception as e:
        print(f"❌ [{provider} Auth] Failed to fetch public keys: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Unable to verify {provider} credentials. Please try again."
        )


def get_apple_public_keys() -> dict:
    """Fetch Apple's public keys for JWT verification."""
    return get_public_keys(APPLE_KEYS_URL, "Apple")


def get_google_public_keys() -> dict:
    """Fetch Google's public keys for JWT verification."""
    return get_public_keys(GOOGLE_KEYS_URL, "Google")


def get_public_key_by_kid(keys_data: dict, kid: str, provider: str) -> dict:
    """
    Get a specific public key by key ID (kid) from a provider's keys.
    """
    for key in keys_data.get("keys", []):
        if key.get("kid") == kid:
            return key
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=f"Invalid {provider} credentials - key not found"
    )


def get_apple_public_key(kid: str) -> dict:
    """Get a specific public key from Apple by key ID (kid)."""
    keys_data = get_apple_public_keys()
    return get_public_key_by_kid(keys_data, kid, "Apple")


def get_google_public_key(kid: str) -> dict:
    """Get a specific public key from Google by key ID (kid)."""
    keys_data = get_google_public_keys()
    return get_public_key_by_kid(keys_data, kid, "Google")


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


def verify_google_identity_token(identity_token: str) -> Tuple[str, Optional[str], Optional[str]]:
    """
    Verify a Google identity token and extract user information.
    
    Args:
        identity_token: The JWT identity token from Google Sign In
        
    Returns:
        Tuple of (google_user_id, email, email_verified)
        
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
                detail="Invalid Google token - missing key ID"
            )
        
        # Get the public key
        google_key = get_google_public_key(kid)
        
        # Verify and decode the token
        # Google tokens use RS256 algorithm
        payload = jwt.decode(
            identity_token,
            google_key,
            algorithms=["RS256"],
            audience=GOOGLE_CLIENT_ID,
            issuer=GOOGLE_ISSUERS,  # jose library accepts list of valid issuers
            options={
                "verify_aud": True,
                "verify_iss": True,
                "verify_exp": True,
            }
        )
        
        # Extract user information
        google_user_id = payload.get("sub")
        email = payload.get("email")
        email_verified = payload.get("email_verified", False)
        
        if not google_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token - missing user ID"
            )
        
        print(f"✅ [Google Auth] Token verified successfully")
        print(f"   - google_user_id: {google_user_id[:20]}...")
        print(f"   - email: {email}")
        print(f"   - email_verified: {email_verified}")
        
        return google_user_id, email, email_verified
        
    except JWTError as e:
        print(f"❌ [Google Auth] JWT verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google credentials: {str(e)}"
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Google Auth] Unexpected error verifying Google token: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Failed to verify Google credentials"
        )


def detect_token_provider(identity_token: str) -> str:
    """
    Detect the identity provider from a JWT token's issuer claim.
    
    Returns:
        "apple" or "google"
        
    Raises:
        HTTPException: If provider is unknown
    """
    try:
        # Peek at unverified claims to determine provider
        unverified_claims = jwt.get_unverified_claims(identity_token)
        issuer = unverified_claims.get("iss", "")
        
        if issuer == APPLE_ISSUER:
            return "apple"
        elif issuer in GOOGLE_ISSUERS:
            return "google"
        else:
            print(f"❌ [Auth] Unknown identity provider issuer: {issuer}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Unknown identity provider: {issuer}"
            )
    except JWTError as e:
        print(f"❌ [Auth] Failed to decode token for provider detection: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid identity token format"
        )


def verify_identity_token(
    identity_token: Optional[str],
    apple_user_id: str,
    email: Optional[str] = None
) -> Tuple[str, Optional[str], Optional[bool]]:
    """
    Verify Apple or Google identity token (auto-detected from JWT issuer).
    
    ALWAYS requires identity_token. No dev mode bypass.
    
    Args:
        identity_token: The JWT from Apple or Google (REQUIRED)
        apple_user_id: Ignored - only used for error messages (user ID extracted from token)
        email: Ignored - extracted from verified token
        
    Returns:
        Tuple of (user_id, email, email_verified)
    """
    if not identity_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identity token is required"
        )
    
    # Auto-detect provider from token's issuer claim
    provider = detect_token_provider(identity_token)
    print(f"🔐 [Auth] Detected provider: {provider}")
    
    if provider == "apple":
        return verify_apple_identity_token(identity_token)
    elif provider == "google":
        return verify_google_identity_token(identity_token)
    else:
        # Should never reach here due to detect_token_provider validation
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unsupported identity provider"
        )
