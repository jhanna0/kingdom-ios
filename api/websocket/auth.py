"""
WebSocket Authentication Helper

Extracts user identity from JWT tokens for WebSocket connections.
Similar to auth_service but returns None instead of raising exceptions.
"""
import os
import logging
from typing import Optional
from jose import JWTError, jwt

logger = logging.getLogger(__name__)

# JWT configuration (same as auth_service.py)
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-this-in-production")
ALGORITHM = "HS256"


def extract_user_from_token(auth_header: str) -> Optional[str]:
    """
    Extract user ID from Authorization header.
    
    Args:
        auth_header: The Authorization header value (e.g., "Bearer eyJ...")
    
    Returns:
        The user's apple_user_id (sub claim) or None if invalid/missing
    """
    if not auth_header:
        return None
    
    # Handle "Bearer <token>" format
    if auth_header.startswith("Bearer "):
        token = auth_header.split(" ", 1)[1]
    else:
        token = auth_header
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        
        if user_id:
            logger.debug(f"Authenticated WebSocket user: {user_id}")
            return user_id
        
        return None
        
    except JWTError as e:
        logger.warning(f"Invalid JWT token in WebSocket connection: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error decoding WebSocket JWT: {e}")
        return None


def validate_kingdom_access(user_id: str, kingdom_id: str) -> bool:
    """
    Check if a user can access a kingdom's chat.
    
    For now, anyone can join any kingdom's chat if they're authenticated.
    In the future, you might want to:
    - Require the user to have visited the kingdom
    - Require minimum reputation
    - Check if kingdom is private/alliance-only
    
    Returns:
        True if access is allowed
    """
    # TODO: Add access control logic if needed
    return True

