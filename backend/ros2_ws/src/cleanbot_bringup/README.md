# cleanbot_bringup

Top-level launch files, robot description and teleop for CleanBot.

## One command to start the robot

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
source ~/cleanbot/ros2_ws/install/setup.bash

ros2 launch cleanbot_bringup robot.launch.py
```

This starts:

1. `robot_state_publisher` with `urdf/cleanbot.urdf.xacro`
2. `cleanbot_hardware_driver` on `/dev/serial0`
3. Nav2 + AMCL two seconds later (so TF is available)

### Modes

| `mode:=` | Stack |
| --- | --- |
| `navigation` (default) | AMCL on `maps/floor_map.yaml` + Nav2 |
| `mapping` | slam_toolbox + Nav2 (build a new map) |
| `localization` | map_server + AMCL only |
| `none` | Hardware driver + robot description only |

Useful extra arguments:

```bash
ros2 launch cleanbot_bringup robot.launch.py \
  serial_port:=/dev/ttyUSB0 \
  robot_id:=robot-east-02 \
  start_lidar:=true \
  start_rviz:=true
```

`headless:=true` (default) keeps RViz off the Pi. The Flutter app renders the
live map and pose through the backend WebSocket instead.

## Teleop

```bash
ros2 launch cleanbot_bringup teleop.launch.py              # keyboard in xterm
ros2 launch cleanbot_bringup teleop.launch.py use_joy:=true # joystick
```

Stop Nav2 before teleoperating: both publish `/cmd_vel`.

## URDF

```
base_footprint
└── base_link                 (blue chassis, 0.42 x 0.34 x 0.12 m)
    ├── top_shell             (white shell)
    ├── left_wheel / right_wheel   (continuous, 0.065 m radius, 0.34 m track)
    ├── front_caster / rear_caster
    ├── laser -> laser_frame  (0.235 m above base_link)
    ├── imu_link
    └── cleaning_deck         (brush + vacuum head)
```

The hardware driver owns `odom -> base_link`; `robot_state_publisher` owns
`base_link -> *`. Never publish the same transform twice.

## Raspberry Pi notes

* Serial console must be disabled: `sudo raspi-config` → Interface Options →
  Serial Port → login shell **No**, hardware port **Yes**. Otherwise the ESP32
  link and the console fight over `/dev/serial0`.
* Add the service user to `dialout`: `sudo usermod -aG dialout cleanbot`.
* If your LiDAR is not an RPLIDAR A1, change `lidar_launch` on the command
  line. Any driver publishing `/scan` in the `laser_frame` frame works.
