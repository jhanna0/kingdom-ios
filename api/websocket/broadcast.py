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

Local Development:
    When WEBSOCKET_API_ENDPOINT is not set, automatically uses the local
    in-memory WebSocket manager for real-time updates.
"""
import os
import time
import asyncio
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def is_local_mode() -> bool:
    """Check if we're running in local development mode."""
    return os.environ.get('WEBSOCKET_API_ENDPOINT') is None


def get_websocket_endpoint() -> Optional[str]:
    """
    Get the WebSocket API endpoint URL from environment.
    
    Returns None if not configured (local dev mode).
    """
    return os.environ.get('WEBSOCKET_API_ENDPOINT')


def _run_async(coro):
    """
    Run an async coroutine from sync code.
    
    Handles the case where we're called from FastAPI's event loop.
    """
    try:
        loop = asyncio.get_running_loop()
        # We're in an async context, schedule it
        return asyncio.ensure_future(coro)
    except RuntimeError:
        # No event loop, create one
        return asyncio.run(coro)


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
    message = {
        "type": "event",
        "event_type": event_type,
        "kingdom_id": kingdom_id,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    if is_local_mode():
        # Use local in-memory WebSocket manager
        from .local_manager import local_manager
        _run_async(local_manager.broadcast_to_kingdom(kingdom_id, message))
        logger.debug(f"[Local WS] Broadcast to kingdom {kingdom_id}: {event_type}")
        return 1  # Approximate - actual count is async
    
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    # Import here to avoid circular imports and cold start overhead
    from .connection_manager import broadcast_to_kingdom
    
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
    message = {
        "type": "notification",
        "event_type": event_type,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    if is_local_mode():
        from .local_manager import local_manager
        _run_async(local_manager.broadcast_to_user(str(user_id), message))
        logger.debug(f"[Local WS] Notify user {user_id}: {event_type}")
        return 1
    
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_user
    
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
    message = {
        "type": "notification",
        "event_type": event_type,
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    if is_local_mode():
        from .local_manager import local_manager
        _run_async(local_manager.broadcast_to_users([str(uid) for uid in user_ids], message))
        logger.debug(f"[Local WS] Notify {len(user_ids)} users: {event_type}")
        return len(user_ids)
    
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_multiple_users
    
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


class AllianceEvents:
    """Events broadcasted to alliance network"""
    ALLY_UNDER_ATTACK = "ally_under_attack"  # Coup or invasion started
    ALLY_BATTLE_ENDED = "ally_battle_ended"  # Battle resolved
    ALLY_RULER_CHANGED = "ally_ruler_changed"  # Ruler changed (any reason)
    ALLIANCE_FORMED = "alliance_formed"  # New alliance in network
    ALLIANCE_EXPIRED = "alliance_expired"  # Alliance ended


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
    HUNT_PLAYER_READY = "hunt_player_ready"
    HUNT_STARTED = "hunt_started"
    HUNT_PHASE_COMPLETE = "hunt_phase_complete"
    HUNT_ROLL_RESULT = "hunt_roll_result"
    HUNT_ENDED = "hunt_ended"


class DuelEvents:
    """
    Events for PvP Arena duels.
    
    The main event is DUEL_TURN_COMPLETE which contains everything:
    - Who attacked
    - The rolls and result
    - New bar position
    - Whose turn is next (or winner if game over)
    
    Frontend should just render what this event says.
    """
    DUEL_INVITATION = "duel_invitation"
    DUEL_OPPONENT_JOINED = "duel_opponent_joined"
    DUEL_STARTED = "duel_started"
    DUEL_ATTACK = "duel_attack"  # Legacy - use TURN_COMPLETE instead
    DUEL_TURN_CHANGED = "duel_turn_changed"  # Legacy
    DUEL_TURN_COMPLETE = "duel_turn_complete"  # NEW: Complete turn info for frontend
    DUEL_ENDED = "duel_ended"
    DUEL_CANCELLED = "duel_cancelled"
    DUEL_TIMEOUT = "duel_timeout"  # Player timed out


def notify_hunt_participants(
    hunt_session: dict,
    event_type: str,
    data: dict
) -> int:
    """
    Send a real-time notification to all participants in a hunt.
    
    Args:
        hunt_session: Hunt session dict (must have 'participants' key)
        event_type: Type of event (use PartyEvents constants)
        data: Event-specific data
    
    Returns:
        Total number of connections notified
    """
    # Extract participant user IDs
    participants = hunt_session.get("participants", {})
    if isinstance(participants, dict):
        user_ids = [str(pid) for pid in participants.keys()]
    else:
        user_ids = []
    
    if not user_ids:
        return 0
    
    message = {
        "type": "hunt_event",
        "event_type": event_type,
        "hunt_id": hunt_session.get("hunt_id"),
        "data": data,
        "timestamp": int(time.time() * 1000)
    }
    
    if is_local_mode():
        from .local_manager import local_manager
        _run_async(local_manager.broadcast_to_users(user_ids, message))
        logger.info(f"[Local WS] Hunt {hunt_session.get('hunt_id')}: {event_type} -> {len(user_ids)} participants")
        return len(user_ids)
    
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_multiple_users
    
    return broadcast_to_multiple_users(
        endpoint_url=endpoint,
        user_ids=user_ids,
        message=message
    )


def notify_alliance_network(
    kingdom_ids: list,
    event_type: str,
    data: dict,
    source_kingdom_id: str = None
) -> int:
    """
    Broadcast an event to multiple kingdoms (typically an alliance network).
    
    Use this to notify allies when something important happens:
    - Ally is under attack (coup/invasion)
    - Battle resolved
    - Ruler changed
    
    Args:
        kingdom_ids: List of kingdom IDs to notify
        event_type: Type of event (use AllianceEvents constants)
        data: Event-specific data
        source_kingdom_id: The kingdom where the event originated
    
    Returns:
        Total number of connections notified
    
    Example:
        # Get allied kingdom IDs (caller does DB lookup)
        allied_kingdom_ids = get_allied_kingdom_ids(db, my_empire_id)
        
        notify_alliance_network(
            kingdom_ids=allied_kingdom_ids,
            event_type=AllianceEvents.ALLY_UNDER_ATTACK,
            data={
                "kingdom_name": "San Francisco",
                "battle_type": "invasion",
                "attacker_name": "EvilRuler"
            },
            source_kingdom_id="san-francisco"
        )
    """
    if not kingdom_ids:
        return 0
    
    total_sent = 0
    for kingdom_id in kingdom_ids:
        sent = notify_kingdom(
            kingdom_id=kingdom_id,
            event_type=event_type,
            data={
                **data,
                "source_kingdom_id": source_kingdom_id,
                "is_alliance_news": True
            }
        )
        total_sent += sent
    
    logger.info(f"[Alliance News] {event_type} -> {len(kingdom_ids)} kingdoms")
    return total_sent


def broadcast_duel_event(
    event_type: str,
    match: dict,
    target_user_ids: list,
    data: dict = None
) -> int:
    """
    Send a real-time notification for duel events.
    
    Args:
        event_type: Type of event (use DuelEvents constants)
        match: Duel match dict
        target_user_ids: List of user IDs to notify
        data: Additional event-specific data
    
    Returns:
        Total number of connections notified
    """
    if not target_user_ids:
        return 0
    
    # Filter out None values from user IDs
    user_ids = [str(uid) for uid in target_user_ids if uid is not None]
    
    if not user_ids:
        return 0
    
    message = {
        "type": "duel_event",
        "event_type": event_type,
        "match_id": match.get("id") if match else None,
        "match": match,
        "data": data or {},
        "timestamp": int(time.time() * 1000)
    }
    
    if is_local_mode():
        from .local_manager import local_manager
        _run_async(local_manager.broadcast_to_users(user_ids, message))
        logger.info(f"[Local WS] Duel {match.get('id') if match else 'N/A'}: {event_type} -> {len(user_ids)} players")
        return len(user_ids)
    
    endpoint = get_websocket_endpoint()
    if not endpoint:
        return 0
    
    from .connection_manager import broadcast_to_multiple_users
    
    return broadcast_to_multiple_users(
        endpoint_url=endpoint,
        user_ids=user_ids,
        message=message
    )
