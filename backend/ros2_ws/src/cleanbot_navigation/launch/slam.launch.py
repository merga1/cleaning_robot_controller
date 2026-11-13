"""Run SLAM (slam_toolbox) plus the Nav2 stack for mapping a new floor.

Usage:
    ros2 launch cleanbot_navigation slam.launch.py
    ros2 launch cleanbot_navigation slam.launch.py use_rviz:=true

Drive the robot around with teleop while it builds the map, then save it:

    ros2 run nav2_map_server map_saver_cli -f ~/maps/my_floor

Copy the resulting .pgm/.yaml pair into `cleanbot_navigation/maps/`.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    use_sim_time = LaunchConfiguration("use_sim_time")
    params_file = LaunchConfiguration("params_file")
    use_rviz = LaunchConfiguration("use_rviz")

    default_params = PathJoinSubstitution(
        [FindPackageShare("cleanbot_navigation"), "config", "slam_params.yaml"]
    )

    slam = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [
                    FindPackageShare("slam_toolbox"),
                    "launch",
                    "online_async_launch.py",
                ]
            )
        ),
        launch_arguments={
            "use_sim_time": use_sim_time,
            "slam_params_file": params_file,
        }.items(),
    )

    # Nav2 without amcl/map_server: SLAM owns the map -> odom transform.
    navigation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [
                    FindPackageShare("nav2_bringup"),
                    "launch",
                    "navigation_launch.py",
                ]
            )
        ),
        launch_arguments={
            "use_sim_time": use_sim_time,
            "params_file": PathJoinSubstitution(
                [
                    FindPackageShare("cleanbot_navigation"),
                    "config",
                    "nav2_params.yaml",
                ]
            ),
            "autostart": "true",
            "use_composition": "False",
        }.items(),
    )

    rviz = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [FindPackageShare("nav2_bringup"), "launch", "rviz_launch.py"]
            )
        ),
        condition=IfCondition(use_rviz),
        launch_arguments={"use_sim_time": use_sim_time}.items(),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument("use_sim_time", default_value="false"),
            DeclareLaunchArgument(
                "params_file",
                default_value=default_params,
                description="slam_toolbox parameter file",
            ),
            DeclareLaunchArgument(
                "use_rviz",
                default_value="false",
                description="Open RViz on the Pi (disabled for headless installs)",
            ),
            slam,
            navigation,
            rviz,
        ]
    )
