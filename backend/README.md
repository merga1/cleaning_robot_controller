# CleanBot backend

FastAPI service that the Flutter app talks to. It owns authentication, robot
state, command lifecycle and the WebSocket telemetry stream, and it bridges all
of that to ROS 2 and the ESP32 motor controller on the Raspberry Pi.

```
Flutter app ──HTTP/WS──► FastAPI ──rclpy──► ROS 2 ──serial──► ESP32
                            │                  │
                            └── in-memory ─────┘ telemetry, Nav2, LiDAR
                                state store
```

## Quick start (desktop, no robot)

```bash
python -m venv backend/.venv
backend/.venv/Scripts/activate          # Linux/macOS: source backend/.venv/bin/activate
pip install -r backend/requirements.txt

# Simulated robot, no ROS 2 needed
CLEANBOT_FORCE_SIMULATION=true backend/.venv/bin/python -m uvicorn \
    app.main:app --host 0.0.0.0 --port 8000 --app-dir backend
```

Windows PowerShell:

```powershell
$env:CLEANBOT_FORCE_SIMULATION='true'
backend\.venv\Scripts\python.exe -m uvicorn app.main:app --port 8000 --app-dir backend
```

Open <http://127.0.0.1:8000/docs> for the generated OpenAPI console.

## Live mode on the Raspberry Pi

The Pi runs the backend inside a virtualenv that can still import `rclpy`.
Create it with `--system-site-packages`, otherwise the ROS 2 packages installed
under `/opt/ros/<distro>` are invisible to Python:

```bash
python3 -m venv --system-site-packages backend/.venv
source /opt/ros/$ROS_DISTRO/setup.bash
source install/setup.bash          # ROS 2 workspace (cleanbot_* packages)
pip install -r backend/requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --app-dir backend
```

`deploy/run_backend.sh` sources both setup files for you, and the systemd unit
calls that script, so the ROS environment is always present when the service
starts. Leave `CLEANBOT_FORCE_SIMULATION=false` to drive real hardware; the
bridge falls back to the simulator only if `rclpy` cannot be imported.

## Default accounts

| Username | Password | Role |
| --- | --- | --- |
| `operator@cleanbot.io` | `CleanBot#2026` | operator (drive, clean, pause) |
| `admin@cleanbot.io` | `Admin#2026` | admin (everything + settings) |
| `readonly@cleanbot.io` | `ReadOnly#2026` | read-only telemetry |

Passwords are PBKDF2-SHA256 hashed at startup; tokens are HS256 JWTs. Override
the user list with `CLEANBOT_USERS='[{...}]'` and always replace
`CLEANBOT_JWT_SECRET` in production.

## REST API

All routes are mounted under `/api/v1`.

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/auth/login` | Email + password → access/refresh token |
| `POST` | `/auth/refresh` | Rotate the access token |
| `POST` | `/auth/logout` | Revoke the refresh token |
| `GET` | `/auth/me` | Current user |
| `GET` | `/health` | Liveness + ROS/hardware connectivity |
| `GET` | `/system/status` | Backend, ROS and robot summary |
| `GET` | `/robots` | Fleet list |
| `GET` | `/robots/{id}` | Robot summary |
| `GET` | `/robots/{id}/telemetry` | Battery, pose, odom, scan |
| `GET` | `/robots/{id}/map` | Occupancy grid + obstacles + dock |
| `GET` | `/dashboard/summary` | Active job, waste, cleanliness, alerts |
| `GET` | `/robots/{id}/waste` | Container fill level |
| `GET` | `/robots/{id}/cleanliness` | Latest cleanliness score |
| `GET` | `/robots/{id}/zones` | Cleaning zones |
| `GET` | `/robots/{id}/detections` | Debris / spill detections |
| `GET` | `/robots/{id}/history` | Completed jobs |
| `GET` | `/robots/{id}/notifications` | Alerts |
| `GET` | `/robots/{id}/maintenance` | Component health |
| `GET` | `/robots/{id}/reports` | Aggregated report |
| `POST` | `/robots/{id}/commands` | Create a command |
| `GET` | `/commands/{command_id}` | Poll command state |
| `POST` | `/robots/{id}/manual-drive` | Joystick / jog drive |
| `POST` | `/robots/{id}/estop` | Latching emergency stop |
| `POST` | `/robots/{id}/zones/{zone_id}/start` | Start cleaning a zone |
| `PATCH` | `/settings` | Robot name, speed, auto-dock, simulation |

Command types: `startCleaning`, `pause`, `resume`, `cancel`, `call`,
`inspectFloor`, `returnToDock`, `requestStatusRefresh`.

### Example

```bash
TOKEN=$(curl -s -X POST http://cleanbot.local:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"operator@cleanbot.io","password":"CleanBot#2026"}' \
  | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -s http://cleanbot.local:8000/api/v1/dashboard/summary \
  -H "Authorization: Bearer $TOKEN"

curl -s -X POST http://cleanbot.local:8000/api/v1/robots/robot-alpha-01/commands \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"command":"startCleaning","idempotency_key":"demo-1","parameters":{"zone_id":"zone-lobby"}}'
```

## WebSocket

```
ws://<host>:8000/api/v1/ws?token=<access_token>
```

The server pushes a full snapshot on connect, then telemetry every 500 ms.
Message envelope:

```json
{
  "robot_id": "robot-alpha-01",
  "type": "robot_state",
  "timestamp": "2026-11-13T06:43:28.218841Z",
  "is_simulated": false,
  "payload": {}
}
```

Types: `robot_state`, `telemetry`, `job_progress`, `container_reading`,
`cleanliness`, `command_status`, `alert`, `pong`. Send `"ping"` to keep the
connection alive; the app reconnects with backoff automatically.

## ROS 2 bridge

`app/ros_bridge.py` spins `rclpy` in a dedicated thread.

* Subscribes: `/odom`, `/battery_state`, `/scan`, `/map`, `/amcl_pose`,
  `/cleanbot/status`, `/cleanbot/detections`
* Publishes: `/cleanbot/hardware_command`, `/cmd_vel`, `/goal_pose`
* Uses the `navigate_to_pose` Nav2 action when available

If `rclpy` is missing or `CLEANBOT_FORCE_SIMULATION=true`, a deterministic
simulator feeds the same state store — the mobile app behaves identically.

## Configuration

Every setting is an environment variable; the systemd unit reads
`/etc/cleanbot/backend.env`. See [`deploy/backend.env.example`](deploy/backend.env.example)
for the full list.

| Variable | Default | Notes |
| --- | --- | --- |
| `CLEANBOT_API_HOST` | `0.0.0.0` | Bind address |
| `CLEANBOT_API_PORT` | `8000` | HTTP + WS port |
| `CLEANBOT_JWT_SECRET` | dev placeholder | **Change in production** |
| `CLEANBOT_ROBOT_ID` | `robot-alpha-01` | Must match the ROS driver |
| `CLEANBOT_FORCE_SIMULATION` | `false` | Disable ROS entirely |
| `CLEANBOT_SIMULATE_WHEN_ROS_MISSING` | `true` | Graceful fallback |
| `CLEANBOT_ENABLE_SIM_ROBOT` | `true` | Extra demo robot in fleet |
| `ROS_DOMAIN_ID` | `0` | Must match the ROS 2 services |
| `CLEANBOT_DATABASE_PATH` | `/var/lib/cleanbot/cleanbot.db` | Reserved for persistence |

## Layout

```
backend/
├── app/
│   ├── main.py          # FastAPI app, lifespan, health, WebSocket
│   ├── config.py        # env-driven settings
│   ├── security.py      # PBKDF2 + JWT + role guards
│   ├── state.py         # thread-safe robot store + simulator
│   ├── ros_bridge.py    # rclpy bridge
│   ├── ws.py            # connection manager
│   ├── schemas.py       # request models
│   └── routers/         # auth.py, robot.py
├── ros2_ws/src/
│   ├── cleanbot_hardware/    # serial driver + ESP32 firmware
│   ├── cleanbot_navigation/  # Nav2, SLAM, maps
│   └── cleanbot_bringup/     # URDF, top-level launch, teleop
├── deploy/              # installer, systemd units, env template
└── requirements.txt
```

See [`deploy/README.md`](deploy/README.md) for the Raspberry Pi installation.
