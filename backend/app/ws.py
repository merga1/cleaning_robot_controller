"""WebSocket connection manager with optional per-user filtering."""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any

from fastapi import WebSocket

LOGGER = logging.getLogger("cleanbot.ws")


@dataclass
class Connection:
    websocket: WebSocket
    user_id: str
    send_lock: asyncio.Lock = field(default_factory=asyncio.Lock)


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[int, Connection] = {}

    @property
    def count(self) -> int:
        return len(self._connections)

    async def connect(self, websocket: WebSocket, user_id: str) -> None:
        await websocket.accept()
        self._connections[id(websocket)] = Connection(
            websocket=websocket, user_id=user_id
        )

    def disconnect(self, websocket: WebSocket) -> None:
        self._connections.pop(id(websocket), None)

    async def broadcast(self, message: dict[str, Any]) -> None:
        if not self._connections:
            return
        stale: list[int] = []
        for key, connection in list(self._connections.items()):
            try:
                async with connection.send_lock:
                    await connection.websocket.send_json(message)
            except Exception:
                stale.append(key)
        for key in stale:
            self._connections.pop(key, None)

    async def broadcast_many(self, messages: list[dict[str, Any]]) -> None:
        for message in messages:
            await self.broadcast(message)

    async def send_to_user(self, user_id: str, message: dict[str, Any]) -> None:
        for connection in list(self._connections.values()):
            if connection.user_id != user_id:
                continue
            try:
                async with connection.send_lock:
                    await connection.websocket.send_json(message)
            except Exception:
                self.disconnect(connection.websocket)


manager = ConnectionManager()
