#!/bin/bash

set -euo pipefail

LOGFILE="bootstrap.log"
PLAYBOOK="site.yml"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)

SKIP_AI_TOOLS=false
INSTALL_DAVINCI=false
DAVINCI_EDITION=""
INSTALL_SYNERGY=false
INSTALL_NVIDIA=false
INSTALL_SYSTEM76=false
SKIP_VSCODE=false
OMIT_LIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ai-tools)
      SKIP_AI_TOOLS=true
      shift
      ;;
    --install-davinci)
      INSTALL_DAVINCI=true
      shift
      ;;
    --davinci-edition)
      DAVINCI_EDITION="$2"
      shift 2
      ;;
    --install-synergy)
      INSTALL_SYNERGY=true
      shift
      ;;
    --install-nvidia)
      INSTALL_NVIDIA=true
      shift
      ;;
    --install-system76)
      INSTALL_SYSTEM76=true
      shift
      ;;
    --skip-vscode-extensions)
      SKIP_VSCODE=true
      shift
      ;;
    --omit-list)
      OMIT_LIST="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo -e "${YELLOW}[$TIMESTAMP] Starting Linux bootstrap script...${NC}" | tee "$LOGFILE"

log_and_run() {
  local cmd_display=("$@")
  echo -e "${YELLOW}-> ${cmd_display[*]}${NC}" | tee -a "$LOGFILE"
  local exit_code
  if command -v script >/dev/null 2>&1; then
    local cmd_string
    printf -v cmd_string '%q ' "$@"
    set +e
    script -qefc "$cmd_string" /dev/null | tee -a "$LOGFILE"
    exit_code=${PIPESTATUS[0]}
    set -e
  else
    set +e
    "$@" 2>&1 | tee -a "$LOGFILE"
    exit_code=${PIPESTATUS[0]}
    set -e
  fi
  return $exit_code
}

sudo_log_and_run() {
  local cmd_display=("sudo" "$@")
  echo -e "${YELLOW}-> ${cmd_display[*]}${NC}" | tee -a "$LOGFILE"
  set +e
  { printf "%s\n" "$SUDO_PASS" | sudo -S "$@"; } 2>&1 | tee -a "$LOGFILE"
  local exit_code=${PIPESTATUS[0]}
  set -e
  return $exit_code
}

if [ -t 0 ]; then
  echo -ne "${YELLOW}Enter your sudo password (used for bootstrap and Ansible): ${NC}"
  stty -echo
  read -r SUDO_PASS
  stty echo
  printf "\n"
else
  read -r SUDO_PASS
fi

if ! printf "%s\n" "$SUDO_PASS" | sudo -S -v >/dev/null 2>&1; then
  echo -e "${RED}Failed to validate sudo credentials. Exiting.${NC}" | tee -a "$LOGFILE"
  exit 1
fi

( while true; do sudo -S -v >/dev/null 2>&1 < <(printf "%s\n" "$SUDO_PASS"); sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# Detect Package Manager
PKG_MGR=""
if command -v dnf >/dev/null; then
    PKG_MGR="dnf"
elif command -v apt-get >/dev/null; then
    PKG_MGR="apt-get"
else
    echo -e "${RED}Unsupported package manager. Only apt and dnf are supported.${NC}" | tee -a "$LOGFILE"
    exit 1
fi

ensure_package() {
  local pkg="$1"
  if [ "$PKG_MGR" == "apt-get" ]; then
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        sudo_log_and_run apt-get install -y "$pkg"
      fi
  elif [ "$PKG_MGR" == "dnf" ]; then
      if ! rpm -q "$pkg" >/dev/null 2>&1; then
        sudo_log_and_run dnf install -y "$pkg"
      fi
  fi
}

echo -e "${YELLOW}Refreshing package cache...${NC}" | tee -a "$LOGFILE"
if [ "$PKG_MGR" == "apt-get" ]; then
    sudo_log_and_run apt-get update
elif [ "$PKG_MGR" == "dnf" ]; then
    sudo_log_and_run dnf makecache
fi

ensure_package git
ensure_package curl
ensure_package python3
# python3-venv is often part of python3 on Fedora, but separate on Debian
if [ "$PKG_MGR" == "apt-get" ]; then
    ensure_package python3-venv
fi
ensure_package python3-pip
ensure_package ansible

log_and_run ansible-galaxy collection install community.general

VARS_FILE=$(mktemp)
chmod 600 "$VARS_FILE"
cat <<EOF > "$VARS_FILE"
{
  "ansible_become_password": "${SUDO_PASS}",
  "skip_ai_tools": ${SKIP_AI_TOOLS},
  "install_davinci": ${INSTALL_DAVINCI},
  "davinci_edition": "${DAVINCI_EDITION}",
  "install_synergy": ${INSTALL_SYNERGY},
  "install_nvidia": ${INSTALL_NVIDIA},
  "install_system76": ${INSTALL_SYSTEM76},
  "skip_vscode_extensions": ${SKIP_VSCODE},
  "omit_list_str": "${OMIT_LIST}"
}
EOF

log_and_run env ANSIBLE_FORCE_COLOR=1 ansible-playbook "$PLAYBOOK" --extra-vars @"$VARS_FILE" && ansible_exit=0 || ansible_exit=$?

rm -f "$VARS_FILE"

kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
unset SUDO_PASS

if [ $ansible_exit -ne 0 ]; then
  echo -e "${RED}Playbook failed. See $LOGFILE for details.${NC}" | tee -a "$LOGFILE"
  exit $ansible_exit
fi

echo -e "${GREEN}Playbook completed successfully.${NC}" | tee -a "$LOGFILE"

if [ ! -f "$HOME/.p10k.zsh" ]; then
  echo "" | tee -a "$LOGFILE"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOGFILE"
  echo -e "${YELLOW}  Powerlevel10k Setup${NC}" | tee -a "$LOGFILE"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOGFILE"
  echo -e "  To configure your Powerlevel10k prompt, run:" | tee -a "$LOGFILE"
  echo "" | tee -a "$LOGFILE"
  echo -e "    ${GREEN}p10k_setup.py${NC}" | tee -a "$LOGFILE"
  echo "" | tee -a "$LOGFILE"
  echo -e "  This lets you apply the default theme, run the interactive" | tee -a "$LOGFILE"
  echo -e "  wizard, or load your own custom .p10k.zsh file." | tee -a "$LOGFILE"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOGFILE"
  echo "" | tee -a "$LOGFILE"
fi

REBOOT_NEEDED=false
REBOOT_REASONS=()

# Check if NVIDIA drivers need a reboot (module installed but not loaded)
if [[ "$INSTALL_NVIDIA" == "true" ]] && command -v modinfo &>/dev/null; then
  NVIDIA_MODULE_INSTALLED=false
  NVIDIA_MODULE_LOADED=false
  if modinfo nvidia &>/dev/null; then
    NVIDIA_MODULE_INSTALLED=true
  fi
  # Note: grep -q cannot be used here because pipefail + SIGPIPE causes
  # lsmod to return non-zero when grep closes the pipe early.
  if lsmod | grep '^nvidia ' >/dev/null 2>&1 || false; then
    NVIDIA_MODULE_LOADED=true
  fi
  if [[ "$NVIDIA_MODULE_INSTALLED" == "true" && "$NVIDIA_MODULE_LOADED" == "false" ]]; then
    REBOOT_NEEDED=true
    REBOOT_REASONS+=("NVIDIA drivers were installed")
  fi
fi

# Check if kernel was upgraded (running kernel != latest installed)
RUNNING_KERNEL=$(uname -r)
if command -v rpm &>/dev/null; then
  LATEST_KERNEL=$(rpm -q kernel --last 2>/dev/null | head -1 | awk '{print $1}' | sed 's/kernel-//')
elif command -v dpkg &>/dev/null; then
  LATEST_KERNEL=$(dpkg -l 'linux-image-[0-9]*' 2>/dev/null | grep '^ii' | awk '{print $2}' | sort -V | tail -1 | sed 's/linux-image-//')
fi
if [[ -n "${LATEST_KERNEL:-}" && "$RUNNING_KERNEL" != "$LATEST_KERNEL" ]]; then
  REBOOT_NEEDED=true
  REBOOT_REASONS+=("Kernel upgraded: ${RUNNING_KERNEL} -> ${LATEST_KERNEL}")
fi

if [[ "$REBOOT_NEEDED" == "true" ]]; then
  echo -e "${YELLOW}Reboot recommended:${NC}" | tee -a "$LOGFILE"
  for reason in "${REBOOT_REASONS[@]}"; do
    echo -e "  - ${reason}" | tee -a "$LOGFILE"
  done
  echo "" | tee -a "$LOGFILE"
  echo -ne "${YELLOW}Reboot now? [y/N]: ${NC}"
  read -r REBOOT_CHOICE
  if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Rebooting...${NC}" | tee -a "$LOGFILE"
    sudo reboot
  else
    echo -e "${GREEN}Skipping reboot. Remember to reboot when convenient.${NC}" | tee -a "$LOGFILE"
  fi
fi
