"""Top-level CleanBot bring-up.

Starts the robot description, hardware driver and (optionally) the navigation
or SLAM stack. One command brings a Raspberry Pi from boot to a robot that the
Flutter app can drive.

Examples:
    ros2 launch cleanbot_bringup robot.launch.py
    ros2 launch cleanbot_bringup robot.launch.py mode:=mapping
    ros2 launch cleanbot_bringup robot.launch.py mode:=none serial_port:=/dev/ttyUSB0
    ros2 launch cleanbot_bringup robot.launch.py start_lidar:=true
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    IncludeLaunchDescription,
    TimerAction,
)
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import (
    Command,
    FindExecutable,
    LaunchConfiguration,
    PythonExpression,
)
from launch_ros.actions import Node


def generate_launch_description() -> LaunchDescription:
    use_sim_time = LaunchConfiguration("use_sim_time")
    serial_port = LaunchConfiguration("serial_port")
    robot_id = LaunchConfiguration("robot_id")
    mode = LaunchConfiguration("mode")
    start_lidar = LaunchConfiguration("start_lidar")
    start_rviz = LaunchConfiguration("start_rviz")

    bringup_share = get_package_share_directory("cleanbot_bringup")
    hardware_share = get_package_share_directory("cleanbot_hardware")
    navigation_share = get_package_share_directory("cleanbot_navigation")

    xacro_file = os.path.join(bringup_share, "urdf", "cleanbot.urdf.xacro")
    robot_description = {
        "robot_description": Command([FindExecutable(name="xacro"), " ", xacro_file])
    }

    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        output="screen",
        parameters=[robot_description, {"use_sim_time": use_sim_time}],
    )

    # Only needed for RViz wheel animation; the hardware driver integrates
    # wheel ticks into /odom independently.
    joint_state_publisher = Node(
        package="joint_state_publisher",
        executable="joint_state_publisher",
        output="screen",
        parameters=[{"use_sim_time": use_sim_time, "rate": 20}],
        condition=IfCondition(start_rviz),
    )

    hardware = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(hardware_share, "launch", "hardware.launch.py")
        ),
        launch_arguments={
            "serial_port": serial_port,
            "robot_id": robot_id,
        }.items(),
    )

    static_map = os.path.join(navigation_share, "maps", "floor_map.yaml")

    navigation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(navigation_share, "launch", "navigation.launch.py")
        ),
        condition=IfCondition(
            PythonExpression(["'", mode, "' == 'navigation'"])
        ),
        launch_arguments={
            "map": LaunchConfiguration("map"),
            "use_sim_time": use_sim_time,
            "headless": LaunchConfiguration("headless"),
        }.items(),
    )

    slam = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(navigation_share, "launch", "slam.launch.py")
        ),
        condition=IfCondition(PythonExpression(["'", mode, "' == 'mapping'"])),
        launch_arguments={
            "use_sim_time": use_sim_time,
            "use_rviz": start_rviz,
        }.items(),
    )

    localization = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(navigation_share, "launch", "localization.launch.py")
        ),
        condition=IfCondition(
            PythonExpression(["'", mode, "' == 'localization'"])
        ),
        launch_arguments={
            "map": LaunchConfiguration("map"),
            "use_sim_time": use_sim_time,
        }.items(),
    )

    # RPLIDAR A1 via sllidar_ros2 (install with: sudo apt install ros-$ROS_DISTRO-sllidar-ros2)
    lidar = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            [
                LaunchConfiguration("lidar_launch"),
            ]
        ),
        condition=IfCondition(start_lidar),
    )

    rviz = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        output="screen",
        arguments=[
            "-d",
            os.path.join(navigation_share, "rviz", "navigation.rviz"),
        ],
        parameters=[{"use_sim_time": use_sim_time}],
        condition=IfCondition(start_rviz),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "mode",
                default_value="navigation",
                choices=["navigation", "mapping", "localization", "none"],
                description="Which autonomy stack to start",
            ),
            DeclareLaunchArgument(
                "map",
                default_value=static_map,
                description="Map yaml used in navigation/localization mode",
            ),
            DeclareLaunchArgument(
                "serial_port",
                default_value="/dev/serial0",
                description="Serial device for the ESP32 base controller",
            ),
            DeclareLaunchArgument(
                "robot_id",
                default_value="robot-alpha-01",
                description="Robot identifier reported to the backend",
            ),
            DeclareLaunchArgument("use_sim_time", default_value="false"),
            DeclareLaunchArgument(
                "start_lidar",
                default_value="false",
                description="Launch sllidar_ros2 for an RPLIDAR A1",
            ),
            DeclareLaunchArgument(
                "lidar_launch",
                default_value=(
                    f"/opt/ros/{os.environ.get('ROS_DISTRO', 'humble')}/share/"
                    "sllidar_ros2/launch/sllidar_a1_launch.py"
                ),
                description="Lidar launch file used when start_lidar:=true",
            ),
            DeclareLaunchArgument(
                "start_rviz",
                default_value="false",
                description="Open RViz and joint_state_publisher on the Pi",
            ),
            DeclareLaunchArgument(
                "headless",
                default_value="true",
                description="Skip the RViz node inside nav2_bringup",
            ),
            robot_state_publisher,
            joint_state_publisher,
            hardware,
            # Give the driver a moment to start publishing /odom and TF
            # before AMCL starts looking for transforms.
            TimerAction(period=2.0, actions=[navigation, localization, slam]),
            lidar,
            rviz,
        ]
    )
