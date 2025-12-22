#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OS_NAME=$(uname -s)

SKIP_AI_TOOLS=false
INSTALL_DAVINCI=false
SKIP_VSCODE=false
BLACKLIST_FILE="$SCRIPT_DIR/.install_blacklist"
OMIT_INPUT=""

# Helper function to print help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message and exit"
    echo "  --skip-ai-tools            Skip installation of AI tools (gemini-cli, claude-cli, antigravity)"
    echo "  --install-davinci          Install DaVinci Resolve dependencies (Pop!_OS/Linux only)"
    echo "  --skip-vscode-extensions   Skip installation of VS Code extensions"
    echo "  --omit \"pkg1 pkg2\"         List of packages to omit from installation (saved to .install_blacklist)"
    echo
    echo "If no options are provided, an interactive menu will be shown."
}

# Helper function to print usage or interactive menu
print_menu() {
    echo "Installation Options:"
    echo "1. Install everything (Standard)"
    echo "2. Install everything EXCEPT AI tools (gemini-cli, claude-cli, antigravity)"
    echo "3. Custom Install (Prompts for options)"
    echo "4. Exit"
    echo -n "Please select an option (1-4): "
}

# Check for flags or interactive mode
if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-ai-tools)
                SKIP_AI_TOOLS=true
                shift
                ;;
            --install-davinci)
                INSTALL_DAVINCI=true
                shift
                ;;
            --skip-vscode-extensions)
                SKIP_VSCODE=true
                shift
                ;;
            --omit)
                if [[ -n "${2:-}" && ! "${2:-}" =~ ^-- ]]; then
                    OMIT_INPUT="$2"
                    shift 2
                else
                    echo "Error: --omit requires a package list argument." >&2
                    exit 1
                fi
                ;;
            *)
                # Pass unknown args? Or error?
                # For safety, let's ignore unknown or pass them?
                # Inner scripts might not like them.
                shift
                ;;
        esac
    done
else
    # Interactive mode
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
            echo "Custom Install:"
            read -p "Skip AI Tools? (y/n): " -r ais
            [[ "$ais" =~ ^[Yy] ]] && SKIP_AI_TOOLS=true
            
            read -p "Install DaVinci Resolve dependencies? (y/n): " -r dav
            [[ "$dav" =~ ^[Yy] ]] && INSTALL_DAVINCI=true

            read -p "Skip VS Code Extensions? (y/n): " -r vsc
            [[ "$vsc" =~ ^[Yy] ]] && SKIP_VSCODE=true

            read -p "Enter packages to omit (space separated, or leave empty): " -r omits
            OMIT_INPUT="$omits"
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Handle Blacklist
if [[ -n "$OMIT_INPUT" ]]; then
    # Create file if not exists
    touch "$BLACKLIST_FILE"
    for pkg in $OMIT_INPUT; do
        if ! grep -q "^$pkg$" "$BLACKLIST_FILE"; then
            echo "$pkg" >> "$BLACKLIST_FILE"
        fi
    done
fi

OMIT_LIST=""
if [[ -f "$BLACKLIST_FILE" ]]; then
    # Read non-empty lines
    OMIT_LIST=$(grep -v '^\s*$' "$BLACKLIST_FILE" | tr '\n' ' ')
fi

# Prepare arguments for the OS specific scripts
ARGS=()
if [[ "$SKIP_AI_TOOLS" == "true" ]]; then ARGS+=("--skip-ai-tools"); fi
if [[ "$INSTALL_DAVINCI" == "true" ]]; then ARGS+=("--install-davinci"); fi
if [[ "$SKIP_VSCODE" == "true" ]]; then ARGS+=("--skip-vscode-extensions"); fi
if [[ -n "$OMIT_LIST" ]]; then ARGS+=("--omit-list" "$OMIT_LIST"); fi

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


