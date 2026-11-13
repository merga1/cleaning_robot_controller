"""Thread-safe in-memory robot state shared by REST, WebSocket and ROS bridge.

The store is intentionally dependency free. It holds the live telemetry that
is fed by the ROS 2 bridge (or by the built-in simulator when ROS is not
available) and exposes API-shaped snapshots for the Flutter application.
"""

from __future__ import annotations

import copy
import math
import random
import threading
import time
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from .config import Settings


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_now() -> str:
    return utc_now().isoformat().replace("+00:00", "Z")


def _iso(dt: datetime) -> str:
    return dt.isoformat().replace("+00:00", "Z")


COMMAND_ALIASES = {
    "call": "call",
    "startcleaning": "startCleaning",
    "start_cleaning": "startCleaning",
    "pause": "pause",
    "resume": "resume",
    "cancel": "cancel",
    "inspectfloor": "inspectFloor",
    "inspect_floor": "inspectFloor",
    "returntodock": "returnToDock",
    "return_to_dock": "returnToDock",
    "requeststatusrefresh": "requestStatusRefresh",
    "request_status_refresh": "requestStatusRefresh",
}

TERMINAL_STATES = {"completed", "rejected", "failed", "expired", "cancelled"}

DEFAULT_ZONES = [
    {
        "id": "zone-lobby",
        "name": "Lobby & Main Hall",
        "description": "Main entrance, reception and lift lobby",
        "area_m2": 180.0,
        "estimated_minutes": 28,
        "priority": "high",
        "polygon": [
            {"x": 0.5, "y": 0.5},
            {"x": 7.5, "y": 0.5},
            {"x": 7.5, "y": 4.8},
            {"x": 0.5, "y": 4.8},
        ],
    },
    {
        "id": "zone-east-wing",
        "name": "East Wing Offices",
        "description": "Open-plan desks and two meeting rooms",
        "area_m2": 240.0,
        "estimated_minutes": 36,
        "priority": "normal",
        "polygon": [
            {"x": 8.0, "y": 0.5},
            {"x": 15.0, "y": 0.5},
            {"x": 15.0, "y": 6.5},
            {"x": 8.0, "y": 6.5},
        ],
    },
    {
        "id": "zone-cafeteria",
        "name": "Cafeteria",
        "description": "Dining area and kitchen access corridor",
        "area_m2": 150.0,
        "estimated_minutes": 22,
        "priority": "high",
        "polygon": [
            {"x": 0.5, "y": 5.0},
            {"x": 7.5, "y": 5.0},
            {"x": 7.5, "y": 9.5},
            {"x": 0.5, "y": 9.5},
        ],
    },
    {
        "id": "zone-restrooms",
        "name": "Restrooms & Corridor",
        "description": "North corridor, restrooms and utility room",
        "area_m2": 90.0,
        "estimated_minutes": 16,
        "priority": "normal",
        "polygon": [
            {"x": 8.0, "y": 7.0},
            {"x": 15.0, "y": 7.0},
            {"x": 15.0, "y": 9.5},
            {"x": 8.0, "y": 9.5},
        ],
    },
    {
        "id": "zone-server",
        "name": "Server Room",
        "description": "Restricted cold-aisle cleaning route",
        "area_m2": 60.0,
        "estimated_minutes": 12,
        "priority": "low",
        "polygon": [
            {"x": 11.0, "y": 3.0},
            {"x": 14.5, "y": 3.0},
            {"x": 14.5, "y": 6.0},
            {"x": 11.0, "y": 6.0},
        ],
    },
]


class RobotStore:
    def __init__(self, config: Settings) -> None:
        self.config = config
        self._lock = threading.RLock()
        self._rng = random.Random(2026)
        self._boot_monotonic = time.monotonic()
        self.ros_connected = False
        self.hardware_connected = False
        self.ros_note = "waiting for ROS 2 bridge"
        self._last_broadcast_fingerprint: dict[str, Any] = {}
        self.cleaning_mode = "standard"
        self.auto_dock = True

        now = iso_now()
        self.robot: dict[str, Any] = {
            "id": config.robot_id,
            "name": config.robot_name,
            "battery_level": 86,
            "is_charging": False,
            "connection_state": "online",
            "status": "idle",
            "is_simulated": False,
            "firmware_version": config.firmware_version,
            "last_updated_at": now,
            "last_data_received_at": now,
            "capabilities": {
                "can_call": True,
                "can_clean": True,
                "can_pause": True,
                "can_resume": True,
                "can_cancel": True,
                "can_inspect": True,
                "can_dock": True,
            },
            "pose": {"x": 1.2, "y": 1.1, "yaw": 0.0},
            "odom": {"linear_x": 0.0, "angular_z": 0.0},
            "scan": {"min_distance_m": 2.4, "obstacle_count": 0},
            "waste": {
                "fill_percentage": 36,
                "sensor_fault": False,
                "capacity_liters": 12.0,
                "level_cm": 31.0,
                "last_emptied_at": _iso(utc_now()),
            },
            "cleanliness": {
                "score": 82.0,
                "confidence": 0.9,
                "timestamp": now,
                "is_simulated": False,
                "zone_name": "Lobby & Main Hall",
            },
            "active_job": None,
            "active_alert_count": 1,
            "history": [],
            "detections": [],
            "notifications": [],
            "zones": copy.deepcopy(DEFAULT_ZONES),
            "map": self._empty_map(),
            "commands": {},
            "last_container_fingerprint": None,
        }

        self._seed_demo_data()
        self._seed_simulated_robot()

    # ------------------------------------------------------------------
    # Seed data
    # ------------------------------------------------------------------
    def _seed_demo_data(self) -> None:
        now = utc_now()
        self.robot["history"] = [
            {
                "job_id": "job-9831",
                "zone_id": "zone-lobby",
                "zone_name": "Lobby & Main Hall",
                "started_at": _iso(now.replace(hour=6, minute=10)),
                "completed_at": _iso(now.replace(hour=6, minute=38)),
                "status": "completed",
                "coverage_area_m2": 178.4,
                "duration_seconds": 1680,
                "battery_start": 96,
                "battery_end": 74,
                "operator": "Floor Operator",
            },
            {
                "job_id": "job-9827",
                "zone_id": "zone-east-wing",
                "zone_name": "East Wing Offices",
                "started_at": _iso(now.replace(day=max(1, now.day - 1), hour=18)),
                "completed_at": _iso(
                    now.replace(day=max(1, now.day - 1), hour=18, minute=35)
                ),
                "status": "completed",
                "coverage_area_m2": 232.9,
                "duration_seconds": 2100,
                "battery_start": 89,
                "battery_end": 63,
                "operator": "Floor Operator",
            },
            {
                "job_id": "job-9819",
                "zone_id": "zone-cafeteria",
                "zone_name": "Cafeteria",
                "started_at": _iso(
                    now.replace(day=max(1, now.day - 1), hour=12, minute=10)
                ),
                "completed_at": _iso(
                    now.replace(day=max(1, now.day - 1), hour=12, minute=41)
                ),
                "status": "failed",
                "coverage_area_m2": 96.2,
                "duration_seconds": 1860,
                "battery_start": 68,
                "battery_end": 41,
                "operator": "Floor Operator",
            },
        ]

        self.robot["detections"] = [
            {
                "id": "det-4401",
                "type": "waste_paper",
                "label": "Paper cup",
                "confidence": 0.93,
                "x": 3.4,
                "y": 2.1,
                "zone_name": "Lobby & Main Hall",
                "timestamp": _iso(now),
                "is_simulated": False,
                "image_url": None,
            },
            {
                "id": "det-4402",
                "type": "spill",
                "label": "Liquid spill",
                "confidence": 0.88,
                "x": 9.8,
                "y": 4.4,
                "zone_name": "East Wing Offices",
                "timestamp": _iso(now.replace(minute=max(0, now.minute - 4))),
                "is_simulated": False,
                "image_url": None,
            },
            {
                "id": "det-4403",
                "type": "dust",
                "label": "Dust cluster",
                "confidence": 0.72,
                "x": 5.0,
                "y": 7.2,
                "zone_name": "Cafeteria",
                "timestamp": _iso(now.replace(minute=max(0, now.minute - 11))),
                "is_simulated": False,
                "image_url": None,
            },
        ]

        self.robot["notifications"] = [
            {
                "id": "ntf-1001",
                "severity": "critical",
                "title": "Cliff sensor triggered",
                "message": "Robot stopped near the north stairwell. Operator attention required.",
                "timestamp": _iso(now.replace(minute=max(0, now.minute - 2))),
                "is_read": False,
                "robot_id": self.config.robot_id,
                "category": "safety",
            },
            {
                "id": "ntf-1002",
                "severity": "warning",
                "title": "Waste container 36% full",
                "message": "Container can continue, but plan an emptying stop soon.",
                "timestamp": _iso(now.replace(minute=max(0, now.minute - 18))),
                "is_read": False,
                "robot_id": self.config.robot_id,
                "category": "waste",
            },
            {
                "id": "ntf-1003",
                "severity": "info",
                "title": "Map synchronized",
                "message": "Navigation map was refreshed from the Raspberry Pi.",
                "timestamp": _iso(now.replace(hour=max(0, now.hour - 1))),
                "is_read": True,
                "robot_id": self.config.robot_id,
                "category": "navigation",
            },
        ]

    def _seed_simulated_robot(self) -> None:
        self.simulated_robot: dict[str, Any] | None = None
        if not self.config.enable_simulated_robot:
            return
        now = iso_now()
        self.simulated_robot = {
            "id": "robot-sim-02",
            "name": "CleanBot Simulator-Beta",
            "battery_level": 64,
            "is_charging": True,
            "connection_state": "online",
            "status": "charging",
            "is_simulated": True,
            "firmware_version": self.config.firmware_version + "-sim",
            "last_updated_at": now,
            "last_data_received_at": now,
            "capabilities": {
                "can_call": True,
                "can_clean": True,
                "can_pause": True,
                "can_resume": True,
                "can_cancel": True,
                "can_inspect": True,
                "can_dock": True,
            },
            "pose": {"x": 0.7, "y": 8.8, "yaw": 3.14},
            "odom": {"linear_x": 0.0, "angular_z": 0.0},
            "scan": {"min_distance_m": 3.1, "obstacle_count": 0},
            "waste": {
                "fill_percentage": 12,
                "sensor_fault": False,
                "capacity_liters": 12.0,
                "level_cm": 10.0,
                "last_emptied_at": now,
            },
            "cleanliness": {
                "score": 90.0,
                "confidence": 0.92,
                "timestamp": now,
                "is_simulated": True,
                "zone_name": "East Wing Offices",
            },
            "active_job": None,
            "active_alert_count": 0,
            "history": [],
            "detections": [],
            "notifications": [],
            "zones": copy.deepcopy(DEFAULT_ZONES),
            "map": self._empty_map(),
            "commands": {},
            "last_container_fingerprint": None,
        }

    def _empty_map(self) -> dict[str, Any]:
        return {
            "width": 0,
            "height": 0,
            "resolution": 0.05,
            "origin": {"x": 0.0, "y": 0.0, "yaw": 0.0},
            "occupancy": [],
            "robot_pose": {"x": 0.0, "y": 0.0, "yaw": 0.0},
            "dock": {"x": 0.7, "y": 0.7, "yaw": 0.0},
            "obstacles": [],
            "updated_at": iso_now(),
        }

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _robot(self, robot_id: str) -> dict[str, Any] | None:
        if robot_id == self.robot["id"]:
            return self.robot
        if self.simulated_robot and robot_id == self.simulated_robot["id"]:
            return self.simulated_robot
        return None

    def _require(self, robot_id: str | None) -> dict[str, Any] | None:
        return self._robot(robot_id or self.robot["id"])

    def _touch(self, robot: dict[str, Any]) -> None:
        now = iso_now()
        robot["last_updated_at"] = now
        robot["last_data_received_at"] = now
        robot["map"]["robot_pose"] = dict(robot["pose"])
        robot["map"]["updated_at"] = now

    def _add_notification(
        self,
        robot: dict[str, Any],
        severity: str,
        title: str,
        message: str,
        category: str = "system",
    ) -> None:
        robot["notifications"].insert(
            0,
            {
                "id": f"ntf-{uuid4().hex[:8]}",
                "severity": severity,
                "title": title,
                "message": message,
                "timestamp": iso_now(),
                "is_read": False,
                "robot_id": robot["id"],
                "category": category,
            },
        )
        robot["notifications"] = robot["notifications"][:100]
        if severity in {"warning", "critical"}:
            robot["active_alert_count"] = min(
                int(robot.get("active_alert_count", 0)) + 1, 99
            )

    # ------------------------------------------------------------------
    # Robot snapshots
    # ------------------------------------------------------------------
    def _robot_payload(self, robot: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": robot["id"],
            "name": robot["name"],
            "battery_level": int(round(float(robot["battery_level"]))),
            "is_charging": bool(robot["is_charging"]),
            "connection_state": robot["connection_state"],
            "status": robot["status"],
            "capabilities": copy.deepcopy(robot["capabilities"]),
            "is_simulated": bool(robot["is_simulated"]),
            "last_updated_at": robot["last_updated_at"],
            "firmware_version": robot["firmware_version"],
        }

    def list_robots(self) -> list[dict[str, Any]]:
        with self._lock:
            robots = [self._robot_payload(self.robot)]
            if self.simulated_robot:
                robots.append(self._robot_payload(self.simulated_robot))
            return robots

    def get_robot(self, robot_id: str | None = None) -> dict[str, Any] | None:
        with self._lock:
            robot = self._require(robot_id)
            return self._robot_payload(robot) if robot else None

    def dashboard(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            job = robot.get("active_job")
            cleanliness = robot.get("cleanliness")
            return {
                "robot_id": robot["id"],
                "active_job": copy.deepcopy(job),
                "waste_fill_percentage": int(robot["waste"]["fill_percentage"]),
                "waste_sensor_fault": bool(robot["waste"]["sensor_fault"]),
                "latest_cleanliness": copy.deepcopy(cleanliness),
                "active_alert_count": int(robot["active_alert_count"]),
                "last_data_received_at": robot["last_data_received_at"],
            }

    def telemetry(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            return {
                "robot_id": robot["id"],
                "battery": {
                    "level": int(round(float(robot["battery_level"]))),
                    "is_charging": bool(robot["is_charging"]),
                },
                "pose": copy.deepcopy(robot["pose"]),
                "odom": copy.deepcopy(robot["odom"]),
                "scan": copy.deepcopy(robot["scan"]),
                "status": robot["status"],
                "mode": self.cleaning_mode,
                "updated_at": robot["last_updated_at"],
            }

    def map_payload(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            payload = copy.deepcopy(robot["map"])
            payload["robot_pose"] = copy.deepcopy(robot["pose"])
            return payload

    def waste(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            waste = copy.deepcopy(robot["waste"])
            waste["status"] = (
                "fault"
                if waste["sensor_fault"]
                else "full"
                if waste["fill_percentage"] >= 90
                else "attention"
                if waste["fill_percentage"] >= 70
                else "normal"
            )
            return waste

    def zones(self, robot_id: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            zones = copy.deepcopy(robot["zones"])
            for zone in zones:
                zone.setdefault("is_available", True)
                zone.setdefault("unavailability_reason", None)
            return zones

    def detections(
        self, robot_id: str | None = None, limit: int = 100
    ) -> list[dict[str, Any]]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            return copy.deepcopy(robot["detections"][:limit])

    def history(self, robot_id: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            return copy.deepcopy(robot["history"])

    def notifications(self, robot_id: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            return copy.deepcopy(robot["notifications"])

    def mark_notification(
        self, notification_id: str, is_read: bool = True
    ) -> dict[str, Any] | None:
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                for item in robot["notifications"]:
                    if item["id"] == notification_id:
                        item["is_read"] = is_read
                        return copy.deepcopy(item)
        return None

    def mark_all_notifications(self) -> int:
        with self._lock:
            count = 0
            for robot in filter(None, (self.robot, self.simulated_robot)):
                for item in robot["notifications"]:
                    if not item["is_read"]:
                        item["is_read"] = True
                        count += 1
            return count

    def cleanliness(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            return copy.deepcopy(robot.get("cleanliness") or {})

    def maintenance(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            battery = int(round(float(robot["battery_level"])))
            components = [
                {
                    "name": "Drive motors",
                    "status": "ok" if robot["status"] != "fault" else "fault",
                    "detail": "Encoder feedback nominal",
                },
                {
                    "name": "LiDAR",
                    "status": "ok",
                    "detail": f'Closest return {robot["scan"]["min_distance_m"]:.2f} m',
                },
                {
                    "name": "Battery pack",
                    "status": "warning" if battery < 25 else "ok",
                    "detail": f"{battery}% remaining",
                },
                {
                    "name": "Waste sensor",
                    "status": "fault"
                    if robot["waste"]["sensor_fault"]
                    else "ok",
                    "detail": f'{robot["waste"]["fill_percentage"]}% full',
                },
                {
                    "name": "ESP32 bridge",
                    "status": "ok" if self.hardware_connected else "warning",
                    "detail": "Serial link healthy"
                    if self.hardware_connected
                    else "Waiting for hardware driver",
                },
                {
                    "name": "ROS 2 / Nav2",
                    "status": "ok" if self.ros_connected else "warning",
                    "detail": self.ros_note,
                },
            ]
            health = 100.0
            for component in components:
                if component["status"] == "warning":
                    health -= 6
                elif component["status"] == "fault":
                    health -= 22
            return {
                "robot_id": robot["id"],
                "health_score": max(0, int(health)),
                "components": components,
                "last_diagnostic_at": robot["last_updated_at"],
                "ros_connected": self.ros_connected,
                "hardware_connected": self.hardware_connected,
                "ros_note": self.ros_note,
            }

    def reports(self, robot_id: str | None = None) -> dict[str, Any]:
        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            history = robot["history"]
            completed = [h for h in history if h["status"] == "completed"]
            total_area = sum(float(h["coverage_area_m2"]) for h in history)
            total_seconds = sum(int(h["duration_seconds"]) for h in history)
            by_zone: dict[str, dict[str, Any]] = {}
            for item in history:
                bucket = by_zone.setdefault(
                    item["zone_name"],
                    {"zone_name": item["zone_name"], "jobs": 0, "area_m2": 0.0},
                )
                bucket["jobs"] += 1
                bucket["area_m2"] += float(item["coverage_area_m2"])
            return {
                "robot_id": robot["id"],
                "period": "last_30_days",
                "total_jobs": len(history),
                "completed_jobs": len(completed),
                "failed_jobs": len(history) - len(completed),
                "total_coverage_m2": round(total_area, 1),
                "total_runtime_seconds": total_seconds,
                "average_cleanliness": robot["cleanliness"]["score"],
                "by_zone": list(by_zone.values()),
                "generated_at": iso_now(),
            }

    def system_status(self) -> dict[str, Any]:
        with self._lock:
            return {
                "backend_version": "1.0.0",
                "hostname": self.config.hostname,
                "uptime_seconds": int(time.monotonic() - self._boot_monotonic),
                "ros_connected": self.ros_connected,
                "ros_note": self.ros_note,
                "hardware_connected": self.hardware_connected,
                "robot_id": self.robot["id"],
                "robot_status": self.robot["status"],
                "map_loaded": self.robot["map"]["width"] > 0,
                "cleaning_mode": self.cleaning_mode,
                "auto_dock": self.auto_dock,
            }

    # ------------------------------------------------------------------
    # ROS updates
    # ------------------------------------------------------------------
    def set_ros_state(self, connected: bool, note: str = "") -> None:
        with self._lock:
            self.ros_connected = connected
            self.ros_note = note or ("ROS 2 bridge running" if connected else "offline")

    def set_hardware_state(self, connected: bool) -> None:
        with self._lock:
            self.hardware_connected = connected

    def update_battery(self, percentage: float, charging: bool | None = None) -> None:
        with self._lock:
            robot = self.robot
            robot["battery_level"] = max(0, min(100, float(percentage)))
            if charging is not None:
                robot["is_charging"] = bool(charging)
            self._touch(robot)

    def update_odom(
        self, x: float, y: float, yaw: float, linear_x: float = 0.0, angular_z: float = 0.0
    ) -> None:
        with self._lock:
            robot = self.robot
            robot["pose"] = {"x": float(x), "y": float(y), "yaw": float(yaw)}
            robot["odom"] = {
                "linear_x": float(linear_x),
                "angular_z": float(angular_z),
            }
            self._touch(robot)

    def update_scan(self, min_distance_m: float, obstacle_count: int) -> None:
        with self._lock:
            robot = self.robot
            robot["scan"] = {
                "min_distance_m": max(0.0, float(min_distance_m)),
                "obstacle_count": int(obstacle_count),
            }
            self._touch(robot)

    def update_pose(self, x: float, y: float, yaw: float) -> None:
        with self._lock:
            robot = self.robot
            robot["pose"] = {"x": float(x), "y": float(y), "yaw": float(yaw)}
            self._touch(robot)

    def update_status(self, payload: dict[str, Any]) -> None:
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                if payload.get("robot_id") and payload["robot_id"] != robot["id"]:
                    continue
                self._apply_status_payload(robot, payload)
                self._touch(robot)

    def _apply_status_payload(
        self, robot: dict[str, Any], payload: dict[str, Any]
    ) -> None:
        if "battery_level" in payload:
            robot["battery_level"] = max(
                0, min(100, float(payload["battery_level"]))
            )
        if "is_charging" in payload:
            robot["is_charging"] = bool(payload["is_charging"])
        if payload.get("status"):
            robot["status"] = str(payload["status"])
        if "waste_fill_percentage" in payload:
            robot["waste"]["fill_percentage"] = max(
                0, min(100, int(payload["waste_fill_percentage"]))
            )
        if "waste_sensor_fault" in payload:
            robot["waste"]["sensor_fault"] = bool(payload["waste_sensor_fault"])
        if payload.get("cleanliness"):
            cleanliness = dict(payload["cleanliness"])
            cleanliness.setdefault("timestamp", iso_now())
            cleanliness.setdefault("is_simulated", robot["is_simulated"])
            cleanliness.setdefault("zone_name", "Cleaning zone")
            robot["cleanliness"] = cleanliness
        if payload.get("active_job") is not None:
            robot["active_job"] = dict(payload["active_job"])
        if "active_alert_count" in payload:
            robot["active_alert_count"] = int(payload["active_alert_count"])
        if payload.get("pose"):
            pose = payload["pose"]
            robot["pose"] = {
                "x": float(pose.get("x", robot["pose"]["x"])),
                "y": float(pose.get("y", robot["pose"]["y"])),
                "yaw": float(pose.get("yaw", robot["pose"]["yaw"])),
            }
        if payload.get("zone_name") and robot.get("active_job"):
            robot["active_job"]["zone_name"] = str(payload["zone_name"])
        if payload.get("command_id") and payload.get("command_state"):
            self._apply_command_state(
                robot, str(payload["command_id"]), str(payload["command_state"])
            )

    def update_detections(self, detections: list[dict[str, Any]]) -> None:
        with self._lock:
            robot = self.robot
            for detection in detections:
                item = dict(detection)
                item.setdefault("id", f"det-{uuid4().hex[:8]}")
                item.setdefault("timestamp", iso_now())
                item.setdefault("is_simulated", False)
                item.setdefault("confidence", 0.7)
                item.setdefault("label", item.get("type", "debris"))
                robot["detections"].insert(0, item)
            robot["detections"] = robot["detections"][:200]
            self._touch(robot)

    def update_map(
        self,
        width: int,
        height: int,
        resolution: float,
        origin: dict[str, float],
        occupancy: list[int],
    ) -> None:
        with self._lock:
            robot = self.robot
            robot["map"].update(
                {
                    "width": int(width),
                    "height": int(height),
                    "resolution": float(resolution),
                    "origin": {
                        "x": float(origin.get("x", 0.0)),
                        "y": float(origin.get("y", 0.0)),
                        "yaw": float(origin.get("yaw", 0.0)),
                    },
                    "occupancy": [int(value) for value in occupancy],
                    "updated_at": iso_now(),
                }
            )
            robot["map"]["robot_pose"] = dict(robot["pose"])
            # Derive a compact obstacle list for the mobile live-map painter.
            obstacles: list[dict[str, float]] = []
            if width and height and len(occupancy) == width * height:
                step = max(1, int(math.sqrt(width * height / 200)))
                for index in range(0, len(occupancy), step):
                    value = occupancy[index]
                    if value >= 60:
                        row, col = divmod(index, width)
                        obstacles.append(
                            {
                                "x": float(origin.get("x", 0.0))
                                + (col + 0.5) * resolution,
                                "y": float(origin.get("y", 0.0))
                                + (row + 0.5) * resolution,
                            }
                        )
            robot["map"]["obstacles"] = obstacles[:300]
            self._touch(robot)

    # ------------------------------------------------------------------
    # Commands
    # ------------------------------------------------------------------
    def create_command(
        self,
        robot_id: str,
        command: str,
        idempotency_key: str,
        parameters: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        normalized = COMMAND_ALIASES.get(command.strip().lower())
        if normalized is None:
            raise ValueError(f"Unsupported command: {command}")

        with self._lock:
            robot = self._require(robot_id)
            if robot is None:
                raise KeyError(robot_id)
            for record in robot["commands"].values():
                if record["idempotency_key"] == idempotency_key:
                    return copy.deepcopy(record)
            command_id = f"cmd-{uuid4().hex[:12]}"
            record = {
                "id": command_id,
                "command_id": command_id,
                "robot_id": robot["id"],
                "command_type": normalized,
                "idempotency_key": idempotency_key,
                "state": "pending",
                "rejection_reason": None,
                "created_at": iso_now(),
                "updated_at": iso_now(),
                "parameters": copy.deepcopy(parameters or {}),
                "state_since": time.monotonic(),
            }
            robot["commands"][command_id] = record
            return copy.deepcopy(record)

    def get_command(self, command_id: str) -> dict[str, Any] | None:
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                if command_id in robot["commands"]:
                    return copy.deepcopy(robot["commands"][command_id])
        return None

    def set_command_state(
        self,
        command_id: str,
        state: str,
        rejection_reason: str | None = None,
    ) -> dict[str, Any] | None:
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                record = robot["commands"].get(command_id)
                if record is not None:
                    self._apply_command_state(robot, command_id, state, rejection_reason)
                    return copy.deepcopy(record)
        return None

    def _apply_command_state(
        self,
        robot: dict[str, Any],
        command_id: str,
        state: str,
        rejection_reason: str | None = None,
    ) -> None:
        record = robot["commands"].get(command_id)
        if record is None:
            return
        record["state"] = state
        record["updated_at"] = iso_now()
        record["state_since"] = time.monotonic()
        if rejection_reason:
            record["rejection_reason"] = rejection_reason

    def _active_command(self, robot: dict[str, Any]) -> dict[str, Any] | None:
        candidates = [
            record
            for record in robot["commands"].values()
            if record["state"] not in TERMINAL_STATES
        ]
        if not candidates:
            return None
        return max(candidates, key=lambda item: item["created_at"])

    # ------------------------------------------------------------------
    # Live command effects (used by the ROS bridge when real hardware runs)
    # ------------------------------------------------------------------
    def begin_live_command(self, command: dict[str, Any]) -> None:
        """Apply the robot-facing effect of a command on live hardware."""
        with self._lock:
            robot = self._require(command.get("robot_id"))
            if robot is None or command.get("command_type") == "requestStatusRefresh":
                return
            self._apply_command_effect(robot, command)
            self._touch(robot)

    def complete_live_command(self, command_id: str) -> None:
        """Archive/finish the effect of a command that reached a terminal state."""
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                command = robot["commands"].get(command_id)
                if command is not None:
                    self._complete_command_effect(robot, command)
                    self._touch(robot)
                    return

    def advance_live_progress(self, dt: float) -> None:
        """Estimate job progress from elapsed time while the robot works.

        Nav2 does not report coverage directly, so the backend maps elapsed
        time onto the zone's estimated duration. The Flutter progress screen
        therefore animates realistically on the real robot too.
        """
        with self._lock:
            robot = self.robot
            job = robot.get("active_job")
            if job is None:
                return
            if robot["status"] not in {"cleaning", "navigating", "returning"}:
                return
            job["elapsed_seconds"] = int(job.get("elapsed_seconds", 0)) + int(
                max(dt, 0.0)
            )
            target_seconds = float(job.get("target_seconds") or 0.0)
            if target_seconds <= 0.0:
                zone = self._find_zone(robot, job.get("zone_id")) or next(
                    (
                        item
                        for item in robot["zones"]
                        if item["name"] == job.get("zone_name")
                    ),
                    None,
                )
                target_seconds = (
                    float(zone["estimated_minutes"]) * 60.0 if zone else 900.0
                )
            progress = min(
                99.0, float(job["elapsed_seconds"]) / max(target_seconds, 1.0) * 100.0
            )
            job["progress_percentage"] = round(progress, 1)
            area = float(job.get("target_area_m2") or 0.0)
            if area <= 0.0:
                zone = self._find_zone(robot, job.get("zone_id"))
                area = (
                    float(zone["area_m2"])
                    if zone
                    else float(job.get("coverage_area_m2", 0.0))
                )
            job["coverage_area_m2"] = round(area * progress / 100.0, 1)
            self._touch(robot)

    # ------------------------------------------------------------------
    # Simulator
    # ------------------------------------------------------------------
    def simulate_step(self, dt: float) -> None:
        with self._lock:
            robot = self.robot
            if robot["is_charging"]:
                robot["battery_level"] = min(
                    100.0, float(robot["battery_level"]) + dt * 0.35
                )
            elif robot["status"] in {"cleaning", "navigating", "returning", "idle"}:
                drain = 0.02 if robot["status"] == "idle" else 0.09
                robot["battery_level"] = max(
                    0.0, float(robot["battery_level"]) - dt * drain
                )

            command = self._active_command(robot)
            now = time.monotonic()
            if command is not None:
                self._advance_command(robot, command, now)

            if robot["status"] in {"cleaning", "navigating"}:
                pose = robot["pose"]
                linear = 0.22 if robot["status"] == "cleaning" else 0.35
                pose["yaw"] += self._rng.uniform(-0.38, 0.38)
                pose["x"] = max(0.6, min(14.8, pose["x"] + math.cos(pose["yaw"]) * linear * dt))
                pose["y"] = max(0.6, min(9.4, pose["y"] + math.sin(pose["yaw"]) * linear * dt))
                robot["odom"] = {
                    "linear_x": round(linear, 2),
                    "angular_z": round(self._rng.uniform(-0.3, 0.3), 2),
                }
                robot["scan"] = {
                    "min_distance_m": round(self._rng.uniform(0.8, 3.5), 2),
                    "obstacle_count": self._rng.randint(0, 3),
                }
                job = robot.get("active_job")
                if job is not None:
                    job["progress_percentage"] = min(
                        99.5,
                        float(job.get("progress_percentage", 0.0)) + dt * 0.95,
                    )
                    job["elapsed_seconds"] = int(job.get("elapsed_seconds", 0)) + int(
                        dt
                    )
                    job["coverage_area_m2"] = round(
                        float(job.get("coverage_area_m2", 0.0)) + dt * 0.8, 1
                    )
                if robot["status"] == "cleaning":
                    robot["waste"]["fill_percentage"] = min(
                        100,
                        int(robot["waste"]["fill_percentage"])
                        + (1 if self._rng.random() < 0.02 else 0),
                    )
            else:
                robot["odom"] = {"linear_x": 0.0, "angular_z": 0.0}

            if self._rng.random() < dt / 45.0:
                score = round(self._rng.uniform(72, 97), 1)
                zone = (
                    robot["active_job"]["zone_name"]
                    if robot.get("active_job")
                    else "Lobby & Main Hall"
                )
                robot["cleanliness"] = {
                    "score": score,
                    "confidence": round(self._rng.uniform(0.72, 0.98), 2),
                    "timestamp": iso_now(),
                    "is_simulated": True,
                    "zone_name": zone,
                }

            if self._rng.random() < dt / 90.0:
                zones = [
                    zone["name"] for zone in robot["zones"]
                ] or ["Lobby & Main Hall"]
                self._add_notification(
                    robot,
                    "info",
                    "Navigation waypoint reached",
                    f"Waypoint acknowledged in {self._rng.choice(zones)}.",
                    "navigation",
                )

            if robot["waste"]["fill_percentage"] >= 90:
                robot["waste"]["sensor_fault"] = False
                robot["status"] = "returning"
                self._add_notification(
                    robot,
                    "warning",
                    "Waste container full",
                    "Returning to dock for container emptying.",
                    "waste",
                )
                robot["waste"]["fill_percentage"] = 20

            self._touch(robot)

            if self.simulated_robot:
                sim = self.simulated_robot
                if sim["is_charging"]:
                    sim["battery_level"] = min(
                        100, float(sim["battery_level"]) + dt * 0.5
                    )
                    if sim["battery_level"] >= 99:
                        sim["is_charging"] = False
                        sim["status"] = "idle"
                sim["last_updated_at"] = iso_now()
                sim["last_data_received_at"] = sim["last_updated_at"]

    def _advance_command(
        self, robot: dict[str, Any], command: dict[str, Any], now: float
    ) -> None:
        state = command["state"]
        elapsed = now - float(command.get("state_since", now))
        command_type = command["command_type"]

        if state == "pending" and elapsed > 0.2:
            self._apply_command_state(robot, command["id"], "dispatched")
        elif state == "dispatched" and elapsed > 0.4:
            self._apply_command_state(robot, command["id"], "accepted")
        elif state == "accepted" and elapsed > 0.7:
            self._apply_command_state(robot, command["id"], "executing")
            self._apply_command_effect(robot, command)
        elif state == "executing":
            duration = 9.0 if command_type in {"call", "returnToDock"} else 16.0
            if command_type in {
                "pause",
                "resume",
                "cancel",
                "requestStatusRefresh",
                "inspectFloor",
            }:
                duration = 2.0
            if elapsed > duration:
                self._apply_command_state(robot, command["id"], "completed")
                self._complete_command_effect(robot, command)

    def _apply_command_effect(
        self, robot: dict[str, Any], command: dict[str, Any]
    ) -> None:
        command_type = command["command_type"]
        parameters = command.get("parameters") or {}
        selected = self._selected_zones(robot, parameters)
        zone = selected[0] if selected else None
        zone_name = str(
            parameters.get("zone_name")
            or (
                ", ".join(str(item["name"]) for item in selected)
                if selected
                else "Lobby & Main Hall"
            )
        )

        if command_type == "call":
            robot["status"] = "navigating"
        elif command_type == "startCleaning":
            robot["status"] = "cleaning"
            robot["active_job"] = {
                "job_id": f"job-{uuid4().hex[:6]}",
                "zone_id": zone["id"] if zone else None,
                "zone_ids": [str(item["id"]) for item in selected],
                "zone_name": zone_name,
                "progress_percentage": 0.0,
                "elapsed_seconds": 0,
                "coverage_area_m2": 0.0,
                "target_seconds": sum(
                    float(item.get("estimated_minutes", 15)) * 60.0
                    for item in selected
                ),
                "target_area_m2": sum(
                    float(item.get("area_m2", 0.0)) for item in selected
                ),
            }
            self._add_notification(
                robot,
                "info",
                "Cleaning started",
                f"Autonomous cleaning started in {zone_name}.",
                "cleaning",
            )
        elif command_type == "pause":
            robot["status"] = "paused"
        elif command_type == "resume":
            robot["status"] = "cleaning"
        elif command_type == "cancel":
            robot["status"] = "idle"
            robot["active_job"] = None
        elif command_type == "inspectFloor":
            robot["status"] = "navigating"
        elif command_type == "returnToDock":
            robot["status"] = "returning"
        elif command_type == "requestStatusRefresh":
            robot["status"] = "idle"

    def _complete_command_effect(
        self, robot: dict[str, Any], command: dict[str, Any]
    ) -> None:
        command_type = command["command_type"]
        if command_type in {"startCleaning", "resume"}:
            job = robot.get("active_job")
            if job:
                job["progress_percentage"] = 100.0
                robot["history"].insert(0, self._history_from_job(robot, job))
            robot["active_job"] = None
            robot["status"] = "idle"
        elif command_type == "call":
            robot["status"] = "idle"
        elif command_type == "inspectFloor":
            robot["status"] = "idle"
            robot["cleanliness"] = {
                "score": round(self._rng.uniform(68, 95), 1),
                "confidence": round(self._rng.uniform(0.78, 0.97), 2),
                "timestamp": iso_now(),
                "is_simulated": robot["is_simulated"],
                "zone_name": (
                    robot["active_job"]["zone_name"]
                    if robot.get("active_job")
                    else "Lobby & Main Hall"
                ),
            }
        elif command_type == "returnToDock":
            robot["status"] = "charging"
            robot["is_charging"] = True
        elif command_type == "cancel":
            robot["status"] = "idle"

    def _history_from_job(
        self, robot: dict[str, Any], job: dict[str, Any]
    ) -> dict[str, Any]:
        return {
            "job_id": job["job_id"],
            "zone_id": job.get("zone_id") or "zone-auto",
            "zone_name": job["zone_name"],
            "started_at": iso_now(),
            "completed_at": iso_now(),
            "status": "completed",
            "coverage_area_m2": float(job.get("coverage_area_m2", 0.0)),
            "duration_seconds": int(job.get("elapsed_seconds", 0)),
            "battery_start": int(round(float(robot["battery_level"]))),
            "battery_end": int(round(float(robot["battery_level"]))),
            "operator": "Floor Operator",
        }

    @staticmethod
    def _find_zone(robot: dict[str, Any], zone_id: Any) -> dict[str, Any] | None:
        if not zone_id:
            return None
        for zone in robot["zones"]:
            if zone["id"] == zone_id:
                return zone
        return None

    def _selected_zones(
        self, robot: dict[str, Any], parameters: dict[str, Any]
    ) -> list[dict[str, Any]]:
        """Resolve the zone(s) a start-cleaning command refers to.

        The mobile app sends a ``zones`` list when several areas are selected;
        the single-zone REST route sends ``zone_id`` instead.
        """
        requested = parameters.get("zones") or parameters.get("zone_ids")
        if isinstance(requested, (list, tuple, set)):
            wanted = {str(item) for item in requested}
            selected = [zone for zone in robot["zones"] if zone["id"] in wanted]
            if selected:
                return selected
        single = self._find_zone(robot, parameters.get("zone_id"))
        return [single] if single is not None else []

    # ------------------------------------------------------------------
    # WebSocket snapshots
    # ------------------------------------------------------------------
    def ws_messages(self) -> list[dict[str, Any]]:
        """Return the current telemetry messages for connected clients."""
        messages: list[dict[str, Any]] = []
        with self._lock:
            for robot in filter(None, (self.robot, self.simulated_robot)):
                payload = {
                    "battery_level": int(round(float(robot["battery_level"]))),
                    "is_charging": bool(robot["is_charging"]),
                    "connection_state": robot["connection_state"],
                    "status": robot["status"],
                    "battery": int(round(float(robot["battery_level"]))),
                    "pose": copy.deepcopy(robot["pose"]),
                    "odom": copy.deepcopy(robot["odom"]),
                    "scan": copy.deepcopy(robot["scan"]),
                }
                messages.append(
                    self._ws(robot, "robot_state", payload)
                )
                messages.append(
                    self._ws(
                        robot,
                        "telemetry",
                        self.telemetry_for(robot),
                    )
                )
                if robot.get("active_job"):
                    job = robot["active_job"]
                    messages.append(
                        self._ws(
                            robot,
                            "job_progress",
                            {
                                "job_id": job.get("job_id"),
                                "zone_name": job.get("zone_name"),
                                "progress_percentage": job.get(
                                    "progress_percentage", 0
                                ),
                                "elapsed_seconds": job.get("elapsed_seconds", 0),
                                "coverage_area_m2": job.get("coverage_area_m2", 0),
                            },
                        )
                    )
                fingerprint = (
                    robot["waste"]["fill_percentage"],
                    robot["waste"]["sensor_fault"],
                )
                if robot.get("last_container_fingerprint") != fingerprint:
                    robot["last_container_fingerprint"] = fingerprint
                    messages.append(
                        self._ws(
                            robot,
                            "container_reading",
                            {
                                "fill_percentage": robot["waste"]["fill_percentage"],
                                "sensor_fault": robot["waste"]["sensor_fault"],
                            },
                        )
                    )
                cleanliness = robot.get("cleanliness") or {}
                clean_fingerprint = (
                    cleanliness.get("score"),
                    cleanliness.get("timestamp"),
                )
                if robot.get("last_clean_fingerprint") != clean_fingerprint:
                    robot["last_clean_fingerprint"] = clean_fingerprint
                    messages.append(
                        self._ws(
                            robot,
                            "cleanliness",
                            copy.deepcopy(cleanliness),
                        )
                    )
                command = self._active_command(robot)
                if command is not None:
                    messages.append(
                        self._ws(
                            robot,
                            "command_status",
                            {
                                "command_id": command["id"],
                                "command_type": command["command_type"],
                                "state": command["state"],
                                "rejection_reason": command.get("rejection_reason"),
                            },
                        )
                    )
        return messages

    @staticmethod
    def telemetry_for(robot: dict[str, Any]) -> dict[str, Any]:
        return {
            "robot_id": robot["id"],
            "battery": {
                "level": int(round(float(robot["battery_level"]))),
                "is_charging": bool(robot["is_charging"]),
            },
            "pose": copy.deepcopy(robot["pose"]),
            "odom": copy.deepcopy(robot["odom"]),
            "scan": copy.deepcopy(robot["scan"]),
            "status": robot["status"],
            "updated_at": robot["last_updated_at"],
        }

    @staticmethod
    def _ws(
        robot: dict[str, Any], message_type: str, payload: dict[str, Any]
    ) -> dict[str, Any]:
        return {
            "robot_id": robot["id"],
            "type": message_type,
            "timestamp": iso_now(),
            "is_simulated": bool(robot["is_simulated"]),
            "payload": copy.deepcopy(payload),
        }
