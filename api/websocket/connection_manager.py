"""
Connection Manager - DynamoDB-backed WebSocket connection tracking

This is the core infrastructure for all real-time features.
Handles connection lifecycle and provides broadcast utilities.
"""
import os
import json
import time
import logging
from typing import Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

# Initialize clients
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('CONNECTIONS_TABLE', 'kingdom-api-connections-dev')


def get_table():
    """Get the connections DynamoDB table"""
    return dynamodb.Table(TABLE_NAME)


def get_api_gateway_client(endpoint_url: str):
    """
    Get API Gateway Management API client for sending messages.
    
    Args:
        endpoint_url: The WebSocket API endpoint (e.g., https://abc123.execute-api.us-east-1.amazonaws.com/dev)
    """
    return boto3.client(
        'apigatewaymanagementapi',
        endpoint_url=endpoint_url
    )


# ===== Connection Lifecycle =====

def save_connection(
    connection_id: str,
    user_id: Optional[str] = None,
    kingdom_id: Optional[str] = None,
    subscriptions: Optional[list] = None
) -> bool:
    """
    Save a new WebSocket connection to DynamoDB.
    
    Args:
        connection_id: The WebSocket connection ID from API Gateway
        user_id: The authenticated user's ID (from JWT)
        kingdom_id: The kingdom the user is currently in
        subscriptions: List of channels to subscribe to (e.g., ["chat", "notifications"])
    
    Returns:
        True if successful, False otherwise
    """
    table = get_table()
    
    # TTL: 24 hours from now (cleanup stale connections)
    ttl = int(time.time()) + 86400
    
    item = {
        'connection_id': connection_id,
        'user_id': user_id or 'anonymous',
        'kingdom_id': kingdom_id or 'none',
        'subscriptions': subscriptions or ['chat'],  # Default to chat
        'connected_at': int(time.time()),
        'ttl': ttl
    }
    
    try:
        table.put_item(Item=item)
        logger.info(f"Saved connection {connection_id} for user {user_id} in kingdom {kingdom_id}")
        return True
    except ClientError as e:
        logger.error(f"Failed to save connection: {e}")
        return False


def delete_connection(connection_id: str) -> bool:
    """
    Remove a WebSocket connection from DynamoDB.
    
    Called on $disconnect or when sending a message fails (stale connection).
    """
    table = get_table()
    
    try:
        table.delete_item(Key={'connection_id': connection_id})
        logger.info(f"Deleted connection {connection_id}")
        return True
    except ClientError as e:
        logger.error(f"Failed to delete connection: {e}")
        return False


def get_connection(connection_id: str) -> Optional[dict]:
    """Get a connection's details"""
    table = get_table()
    
    try:
        response = table.get_item(Key={'connection_id': connection_id})
        return response.get('Item')
    except ClientError as e:
        logger.error(f"Failed to get connection: {e}")
        return None


def update_connection(
    connection_id: str,
    kingdom_id: Optional[str] = None,
    subscriptions: Optional[list] = None
) -> bool:
    """
    Update a connection's kingdom or subscriptions.
    
    Called when:
    - User travels to a new kingdom
    - User subscribes/unsubscribes from channels
    """
    table = get_table()
    
    update_expr = "SET "
    expr_values = {}
    expr_names = {}
    
    if kingdom_id is not None:
        update_expr += "#k = :k, "
        expr_values[':k'] = kingdom_id
        expr_names['#k'] = 'kingdom_id'
    
    if subscriptions is not None:
        update_expr += "#s = :s, "
        expr_values[':s'] = subscriptions
        expr_names['#s'] = 'subscriptions'
    
    # Update TTL
    update_expr += "ttl = :ttl"
    expr_values[':ttl'] = int(time.time()) + 86400
    
    try:
        table.update_item(
            Key={'connection_id': connection_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names if expr_names else None
        )
        return True
    except ClientError as e:
        logger.error(f"Failed to update connection: {e}")
        return False


# ===== Query Connections =====

def get_kingdom_connections(kingdom_id: str, subscription_filter: Optional[str] = None) -> list:
    """
    Get all connections in a kingdom.
    
    Args:
        kingdom_id: The kingdom to query
        subscription_filter: Optional - only return connections subscribed to this channel
    
    Returns:
        List of connection items
    """
    table = get_table()
    
    try:
        response = table.query(
            IndexName='kingdom-index',
            KeyConditionExpression='kingdom_id = :k',
            ExpressionAttributeValues={':k': kingdom_id}
        )
        
        connections = response.get('Items', [])
        
        # Filter by subscription if specified
        if subscription_filter:
            connections = [
                c for c in connections
                if subscription_filter in c.get('subscriptions', [])
            ]
        
        return connections
    except ClientError as e:
        logger.error(f"Failed to query kingdom connections: {e}")
        return []


def get_user_connections(user_id: str) -> list:
    """
    Get all connections for a specific user.
    
    Useful for:
    - Direct messages
    - Personal notifications
    - Detecting if user is online
    """
    table = get_table()
    
    try:
        response = table.query(
            IndexName='user-index',
            KeyConditionExpression='user_id = :u',
            ExpressionAttributeValues={':u': user_id}
        )
        return response.get('Items', [])
    except ClientError as e:
        logger.error(f"Failed to query user connections: {e}")
        return []


# ===== Message Sending =====

def send_to_connection(endpoint_url: str, connection_id: str, message: dict) -> bool:
    """
    Send a message to a specific WebSocket connection.
    
    Args:
        endpoint_url: The WebSocket API endpoint
        connection_id: Target connection ID
        message: Dict to send (will be JSON encoded)
    
    Returns:
        True if successful, False if connection is stale
    """
    client = get_api_gateway_client(endpoint_url)
    
    try:
        client.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message).encode('utf-8')
        )
        return True
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == 'GoneException':
            # Connection is stale, clean it up
            logger.info(f"Stale connection {connection_id}, removing")
            delete_connection(connection_id)
        else:
            logger.error(f"Failed to send to {connection_id}: {e}")
        return False


def broadcast_to_kingdom(
    endpoint_url: str,
    kingdom_id: str,
    message: dict,
    channel: str = 'chat',
    exclude_connection: Optional[str] = None
) -> int:
    """
    Broadcast a message to all connections in a kingdom.
    
    This is the main broadcast function for kingdom-scoped events.
    
    Args:
        endpoint_url: The WebSocket API endpoint
        kingdom_id: Target kingdom
        message: Dict to broadcast
        channel: Only send to connections subscribed to this channel
        exclude_connection: Optional connection to skip (e.g., the sender)
    
    Returns:
        Number of connections that received the message
    """
    connections = get_kingdom_connections(kingdom_id, subscription_filter=channel)
    
    sent_count = 0
    for conn in connections:
        conn_id = conn['connection_id']
        
        # Skip excluded connection
        if exclude_connection and conn_id == exclude_connection:
            continue
        
        if send_to_connection(endpoint_url, conn_id, message):
            sent_count += 1
    
    logger.info(f"Broadcast to {sent_count}/{len(connections)} connections in kingdom {kingdom_id}")
    return sent_count


def broadcast_to_user(endpoint_url: str, user_id: str, message: dict) -> int:
    """
    Send a message to all of a user's connections.
    
    Useful for notifications that should appear on all their devices.
    """
    connections = get_user_connections(user_id)
    
    sent_count = 0
    for conn in connections:
        if send_to_connection(endpoint_url, conn['connection_id'], message):
            sent_count += 1
    
    return sent_count


def broadcast_to_multiple_users(endpoint_url: str, user_ids: list, message: dict) -> int:
    """
    Send a message to multiple users.
    
    Useful for:
    - Party notifications (group hunts)
    - Alliance-wide messages
    """
    sent_count = 0
    for user_id in user_ids:
        sent_count += broadcast_to_user(endpoint_url, user_id, message)
    return sent_count

