#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo ""
    echo "Please run this script with sudo:"
    echo "    sudo $0"
    echo ""
    exit 1
fi

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
  bash -c "$*" >> "$LOGFILE" 2>&1
}

## Check for Homebrew installation
echo "== Reached: brew install section ==" | tee -a "$LOGFILE"
if ! command -v brew &> /dev/null; then
  echo -e "${YELLOW}Homebrew not found. Installing Hombrew...${NC}" | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOGFILE" 2>&1
  echo -e "${GREEN}Homebrew installed.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${GREEN}Homebrew is already installed.${NC}" | tee -a "$LOGFILE"
fi

## Validate and repair Homebrew if needed
echo "== Reached: brew repair section ==" | tee -a "$LOGFILE"
log_and_run "test -d \$(brew --repo) || echo 'Homebrew repo missing — repairing...'"

## Ensure Rosetta 2 (for Apple Silicon)
if [[ $(uname -m) == "arm64" ]]; then
  echo -e "${YELLOW}Apple Silicon detected. Installing Rosetta 2 if needed...${NC}" | tee -a "$LOGFILE"
  if /usr/bin/pgrep oahd &>/dev/null; then
    echo -e "${GREEN}Rosetta 2 already installed.${NC}" | tee -a "$LOGFILE"
  else
    log_and_run "/usr/sbin/softwareupdate --install-rosetta --agree-to-license"
  fi
fi

## Ensure Xcode Command Line Tools
echo -e "${YELLOW}Checking for Xcode Command Line Tools...${NC}" | tee -a "$LOGFILE"
if ! xcode-select -p &>/dev/null; then
  echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}" | tee -a "$LOGFILE"
  # This will trigger a GUI prompt, so we try to install it in a non-blocking way
  log_and_run "xcode-select --install || true"
else
  echo -e "${GREEN}Xcode Command Line Tools already installed.${NC}" | tee -a "$LOGFILE"
fi

# Reinstall Homebrew if the Git repo is corrupted
if [[ ! -d "$(brew --repo)/.git" ]]; then
  echo -e "${YELLOW}Homebrew appears broken. Re-running official installer to repair it...${NC}" | tee -a "$LOGFILE"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOGFILE" 2>&1
  echo -e "${GREEN}Homebrew repaired.${NC}" | tee -a "$LOGFILE"
fi

## Now it's safe to update Homebrew
log_and_run "brew update"

## Check for Ansible installation
echo "== Reached: Ansible installation section ==" | tee -a "$LOGFILE"
if ! command -v ansible &> /dev/null; then
  echo -e "${YELLOW}Ansible not found. Installing Ansible via Homebrew...${NC}" | tee -a "$LOGFILE"
  log_and_run "brew install ansible"
  echo -e "${GREEN}Ansible installed.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${GREEN}Ansible is already installed.${NC}" | tee -a "$LOGFILE"
fi

## Ensure required collection is installed
echo "== Reached: Ansible collection section ==" | tee -a "$LOGFILE"
echo -e "${YELLOW}Ensuring required Ansible collections are installed...${NC}" | tee -a "$LOGFILE"
log_and_run "ansible-galaxy collection install community.general"

## VS Code check (used as a fact for the role)
echo "== Reached: VS Code check section ==" | tee -a "$LOGFILE"
if [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code &> /dev/null; then
  export INSTALL_VSCODE_EXTENSIONS=true
  echo -e "${GREEN}Vidual Studio Code is installed. VS Code extensions will be installed.${NC}" | tee -a "$LOGFILE"
else
  export INSTALL_VSCODE_EXTENSIONS=false
  echo -e "${YELLOW}Visual Studio Code is NOT installed. Skipping VS Code extensions.${NC}" | tee -a "$LOGFILE"
fi

## Run Ansbile Playbook for config/package management
echo "== Reached: Ansbile role (final) section ==" | tee -a "$LOGFILE"
if [[ -f "$PLAYBOOK" ]]; then
  echo -e "${YELLOW}Running Ansible playbook: ${PLAYBOOK}${NC}" | tee -a "$LOGFILE"
  log_and_run "ansible-playbook $PLAYBOOK -e \"install_vscode_extensions=$INSTALL_VSCODE_EXTENSIONS\""
  echo -e "${GREEN}Playbook completed successfull.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${RED}Playbook $PLAYBOOK not found. Exiting.${NC}" | tee -a "$LOGFILE"
  exit 1
fi
