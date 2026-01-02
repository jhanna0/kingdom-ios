"""
Validation utilities for user input
"""
import re
from typing import Tuple


def validate_username(username: str) -> Tuple[bool, str]:
    """
    Validate username according to rules:
    - 3-20 characters after trimming
    - Only letters, numbers, and single spaces (no consecutive spaces)
    - Strip leading/trailing whitespace
    - No special characters
    
    Returns:
        Tuple of (is_valid, error_message)
        If valid, error_message is empty string
    """
    if not username:
        return False, "Username cannot be empty"
    
    # Strip leading/trailing whitespace
    username = username.strip()
    
    # Check length (3-20 characters)
    if len(username) < 3:
        return False, "Username must be at least 3 characters long"
    
    if len(username) > 20:
        return False, "Username must be no more than 20 characters long"
    
    # Check for consecutive spaces
    if "  " in username:
        return False, "Username cannot have consecutive spaces"
    
    # Check for only letters, numbers, and single spaces
    # Pattern: start with alphanumeric, can have single spaces between words, end with alphanumeric
    if not re.match(r'^[a-zA-Z0-9]+( [a-zA-Z0-9]+)*$', username):
        return False, "Username can only contain letters, numbers, and single spaces between words"
    
    return True, ""


def sanitize_username(username: str) -> str:
    """
    Sanitize username by:
    - Stripping leading/trailing whitespace
    - Replacing consecutive spaces with single space
    
    Returns:
        Sanitized username string
    """
    if not username:
        return ""
    
    # Strip leading/trailing whitespace
    username = username.strip()
    
    # Replace consecutive spaces with single space
    username = re.sub(r'\s+', ' ', username)
    
    return username

