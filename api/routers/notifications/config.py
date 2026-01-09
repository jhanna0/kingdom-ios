"""
Notification configuration - SINGLE SOURCE OF TRUTH for notification metadata
Frontend just renders what backend sends - no switch statements!
"""

# Notification type configurations
# icon: SF Symbol name
# color: Theme color name that frontend maps to KingdomTheme.Colors
NOTIFICATION_TYPES = {
    # Coup notifications
    "coup_vote_needed": {
        "icon": "crown.fill",
        "color": "buttonWarning"
    },
    "coup_in_progress": {
        "icon": "crown.fill",
        "color": "buttonWarning"
    },
    "coup_against_you": {
        "icon": "crown.fill",
        "color": "buttonDanger"
    },
    "coup_resolved": {
        "icon": "flag.checkered",
        "color": "inkMedium"
    },
    
    # Invasion notifications
    "invasion_against_you": {
        "icon": "exclamationmark.shield.fill",
        "color": "buttonDanger"
    },
    "ally_under_attack": {
        "icon": "handshake.fill",
        "color": "buttonWarning"
    },
    "invasion_defense_needed": {
        "icon": "shield.fill",
        "color": "buttonWarning"
    },
    "invasion_in_progress": {
        "icon": "shield.fill",
        "color": "buttonWarning"
    },
    "invasion_resolved": {
        "icon": "flag.checkered",
        "color": "inkMedium"
    },
    
    # Alliance notifications
    "alliance_request_received": {
        "icon": "handshake.fill",
        "color": "buttonSuccess"
    },
    "alliance_request_sent": {
        "icon": "paperplane.fill",
        "color": "inkMedium"
    },
    "alliance_accepted": {
        "icon": "handshake.fill",
        "color": "buttonSuccess"
    },
    "alliance_declined": {
        "icon": "xmark.circle.fill",
        "color": "inkMedium"
    },
    
    # Contract notifications
    "contract_ready": {
        "icon": "checkmark.circle.fill",
        "color": "buttonSuccess"
    },
    
    # Player notifications
    "level_up": {
        "icon": "star.fill",
        "color": "imperialGold"
    },
    "skill_points": {
        "icon": "sparkles",
        "color": "buttonPrimary"
    },
    "checkin_ready": {
        "icon": "location.fill",
        "color": "buttonPrimary"
    },
    
    # Kingdom notifications
    "treasury_full": {
        "icon": "dollarsign.circle.fill",
        "color": "imperialGold"
    },
    "kingdom_event": {
        "icon": "scroll.fill",
        "color": "inkMedium"
    },
}

# Priority configurations
PRIORITY_CONFIG = {
    "critical": {
        "color": "buttonDanger",
        "border_color": "buttonDanger"
    },
    "high": {
        "color": "buttonWarning",
        "border_color": "buttonWarning"
    },
    "medium": {
        "color": "inkMedium",
        "border_color": "inkMedium"
    },
    "low": {
        "color": "inkLight",
        "border_color": "inkLight"
    }
}


def get_notification_metadata(notification_type: str) -> dict:
    """Get icon and color for a notification type"""
    config = NOTIFICATION_TYPES.get(notification_type, {
        "icon": "bell.fill",
        "color": "inkMedium"
    })
    return config


def enrich_notification(notification: dict) -> dict:
    """Add icon and color to a notification dict based on its type"""
    metadata = get_notification_metadata(notification.get("type", ""))
    notification["icon"] = metadata["icon"]
    notification["icon_color"] = metadata["color"]
    
    # Also add priority-based colors
    priority = notification.get("priority", "medium")
    priority_config = PRIORITY_CONFIG.get(priority, PRIORITY_CONFIG["medium"])
    notification["priority_color"] = priority_config["color"]
    notification["border_color"] = priority_config["border_color"]
    
    return notification
