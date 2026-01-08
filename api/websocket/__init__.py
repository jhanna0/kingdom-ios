"""
WebSocket handlers for real-time features
- Kingdom chat rooms
- Group hunts
- Live notifications
- Battle updates

Usage from REST API:
    from websocket.broadcast import notify_kingdom, notify_user, KingdomEvents
    
    # Notify all users in a kingdom
    notify_kingdom(
        kingdom_id="12345",
        event_type=KingdomEvents.COUP_STARTED,
        data={"attacker": "PlayerName"}
    )
    
    # Notify a specific user
    notify_user(
        user_id="abc123",
        event_type=UserEvents.GOLD_RECEIVED,
        data={"amount": 100}
    )
"""

from .broadcast import (
    notify_kingdom,
    notify_user,
    notify_users,
    KingdomEvents,
    UserEvents,
    PartyEvents
)

