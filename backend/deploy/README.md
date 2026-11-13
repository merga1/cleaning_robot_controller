# CleanBot Raspberry Pi deployment

Everything needed to turn a fresh Raspberry Pi into the robot's compute unit:
the FastAPI backend, the ROS 2 hardware/navigation stack, and both systemd
services.

```
┌──────────────── Raspberry Pi ────────────────┐
│                                              │
│  cleanbot-ros.service                        │
│    cleanbot_bringup/robot.launch.py          │
│      ├── hardware_driver  ── serial ──► ESP32│
│      ├── robot_state_publisher               │
│      └── Nav2 + AMCL (map)                   │
│                  │ /odom /map /scan /status  │
│  cleanbot-backend.service                    │
│    FastAPI + rclpy bridge + WebSocket        │
│                  │ :8000                     │
└──────────────────┼───────────────────────────┘
                   │ Wi-Fi / Ethernet
             ┌─────▼──────┐
             │ Flutter app│
             └────────────┘
```

## Prerequisites

1. Raspberry Pi 4 (2 GB+) or Pi 5, 64-bit Raspberry Pi OS or Ubuntu Server.
2. ROS 2 **Humble** (22.04) or **Jazzy** (24.04) installed at `/opt/ros/<distro>`.
3. The repo cloned somewhere on the Pi, e.g. `~/Cleaning_robot_controller`.
4. A serial link to the ESP32 at `/dev/serial0` (or `/dev/ttyUSB0`).

### Enable the serial port

```bash
sudo raspi-config
# Interface Options -> Serial Port
#   login shell over serial : No
#   serial hardware enabled : Yes
sudo usermod -aG dialout "$USER"
```

## Install

```bash
cd ~/Cleaning_robot_controller
sudo bash backend/deploy/install_on_pi.sh
```

The script is idempotent. It:

* creates the `cleanbot` service user and `/var/lib/cleanbot`
* installs apt dependencies for the detected ROS distro
* copies the project to `/opt/cleanbot`
* creates `backend/.venv` (with `--system-site-packages`, required for `rclpy`)
  and installs `requirements.txt`
* `colcon build`s `cleanbot_hardware`, `cleanbot_navigation`, `cleanbot_bringup`
* writes `/etc/cleanbot/backend.env` with a random JWT secret
* installs and enables both systemd units
* optionally sets the hostname to `cleanbot` (`CLEANBOT_SET_HOSTNAME=1`)

Useful flags:

| Variable | Effect |
| --- | --- |
| `CLEANBOT_INSTALL_DIR` | Install location (default `/opt/cleanbot`) |
| `CLEANBOT_USER` | Service user (default `cleanbot`) |
| `CLEANBOT_SET_HOSTNAME=1` | Set hostname to `cleanbot` for mDNS |
| `CLEANBOT_SKIP_APT=1` | Skip apt, for offline re-runs |

## Verify

```bash
systemctl status cleanbot-backend cleanbot-ros
journalctl -u cleanbot-backend -n 50
journalctl -u cleanbot-ros -n 50

curl http://localhost:8000/api/v1/health
# {"status":"ok", ...}

source /opt/ros/$ROS_DISTRO/setup.bash
source /opt/cleanbot/ros2_ws/install/setup.bash
ros2 topic hz /odom
ros2 topic echo /cleanbot/status
ros2 topic echo /map --once | head
```

## Connect the Flutter app

1. Put the phone on the same Wi-Fi network as the Pi.
2. Login screen -> **Backend settings**.
3. Host `cleanbot.local` (or the Pi's IP), port `8000`, TLS off.
4. **Test connection** -> **Save**, then sign in.

If mDNS does not resolve on your network, use the IP address printed by the
installer (`hostname -I`).

## Manual run (development)

```bash
# Backend with auto-reload
cd /opt/cleanbot/backend
source /opt/ros/$ROS_DISTRO/setup.bash
.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# ROS stack with RViz
source /opt/ros/$ROS_DISTRO/setup.bash
source /opt/cleanbot/ros2_ws/install/setup.bash
ros2 launch cleanbot_bringup robot.launch.py start_rviz:=true
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Backend returns `ros_connected: false` | `journalctl -u cleanbot-ros`; ensure `ROS_DOMAIN_ID` matches in both units |
| App shows "offline" everywhere | Check firewall: `sudo ufw allow 8000/tcp`, and phone is on the same subnet |
| `hardware_connected: false` | ESP32 not on `/dev/serial0`; check `ls -l /dev/serial0`, baud rate, and `dmesg | grep tty` |
| Robot drives, no map | LiDAR driver not running; `ros2 topic hz /scan` |
| AMCL never localises | Wrong initial pose in `nav2_params.yaml` or map origin mismatch |
| Services restart loop | `.env` must be readable by the `cleanbot` group: `sudo chmod 0640 /etc/cleanbot/backend.env` |

## Updating

```bash
cd ~/Cleaning_robot_controller
git pull
sudo ./backend/deploy/install_on_pi.sh
sudo systemctl restart cleanbot-backend cleanbot-ros
```

The existing `/etc/cleanbot/backend.env` is preserved, so JWT secrets and
custom users survive updates.
