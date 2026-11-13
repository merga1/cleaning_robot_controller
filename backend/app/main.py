"""CleanBot Raspberry Pi backend.

FastAPI service that exposes the REST + WebSocket contract consumed by the
Flutter controller and bridges it to ROS 2 (Nav2, LiDAR, odometry, battery)
and the ESP32/Arduino hardware driver.
"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import Depends, FastAPI, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import auth, robot
from .ros_bridge import RosBridge
from .security import AuthUser, decode_token, get_current_user, user_directory
from .state import RobotStore, iso_now
from .ws import manager

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
LOGGER = logging.getLogger("cleanbot.api")

API_VERSION = "1.0.0"


async def _telemetry_loop(app: FastAPI) -> None:
    store: RobotStore = app.state.store
    while True:
        try:
            messages = store.ws_messages()
            if messages:
                await manager.broadcast_many(messages)
        except asyncio.CancelledError:
            raise
        except Exception:  # pragma: no cover - keep the loop alive
            LOGGER.exception("Telemetry broadcast failed")
        await asyncio.sleep(0.5)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    store = RobotStore(settings)
    bridge = RosBridge(store, settings)
    app.state.store = store
    app.state.bridge = bridge

    bridge.start()
    task = asyncio.create_task(_telemetry_loop(app), name="cleanbot-telemetry")
    LOGGER.info(
        "CleanBot backend ready on %s:%s (robot %s)",
        settings.host,
        settings.port,
        settings.robot_id,
    )
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        bridge.stop()
        LOGGER.info("CleanBot backend stopped")


app = FastAPI(
    title="CleanBot Raspberry Pi API",
    version=API_VERSION,
    description=(
        "REST + WebSocket backend for the CleanBot cleaning robot. "
        "Bridges the Flutter controller to ROS 2 navigation and the hardware driver."
    ),
    lifespan=lifespan,
)

_allow_all = "*" in settings.cors_origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=not _allow_all,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(robot.router, prefix="/api/v1")


@app.get("/", tags=["system"])
def root() -> dict:
    return {
        "name": "CleanBot Raspberry Pi API",
        "version": API_VERSION,
        "docs": "/docs",
        "health": "/api/v1/health",
        "websocket": "/api/v1/ws?token=<access_token>",
    }


@app.get("/api/v1/health", tags=["system"])
def health() -> dict:
    store: RobotStore = app.state.store
    return {
        "status": "ok",
        "version": API_VERSION,
        "robot_id": settings.robot_id,
        "ros_connected": store.ros_connected,
        "ros_note": store.ros_note,
        "hardware_connected": store.hardware_connected,
        "connected_clients": manager.count,
        "time": iso_now(),
    }


@app.get("/api/v1/system/status", tags=["system"])
def system_status(_: AuthUser = Depends(get_current_user)) -> dict:
    return app.state.store.system_status()


@app.websocket("/api/v1/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(default=""),
) -> None:
    if not token:
        await websocket.close(code=4401, reason="Missing access token")
        return
    try:
        claims = decode_token(token)
    except Exception:
        await websocket.close(code=4401, reason="Invalid access token")
        return

    user = user_directory.by_id(str(claims.get("sub")))
    if user is None:
        await websocket.close(code=4401, reason="Unknown user")
        return

    await manager.connect(websocket, user.id)
    store: RobotStore = app.state.store
    try:
        # Send a full snapshot immediately so the app does not wait for ticks.
        for message in store.ws_messages():
            await websocket.send_json(message)
        while True:
            # The client only needs a keepalive; all telemetry is pushed.
            raw = await websocket.receive_text()
            if raw.strip().lower() == "ping":
                await websocket.send_json(
                    {
                        "robot_id": settings.robot_id,
                        "type": "pong",
                        "timestamp": iso_now(),
                        "is_simulated": False,
                        "payload": {},
                    }
                )
    except WebSocketDisconnect:
        pass
    except Exception:  # pragma: no cover - transport level errors
        LOGGER.debug("WebSocket disconnected", exc_info=True)
    finally:
        manager.disconnect(websocket)
