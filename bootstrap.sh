#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OS_NAME=$(uname -s)

SKIP_AI_TOOLS=false

# Helper function to print help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message and exit"
    echo "  --skip-ai-tools     Skip installation of AI tools (gemini-cli, claude-cli, antigravity)"
    echo
    echo "If no options are provided, an interactive menu will be shown."
}

# Helper function to print usage or interactive menu
print_menu() {
    echo "AI Tools Installation Options:"
    echo "1. Install everything (including AI tools)"
    echo "2. Install everything EXCEPT AI tools (gemini-cli, claude-cli, antigravity)"
    echo "3. Exit"
    echo -n "Please select an option (1-3): "
}

# Check for flags
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        case $arg in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-ai-tools)
                SKIP_AI_TOOLS=true
                ;;
            *)
                # Pass other arguments through
                ;;
        esac
    done
else
    # Interactive mode
    echo "No flags provided."
    print_menu
    read -r choice
    case $choice in
        1)
            SKIP_AI_TOOLS=false
            ;;
        2)
            SKIP_AI_TOOLS=true
            ;;
        3)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Prepare arguments for the OS specific scripts
ARGS=("$@")
if [[ "$SKIP_AI_TOOLS" == "true" ]]; then
    # Check if flag is already in ARGS to avoid duplication
    found=false
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" == "--skip-ai-tools" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == "false" ]]; then
        ARGS+=("--skip-ai-tools")
    fi
fi

case "$OS_NAME" in
  Darwin)
    exec "$SCRIPT_DIR/macOSBootstrap.sh" "${ARGS[@]}"
    ;;
  Linux)
    exec "$SCRIPT_DIR/linuxBootstrap.sh" "${ARGS[@]}"
    ;;
  *)
    echo "Unsupported operating system: $OS_NAME" >&2
    echo "Only macOS and Ubuntu/Pop!_OS (Linux) are currently supported." >&2
    exit 1
    ;;
esac


