#!/bin/bash

set -euo pipefail

## Setup Options
LOGFILE="bootstrap.log"
PLAYBOOK="site.yml"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[$TIMESTAMP] Starting macOS bootstrap script...${NC}" | tee "$LOGFILE"

## Log and run commands
log_and_run() {
  echo -e "${YELLOW}-> $*${NC}" | tee -a "$LOGFILE"
  eval "$@" >> "$LOGFILE" 2>&1
}

## Check for Homebrew installation
if ! command -v brew &> /dev/null; then
  echo -e "${YELLOW}Homebrew not found. Installing Hombrew...${NC}" | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOGFILE" 2>&1
  echo -e "${GREEN}Homebrew installed.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${GREEN}Homebrew is already installed.${NC}" | tee -a "$LOGFILE"
fi

## Ensure Homebrew is up to date
#echo -e "${YELLOW}Updating Homebrew...${NC}"
log_and_run "brew update"

## Check for Ansible installation
if ! command -v ansible &> /dev/null; then
  echo -e "${YELLOW}Ansible not found. Installing Ansible via Homebrew...${NC}" | tee -a "$LOGFILE"
  log_and_run "brew install ansible"
  echo -e "${GREEN}Ansible installed.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${GREEN}Ansible is already installed.${NC}" | tee -a "$LOGFILE"
fi

## Ensure required collection is installed
echo -e "${YELLOW}Ensuring required Ansible collections are installed...${NC}" | tee -a "$LOGFILE"
log_and_run "ansible-galaxy collection install community.general"

## VS Code check (used as a fact for the role)
if [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code &> /dev/null; then
  export INSTALL_VSCODE_EXTENSIONS=true
  echo -e "${GREEN}Vidual Studio Code is installed. VS Code extensions will be installed.${NC}" | tee -a "$LOGFILE"
else
  export INSTALL_VSCODE_EXTENSIONS=false
  echo -e "${YELLOW}Visual Studio Code is NOT installed. Skipping VS Code extensions.${NC}" | tee -a "$LOGFILE"
fi

## Run Ansbile Playbook for config/package management
if [[ -f "$PLAYBOOK" ]]; then
  echo -e "${YELLOW}Running Ansible playbook: ${PLAYBOOK}${NC}" | tee -a "$LOGFILE"
  log_and_run "ansible-playbook $PLAYBOOK -e \"install_vscode_extensions=$INSTALL_VSCODE_EXTENSIONS\""
  echo -e "${GREEN}Playbook completed successfull.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${RED}Playbook $PLAYBOOK not found. Exiting.${NC}" | tee -a "$LOGFILE"
  exit 1
fi
