#!/usr/bin/env python3
"""ROS 2 hardware driver for the CleanBot differential-drive base.

Responsibilities
----------------
* Own the serial link to the ESP32/Arduino motor controller.
* Convert wheel encoder ticks into ``nav_msgs/Odometry`` and the
  ``odom -> base_link`` transform.
* Publish ``sensor_msgs/BatteryState`` and a JSON heartbeat on
  ``/cleanbot/status`` that the FastAPI backend consumes.
* Translate ``geometry_msgs/Twist`` into motor commands with a watchdog so
  the base stops if Nav2 or the operator stops sending commands.
* Execute high-level cleaning / e-stop commands coming from the backend on
  ``/cleanbot/hardware_command``.

The node is deliberately defensive: a serial failure never crashes the ROS
graph, it only disables motion and reports ``hardware_connected: false``.
"""

from __future__ import annotations

import json
import math
import threading
import time
from typing import Any

import rclpy
from geometry_msgs.msg import TransformStamped, Twist
from nav_msgs.msg import Odometry
from rclpy.node import Node
from sensor_msgs.msg import BatteryState
from std_msgs.msg import Bool, String
from tf2_ros import TransformBroadcaster

from . import serial_protocol as proto

try:  # serial is optional at import time so the node can be inspected on a PC
    import serial
    from serial import SerialException
except Exception:  # pragma: no cover - depends on pyserial being installed
    serial = None

    class SerialException(Exception):
        """Fallback so ``except SerialException`` never raises."""


class HardwareDriver(Node):
    """Serial <-> ROS 2 bridge for the CleanBot base."""

    def __init__(self) -> None:
        super().__init__("cleanbot_hardware_driver")

        # ---------------------------------------------------------------
        # Parameters
        # ---------------------------------------------------------------
        self.declare_parameter("serial_port", "/dev/serial0")
        self.declare_parameter("baudrate", 115200)
        self.declare_parameter("robot_id", "robot-alpha-01")
        self.declare_parameter("wheel_radius", 0.065)
        self.declare_parameter("wheel_separation", 0.34)
        self.declare_parameter("ticks_per_revolution", 1320.0)
        self.declare_parameter("odom_frame", "odom")
        self.declare_parameter("base_frame", "base_link")
        self.declare_parameter("cmd_vel_topic", "/cmd_vel")
        self.declare_parameter("odom_topic", "/odom")
        self.declare_parameter("battery_topic", "/battery_state")
        self.declare_parameter("status_topic", "/cleanbot/status")
        self.declare_parameter("hardware_command_topic", "/cleanbot/hardware_command")
        self.declare_parameter("estop_topic", "/cleanbot/estop")
        self.declare_parameter("publish_rate", 30.0)
        self.declare_parameter("status_rate", 2.0)
        self.declare_parameter("command_timeout", 0.6)
        self.declare_parameter("max_linear_speed", 0.55)
        self.declare_parameter("max_angular_speed", 1.8)
        self.declare_parameter("battery_min_voltage", 9.6)
        self.declare_parameter("battery_max_voltage", 12.6)
        self.declare_parameter("battery_cells", 3)
        self.declare_parameter("reconnect_interval", 2.0)

        self.serial_port: str = self.get_parameter("serial_port").value
        self.baudrate: int = int(self.get_parameter("baudrate").value)
        self.robot_id: str = self.get_parameter("robot_id").value
        self.wheel_radius: float = float(self.get_parameter("wheel_radius").value)
        self.wheel_separation: float = float(
            self.get_parameter("wheel_separation").value
        )
        self.ticks_per_revolution: float = float(
            self.get_parameter("ticks_per_revolution").value
        )
        self.odom_frame: str = self.get_parameter("odom_frame").value
        self.base_frame: str = self.get_parameter("base_frame").value
        self.cmd_vel_topic: str = self.get_parameter("cmd_vel_topic").value
        self.odom_topic: str = self.get_parameter("odom_topic").value
        self.battery_topic: str = self.get_parameter("battery_topic").value
        self.status_topic: str = self.get_parameter("status_topic").value
        self.hardware_command_topic: str = self.get_parameter(
            "hardware_command_topic"
        ).value
        self.estop_topic: str = self.get_parameter("estop_topic").value
        self.publish_rate: float = float(self.get_parameter("publish_rate").value)
        self.status_rate: float = float(self.get_parameter("status_rate").value)
        self.command_timeout: float = float(
            self.get_parameter("command_timeout").value
        )
        self.max_linear_speed: float = float(
            self.get_parameter("max_linear_speed").value
        )
        self.max_angular_speed: float = float(
            self.get_parameter("max_angular_speed").value
        )
        self.battery_min_voltage: float = float(
            self.get_parameter("battery_min_voltage").value
        )
        self.battery_max_voltage: float = float(
            self.get_parameter("battery_max_voltage").value
        )
        self.battery_cells: int = int(self.get_parameter("battery_cells").value)
        self.reconnect_interval: float = float(
            self.get_parameter("reconnect_interval").value
        )

        self.distance_per_tick = (
            2.0 * math.pi * self.wheel_radius / max(self.ticks_per_revolution, 1.0)
        )

        # ---------------------------------------------------------------
        # Shared state (guarded by ``_lock``)
        # ---------------------------------------------------------------
        self._lock = threading.RLock()
        self._write_lock = threading.Lock()
        self._serial: Any = None
        self._reader: threading.Thread | None = None
        self._running = True
        self._connected = False
        self._last_rx = 0.0
        self._last_tx = 0.0
        self._last_reconnect_attempt = 0.0

        self._left_ticks = 0
        self._right_ticks = 0
        self._last_left_ticks = 0
        self._last_right_ticks = 0

        self._x = 0.0
        self._y = 0.0
        self._yaw = 0.0
        self._linear = 0.0
        self._angular = 0.0

        self._battery_voltage = 0.0
        self._battery_percentage = 0.0
        self._charging = False
        self._estop = False
        self._estop_latched = False
        self._brush_on = False
        self._cleaning_mode = "standard"
        self._cleaning_speed = 1.0
        self._waste_fill = 0
        self._waste_fault = False
        self._cliff = False
        self._bumper = False
        self._firmware_version = "unknown"
        self._last_event = ""

        self._target_linear = 0.0
        self._target_angular = 0.0
        self._last_cmd_vel_at = 0.0

        self._active_command_id: str | None = None
        self._active_command_type: str | None = None

        # ---------------------------------------------------------------
        # ROS interfaces
        # ---------------------------------------------------------------
        self._odom_pub = self.create_publisher(Odometry, self.odom_topic, 20)
        self._battery_pub = self.create_publisher(
            BatteryState, self.battery_topic, 10
        )
        self._status_pub = self.create_publisher(String, self.status_topic, 10)
        self._tf_broadcaster = TransformBroadcaster(self)

        self.create_subscription(Twist, self.cmd_vel_topic, self._on_cmd_vel, 20)
        self.create_subscription(Bool, self.estop_topic, self._on_estop, 10)
        self.create_subscription(
            String, self.hardware_command_topic, self._on_hardware_command, 10
        )

        period = 1.0 / max(self.publish_rate, 1.0)
        self.create_timer(period, self._tick)
        self.create_timer(1.0 / max(self.status_rate, 0.1), self._publish_status)
        self.create_timer(0.5, self._connection_watchdog)

        self.get_logger().info(
            "CleanBot hardware driver starting on %s @ %d baud"
            % (self.serial_port, self.baudrate)
        )
        self._connect()

    # ------------------------------------------------------------------
    # Serial link
    # ------------------------------------------------------------------
    def _connect(self) -> bool:
        if serial is None:
            self.get_logger().error("pyserial is not installed (python3-serial)")
            self._connected = False
            return False
        if self._serial is not None:
            self._connected = True
            return True

        try:
            self._serial = serial.Serial(
                self.serial_port,
                self.baudrate,
                timeout=0.1,
                write_timeout=0.5,
            )
        except (SerialException, OSError) as exc:
            self._serial = None
            self._connected = False
            self.get_logger().error(
                "Serial connection failed (%s): %s" % (self.serial_port, exc)
            )
            return False

        self._connected = True
        self._last_rx = time.monotonic()
        time.sleep(0.2)
        self._send(proto.request_status())
        self._start_reader()

        self.get_logger().info("Serial link established on %s" % self.serial_port)
        return True

    def _start_reader(self) -> None:
        if self._reader is not None and self._reader.is_alive():
            return
        self._reader = threading.Thread(
            target=self._read_loop, name="cleanbot-serial-reader", daemon=True
        )
        self._reader.start()

    def _disconnect(self, reason: str = "") -> None:
        with self._lock:
            was_connected = self._connected
            self._connected = False
            self._brush_on = False
            self._target_linear = 0.0
            self._target_angular = 0.0
            port = self._serial
            self._serial = None
        if port is not None:
            try:
                port.close()
            except Exception:  # pragma: no cover - best effort
                pass
        if was_connected:
            self.get_logger().warning("Serial link lost: %s" % (reason or "unknown"))

    def _read_loop(self) -> None:
        while self._running:
            port = self._serial
            if port is None:
                time.sleep(0.2)
                continue
            try:
                line = port.readline()
            except (SerialException, OSError) as exc:
                self._disconnect(str(exc))
                continue

            if not line:
                continue

            message = proto.decode(line)
            if message is None:
                continue
            self._last_rx = time.monotonic()
            try:
                self._handle_firmware_message(message)
            except Exception as exc:  # pragma: no cover - runtime safety
                self.get_logger().error("Bad firmware message: %s" % exc)

    def _send(self, message: dict[str, Any]) -> bool:
        port = self._serial
        if port is None:
            return False
        try:
            with self._write_lock:
                port.write(proto.encode(message))
                port.flush()
            self._last_tx = time.monotonic()
            return True
        except (SerialException, OSError) as exc:
            self._disconnect(str(exc))
            return False

    def _connection_watchdog(self) -> None:
        if not self._running:
            return
        if self._serial is None:
            now = time.monotonic()
            if now - self._last_reconnect_attempt >= self.reconnect_interval:
                self._last_reconnect_attempt = now
                self._connect()
            return

        # Firmware streams telemetry at ~20 Hz; 1.5 s silence is a fault.
        if self._connected and time.monotonic() - self._last_rx > 1.5:
            self._disconnect("telemetry timeout")

    # ------------------------------------------------------------------
    # Firmware messages
    # ------------------------------------------------------------------
    def _handle_firmware_message(self, message: dict[str, Any]) -> None:
        message_type = str(message.get("type", ""))

        if message_type == proto.MSG_HELLO:
            with self._lock:
                self._firmware_version = str(
                    message.get("firmware", self._firmware_version)
                )
            self.get_logger().info("Firmware %s online" % self._firmware_version)
            return

        if message_type == proto.MSG_ACK:
            self.get_logger().debug("Firmware ack: %s" % message)
            return

        if message_type == proto.MSG_EVENT:
            event = str(message.get("event", "unknown"))
            with self._lock:
                self._last_event = event
            self.get_logger().info("Firmware event: %s" % event)
            return

        if message_type != proto.MSG_TELEMETRY:
            return

        with self._lock:
            if "left_ticks" in message:
                self._left_ticks = int(message["left_ticks"])
            if "right_ticks" in message:
                self._right_ticks = int(message["right_ticks"])

            voltage = message.get("battery_voltage")
            if voltage is not None:
                self._battery_voltage = float(voltage)
                self._battery_percentage = self._voltage_to_percentage(
                    self._battery_voltage
                )

            if "charging" in message:
                self._charging = bool(message["charging"])
            if "estop" in message:
                self._estop = bool(message["estop"])
            if "brush" in message:
                self._brush_on = bool(message["brush"])
            if "waste_fill" in message:
                self._waste_fill = max(0, min(100, int(message["waste_fill"])))
            if "waste_sensor_fault" in message:
                self._waste_fault = bool(message["waste_sensor_fault"])
            if "cliff" in message:
                self._cliff = bool(message["cliff"])
            if "bumper" in message:
                self._bumper = bool(message["bumper"])
            if "firmware" in message:
                self._firmware_version = str(message["firmware"])

        # Hardware safety interlocks always win over remote commands.
        if self._estop or self._cliff or self._bumper:
            self._emergency_stop_latched()

        self._integrate_odometry()

    def _voltage_to_percentage(self, voltage: float) -> float:
        span = max(self.battery_max_voltage - self.battery_min_voltage, 0.1)
        ratio = (voltage - self.battery_min_voltage) / span
        return max(0.0, min(1.0, ratio))

    def _emergency_stop_latched(self) -> None:
        with self._lock:
            self._estop_latched = True
            self._target_linear = 0.0
            self._target_angular = 0.0
            self._brush_on = False
        self._send(proto.stop())
        self._send(proto.cleaning(False))

    # ------------------------------------------------------------------
    # Odometry
    # ------------------------------------------------------------------
    def _integrate_odometry(self) -> None:
        with self._lock:
            d_left = (self._left_ticks - self._last_left_ticks) * self.distance_per_tick
            d_right = (
                self._right_ticks - self._last_right_ticks
            ) * self.distance_per_tick
            self._last_left_ticks = self._left_ticks
            self._last_right_ticks = self._right_ticks

            distance = (d_left + d_right) / 2.0
            d_theta = (d_right - d_left) / max(self.wheel_separation, 1e-3)

            # Midpoint integration keeps the estimate stable at low tick rates.
            mid_theta = self._yaw + d_theta / 2.0
            self._x += distance * math.cos(mid_theta)
            self._y += distance * math.sin(mid_theta)
            self._yaw = self._normalise_angle(self._yaw + d_theta)

    @staticmethod
    def _normalise_angle(angle: float) -> float:
        while angle > math.pi:
            angle -= 2.0 * math.pi
        while angle < -math.pi:
            angle += 2.0 * math.pi
        return angle

    # ------------------------------------------------------------------
    # Command handling
    # ------------------------------------------------------------------
    def _on_cmd_vel(self, msg: Twist) -> None:
        with self._lock:
            if self._estop_latched:
                return
            self._target_linear = max(
                -self.max_linear_speed, min(self.max_linear_speed, msg.linear.x)
            )
            self._target_angular = max(
                -self.max_angular_speed, min(self.max_angular_speed, msg.angular.z)
            )
            self._last_cmd_vel_at = time.monotonic()

    def _on_estop(self, msg: Bool) -> None:
        if msg.data:
            self._latch_estop()
        else:
            self._release_estop()

    def _latch_estop(self) -> None:
        self.get_logger().warning("E-stop engaged")
        with self._lock:
            self._estop_latched = True
            self._estop = True
            self._target_linear = 0.0
            self._target_angular = 0.0
            self._brush_on = False
        self._send(proto.estop(True))
        self._send(proto.stop())
        self._send(proto.cleaning(False))

    def _release_estop(self) -> None:
        with self._lock:
            if self._estop:
                # A stuck physical button must not be overridden remotely.
                self.get_logger().warning("E-stop release requested")
                self._estop_latched = False
            self._estop = False
        self._send(proto.estop(False))

    def _on_hardware_command(self, msg: String) -> None:
        try:
            payload = json.loads(msg.data)
        except (json.JSONDecodeError, TypeError):
            self.get_logger().warning("Ignoring malformed hardware command")
            return
        if not isinstance(payload, dict):
            return

        command = str(payload.get("command", "")).strip()
        command_id = payload.get("command_id")
        parameters = payload.get("parameters") or {}

        if not command:
            return

        self.get_logger().info(
            "Hardware command %s (%s)" % (command, command_id or "no-id")
        )

        with self._lock:
            self._active_command_id = str(command_id) if command_id else None
            self._active_command_type = command

        if command in {"estop", "emergencyStop"}:
            engage = bool(payload.get("stop", True))
            self._latch_estop() if engage else self._release_estop()
            self._finish_command("completed")
            return

        if command in {"pause", "cancel", "stop"}:
            with self._lock:
                self._target_linear = 0.0
                self._target_angular = 0.0
                self._brush_on = False
            self._send(proto.stop())
            self._send(proto.cleaning(False))
            self._finish_command("completed")
            return

        if command == "requestStatusRefresh":
            self._send(proto.request_status())
            self._publish_status()
            self._finish_command("completed")
            return

        if command in {"startCleaning", "resume", "inspectFloor"}:
            mode = str(parameters.get("cleaning_mode", self._cleaning_mode))
            speed = float(parameters.get("cleaning_speed", 1.0))
            with self._lock:
                self._cleaning_mode = mode
                self._cleaning_speed = max(0.1, min(1.0, speed))
                self._brush_on = True
            self._send(proto.cleaning(True, self._cleaning_mode, self._cleaning_speed))
            # Navigation drives /cmd_vel; hardware simply arms the cleaning deck.
            self._finish_command("executing")
            return

        if command == "returnToDock":
            with self._lock:
                self._brush_on = False
            self._send(proto.cleaning(False))
            self._finish_command("executing")
            return

        if command == "call":
            self._finish_command("executing")
            return

        # Unknown commands are acknowledged so the backend does not hang.
        self._finish_command("accepted")

    def _finish_command(self, state: str) -> None:
        command_id = self._active_command_id
        if not command_id:
            return
        self._publish_status(extra={"command_id": command_id, "command_state": state})
        if state in {"completed", "rejected", "failed"}:
            with self._lock:
                self._active_command_id = None
                self._active_command_type = None

    # ------------------------------------------------------------------
    # Periodic loop
    # ------------------------------------------------------------------
    def _tick(self) -> None:
        now = time.monotonic()
        with self._lock:
            if self._estop_latched:
                self._target_linear = 0.0
                self._target_angular = 0.0
            elif now - self._last_cmd_vel_at > self.command_timeout:
                # Watchdog: Nav2 died or the operator released the stick.
                self._target_linear = 0.0
                self._target_angular = 0.0

            linear = self._target_linear
            angular = self._target_angular
            x = self._x
            y = self._y
            yaw = self._yaw

        if self._connected:
            self._send(proto.cmd_vel(linear, angular))

        self._publish_odometry(x, y, yaw, linear, angular)
        self._publish_odom_tf(x, y, yaw)

    def _publish_odometry(
        self, x: float, y: float, yaw: float, linear: float, angular: float
    ) -> None:
        msg = Odometry()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = self.odom_frame
        msg.child_frame_id = self.base_frame

        msg.pose.pose.position.x = x
        msg.pose.pose.position.y = y
        msg.pose.pose.position.z = 0.0
        msg.pose.pose.orientation.z = math.sin(yaw / 2.0)
        msg.pose.pose.orientation.w = math.cos(yaw / 2.0)

        msg.twist.twist.linear.x = linear
        msg.twist.twist.angular.z = angular

        # Modest covariance hints keep robot_localization/Nav2 happy.
        msg.pose.covariance[0] = 0.01
        msg.pose.covariance[7] = 0.01
        msg.pose.covariance[35] = 0.02
        msg.twist.covariance[0] = 0.02
        msg.twist.covariance[35] = 0.04

        self._odom_pub.publish(msg)

    def _publish_odom_tf(self, x: float, y: float, yaw: float) -> None:
        transform = TransformStamped()
        transform.header.stamp = self.get_clock().now().to_msg()
        transform.header.frame_id = self.odom_frame
        transform.child_frame_id = self.base_frame
        transform.transform.translation.x = x
        transform.transform.translation.y = y
        transform.transform.rotation.z = math.sin(yaw / 2.0)
        transform.transform.rotation.w = math.cos(yaw / 2.0)
        self._tf_broadcaster.sendTransform(transform)

    def _publish_battery(self) -> None:
        msg = BatteryState()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = self.base_frame
        msg.voltage = self._battery_voltage
        msg.percentage = self._battery_percentage
        msg.charge = float("nan")
        msg.capacity = float("nan")
        msg.design_capacity = float("nan")
        msg.power_supply_technology = BatteryState.POWER_SUPPLY_TECHNOLOGY_LION
        msg.present = self._connected
        if self._charging:
            msg.power_supply_status = BatteryState.POWER_SUPPLY_STATUS_CHARGING
        elif self._battery_percentage >= 0.99:
            msg.power_supply_status = BatteryState.POWER_SUPPLY_STATUS_FULL
        else:
            msg.power_supply_status = BatteryState.POWER_SUPPLY_STATUS_DISCHARGING
        self._battery_pub.publish(msg)

    def _publish_status(self, extra: dict[str, Any] | None = None) -> None:
        with self._lock:
            status = self._derive_status()
            payload: dict[str, Any] = {
                "robot_id": self.robot_id,
                "hardware_connected": self._connected,
                "firmware_version": self._firmware_version,
                "battery_voltage": round(self._battery_voltage, 2),
                "battery_level": int(round(self._battery_percentage * 100.0)),
                "is_charging": self._charging,
                "estop": self._estop or self._estop_latched,
                "brush_on": self._brush_on,
                "cleaning_mode": self._cleaning_mode,
                "waste_fill_percentage": self._waste_fill,
                "waste_sensor_fault": self._waste_fault,
                "cliff_detected": self._cliff,
                "bumper_pressed": self._bumper,
                "last_event": self._last_event,
                "linear_speed": round(self._target_linear, 3),
                "angular_speed": round(self._target_angular, 3),
                "pose": {
                    "x": round(self._x, 3),
                    "y": round(self._y, 3),
                    "yaw": round(self._yaw, 3),
                },
                "stamp": time.time(),
            }
            if status:
                payload["status"] = status
            if extra:
                payload.update(extra)

        self._status_pub.publish(String(data=json.dumps(payload)))
        self._publish_battery()

    def _derive_status(self) -> str | None:
        if self._estop or self._estop_latched or self._cliff or self._bumper:
            return "fault"
        if not self._connected:
            return "offline"
        if self._charging:
            return "charging"
        if self._brush_on:
            return "cleaning"
        return None

    # ------------------------------------------------------------------
    # Shutdown
    # ------------------------------------------------------------------
    def destroy_node(self) -> bool:
        self._running = False
        self._send(proto.stop())
        self._send(proto.cleaning(False))
        self._disconnect("shutting down")
        return super().destroy_node()


def main(args: list[str] | None = None) -> None:
    rclpy.init(args=args)
    node = HardwareDriver()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
