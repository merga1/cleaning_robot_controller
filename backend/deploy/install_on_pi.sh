#!/usr/bin/env bash
#
# CleanBot Raspberry Pi installer
# -------------------------------
# Installs the Python backend, builds the ROS 2 workspace and registers both
# systemd services so the robot comes up after a reboot.
#
# Tested on Raspberry Pi OS 64-bit with ROS 2 Humble (22.04) and Jazzy (24.04).
#
# Usage:
#   sudo ./backend/deploy/install_on_pi.sh
#   sudo CLEANBOT_SET_HOSTNAME=1 ./backend/deploy/install_on_pi.sh
#   sudo CLEANBOT_SKIP_APT=1 ./backend/deploy/install_on_pi.sh   # offline re-run
#
set -euo pipefail

CLEANBOT_USER="${CLEANBOT_USER:-cleanbot}"
INSTALL_DIR="${CLEANBOT_INSTALL_DIR:-/opt/cleanbot}"
DATA_DIR="${CLEANBOT_DATA_DIR:-/var/lib/cleanbot}"
CONFIG_DIR="/etc/cleanbot"
ROS_WS="${INSTALL_DIR}/ros2_ws"
SET_HOSTNAME="${CLEANBOT_SET_HOSTNAME:-0}"
SKIP_APT="${CLEANBOT_SKIP_APT:-0}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

log()  { printf '\033[1;34m[cleanbot]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[cleanbot]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[cleanbot]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo $0"

# ---------------------------------------------------------------------------
# 1. Pre-flight
# ---------------------------------------------------------------------------
[[ -f "${REPO_ROOT}/backend/requirements.txt" ]] \
  || die "backend/requirements.txt not found - run from a CleanBot checkout"

if [[ -z "${ROS_DISTRO:-}" ]]; then
  ROS_DISTRO="$(ls /opt/ros 2>/dev/null | head -n1 || true)"
fi
[[ -n "${ROS_DISTRO:-}" && -d "/opt/ros/${ROS_DISTRO}" ]] \
  || die "ROS 2 not found in /opt/ros. Install ROS 2 first (humble or jazzy)."

log "Repository : ${REPO_ROOT}"
log "Install to : ${INSTALL_DIR}"
log "ROS distro : ${ROS_DISTRO}"

# ---------------------------------------------------------------------------
# 2. System user and directories
# ---------------------------------------------------------------------------
if ! id -u "${CLEANBOT_USER}" >/dev/null 2>&1; then
  log "Creating service user ${CLEANBOT_USER}"
  useradd --create-home --shell /bin/bash "${CLEANBOT_USER}"
fi

install -d -o "${CLEANBOT_USER}" -g "${CLEANBOT_USER}" "${DATA_DIR}"
install -d -m 0755 "${CONFIG_DIR}"

# ---------------------------------------------------------------------------
# 3. APT dependencies
# ---------------------------------------------------------------------------
if [[ "${SKIP_APT}" != "1" ]]; then
  log "Installing system packages"
  apt-get update -qq

  REQUIRED=(
    python3-venv python3-pip python3-serial python3-colcon-common-extensions
    "ros-${ROS_DISTRO}-nav2-bringup"
    "ros-${ROS_DISTRO}-slam-toolbox"
    "ros-${ROS_DISTRO}-robot-state-publisher"
    "ros-${ROS_DISTRO}-joint-state-publisher"
    "ros-${ROS_DISTRO}-xacro"
    "ros-${ROS_DISTRO}-tf2-ros"
    "ros-${ROS_DISTRO}-teleop-twist-keyboard"
    "ros-${ROS_DISTRO}-rviz2"
  )
  apt-get install -y -qq "${REQUIRED[@]}"

  OPTIONAL=(
    "ros-${ROS_DISTRO}-sllidar-ros2"
    "ros-${ROS_DISTRO}-joy"
    "ros-${ROS_DISTRO}-teleop-twist-joy"
  )
  for pkg in "${OPTIONAL[@]}"; do
    apt-get install -y -qq "${pkg}" 2>/dev/null || warn "Optional package skipped: ${pkg}"
  done
else
  log "Skipping apt (CLEANBOT_SKIP_APT=1)"
fi

# ---------------------------------------------------------------------------
# 4. Copy the project
# ---------------------------------------------------------------------------
if [[ "${REPO_ROOT}" != "${INSTALL_DIR}" ]]; then
  log "Copying project to ${INSTALL_DIR}"
  install -d "${INSTALL_DIR}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' --exclude 'build' --exclude '.dart_tool' \
      --exclude 'backend/.venv' --exclude 'ros2_ws/build' \
      --exclude 'ros2_ws/install' --exclude 'ros2_ws/log' \
      "${REPO_ROOT}/" "${INSTALL_DIR}/"
  else
    cp -a "${REPO_ROOT}/." "${INSTALL_DIR}/"
    rm -rf "${INSTALL_DIR}/.git" "${INSTALL_DIR}/backend/.venv"
  fi
fi

chown -R "${CLEANBOT_USER}:${CLEANBOT_USER}" "${INSTALL_DIR}"

# ---------------------------------------------------------------------------
# 5. Python backend
# ---------------------------------------------------------------------------
log "Creating Python virtualenv (with system site packages for rclpy)"
VENV_DIR="${INSTALL_DIR}/backend/.venv"
if [[ -d "${VENV_DIR}" ]] \
  && ! grep -q "include-system-site-packages = true" "${VENV_DIR}/pyvenv.cfg" 2>/dev/null; then
  warn "Existing venv cannot see ROS 2; recreating it"
  rm -rf "${VENV_DIR}"
fi
sudo -u "${CLEANBOT_USER}" python3 -m venv --system-site-packages "${VENV_DIR}"
sudo -u "${CLEANBOT_USER}" "${VENV_DIR}/bin/pip" install --upgrade pip wheel >/dev/null
sudo -u "${CLEANBOT_USER}" "${VENV_DIR}/bin/pip" install \
  -r "${INSTALL_DIR}/backend/requirements.txt"

# ---------------------------------------------------------------------------
# 6. ROS 2 workspace
# ---------------------------------------------------------------------------
log "Building ROS 2 workspace (this takes a few minutes on a Pi)"
sudo -u "${CLEANBOT_USER}" /bin/bash -c "
  set -e
  source /opt/ros/${ROS_DISTRO}/setup.bash
  cd '${ROS_WS}'
  colcon build --symlink-install --packages-select \
    cleanbot_hardware cleanbot_navigation cleanbot_bringup
"

# ---------------------------------------------------------------------------
# 7. Environment file
# ---------------------------------------------------------------------------
ENV_FILE="${CONFIG_DIR}/backend.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log "Writing ${ENV_FILE}"
  SECRET="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  sed -e "s|replace-with-a-long-random-secret|${SECRET}|" \
    "${INSTALL_DIR}/backend/deploy/backend.env.example" > "${ENV_FILE}"
  chmod 0640 "${ENV_FILE}"
  chown root:"${CLEANBOT_USER}" "${ENV_FILE}"
else
  log "Keeping existing ${ENV_FILE}"
fi

# ---------------------------------------------------------------------------
# 8. systemd units
# ---------------------------------------------------------------------------
log "Installing systemd units"
for unit in cleanbot-backend cleanbot-ros; do
  sed -e "s|__CLEANBOT_USER__|${CLEANBOT_USER}|g" \
      -e "s|__INSTALL_DIR__|${INSTALL_DIR}|g" \
      -e "s|__ROS_DISTRO__|${ROS_DISTRO}|g" \
      "${INSTALL_DIR}/backend/deploy/${unit}.service" \
      > "/etc/systemd/system/${unit}.service"
  chmod 0644 "/etc/systemd/system/${unit}.service"
done

chmod +x "${INSTALL_DIR}/backend/deploy/install_on_pi.sh" \
         "${INSTALL_DIR}/backend/deploy/run_backend.sh"

systemctl daemon-reload
systemctl enable cleanbot-backend.service cleanbot-ros.service

# ---------------------------------------------------------------------------
# 9. Optional hostname (makes cleanbot.local resolvable over mDNS)
# ---------------------------------------------------------------------------
if [[ "${SET_HOSTNAME}" == "1" ]]; then
  log "Setting hostname to cleanbot"
  hostnamectl set-hostname cleanbot
fi

# ---------------------------------------------------------------------------
# 10. Done
# ---------------------------------------------------------------------------
log "Starting services"
systemctl restart cleanbot-backend.service \
  || warn "Backend failed to start - check journalctl -u cleanbot-backend"
systemctl restart cleanbot-ros.service \
  || warn "ROS service failed to start - check journalctl -u cleanbot-ros"
cat <<EOF

  CleanBot installed.

  Backend      : http://$(hostname -I | awk '{print $1}'):8000/api/v1/health
  Logs         : journalctl -u cleanbot-backend -f
                 journalctl -u cleanbot-ros -f
  Config       : ${CONFIG_DIR}/backend.env
  ROS workspace: ${ROS_WS}

  Default accounts (change them in ${CONFIG_DIR}/backend.env):
    operator@cleanbot.io / CleanBot#2026
    admin@cleanbot.io    / Admin#2026
    readonly@cleanbot.io / ReadOnly#2026

  In the Flutter app open Backend Settings on the login screen and set:
    Host: $(hostname).local   Port: 8000   TLS: off

EOF
