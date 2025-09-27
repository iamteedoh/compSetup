#!/bin/bash

set -euo pipefail

LOGFILE="bootstrap.log"
PLAYBOOK="site.yml"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}[$TIMESTAMP] Starting Linux bootstrap script...${NC}" | tee "$LOGFILE"

if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}Validating sudo access...${NC}" | tee -a "$LOGFILE"
  if ! sudo -v; then
    echo -e "${RED}Unable to obtain sudo privileges. Exiting.${NC}" | tee -a "$LOGFILE"
    exit 1
  fi
fi

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing package: ${pkg}${NC}" | tee -a "$LOGFILE"
    sudo apt-get install -y "$pkg" >> "$LOGFILE" 2>&1
  fi
}

echo -e "${YELLOW}Refreshing apt cache...${NC}" | tee -a "$LOGFILE"
sudo apt-get update >> "$LOGFILE" 2>&1

ensure_package git
ensure_package curl
ensure_package python3
ensure_package python3-venv
ensure_package python3-pip
ensure_package ansible

echo -e "${YELLOW}Ensuring required Ansible collections are installed...${NC}" | tee -a "$LOGFILE"
ansible-galaxy collection install community.general >> "$LOGFILE" 2>&1

echo -e "${YELLOW}Running Ansible playbook: ${PLAYBOOK}${NC}" | tee -a "$LOGFILE"
ansible-playbook "$PLAYBOOK" >> "$LOGFILE" 2>&1

echo -e "${GREEN}Playbook completed successfully.${NC}" | tee -a "$LOGFILE"

