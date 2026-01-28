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

SKIP_AI_TOOLS=false
INSTALL_DAVINCI=false
DAVINCI_EDITION=""
INSTALL_SYNERGY=false
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

echo -e "${YELLOW}[$TIMESTAMP] Starting macOS bootstrap script...${NC}" | tee "$LOGFILE"

## Prime sudo (caches credentials for other parts)
echo -e "${YELLOW}Validating sudo access...${NC}" | tee -a "$LOGFILE"
echo -ne "${YELLOW}Enter your macOS password (used for sudo and Ansible): ${NC}"
stty -echo
read -r SUDO_PASS
stty echo
echo
if ! printf "%s\n" "$SUDO_PASS" | sudo -S -v >/dev/null 2>&1; then
  echo -e "${RED}Failed to validate sudo credentials. Exiting.${NC}" | tee -a "$LOGFILE"
  exit 1
fi
# Keep sudo alive for the duration of this script to avoid re-prompts
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
# Provide Ansible with the become password via environment (avoids interactive prompts)
export ANSIBLE_BECOME_PASSWORD="$SUDO_PASS"
unset SUDO_PASS
export ANSIBLE_FORCE_COLOR=true

## Ensure /usr/local/share/zsh is writable by current user
echo -e "${YELLOW}Ensuring /usr/local/share/zsh is writable...${NC}" | tee -a "$LOGFILE"
if [[ -d /usr/local/share/zsh ]]; then
  sudo chown -R "$USER" /usr/local/share/zsh /usr/local/share/zsh/site-functions
  sudo chmod u+w /usr/local/share/zsh /usr/local/share/zsh/site-functions
fi

## Log and run commands
log_and_run() {
  echo -e "${YELLOW}-> $*${NC}" | tee -a "$LOGFILE"
  # Disabling 'e' temporarily for commands that might fail but we want to continue
  set +e
  bash -c "$*" 2>&1 | tee -a "$LOGFILE"
  local exit_code=${PIPESTATUS[0]}
  set -e
  return $exit_code
}

# Run a command and only write output to the log (no console echo of the command)
run_silent() {
  # Disabling 'e' temporarily for commands that might fail but we want to continue
  set +e
  bash -c "$*" 2>&1 | tee -a "$LOGFILE" > /dev/null
  local exit_code=${PIPESTATUS[0]}
  set -e
  return $exit_code
}

## Check for Homebrew installation
echo "== Reached: brew install section ==" | tee -a "$LOGFILE"
if ! command -v brew &> /dev/null; then
  echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}" | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOGFILE" 2>&1
  echo -e "${GREEN}Homebrew installed.${NC}" | tee -a "$LOGFILE"
else
  echo -e "${GREEN}Homebrew is already installed.${NC}" | tee -a "$LOGFILE"
fi

## Ensure correct Homebrew environment (for Apple Silicon)
if [[ "$(uname -m)" == "arm64" ]]; then
  echo -e "${YELLOW}Setting up Homebrew environment for Apple Silicon...${NC}" | tee -a "$LOGFILE"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

## Validate and repair Homebrew if needed
echo "== Reached: brew repair section ==" | tee -a "$LOGFILE"
# Check if a basic brew command fails. This is a better sign of a broken installation
# than `brew doctor`, which can exit with a non-zero status for simple warnings.
if ! brew config >/dev/null 2>&1; then
  echo -e "${YELLOW}Homebrew installation appears to be broken. Attempting repair...${NC}" | tee -a "$LOGFILE"
  log_and_run "brew update --force"
  log_and_run "brew upgrade"
else
  echo -e "${GREEN}Homebrew installation is functional.${NC}" | tee -a "$LOGFILE"
  # Proactively remove duplicate formulae when a cask of the same name is installed (e.g., handbrake)
  echo -e "${YELLOW}Checking for cask/formula duplicates before upgrade...${NC}" | tee -a "$LOGFILE"
  run_silent "bash -c 'c=\$(brew list --cask --versions 2>/dev/null | awk '\''{print \$1}'\''); f=\$(brew list --formula --versions 2>/dev/null | awk '\''{print \$1}'\''); for n in \$c; do if echo \"\$f\" | grep -qx \"\$n\"; then echo \"Uninstalling duplicate formula: \$n (cask present)\"; brew uninstall --formula \"\$n\" || true; fi; done'"
  echo -e "${YELLOW}Checking for outdated packages and upgrading...${NC}" | tee -a "$LOGFILE"
  OUTDATED_COUNT=$(brew outdated | wc -l | tr -d ' ')
  if [[ "$OUTDATED_COUNT" -gt 0 ]]; then
    echo -e "${YELLOW}$OUTDATED_COUNT packages are outdated. Upgrading...${NC}" | tee -a "$LOGFILE"
    log_and_run "brew upgrade"
    echo -e "${GREEN}Homebrew packages upgraded.${NC}" | tee -a "$LOGFILE"
  else
    echo -e "${GREEN}No outdated Homebrew packages found.${NC}" | tee -a "$LOGFILE"
  fi
fi


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
  log_and_run "xcode-select --install || true"
else
  echo -e "${GREEN}Xcode Command Line Tools already installed.${NC}" | tee -a "$LOGFILE"
fi

## Now it's safe to update Homebrew and check for issues
log_and_run "brew update"
# We still run `brew doctor` to log any potential issues, but `|| true` prevents it
# from stopping the script on warnings.
log_and_run "brew doctor || true"

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
if [[ "$SKIP_VSCODE" == "true" ]]; then
  export INSTALL_VSCODE_EXTENSIONS=false
  echo -e "${YELLOW}Skipping VS Code extensions as requested via flag.${NC}" | tee -a "$LOGFILE"
elif [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code &> /dev/null; then
  export INSTALL_VSCODE_EXTENSIONS=true
  echo -e "${GREEN}Visual Studio Code is installed. VS Code extensions will be installed.${NC}" | tee -a "$LOGFILE"
else
  export INSTALL_VSCODE_EXTENSIONS=false
  echo -e "${YELLOW}Visual Studio Code is NOT installed. Skipping VS Code extensions.${NC}" | tee -a "$LOGFILE"
fi

## Run Ansible Playbook for config/package management
echo "== Reached: Ansible role (final) section ==" | tee -a "$LOGFILE"
if [[ -f "$PLAYBOOK" ]]; then
  echo -e "${YELLOW}Running Ansible playbook: ${PLAYBOOK}${NC}" | tee -a "$LOGFILE"
  if [[ "$INSTALL_VSCODE_EXTENSIONS" == "true" ]]; then
    VSCODE_FLAG=true
  else
    VSCODE_FLAG=false
  fi
VARS_FILE=$(mktemp -t ansible-vars.XXXXXX)
  chmod 600 "$VARS_FILE"
printf '{"install_vscode_extensions": %s, "ansible_become_password": "%s", "skip_ai_tools": %s, "install_davinci": %s, "davinci_edition": "%s", "install_synergy": %s, "omit_list_str": "%s"}\n' "$VSCODE_FLAG" "$ANSIBLE_BECOME_PASSWORD" "$SKIP_AI_TOOLS" "$INSTALL_DAVINCI" "$DAVINCI_EDITION" "$INSTALL_SYNERGY" "$OMIT_LIST" > "$VARS_FILE"
log_and_run "ansible-playbook $PLAYBOOK --extra-vars @\"$VARS_FILE\""
  rm -f "$VARS_FILE" 2>/dev/null || true
  echo -e "${GREEN}Playbook completed successfully.${NC}" | tee -a "$LOGFILE"

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

else
  echo -e "${RED}Playbook $PLAYBOOK not found. Exiting.${NC}" | tee -a "$LOGFILE"
  exit 1
fi
