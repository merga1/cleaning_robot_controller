"""Launch the CleanBot hardware driver.

Usage:
    ros2 launch cleanbot_hardware hardware.launch.py
    ros2 launch cleanbot_hardware hardware.launch.py serial_port:=/dev/ttyUSB0
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    serial_port = LaunchConfiguration("serial_port")
    baudrate = LaunchConfiguration("baudrate")
    robot_id = LaunchConfiguration("robot_id")
    params_file = LaunchConfiguration("params_file")

    default_params = PathJoinSubstitution(
        [FindPackageShare("cleanbot_hardware"), "config", "hardware.yaml"]
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "serial_port",
                default_value="/dev/serial0",
                description="Serial device connected to the ESP32/Arduino",
            ),
            DeclareLaunchArgument(
                "baudrate",
                default_value="115200",
                description="Serial baud rate",
            ),
            DeclareLaunchArgument(
                "robot_id",
                default_value="robot-alpha-01",
                description="Robot identifier reported to the backend",
            ),
            DeclareLaunchArgument(
                "params_file",
                default_value=default_params,
                description="Full path to the hardware parameter file",
            ),
            Node(
                package="cleanbot_hardware",
                executable="hardware_driver",
                name="cleanbot_hardware_driver",
                output="screen",
                emulate_tty=True,
                parameters=[
                    params_file,
                    {
                        "serial_port": serial_port,
                        "baudrate": baudrate,
                        "robot_id": robot_id,
                    },
                ],
            ),
        ]
    )
