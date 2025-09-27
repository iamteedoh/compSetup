---
#!/bin/bash

set -euo pipefail

LOGFILE="bootstrap.log"
PLAYBOOK="site.yml"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo -e "${YELLOW}[$TIMESTAMP] Starting Linux bootstrap script...${NC}" | tee "$LOGFILE"

echo -ne "${YELLOW}Enter your sudo password (used for bootstrap and Ansible): ${NC}"
stty -echo
read -r SUDO_PASS
stty echo
printf "\n"

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
    echo -e "${YELLOW}Installing package: ${pkg}${NC}" | tee -a "$LOGFILE"
    printf "%s\n" "$SUDO_PASS" | sudo -S apt-get install -y "$pkg" >> "$LOGFILE" 2>&1
  fi
}

echo -e "${YELLOW}Refreshing apt cache...${NC}" | tee -a "$LOGFILE"
printf "%s\n" "$SUDO_PASS" | sudo -S apt-get update >> "$LOGFILE" 2>&1

ensure_package git
ensure_package curl
ensure_package python3
ensure_package python3-venv
ensure_package python3-pip
ensure_package ansible

printf "%s" "${SUDO_PASS}" | ansible-galaxy collection install community.general >> "$LOGFILE" 2>&1

VARS_FILE=$(mktemp)
chmod 600 "$VARS_FILE"
cat <<EOF > "$VARS_FILE"
{
  "ansible_become_password": "${SUDO_PASS}"
}
EOF

printf "%s\n" "$SUDO_PASS" | ansible-playbook "$PLAYBOOK" --extra-vars @"$VARS_FILE" >> "$LOGFILE" 2>&1
rm -f "$VARS_FILE"

kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
unset SUDO_PASS

echo -e "${GREEN}Playbook completed successfully.${NC}" | tee -a "$LOGFILE"

