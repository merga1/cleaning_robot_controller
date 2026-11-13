# cleanbot_navigation

Nav2 + SLAM configuration, launch files and the saved floor map for CleanBot.

## Contents

| Path | Purpose |
| --- | --- |
| `launch/navigation.launch.py` | AMCL localisation + full Nav2 stack on a saved map |
| `launch/slam.launch.py` | slam_toolbox mapping + Nav2, for building new maps |
| `launch/localization.launch.py` | map_server + AMCL only |
| `config/nav2_params.yaml` | Costmaps, planners, controllers, behaviours |
| `config/slam_params.yaml` | slam_toolbox online async |
| `maps/floor_map.{pgm,yaml}` | 16 m x 10.5 m demo floor at 0.05 m/px |
| `rviz/navigation.rviz` | Blue/white RViz layout |

## Frames

```
map ──(AMCL or slam_toolbox)──► odom ──(hardware driver)──► base_link ──► laser
```

`/scan` must be a `sensor_msgs/LaserScan` in the `laser` frame; the URDF in
`cleanbot_bringup` provides the static `base_link -> laser` transform.

## Run

```bash
# Saved map + navigation
ros2 launch cleanbot_navigation navigation.launch.py

# Build a new map (drive with cleanbot_bringup/teleop.launch.py)
ros2 launch cleanbot_navigation slam.launch.py
ros2 run nav2_map_server map_saver_cli -f ~/maps/new_floor
```

On a headless Pi pass `headless:=true` to skip RViz; the Flutter app draws the
live map from `/map` through the backend WebSocket.

## Behaviour

* `FollowPath`: Regulated Pure Pursuit, 0.35 m/s cruise, 0.15 m goal tolerance.
* Local costmap: 3 m x 3 m rolling window from `/scan`.
* Global costmap: static map + live obstacles, 0.45 m inflation.
* Recovery behaviours: spin, back-up, drive-on-heading, wait.
* `collision_monitor` stops the base if an obstacle enters the footprint.

## Tuning notes

* Increase `inflation_radius` if the robot clips door frames.
* Lower `desired_linear_vel` to 0.25 m/s for polished floors.
* `robot_radius: 0.22` assumes the 0.44 m chassis; update if the shell changes.
* The demo map is synthetic. Replace it with a `map_saver_cli` capture of the
  real floor before production use.

## Humble vs Jazzy

`nav2_params.yaml` carries both `behavior_server` (Jazzy) and
`recoveries_server` (Humble) sections, and both BT XML keys. Unused sections
are ignored, so the same file works on either distribution.
