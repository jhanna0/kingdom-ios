"""
Shared utilities for notifications
"""
from sqlalchemy.orm import Session
from db import User, PlayerState


def get_player_state(db: Session, user: User) -> PlayerState:
    """Get or create player state"""
    if not user.player_state:
        state = PlayerState(
            user_id=user.id,
            hometown_kingdom_id=None  # Will be set on first check-in
        )
        db.add(state)
        db.commit()
        db.refresh(state)
        return state
    return user.player_state



