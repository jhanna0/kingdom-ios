"""
Local WebSocket Connection Manager

In-memory connection tracking for local development.
This replaces the DynamoDB-backed manager when running locally.

Usage:
    from websocket.local_manager import LocalConnectionManager, local_manager
    
    # In FastAPI WebSocket endpoint
    @app.websocket("/ws")
    async def websocket_endpoint(websocket: WebSocket):
        await local_manager.handle_connection(websocket)
"""
import json
import time
import logging
from typing import Dict, List, Optional, Set
from dataclasses import dataclass, field
from fastapi import WebSocket, WebSocketDisconnect

from .auth import extract_user_from_token

logger = logging.getLogger(__name__)


@dataclass
class LocalConnection:
    """Represents a WebSocket connection in local dev."""
    websocket: WebSocket
    user_id: str
    kingdom_id: str = "none"
    subscriptions: List[str] = field(default_factory=lambda: ["chat", "notifications"])
    connected_at: float = field(default_factory=time.time)


class LocalConnectionManager:
    """
    In-memory WebSocket connection manager for local development.
    
    Thread-safe for FastAPI's async model.
    """
    
    def __init__(self):
        # connection_id -> LocalConnection
        self._connections: Dict[str, LocalConnection] = {}
        # user_id -> set of connection_ids
        self._user_connections: Dict[str, Set[str]] = {}
        # kingdom_id -> set of connection_ids
        self._kingdom_connections: Dict[str, Set[str]] = {}
        # Counter for connection IDs
        self._counter = 0
    
    def _generate_connection_id(self) -> str:
        """Generate a unique connection ID."""
        self._counter += 1
        return f"local-{self._counter}-{int(time.time() * 1000)}"
    
    async def connect(
        self,
        websocket: WebSocket,
        user_id: str,
        kingdom_id: str = "none"
    ) -> str:
        """
        Accept a WebSocket connection and register it.
        
        Returns the connection_id.
        """
        await websocket.accept()
        
        connection_id = self._generate_connection_id()
        
        conn = LocalConnection(
            websocket=websocket,
            user_id=user_id,
            kingdom_id=kingdom_id,
        )
        
        self._connections[connection_id] = conn
        
        # Index by user
        if user_id not in self._user_connections:
            self._user_connections[user_id] = set()
        self._user_connections[user_id].add(connection_id)
        
        # Index by kingdom
        if kingdom_id not in self._kingdom_connections:
            self._kingdom_connections[kingdom_id] = set()
        self._kingdom_connections[kingdom_id].add(connection_id)
        
        logger.info(f"[Local WS] Connected: {connection_id} user={user_id} kingdom={kingdom_id}")
        
        # Send welcome message
        await self.send_to_connection(connection_id, {
            "type": "connected",
            "connection_id": connection_id,
            "user_id": user_id,
            "kingdom_id": kingdom_id,
        })
        
        return connection_id
    
    def disconnect(self, connection_id: str) -> None:
        """Remove a connection from all indexes."""
        conn = self._connections.pop(connection_id, None)
        if not conn:
            return
        
        # Remove from user index
        if conn.user_id in self._user_connections:
            self._user_connections[conn.user_id].discard(connection_id)
            if not self._user_connections[conn.user_id]:
                del self._user_connections[conn.user_id]
        
        # Remove from kingdom index
        if conn.kingdom_id in self._kingdom_connections:
            self._kingdom_connections[conn.kingdom_id].discard(connection_id)
            if not self._kingdom_connections[conn.kingdom_id]:
                del self._kingdom_connections[conn.kingdom_id]
        
        logger.info(f"[Local WS] Disconnected: {connection_id}")
    
    def update_kingdom(self, connection_id: str, new_kingdom_id: str) -> bool:
        """Update a connection's kingdom subscription."""
        conn = self._connections.get(connection_id)
        if not conn:
            return False
        
        old_kingdom = conn.kingdom_id
        
        # Remove from old kingdom index
        if old_kingdom in self._kingdom_connections:
            self._kingdom_connections[old_kingdom].discard(connection_id)
            if not self._kingdom_connections[old_kingdom]:
                del self._kingdom_connections[old_kingdom]
        
        # Add to new kingdom index
        conn.kingdom_id = new_kingdom_id
        if new_kingdom_id not in self._kingdom_connections:
            self._kingdom_connections[new_kingdom_id] = set()
        self._kingdom_connections[new_kingdom_id].add(connection_id)
        
        logger.info(f"[Local WS] {connection_id} moved from kingdom {old_kingdom} to {new_kingdom_id}")
        return True
    
    async def send_to_connection(self, connection_id: str, message: dict) -> bool:
        """Send a message to a specific connection."""
        conn = self._connections.get(connection_id)
        if not conn:
            return False
        
        try:
            await conn.websocket.send_json(message)
            return True
        except Exception as e:
            logger.warning(f"[Local WS] Failed to send to {connection_id}: {e}")
            self.disconnect(connection_id)
            return False
    
    async def broadcast_to_kingdom(
        self,
        kingdom_id: str,
        message: dict,
        exclude_connection: Optional[str] = None
    ) -> int:
        """Broadcast a message to all connections in a kingdom."""
        connection_ids = self._kingdom_connections.get(kingdom_id, set()).copy()
        
        sent_count = 0
        for conn_id in connection_ids:
            if conn_id == exclude_connection:
                continue
            if await self.send_to_connection(conn_id, message):
                sent_count += 1
        
        logger.info(f"[Local WS] Broadcast to kingdom {kingdom_id}: {sent_count}/{len(connection_ids)} connections")
        return sent_count
    
    async def broadcast_to_user(self, user_id: str, message: dict) -> int:
        """Send a message to all connections for a user."""
        connection_ids = self._user_connections.get(user_id, set()).copy()
        
        sent_count = 0
        for conn_id in connection_ids:
            if await self.send_to_connection(conn_id, message):
                sent_count += 1
        
        return sent_count
    
    async def broadcast_to_users(self, user_ids: List[str], message: dict) -> int:
        """Send a message to multiple users."""
        sent_count = 0
        for user_id in user_ids:
            sent_count += await self.broadcast_to_user(str(user_id), message)
        return sent_count
    
    def get_connection(self, connection_id: str) -> Optional[LocalConnection]:
        """Get a connection by ID."""
        return self._connections.get(connection_id)
    
    def get_user_connections(self, user_id: str) -> List[str]:
        """Get all connection IDs for a user."""
        return list(self._user_connections.get(user_id, set()))
    
    def get_kingdom_connections(self, kingdom_id: str) -> List[str]:
        """Get all connection IDs in a kingdom."""
        return list(self._kingdom_connections.get(kingdom_id, set()))
    
    async def handle_connection(
        self,
        websocket: WebSocket,
        token: Optional[str] = None,
        kingdom_id: str = "none"
    ) -> None:
        """
        Main connection handler for the WebSocket endpoint.
        
        Handles:
        - Authentication
        - Connection lifecycle
        - Message routing
        """
        # Authenticate
        user_id = "anonymous"
        if token:
            extracted = extract_user_from_token(f"Bearer {token}")
            if extracted:
                user_id = extracted
        
        if user_id == "anonymous":
            # For local dev, we'll allow anonymous connections with a warning
            logger.warning("[Local WS] Anonymous connection (no/invalid token)")
        
        # Accept and register
        connection_id = await self.connect(websocket, user_id, kingdom_id)
        
        try:
            # Message loop
            while True:
                data = await websocket.receive_json()
                await self._handle_message(connection_id, data)
        
        except WebSocketDisconnect:
            logger.info(f"[Local WS] Client disconnected: {connection_id}")
        except Exception as e:
            logger.error(f"[Local WS] Error in connection {connection_id}: {e}")
        finally:
            self.disconnect(connection_id)
    
    async def _handle_message(self, connection_id: str, data: dict) -> None:
        """Route incoming WebSocket messages."""
        action = data.get("action", "")
        
        if action == "subscribe":
            # Switch kingdoms
            kingdom_id = data.get("kingdom_id", "none")
            self.update_kingdom(connection_id, kingdom_id)
            await self.send_to_connection(connection_id, {
                "type": "subscribed",
                "kingdom_id": kingdom_id,
            })
        
        elif action == "unsubscribe":
            self.update_kingdom(connection_id, "none")
            await self.send_to_connection(connection_id, {
                "type": "unsubscribed",
            })
        
        elif action == "ping":
            await self.send_to_connection(connection_id, {
                "type": "pong",
                "timestamp": int(time.time() * 1000),
            })
        
        elif action == "sendMessage":
            # Chat message
            await self._handle_chat_message(connection_id, data)
        
        else:
            await self.send_to_connection(connection_id, {
                "type": "error",
                "message": f"Unknown action: {action}",
                "valid_actions": ["subscribe", "unsubscribe", "ping", "sendMessage"],
            })
    
    async def _handle_chat_message(self, connection_id: str, data: dict) -> None:
        """Handle chat messages."""
        conn = self._connections.get(connection_id)
        if not conn:
            return
        
        message_text = data.get("message", "")
        if not message_text:
            await self.send_to_connection(connection_id, {
                "type": "error",
                "message": "Message cannot be empty",
            })
            return
        
        if conn.kingdom_id == "none":
            await self.send_to_connection(connection_id, {
                "type": "error",
                "message": "You must be in a kingdom to chat",
            })
            return
        
        # Build and broadcast
        broadcast_msg = {
            "type": "message",
            "kingdom_id": conn.kingdom_id,
            "sender": {
                "user_id": conn.user_id,
                "display_name": data.get("display_name", conn.user_id),
            },
            "message": message_text,
            "timestamp": int(time.time() * 1000),
        }
        
        await self.broadcast_to_kingdom(conn.kingdom_id, broadcast_msg)
    
    @property
    def stats(self) -> dict:
        """Get connection statistics for debugging."""
        return {
            "total_connections": len(self._connections),
            "unique_users": len(self._user_connections),
            "active_kingdoms": len(self._kingdom_connections),
        }


# Global singleton for local development
local_manager = LocalConnectionManager()

