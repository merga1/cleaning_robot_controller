"""Configuration for the CleanBot Raspberry Pi backend.

Every value can be supplied through environment variables (or the systemd
EnvironmentFile at /etc/cleanbot/backend.env). Defaults are safe for a
single-robot Raspberry Pi installation.
"""

from __future__ import annotations

import json
import os
import socket
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


def _env(name: str, default: str) -> str:
    value = os.environ.get(name)
    return default if value is None or value == "" else value


def _env_int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    try:
        return float(_env(name, str(default)))
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    return _env(name, "true" if default else "false").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


DEFAULT_USERS: list[dict[str, Any]] = [
    {
        "id": "usr-admin-01",
        "username": "admin@cleanbot.io",
        "email": "admin@cleanbot.io",
        "full_name": "System Administrator",
        "role": "admin",
        "password": "Admin#2026",
    },
    {
        "id": "usr-operator-01",
        "username": "operator@cleanbot.io",
        "email": "operator@cleanbot.io",
        "full_name": "Floor Operator",
        "role": "operator",
        "password": "CleanBot#2026",
    },
    {
        "id": "usr-auditor-01",
        "username": "readonly@cleanbot.io",
        "email": "readonly@cleanbot.io",
        "full_name": "Audit Supervisor",
        "role": "readonly",
        "password": "ReadOnly#2026",
    },
]


@dataclass(slots=True)
class Settings:
    host: str = field(default_factory=lambda: _env("CLEANBOT_API_HOST", "0.0.0.0"))
    port: int = field(default_factory=lambda: _env_int("CLEANBOT_API_PORT", 8000))
    jwt_secret: str = field(
        default_factory=lambda: _env(
            "CLEANBOT_JWT_SECRET", "change-me-cleanbot-raspberry-pi-secret"
        )
    )
    access_token_minutes: int = field(
        default_factory=lambda: _env_int("CLEANBOT_ACCESS_TOKEN_MINUTES", 480)
    )
    refresh_token_days: int = field(
        default_factory=lambda: _env_int("CLEANBOT_REFRESH_TOKEN_DAYS", 30)
    )
    cors_origins: list[str] = field(
        default_factory=lambda: [
            origin.strip()
            for origin in _env("CLEANBOT_CORS_ORIGINS", "*").split(",")
            if origin.strip()
        ]
    )
    robot_id: str = field(
        default_factory=lambda: _env("CLEANBOT_ROBOT_ID", "robot-alpha-01")
    )
    robot_name: str = field(
        default_factory=lambda: _env("CLEANBOT_ROBOT_NAME", "CleanBot Pro (East Wing)")
    )
    firmware_version: str = field(
        default_factory=lambda: _env("CLEANBOT_FIRMWARE_VERSION", "v2.4.1")
    )
    map_frame: str = field(default_factory=lambda: _env("CLEANBOT_MAP_FRAME", "map"))
    odom_frame: str = field(default_factory=lambda: _env("CLEANBOT_ODOM_FRAME", "odom"))
    base_frame: str = field(
        default_factory=lambda: _env("CLEANBOT_BASE_FRAME", "base_link")
    )
    enable_simulated_robot: bool = field(
        default_factory=lambda: _env_bool("CLEANBOT_ENABLE_SIM_ROBOT", True)
    )
    simulate_when_ros_missing: bool = field(
        default_factory=lambda: _env_bool("CLEANBOT_SIMULATE_WHEN_ROS_MISSING", True)
    )
    force_simulation: bool = field(
        default_factory=lambda: _env_bool("CLEANBOT_FORCE_SIMULATION", False)
    )
    ros_topic_battery: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_BATTERY", "/battery_state")
    )
    ros_topic_odom: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_ODOM", "/odom")
    )
    ros_topic_scan: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_SCAN", "/scan")
    )
    ros_topic_map: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_MAP", "/map")
    )
    ros_topic_amcl: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_AMCL", "/amcl_pose")
    )
    ros_topic_status: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_STATUS", "/cleanbot/status")
    )
    ros_topic_detections: str = field(
        default_factory=lambda: _env(
            "CLEANBOT_TOPIC_DETECTIONS", "/cleanbot/detections"
        )
    )
    ros_topic_hardware_command: str = field(
        default_factory=lambda: _env(
            "CLEANBOT_TOPIC_HARDWARE_COMMAND", "/cleanbot/hardware_command"
        )
    )
    ros_topic_cmd_vel: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_CMD_VEL", "/cmd_vel")
    )
    ros_topic_goal_pose: str = field(
        default_factory=lambda: _env("CLEANBOT_TOPIC_GOAL_POSE", "/goal_pose")
    )
    ros_domain_id: int = field(
        default_factory=lambda: _env_int("ROS_DOMAIN_ID", 0)
    )
    database_path: Path = field(
        default_factory=lambda: Path(
            _env("CLEANBOT_DATABASE_PATH", "/var/lib/cleanbot/cleanbot.db")
        )
    )
    log_level: str = field(default_factory=lambda: _env("CLEANBOT_LOG_LEVEL", "INFO"))
    users: list[dict[str, Any]] = field(default_factory=lambda: _load_users())

    @property
    def hostname(self) -> str:
        return socket.gethostname()


def _load_users() -> list[dict[str, Any]]:
    raw = os.environ.get("CLEANBOT_USERS")
    if not raw:
        return DEFAULT_USERS
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list) and parsed:
            return parsed
    except json.JSONDecodeError:
        pass
    return DEFAULT_USERS


settings = Settings()
