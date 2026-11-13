# cleanbot_hardware

ROS 2 driver for the CleanBot differential-drive base and the ESP32 firmware
that talks to it.

```
Pi (ROS 2)  ──serial JSON──►  ESP32  ──PWM──►  motor driver  ──►  wheels
     ▲                          │
     └── encoders / battery ◄───┘
```

## Published topics

| Topic | Type | Notes |
| --- | --- | --- |
| `/odom` | `nav_msgs/Odometry` | Wheel odometry integrated from encoder ticks |
| `/battery_state` | `sensor_msgs/BatteryState` | Voltage → percentage, charging flag |
| `/cleanbot/status` | `std_msgs/String` | JSON heartbeat consumed by the FastAPI backend |
| `TF odom → base_link` | `tf2` | Required by Nav2 |

## Subscribed topics

| Topic | Type | Notes |
| --- | --- | --- |
| `/cmd_vel` | `geometry_msgs/Twist` | From Nav2 or the teleop pad, 0.6 s watchdog |
| `/cleanbot/estop` | `std_msgs/Bool` | Latching emergency stop |
| `/cleanbot/hardware_command` | `std_msgs/String` | JSON commands from the backend |

### `/cleanbot/status` payload

```json
{
  "robot_id": "robot-alpha-01",
  "hardware_connected": true,
  "firmware_version": "cleanbot-esp32-1.0.0",
  "battery_level": 87,
  "is_charging": false,
  "estop": false,
  "brush_on": true,
  "waste_fill_percentage": 34,
  "waste_sensor_fault": false,
  "cliff_detected": false,
  "bumper_pressed": false,
  "status": "cleaning",
  "command_id": "cmd-1a2b3c",
  "command_state": "executing"
}
```

The backend maps `command_id` / `command_state` straight onto its command
lifecycle, so every command sent from the Flutter app is acknowledged by real
hardware.

## Build and run

```bash
cd ~/cleanbot/ros2_ws
colcon build --packages-select cleanbot_hardware --symlink-install
source install/setup.bash
ros2 launch cleanbot_hardware hardware.launch.py serial_port:=/dev/serial0
```

Verify:

```bash
ros2 topic echo /cleanbot/status
ros2 topic hz /odom
ros2 run tf2_ros tf2_echo odom base_link
```

## Calibration

`ticks_per_revolution` and `wheel_radius` control odometry accuracy.

1. Mark a 2 m straight line on the floor.
2. Drive forward until the robot has physically travelled 2 m.
3. Compare with `ros2 topic echo /odom --field pose.pose.position.x`.
4. Scale `ticks_per_revolution` by `measured_distance / 2.0`, rebuild, repeat.

`wheel_separation` (centre-to-centre) removes yaw drift during spins. Spin the
robot 10 full turns and scale by `measured_angle / (10 * 2π)`.

## Wiring

See the header of [`firmware/cleanbot_firmware.ino`](firmware/cleanbot_firmware.ino)
for the full pin map. Encoder inputs on GPIO 34/35/36/39 are input-only; add
external 10 kΩ pull-ups. The battery divider must never exceed 3.3 V at the
ADC pin.

## Firmware protocol

Newline-delimited JSON, 115200 baud.

```text
Pi -> ESP32  {"v":1,"type":"cmd_vel","linear":0.2,"angular":0.0}
Pi -> ESP32  {"v":1,"type":"estop","engage":true}
Pi -> ESP32  {"v":1,"type":"cleaning","enabled":true,"mode":"standard","speed":1.0}
ESP32 -> Pi  {"type":"telemetry","left_ticks":1234,"right_ticks":1230,...}
```

Flash with the Arduino IDE or:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 firmware
arduino-cli upload  --fqbn esp32:esp32:esp32 -p /dev/ttyUSB0 firmware
```
