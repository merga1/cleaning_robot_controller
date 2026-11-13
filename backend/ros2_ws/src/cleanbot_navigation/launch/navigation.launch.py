"""Localise on a saved map and run the Nav2 stack.

Usage:
    ros2 launch cleanbot_navigation navigation.launch.py
    ros2 launch cleanbot_navigation navigation.launch.py map:=$HOME/maps/west_wing.yaml

Assumes the robot base is already publishing /scan, /odom and the
odom -> base_link transform (cleanbot_hardware or cleanbot_bringup).
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    map_file = LaunchConfiguration("map")
    params_file = LaunchConfiguration("params_file")
    use_sim_time = LaunchConfiguration("use_sim_time")
    autostart = LaunchConfiguration("autostart")
    headless = LaunchConfiguration("headless")

    default_map = PathJoinSubstitution(
        [FindPackageShare("cleanbot_navigation"), "maps", "floor_map.yaml"]
    )
    default_params = PathJoinSubstitution(
        [FindPackageShare("cleanbot_navigation"), "config", "nav2_params.yaml"]
    )

    nav2_bringup = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [
                    FindPackageShare("nav2_bringup"),
                    "launch",
                    "bringup_launch.py",
                ]
            )
        ),
        launch_arguments={
            "map": map_file,
            "use_sim_time": use_sim_time,
            "params_file": params_file,
            "autostart": autostart,
            "slam": "False",
            "use_composition": "False",
            "headless": headless,
        }.items(),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "map",
                default_value=default_map,
                description="Absolute path to the map yaml to localise against",
            ),
            DeclareLaunchArgument(
                "params_file",
                default_value=default_params,
                description="Nav2 parameter file",
            ),
            DeclareLaunchArgument(
                "use_sim_time",
                default_value="false",
                description="Use simulated clock (Gazebo only)",
            ),
            DeclareLaunchArgument(
                "autostart",
                default_value="true",
                description="Automatically configure and activate lifecycle nodes",
            ),
            DeclareLaunchArgument(
                "headless",
                default_value="false",
                description="Skip RViz on the Pi (use the Flutter map instead)",
            ),
            nav2_bringup,
        ]
    )
