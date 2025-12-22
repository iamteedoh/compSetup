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
for arg in "$@"; do
  if [[ "$arg" == "--skip-ai-tools" ]]; then
    SKIP_AI_TOOLS=true
  fi
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

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    sudo_log_and_run apt-get install -y "$pkg"
  fi
}

echo -e "${YELLOW}Refreshing apt cache...${NC}" | tee -a "$LOGFILE"
sudo_log_and_run apt-get update

ensure_package git
ensure_package curl
ensure_package python3
ensure_package python3-venv
ensure_package python3-pip
ensure_package ansible

log_and_run ansible-galaxy collection install community.general

VARS_FILE=$(mktemp)
chmod 600 "$VARS_FILE"
cat <<EOF > "$VARS_FILE"
{
  "ansible_become_password": "${SUDO_PASS}",
  "skip_ai_tools": ${SKIP_AI_TOOLS}
}
EOF

if ! log_and_run env ANSIBLE_FORCE_COLOR=1 ansible-playbook "$PLAYBOOK" --extra-vars @"$VARS_FILE"; then
  ansible_exit=$?
else
  ansible_exit=0
fi

rm -f "$VARS_FILE"

kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
unset SUDO_PASS

if [ $ansible_exit -ne 0 ]; then
  echo -e "${RED}Playbook failed. See $LOGFILE for details.${NC}" | tee -a "$LOGFILE"
  exit $ansible_exit
fi

echo -e "${GREEN}Playbook completed successfully.${NC}" | tee -a "$LOGFILE"

