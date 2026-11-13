"""ROS 2 <-> REST/WebSocket bridge.

The bridge runs rclpy in a dedicated thread so the FastAPI event loop never
blocks. When ROS 2 is not installed (desktop development) or the bridge is
explicitly forced into simulation, a deterministic simulator feeds the same
state store so the mobile app remains fully usable.
"""

from __future__ import annotations

import json
import logging
import math
import queue
import threading
import time
from typing import Any

from .config import Settings
from .state import RobotStore

LOGGER = logging.getLogger("cleanbot.ros")


def _yaw_from_quaternion(x: float, y: float, z: float, w: float) -> float:
    siny_cosp = 2.0 * (w * z + x * y)
    cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
    return math.atan2(siny_cosp, cosy_cosp)


class RosBridge:
    def __init__(self, store: RobotStore, config: Settings) -> None:
        self.store = store
        self.config = config
        self._commands: queue.Queue[dict[str, Any]] = queue.Queue()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._simulator_thread: threading.Thread | None = None
        self._node: Any = None
        self._publishers: dict[str, Any] = {}
        self._action_client: Any = None
        self._nav_goal_handle: Any = None

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def start(self) -> None:
        if self._thread is not None or self._simulator_thread is not None:
            return
        if self.config.force_simulation:
            LOGGER.info("CLEANBOT_FORCE_SIMULATION is enabled; starting simulator")
            self._start_simulator()
            return

        self._thread = threading.Thread(
            target=self._run_ros, name="cleanbot-ros-bridge", daemon=True
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        node = self._node
        if node is not None:
            try:
                node.destroy_node()
            except Exception:  # pragma: no cover - best effort shutdown
                pass
        try:
            import rclpy

            if rclpy.ok():
                rclpy.shutdown()
        except Exception:  # pragma: no cover
            pass
        for thread in (self._thread, self._simulator_thread):
            if thread is not None and thread.is_alive():
                thread.join(timeout=3.0)

    def _start_simulator(self) -> None:
        self.store.set_ros_state(False, "ROS 2 unavailable — simulator active")
        self.store.set_hardware_state(False)

        def _loop() -> None:
            last = time.monotonic()
            while not self._stop.is_set():
                time.sleep(0.5)
                now = time.monotonic()
                dt = min(2.0, now - last)
                last = now
                self.store.simulate_step(dt)

        self._simulator_thread = threading.Thread(
            target=_loop, name="cleanbot-simulator", daemon=True
        )
        self._simulator_thread.start()

    # ------------------------------------------------------------------
    # ROS setup
    # ------------------------------------------------------------------
    def _run_ros(self) -> None:
        try:
            import rclpy
            from geometry_msgs.msg import PoseStamped
            from nav_msgs.msg import OccupancyGrid, Odometry
            from rclpy.node import Node
            from sensor_msgs.msg import BatteryState, LaserScan
            from std_msgs.msg import String
        except Exception as exc:  # pragma: no cover - depends on Pi install
            LOGGER.warning("rclpy / ROS 2 messages unavailable: %s", exc)
            if self.config.simulate_when_ros_missing:
                self._start_simulator()
            else:
                self.store.set_ros_state(False, f"ROS 2 not available: {exc}")
            return

        try:
            rclpy.init(args=None)
            node = Node("cleanbot_api_bridge")
            self._node = node

            self._publishers["hardware"] = node.create_publisher(
                String, self.config.ros_topic_hardware_command, 10
            )
            self._publishers["cmd_vel"] = node.create_publisher(
                __import__("geometry_msgs.msg", fromlist=["Twist"]).Twist,
                self.config.ros_topic_cmd_vel,
                10,
            )
            self._publishers["goal_pose"] = node.create_publisher(
                PoseStamped, self.config.ros_topic_goal_pose, 10
            )

            node.create_subscription(
                BatteryState, self.config.ros_topic_battery, self._on_battery, 10
            )
            node.create_subscription(
                Odometry, self.config.ros_topic_odom, self._on_odom, 20
            )
            node.create_subscription(
                LaserScan, self.config.ros_topic_scan, self._on_scan, 10
            )
            node.create_subscription(
                PoseStamped,
                self.config.ros_topic_amcl,
                self._on_amcl_pose,
                10,
            )
            node.create_subscription(
                OccupancyGrid, self.config.ros_topic_map, self._on_map, 2
            )
            node.create_subscription(
                String, self.config.ros_topic_status, self._on_status, 10
            )
            node.create_subscription(
                String,
                self.config.ros_topic_detections,
                self._on_detections,
                10,
            )

            try:
                from nav2_msgs.action import NavigateToPose
                from rclpy.action import ActionClient

                self._action_client = ActionClient(
                    node, NavigateToPose, "navigate_to_pose"
                )
            except Exception:
                self._action_client = None
                LOGGER.info("nav2_msgs not available; publishing /goal_pose instead")

            node.create_timer(0.1, self._drain_commands)
            node.create_timer(1.0, self._heartbeat)

            self.store.set_ros_state(True, "ROS 2 bridge connected")
            LOGGER.info("ROS 2 bridge started (domain %s)", self.config.ros_domain_id)
            rclpy.spin(node)
        except Exception as exc:  # pragma: no cover
            LOGGER.exception("ROS bridge crashed: %s", exc)
            self.store.set_ros_state(False, f"ROS bridge error: {exc}")
        finally:
            self.store.set_ros_state(False, "ROS 2 bridge stopped")
            self.store.set_hardware_state(False)
            try:
                import rclpy

                if rclpy.ok():
                    rclpy.shutdown()
            except Exception:
                pass

    def _heartbeat(self) -> None:
        # The hardware driver reports this flag through /cleanbot/status.
        self.store.set_ros_state(True, "ROS 2 bridge connected")
        if self._simulator_thread is None:
            self.store.advance_live_progress(1.0)

    # ------------------------------------------------------------------
    # Subscribers
    # ------------------------------------------------------------------
    def _on_battery(self, msg: Any) -> None:
        percentage = float(getattr(msg, "percentage", 0.0))
        if 0.0 <= percentage <= 1.5:
            percentage *= 100.0
        status = int(getattr(msg, "power_supply_status", 0))
        charging = status in {1, 4}
        self.store.update_battery(percentage, charging)

    def _on_odom(self, msg: Any) -> None:
        pose = msg.pose.pose
        orientation = pose.orientation
        self.store.update_odom(
            pose.position.x,
            pose.position.y,
            _yaw_from_quaternion(
                orientation.x, orientation.y, orientation.z, orientation.w
            ),
            msg.twist.twist.linear.x,
            msg.twist.twist.angular.z,
        )

    def _on_scan(self, msg: Any) -> None:
        valid = [
            float(value)
            for value in msg.ranges
            if math.isfinite(value) and float(value) > 0.01
        ]
        min_distance = min(valid) if valid else 0.0
        obstacles = len([value for value in valid if value < 1.0])
        self.store.update_scan(min_distance, obstacles)

    def _on_amcl_pose(self, msg: Any) -> None:
        pose = msg.pose.pose
        orientation = pose.orientation
        self.store.update_pose(
            pose.position.x,
            pose.position.y,
            _yaw_from_quaternion(
                orientation.x, orientation.y, orientation.z, orientation.w
            ),
        )

    def _on_map(self, msg: Any) -> None:
        origin = msg.info.origin
        q = origin.orientation
        self.store.update_map(
            int(msg.info.width),
            int(msg.info.height),
            float(msg.info.resolution),
            {
                "x": float(origin.position.x),
                "y": float(origin.position.y),
                "yaw": _yaw_from_quaternion(q.x, q.y, q.z, q.w),
            },
            list(msg.data),
        )

    def _on_status(self, msg: Any) -> None:
        try:
            payload = json.loads(msg.data)
            if isinstance(payload, dict):
                if "hardware_connected" in payload:
                    self.store.set_hardware_state(
                        bool(payload["hardware_connected"])
                    )
                self.store.update_status(payload)
        except (json.JSONDecodeError, TypeError):
            LOGGER.debug("Ignoring malformed /cleanbot/status payload")

    def _on_detections(self, msg: Any) -> None:
        try:
            payload = json.loads(msg.data)
            detections = payload if isinstance(payload, list) else payload.get(
                "detections", []
            )
            if isinstance(detections, list):
                self.store.update_detections(detections)
        except (json.JSONDecodeError, TypeError, AttributeError):
            LOGGER.debug("Ignoring malformed /cleanbot/detections payload")

    # ------------------------------------------------------------------
    # Command dispatch
    # ------------------------------------------------------------------
    def dispatch(self, command: dict[str, Any]) -> None:
        """Queue a command for the ROS thread (thread-safe)."""
        self._commands.put(command)
        if self._simulator_thread is not None:
            # The simulator advances command states itself.
            return

    def _drain_commands(self) -> None:
        while True:
            try:
                command = self._commands.get_nowait()
            except queue.Empty:
                return
            try:
                self._execute_command(command)
            except Exception as exc:  # pragma: no cover - runtime safety
                LOGGER.exception("Failed to dispatch command: %s", exc)
                self.store.set_command_state(
                    command["id"], "failed", rejection_reason=str(exc)
                )

    def _execute_command(self, command: dict[str, Any]) -> None:
        command_type = command["command_type"]
        command_id = command["id"]
        parameters = command.get("parameters") or {}

        self.store.set_command_state(command_id, "dispatched")
        # Apply the robot-facing effect immediately so the dashboard reflects
        # the new status without waiting for the next simulator tick.
        self.store.begin_live_command(command)

        payload = json.dumps(
            {
                "command": command_type,
                "command_id": command_id,
                "parameters": parameters,
                "stop": command_type
                in {"pause", "cancel", "returnToDock"},
            }
        )
        hardware_publisher = self._publishers.get("hardware")
        if hardware_publisher is not None:
            from std_msgs.msg import String

            hardware_publisher.publish(String(data=payload))

        if command_type in {"pause", "cancel"}:
            self._cancel_navigation()
            self._stop_base()
            self.store.set_command_state(command_id, "accepted")
            self.store.set_command_state(command_id, "executing")
            self.store.complete_live_command(command_id)
            self.store.set_command_state(command_id, "completed")
            return

        if command_type in {"startCleaning", "call", "inspectFloor", "returnToDock"}:
            target = parameters.get("target")
            if not target:
                target = self._target_for(command_type, parameters)
            if target is not None:
                self._send_navigation_goal(command_id, target)
            else:
                self.store.set_command_state(command_id, "accepted")
                self.store.set_command_state(command_id, "executing")
            return

        if command_type == "resume":
            target = parameters.get("target")
            if target:
                self._send_navigation_goal(command_id, target)
            else:
                self.store.set_command_state(command_id, "accepted")
                self.store.set_command_state(command_id, "executing")
            return

        if command_type == "requestStatusRefresh":
            self.store.set_command_state(command_id, "accepted")
            self.store.set_command_state(command_id, "completed")
            return

        self.store.set_command_state(command_id, "accepted")
        self.store.set_command_state(command_id, "executing")

    def _target_for(
        self, command_type: str, parameters: dict[str, Any]
    ) -> dict[str, float] | None:
        zones = self.store.zones()
        if command_type == "returnToDock":
            return {"x": 0.7, "y": 0.7, "yaw": 0.0}
        if command_type == "call":
            return {"x": 1.2, "y": 1.1, "yaw": 0.0}
        zone_id = parameters.get("zone_id")
        for zone in zones:
            if zone["id"] == zone_id:
                points = zone.get("polygon") or []
                if points:
                    return {
                        "x": sum(point["x"] for point in points) / len(points),
                        "y": sum(point["y"] for point in points) / len(points),
                        "yaw": 0.0,
                    }
        return None

    def _send_navigation_goal(
        self, command_id: str, target: dict[str, float]
    ) -> None:
        try:
            import rclpy
            from geometry_msgs.msg import PoseStamped
            from std_msgs.msg import String
        except Exception:  # pragma: no cover
            self.store.set_command_state(command_id, "failed")
            return

        if self._action_client is not None:
            from nav2_msgs.action import NavigateToPose

            goal = NavigateToPose.Goal()
            goal.pose.header.frame_id = self.config.map_frame
            goal.pose.header.stamp = self._node.get_clock().now().to_msg()
            goal.pose.pose.position.x = float(target["x"])
            goal.pose.pose.position.y = float(target["y"])
            goal.pose.pose.orientation.z = math.sin(float(target.get("yaw", 0)) / 2)
            goal.pose.pose.orientation.w = math.cos(float(target.get("yaw", 0)) / 2)
            if not self._action_client.wait_for_server(timeout_sec=2.0):
                self.store.set_command_state(
                    command_id, "failed", "Nav2 action server unavailable"
                )
                return
            future = self._action_client.send_goal_async(goal)
            future.add_done_callback(
                lambda done: self._on_goal_response(done, command_id)
            )
        else:
            pose = PoseStamped()
            pose.header.frame_id = self.config.map_frame
            pose.header.stamp = self._node.get_clock().now().to_msg()
            pose.pose.position.x = float(target["x"])
            pose.pose.position.y = float(target["y"])
            pose.pose.orientation.z = math.sin(float(target.get("yaw", 0)) / 2)
            pose.pose.orientation.w = math.cos(float(target.get("yaw", 0)) / 2)
            publisher = self._publishers.get("goal_pose")
            if publisher is not None:
                publisher.publish(pose)
            self.store.set_command_state(command_id, "accepted")

    def _on_goal_response(self, future: Any, command_id: str) -> None:
        """Handle Nav2 goal acceptance and subscribe to the result."""
        try:
            goal_handle = future.result()
        except Exception as exc:  # pragma: no cover - action transport errors
            LOGGER.exception("Navigation goal failed: %s", exc)
            self.store.set_command_state(command_id, "failed", str(exc))
            return

        if goal_handle is None or not goal_handle.accepted:
            self.store.set_command_state(
                command_id, "rejected", "Navigation goal rejected"
            )
            return

        self._nav_goal_handle = goal_handle
        self.store.set_command_state(command_id, "accepted")
        result_future = goal_handle.get_result_async()
        result_future.add_done_callback(
            lambda done: self._on_goal_result(done, command_id)
        )

    def _on_goal_result(self, future: Any, command_id: str) -> None:
        """Mark the command complete/failed when Nav2 finishes the goal."""
        self._nav_goal_handle = None
        try:
            wrapped = future.result()
        except Exception as exc:  # pragma: no cover - cancellation/transport
            LOGGER.warning("Navigation result unavailable for %s: %s", command_id, exc)
            self.store.set_command_state(command_id, "failed", str(exc))
            return

        status = getattr(wrapped, "status", None)
        if status == 4:  # action_msgs/GoalStatus.STATUS_SUCCEEDED
            self.store.complete_live_command(command_id)
            self.store.set_command_state(command_id, "completed")
        elif status == 5:  # STATUS_CANCELED
            self.store.set_command_state(command_id, "cancelled")
        elif status == 6:  # STATUS_ABORTED
            self.store.set_command_state(command_id, "failed", "Navigation aborted")
            self.store.complete_live_command(command_id)

    def _cancel_navigation(self) -> None:
        if self._nav_goal_handle is not None:
            try:
                self._nav_goal_handle.cancel_goal_async()
            except Exception:
                pass
            self._nav_goal_handle = None
        if self._action_client is not None:
            try:
                self._action_client.cancel_goal_async()
            except Exception:
                pass
        try:
            from geometry_msgs.msg import Twist

            publisher = self._publishers.get("cmd_vel")
            if publisher is not None:
                publisher.publish(Twist())
        except Exception:
            pass

    def _stop_base(self) -> None:
        try:
            from geometry_msgs.msg import Twist

            publisher = self._publishers.get("cmd_vel")
            if publisher is not None:
                publisher.publish(Twist())
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Manual drive
    # ------------------------------------------------------------------
    def manual_drive(self, linear_x: float, angular_z: float, duration_ms: int) -> None:
        if self._simulator_thread is not None:
            pose = self.store.robot["pose"]
            pose["yaw"] += angular_z * (duration_ms / 1000.0)
            pose["x"] += math.cos(pose["yaw"]) * linear_x * (duration_ms / 1000.0)
            pose["y"] += math.sin(pose["yaw"]) * linear_x * (duration_ms / 1000.0)
            self.store.update_odom(
                pose["x"], pose["y"], pose["yaw"], linear_x, angular_z
            )
            return

        try:
            from geometry_msgs.msg import Twist

            publisher = self._publishers.get("cmd_vel")
            if publisher is None:
                return
            twist = Twist()
            twist.linear.x = float(linear_x)
            twist.angular.z = float(angular_z)
            publisher.publish(twist)

            def _stop() -> None:
                stop = Twist()
                if publisher is not None:
                    publisher.publish(stop)

            timer = threading.Timer(max(0.05, duration_ms / 1000.0), _stop)
            timer.daemon = True
            timer.start()
        except Exception:
            LOGGER.exception("Manual drive failed")

    def publish_estop(self, engaged: bool = True) -> None:
        if self._simulator_thread is not None:
            self.store.update_status({"status": "fault"})
            return
        hardware = self._publishers.get("hardware")
        if hardware is None:
            return
        try:
            from std_msgs.msg import String

            hardware.publish(String(data=json.dumps({"command": "estop", "stop": engaged})))
        except Exception:
            pass
        if engaged:
            self._cancel_navigation()
