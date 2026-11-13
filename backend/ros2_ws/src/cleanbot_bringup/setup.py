from glob import glob

from setuptools import setup

package_name = "cleanbot_bringup"

setup(
    name=package_name,
    version="1.0.0",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
        (f"share/{package_name}/launch", glob("launch/*.launch.py")),
        (f"share/{package_name}/config", glob("config/*.yaml")),
        (f"share/{package_name}/urdf", glob("urdf/*")),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="CleanBot Robotics",
    maintainer_email="robotics@cleanbot.local",
    description="CleanBot bring-up launch files and URDF",
    license="Apache-2.0",
    entry_points={"console_scripts": []},
)
