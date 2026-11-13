from setuptools import setup

package_name = "cleanbot_hardware"

setup(
    name=package_name,
    version="1.0.0",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
        (f"share/{package_name}/launch", ["launch/hardware.launch.py"]),
        (f"share/{package_name}/config", ["config/hardware.yaml"]),
        (f"share/{package_name}/firmware", ["firmware/cleanbot_firmware.ino"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="CleanBot Robotics",
    maintainer_email="robotics@cleanbot.local",
    description="ESP32/Arduino hardware driver for CleanBot",
    license="Apache-2.0",
    entry_points={
        "console_scripts": [
            "hardware_driver = cleanbot_hardware.hardware_driver:main",
        ],
    },
)
