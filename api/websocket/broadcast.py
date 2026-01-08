"""
Broadcast Utilities for REST API Integration

Use these functions from your REST API handlers to push real-time
updates to connected WebSocket clients.

Example usage in a router:
    from websocket.broadcast import notify_kingdom, notify_user
    
    @router.post("/coups/{kingdom_id}/start")
    def start_coup(...):
        # ... start coup logic ...
        
        # Push real-time notification
        notify_kingdom(
            kingdom_id=kingdom_id,
            event_type="coup_started",
            data={"attacker": user.display_name, "coup_id": coup.id}
        )
"""
import os
import time
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def get_websocket_endpoint() -> Optional[str]:
    """
    Get the WebSocket API endpoint URL from environment.
    
    Returns None if not configured (local dev without WebSocket).
    """
    endpoint = os.environ.get('WEBSOCKET_API_ENDPOINT')
    
    if not endpoint:
        logger.debug("WEBSOCKET_API_ENDPOINT not set, skipping real-time notifications")
        return None
    
    return endpoint


def notify_kingdom(
    kingdom_id: str,
    event_type: str,
    data: dict,
    channel: str = "notifications"
) -> int:
    """
    Send a real-time notification to all users in a kingdom.
    
    Args:
        kingdom_id: Target kingdom
        event_type: Type of event (e.g., "coup_started", "contract_completed")
        data: Event-specific data
        channel: Which subscription channel (default: "notifications")
    
    Returns:
        Number of connections notified (0 if WebSocket not configured)
    
    Example:
        notify_kingdom(
            kingdom_id="12345",
            event_type="building_upgraded",
            data={
                "building_type": "wall",
                "new_level": 3,
                "upgraded_by": "PlayerName"
            }
        )
    """
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    # Import here to avoid circular imports and cold start overhead
    from .connection_manager import broadcast_to_kingdom
    
    message = {
        "type": "event",
        "event_type": event_type,
        "kingdom_id": kingdom_id,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    return broadcast_to_kingdom(
        endpoint_url=endpoint,
        kingdom_id=kingdom_id,
        message=message,
        channel=channel
    )


def notify_user(
    user_id: str,
    event_type: str,
    data: dict
) -> int:
    """
    Send a real-time notification to a specific user (all their devices).
    
    Args:
        user_id: Target user's ID
        event_type: Type of event
        data: Event-specific data
    
    Returns:
        Number of connections notified
    
    Example:
        notify_user(
            user_id="abc123",
            event_type="gold_received",
            data={"amount": 100, "from": "contract_reward"}
        )
    """
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_user
    
    message = {
        "type": "notification",
        "event_type": event_type,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    return broadcast_to_user(
        endpoint_url=endpoint,
        user_id=user_id,
        message=message
    )


def notify_users(
    user_ids: list,
    event_type: str,
    data: dict
) -> int:
    """
    Send a notification to multiple specific users.
    
    Useful for:
    - Party notifications (group hunts)
    - Alliance announcements
    - Battle participant updates
    
    Args:
        user_ids: List of user IDs to notify
        event_type: Type of event
        data: Event-specific data
    
    Returns:
        Total number of connections notified
    """
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_multiple_users
    
    message = {
        "type": "notification",
        "event_type": event_type,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    return broadcast_to_multiple_users(
        endpoint_url=endpoint,
        user_ids=user_ids,
        message=message
    )


# ===== Event Type Constants =====
# Define your event types here for consistency

class KingdomEvents:
    """Events broadcasted to everyone in a kingdom"""
    CHAT_MESSAGE = "chat_message"
    COUP_STARTED = "coup_started"
    COUP_ENDED = "coup_ended"
    INVASION_STARTED = "invasion_started"
    INVASION_ENDED = "invasion_ended"
    BUILDING_UPGRADED = "building_upgraded"
    CONTRACT_POSTED = "contract_posted"
    CONTRACT_COMPLETED = "contract_completed"
    RULER_CHANGED = "ruler_changed"
    PLAYER_JOINED = "player_joined"
    PLAYER_LEFT = "player_left"


class UserEvents:
    """Events sent to specific users"""
    GOLD_RECEIVED = "gold_received"
    GOLD_SPENT = "gold_spent"
    LEVEL_UP = "level_up"
    SKILL_TRAINED = "skill_trained"
    ITEM_RECEIVED = "item_received"
    CONTRACT_REWARD = "contract_reward"
    COUP_VOTE_NEEDED = "coup_vote_needed"
    FRIEND_REQUEST = "friend_request"
    ALLIANCE_INVITE = "alliance_invite"


class PartyEvents:
    """Events for group activities (hunts, raids, etc.)"""
    HUNT_LOBBY_CREATED = "hunt_lobby_created"
    HUNT_PLAYER_JOINED = "hunt_player_joined"
    HUNT_PLAYER_LEFT = "hunt_player_left"
    HUNT_STARTED = "hunt_started"
    HUNT_PHASE_CHANGED = "hunt_phase_changed"
    HUNT_ROLL_RESULT = "hunt_roll_result"
    HUNT_ENDED = "hunt_ended"

