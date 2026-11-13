"""Line-delimited JSON protocol shared with the ESP32/Arduino firmware.

The firmware speaks newline-delimited JSON in both directions:

    firmware -> Pi   {"type": "telemetry", "left_ticks": 120, ...}
    Pi -> firmware   {"type": "cmd_vel", "linear": 0.2, "angular": 0.0}

Keeping the protocol in one module makes it easy to unit test without a
serial port and to document the contract in a single place.
"""

from __future__ import annotations

import json
from typing import Any

PROTOCOL_VERSION = 1

# Firmware message types
MSG_TELEMETRY = "telemetry"
MSG_ACK = "ack"
MSG_EVENT = "event"
MSG_HELLO = "hello"

# Host message types
MSG_CMD_VEL = "cmd_vel"
MSG_STOP = "stop"
MSG_ESTOP = "estop"
MSG_CLEANING = "cleaning"
MSG_REQUEST_STATUS = "request_status"
MSG_SET_PID = "set_pid"
MSG_PING = "ping"


def encode(message: dict[str, Any]) -> bytes:
    """Serialise a host message for the serial link."""
    payload = dict(message)
    payload.setdefault("v", PROTOCOL_VERSION)
    return (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")


def decode(line: bytes | str) -> dict[str, Any] | None:
    """Parse a single firmware line, returning ``None`` for junk frames."""
    try:
        text = line.decode("utf-8", "ignore") if isinstance(line, bytes) else line
    except UnicodeDecodeError:  # pragma: no cover - defensive
        return None

    text = text.strip()
    if not text:
        return None

    try:
        parsed = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return None

    return parsed if isinstance(parsed, dict) else None


def cmd_vel(linear: float, angular: float) -> dict[str, Any]:
    return {
        "type": MSG_CMD_VEL,
        "linear": round(float(linear), 4),
        "angular": round(float(angular), 4),
    }


def stop() -> dict[str, Any]:
    return {"type": MSG_STOP}


def estop(engaged: bool) -> dict[str, Any]:
    return {"type": MSG_ESTOP, "engage": bool(engaged)}


def cleaning(enabled: bool, mode: str = "standard", speed: float = 1.0) -> dict[str, Any]:
    return {
        "type": MSG_CLEANING,
        "enabled": bool(enabled),
        "mode": mode,
        "speed": round(float(speed), 3),
    }


def request_status() -> dict[str, Any]:
    return {"type": MSG_REQUEST_STATUS}


def ping() -> dict[str, Any]:
    return {"type": MSG_PING}
