"""Keyboard / joystick teleoperation for CleanBot.

Examples:
    ros2 launch cleanbot_bringup teleop.launch.py
    ros2 launch cleanbot_bringup teleop.launch.py use_joy:=true

`teleop_twist_keyboard` publishes to /cmd_vel, the same topic Nav2 uses. Stop
navigation before teleoperating, otherwise both nodes fight for the base.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description() -> LaunchDescription:
    use_joy = LaunchConfiguration("use_joy")
    cmd_vel_topic = LaunchConfiguration("cmd_vel_topic")
    speed = LaunchConfiguration("speed")
    turn = LaunchConfiguration("turn")

    keyboard = Node(
        package="teleop_twist_keyboard",
        executable="teleop_twist_keyboard",
        name="cleanbot_keyboard_teleop",
        output="screen",
        prefix="xterm -e",
        remappings=[("/cmd_vel", cmd_vel_topic)],
        parameters=[
            {
                "speed": speed,
                "turn": turn,
            }
        ],
        condition=UnlessCondition(use_joy),
    )

    joy = Node(
        package="joy",
        executable="joy_node",
        name="cleanbot_joy",
        output="screen",
        condition=IfCondition(use_joy),
    )

    teleop_joy = Node(
        package="teleop_twist_joy",
        executable="teleop_node",
        name="cleanbot_joy_teleop",
        output="screen",
        parameters=[
            {
                "axis_linear.x": 1,
                "axis_angular.yaw": 0,
                "scale_linear.x": 0.35,
                "scale_angular.yaw": 0.9,
                "enable_button": 5,
            }
        ],
        remappings=[("/cmd_vel", cmd_vel_topic)],
        condition=IfCondition(use_joy),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "use_joy",
                default_value="false",
                description="Use joystick instead of keyboard (requires xterm)",
            ),
            DeclareLaunchArgument(
                "cmd_vel_topic",
                default_value="/cmd_vel",
                description="Velocity topic shared with Nav2",
            ),
            DeclareLaunchArgument("speed", default_value="0.35"),
            DeclareLaunchArgument("turn", default_value="0.9"),
            keyboard,
            joy,
            teleop_joy,
        ]
    )
