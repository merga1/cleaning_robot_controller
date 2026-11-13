#!/usr/bin/env bash
#
# Launch the CleanBot backend with the ROS 2 environment sourced.
#
# Called by cleanbot-backend.service. Sourcing ROS makes rclpy and the message
# packages importable from /opt/ros/<distro> while the Python dependencies stay
# isolated in backend/.venv (created with --system-site-packages).
#
set -euo pipefail

INSTALL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ROS_DISTRO="${ROS_DISTRO:-humble}"

if [[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
else
  echo "[cleanbot] ROS ${ROS_DISTRO} not found; starting in simulation mode" >&2
  export CLEANBOT_FORCE_SIMULATION="${CLEANBOT_FORCE_SIMULATION:-true}"
fi

if [[ -f "${INSTALL_DIR}/ros2_ws/install/setup.bash" ]]; then
  # shellcheck disable=SC1091
  source "${INSTALL_DIR}/ros2_ws/install/setup.bash"
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
export PYTHONUNBUFFERED=1

cd "${INSTALL_DIR}/backend"

exec "${INSTALL_DIR}/backend/.venv/bin/python" -m uvicorn app.main:app \
  --host "${CLEANBOT_API_HOST:-0.0.0.0}" \
  --port "${CLEANBOT_API_PORT:-8000}" \
  --workers 1 \
  --proxy-headers
