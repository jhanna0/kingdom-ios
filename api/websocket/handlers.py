"""
WebSocket Lambda Handlers

These are the entry points for API Gateway WebSocket events.
Each handler corresponds to a route in serverless.yml.
"""
import os
import json
import logging
import time
from typing import Optional

from .connection_manager import (
    save_connection,
    delete_connection,
    get_connection,
    update_connection,
    broadcast_to_kingdom,
    send_to_connection
)
from .auth import extract_user_from_token

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def get_endpoint_url(event: dict) -> str:
    """Extract the WebSocket API endpoint URL from the event"""
    # Use env var (same as broadcast.py) - required for custom domains
    endpoint = os.environ.get('WEBSOCKET_API_ENDPOINT')
    if endpoint:
        return endpoint
    # Fallback for local dev
    domain = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    return f"https://{domain}/{stage}"


def response(status_code: int, body: dict = None):
    """Standard WebSocket response format"""
    return {
        'statusCode': status_code,
        'body': json.dumps(body) if body else ''
    }


# ===== $connect Handler =====

def connect_handler(event, context):
    """
    Handle new WebSocket connections.
    
    REQUIRES AUTHENTICATION - anonymous connections are rejected.
    
    Client connects with:
    - Authorization header (JWT token) - REQUIRED
    - Query params: ?kingdom_id=123
    
    Example client connection:
        wss://api.example.com/dev?kingdom_id=12345
        Headers: Authorization: Bearer <jwt_token>
    """
    connection_id = event['requestContext']['connectionId']
    
    # Extract auth from query string or headers
    query_params = event.get('queryStringParameters') or {}
    headers = event.get('headers') or {}
    
    # REQUIRE authentication
    auth_header = headers.get('Authorization') or headers.get('authorization')
    if not auth_header:
        logger.warning(f"Rejected connection {connection_id}: No auth token")
        return response(401)  # Unauthorized - closes connection
    
    user_id = extract_user_from_token(auth_header)
    if not user_id:
        logger.warning(f"Rejected connection {connection_id}: Invalid auth token")
        return response(401)  # Unauthorized - closes connection
    
    # Get kingdom from query params
    kingdom_id = query_params.get('kingdom_id', 'none')
    
    # Save connection
    success = save_connection(
        connection_id=connection_id,
        user_id=user_id,
        kingdom_id=kingdom_id,
        subscriptions=['chat']
    )
    
    if success:
        logger.info(f"Connected: {connection_id}, user={user_id}, kingdom={kingdom_id}")
        return response(200)
    else:
        logger.error(f"Failed to save connection {connection_id}")
        return response(500)


# ===== $disconnect Handler =====

def disconnect_handler(event, context):
    """
    Handle WebSocket disconnections.
    
    Clean up the connection from DynamoDB.
    """
    connection_id = event['requestContext']['connectionId']
    
    delete_connection(connection_id)
    logger.info(f"Disconnected: {connection_id}")
    
    return response(200)


# ===== $default Handler =====

def default_handler(event, context):
    """
    Handle unrecognized WebSocket message routes.
    
    Returns an error to help debug client issues.
    """
    connection_id = event['requestContext']['connectionId']
    
    body = json.loads(event.get('body', '{}'))
    action = body.get('action', 'unknown')
    
    logger.warning(f"Unknown action '{action}' from {connection_id}")
    
    # Send error back to client
    endpoint_url = get_endpoint_url(event)
    send_to_connection(endpoint_url, connection_id, {
        'type': 'error',
        'message': f"Unknown action: {action}",
        'valid_actions': ['subscribe', 'unsubscribe', 'sendMessage']
    })
    
    return response(200)


# ===== subscribe Handler =====

def subscribe_handler(event, context):
    """
    Handle subscription requests (switch kingdoms).
    
    Client sends:
    {
        "action": "subscribe",
        "kingdom_id": "12345"
    }
    """
    connection_id = event['requestContext']['connectionId']
    endpoint_url = get_endpoint_url(event)
    
    body = json.loads(event.get('body', '{}'))
    kingdom_id = body.get('kingdom_id')
    
    if not kingdom_id:
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'kingdom_id is required'
        })
        return response(400)
    
    # Get current connection state
    conn = get_connection(connection_id)
    if not conn:
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'Connection not found'
        })
        return response(400)
    
    # Update connection with new kingdom
    update_connection(
        connection_id=connection_id,
        kingdom_id=kingdom_id,
        subscriptions=['chat']
    )
    
    # Confirm to client
    send_to_connection(endpoint_url, connection_id, {
        'type': 'subscribed',
        'kingdom_id': kingdom_id
    })
    
    logger.info(f"Subscription updated: {connection_id} -> kingdom={kingdom_id}")
    return response(200)


# ===== unsubscribe Handler =====

def unsubscribe_handler(event, context):
    """
    Handle leaving a kingdom chat.
    
    Client sends:
    {
        "action": "unsubscribe"
    }
    """
    connection_id = event['requestContext']['connectionId']
    endpoint_url = get_endpoint_url(event)
    
    # Set kingdom to 'none' (disconnected from chat but still connected)
    update_connection(connection_id=connection_id, kingdom_id='none')
    
    send_to_connection(endpoint_url, connection_id, {
        'type': 'unsubscribed'
    })
    
    return response(200)


# ===== sendMessage Handler =====
# NOTE: This handler has VPC access for database lookups

def send_message_handler(event, context):
    """
    Handle chat messages.
    
    REQUIRES:
    - Valid auth token (enforced at connect)
    - User must be IN the kingdom (current_kingdom_id matches)
    
    Client sends:
    {
        "action": "sendMessage",
        "message": "Hello everyone!"
    }
    
    Server broadcasts to all connections in the same kingdom.
    """
    connection_id = event['requestContext']['connectionId']
    endpoint_url = get_endpoint_url(event)
    
    body = json.loads(event.get('body', '{}'))
    message_text = body.get('message', '')
    
    # Validate message
    if not message_text:
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'Message cannot be empty'
        })
        return response(400)
    
    if len(message_text) > 500:
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'Message too long (max 500 characters)'
        })
        return response(400)
    
    # Get sender's connection info
    conn = get_connection(connection_id)
    if not conn:
        return response(400)
    
    kingdom_id = conn.get('kingdom_id')
    user_id = conn.get('user_id')
    
    # Must be authenticated
    if not user_id or user_id == 'anonymous':
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'Authentication required'
        })
        return response(401)
    
    # Must be in a kingdom
    if not kingdom_id or kingdom_id == 'none':
        send_to_connection(endpoint_url, connection_id, {
            'type': 'error',
            'message': 'You must be in a kingdom to chat'
        })
        return response(400)
    
    # ===== DATABASE VALIDATION =====
    # Look up user and verify they're actually in this kingdom
    
    from db import get_db, User, PlayerState
    
    db = next(get_db())
    try:
        # Find user by apple_user_id (which is stored as user_id in connection)
        user = db.query(User).filter(User.apple_user_id == user_id).first()
        
        if not user:
            send_to_connection(endpoint_url, connection_id, {
                'type': 'error',
                'message': 'User not found'
            })
            return response(400)
        
        # Get player state to check current kingdom
        player_state = db.query(PlayerState).filter(PlayerState.user_id == user.id).first()
        
        if not player_state:
            send_to_connection(endpoint_url, connection_id, {
                'type': 'error',
                'message': 'Player state not found'
            })
            return response(400)
        
        # VERIFY user is actually in this kingdom
        if str(player_state.current_kingdom_id) != str(kingdom_id):
            send_to_connection(endpoint_url, connection_id, {
                'type': 'error',
                'message': 'You must be in this kingdom to chat here'
            })
            logger.warning(
                f"User {user.display_name} tried to chat in kingdom {kingdom_id} "
                f"but is in {player_state.current_kingdom_id}"
            )
            return response(403)
        
        display_name = user.display_name or "Unknown"
        
    finally:
        db.close()
    
    # Build the broadcast message
    broadcast_msg = {
        'type': 'message',
        'kingdom_id': kingdom_id,
        'sender': {
            'user_id': user_id,
            'display_name': display_name
        },
        'message': message_text,
        'timestamp': int(time.time() * 1000)
    }
    
    # Broadcast to everyone in the kingdom
    sent_count = broadcast_to_kingdom(
        endpoint_url=endpoint_url,
        kingdom_id=kingdom_id,
        message=broadcast_msg,
        channel='chat',
        exclude_connection=None  # Include sender so they see their own message
    )
    
    logger.info(f"Message from {display_name} in kingdom {kingdom_id} sent to {sent_count} connections")
    return response(200)
