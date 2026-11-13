# CleanBot — Cleaning Robot Controller

Flutter controller app plus the complete Raspberry Pi stack (FastAPI backend,
ROS 2 hardware driver, Nav2 navigation and ESP32 firmware) for an autonomous
floor-cleaning robot.

The whole product uses a strict **blue + white** palette with full light and
dark mode support.

## Repository layout

| Path | Contents |
| --- | --- |
| `lib/` | Flutter app (feature-first: `auth`, `dashboard`, `controls`, `map`, `zones`, `robots`, `waste`, `inspection`, `notifications`, `reports`, `settings`, …) |
| `test/` | Widget and unit tests |
| `backend/app/` | FastAPI REST + WebSocket backend, JWT auth, ROS 2 bridge, simulator |
| `backend/ros2_ws/src/cleanbot_hardware/` | Serial driver + ESP32 firmware |
| `backend/ros2_ws/src/cleanbot_navigation/` | Nav2 / SLAM params, launch files, floor map |
| `backend/ros2_ws/src/cleanbot_bringup/` | URDF, top-level launch, teleop |
| `backend/deploy/` | Pi installer, systemd units, env template |

## App

### Features

* Live dashboard: battery, status, active job, cleanliness, container level
* Manual drive with dead-man behaviour, pause/resume/cancel, return-to-dock
* Live map with robot pose, obstacles and saved zones
* Zone management, cleaning history, reports, maintenance health
* Detections feed, notifications, multi-robot fleet view
* Login with roles (`operator`, `admin`, `readonly`) and configurable backend
  address (host, port, TLS, demo mode)
* BLoC/Riverpod feature modules, go_router navigation
* Blue/white light and dark themes with a single source of truth in
  `lib/core/theme/app_colors.dart`

### Run

```bash
flutter pub get
flutter run
```

### Point it at the robot

On the login screen open **Backend settings**:

| Field | Value |
| --- | --- |
| Host | `cleanbot.local` (or the Pi's IP) |
| Port | `8000` |
| TLS | off (enable if you put a reverse proxy in front) |
| Demo mode | off for the live robot |

**Test connection** then **Save**. The app stores the setting in
`SharedPreferences` and rebuilds its REST/WebSocket clients from it.

### Checks

```bash
flutter analyze
flutter test
```

## Raspberry Pi

One command installs the backend, builds the ROS 2 workspace and enables both
services:

```bash
cd ~/Cleaning_robot_controller
sudo bash backend/deploy/install_on_pi.sh
```

Requires ROS 2 Humble or Jazzy at `/opt/ros/<distro>`, and the serial console
disabled (`raspi-config` → Interface Options → Serial Port).

### What runs on the Pi

```
cleanbot-ros.service
  ros2 launch cleanbot_bringup robot.launch.py
    robot_state_publisher (URDF)
    cleanbot_hardware_driver  ──serial──►  ESP32  ──►  motors / encoders
    Nav2 + AMCL on maps/floor_map.yaml

cleanbot-backend.service
  uvicorn app.main:app  ──rclpy──►  ROS 2 graph
  REST + WebSocket on :8000
```

* `ros2 launch cleanbot_bringup robot.launch.py mode:=mapping` builds a new map
  with slam_toolbox.
* `ros2 launch cleanbot_bringup teleop.launch.py` drives the base from a
  keyboard or joystick.
* Commands from the app travel REST → backend → `/cleanbot/hardware_command` →
  firmware, and navigation goals go through the Nav2 `navigate_to_pose` action.

Verify after install:

```bash
curl http://cleanbot.local:8000/api/v1/health
ros2 topic echo /cleanbot/status
ros2 topic hz /odom
```

### Default accounts

| Username | Password | Role |
| --- | --- | --- |
| `operator@cleanbot.io` | `CleanBot#2026` | operator |
| `admin@cleanbot.io` | `Admin#2026` | admin |
| `readonly@cleanbot.io` | `ReadOnly#2026` | read-only |

Change them in `/etc/cleanbot/backend.env` before exposing the Pi on a network.

## Documentation

* [`backend/README.md`](backend/README.md) — API, WebSocket protocol, configuration
* [`backend/deploy/README.md`](backend/deploy/README.md) — Pi installation and troubleshooting
* [`backend/ros2_ws/src/cleanbot_hardware/README.md`](backend/ros2_ws/src/cleanbot_hardware/README.md) — wiring, serial protocol, odometry calibration
* [`backend/ros2_ws/src/cleanbot_navigation/README.md`](backend/ros2_ws/src/cleanbot_navigation/README.md) — Nav2 tuning, mapping, frames
* [`backend/ros2_ws/src/cleanbot_bringup/README.md`](backend/ros2_ws/src/cleanbot_bringup/README.md) — URDF, launch modes, teleop

## Architecture summary

```
┌──────────────┐   HTTPS / WSS   ┌─────────────────────────────┐
│ Flutter app  │ ◄─────────────► │ FastAPI backend (Pi)        │
│ Android/iOS  │                 │  auth · state · WS fan-out  │
└──────────────┘                 └──────────┬──────────────────┘
                                            │ rclpy
                                 ┌──────────▼──────────────────┐
                                 │ ROS 2 (Pi)                  │
                                 │  Nav2 · AMCL / SLAM · LiDAR │
                                 │  cleanbot_hardware_driver   │
                                 └──────────┬──────────────────┘
                                            │ serial JSON
                                 ┌──────────▼──────────────────┐
                                 │ ESP32 firmware              │
                                 │  motors · encoders · safety │
                                 └─────────────────────────────┘
```

If ROS 2 is unavailable the backend serves a deterministic simulator, so the
app and API remain fully testable on a laptop.
