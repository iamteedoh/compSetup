#!/bin/bash

# CompSetup - The Ultimate Bootstrapper
# TUI Wrapper for macOS and Linux setup scripts

set -u

# --- Configuration & State ---
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OS_NAME=$(uname -s)
BLACKLIST_FILE="$HOME/.install_blacklist"

# State Variables
SKIP_AI_TOOLS=false
INSTALL_DAVINCI=false
SKIP_VSCODE=false
OMIT_LIST=""

# --- Colors & Styles ---
ESC=$(printf '\033')
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"
MAGENTA="${ESC}[35m"
CYAN="${ESC}[36m"
WHITE="${ESC}[37m"

# Backgrounds
BG_BLUE="${ESC}[44m"
BG_BLACK="${ESC}[40m"

# Icons
ICON_OS=""
ICON_AI="🤖"
ICON_CODE=""
ICON_MEDIA=""
ICON_PKG=""
ICON_WARN=""
ICON_CHECK=""

# --- Helper Functions ---

# Clear screen
clear_screen() {
    printf "${ESC}[2J${ESC}[H"
}

# Draw a horizontal line
draw_line() {
    local char="${1:-─}"
    local width=$(tput cols)
    for ((i=0; i<width; i++)); do printf "%s" "$char"; done
    printf "\n"
}

# Draw Header
draw_header() {
    clear_screen
    printf "${BG_BLUE}${WHITE}${BOLD}  %s  COMPSETUP BOOTSTRAPPER  %s  ${RESET}\n" "$ICON_PKG" "$ICON_OS"
    printf "${BG_BLACK}${CYAN}  OS: ${OS_NAME} | User: ${USER} | Dir: ${SCRIPT_DIR}  ${RESET}\n"
    draw_line "━"
}

# Status Badge
get_status_badge() {
    if [[ "$1" == "true" ]]; then
        printf "${GREEN}[ON]${RESET}"
    else
        printf "${DIM}[OFF]${RESET}"
    fi
}

# Main Menu
show_main_menu() {
    draw_header
    echo ""
    echo -e "  ${BOLD}Select an action:${RESET}"
    echo ""
    echo -e "  ${CYAN}[1]${RESET} 🚀 Install Everything (Standard)"
    echo -e "  ${CYAN}[2]${RESET} 🍃 Install Everything (No AI Tools)"
    echo -e "  ${CYAN}[3]${RESET} ⚙️  Custom Installation / Configure Options"
    echo -e "  ${CYAN}[4]${RESET} 📝 Edit Package Blacklist"
    echo -e "  ${CYAN}[Q]${RESET} ❌ Exit"
    echo ""
    draw_line "─"
    echo -e "${DIM}  Use number keys to select.${RESET}"
}

# Custom Config Menu
show_custom_menu() {
    while true; do
        draw_header
        echo ""
        echo -e "  ${BOLD}Custom Configuration:${RESET}"
        echo ""
        echo -e "  ${CYAN}[1]${RESET} ${ICON_AI} Skip AI Tools .................... $(get_status_badge $SKIP_AI_TOOLS)"
        echo -e "  ${CYAN}[2]${RESET} ${ICON_CODE} Skip VS Code Extensions ........... $(get_status_badge $SKIP_VSCODE)"
        echo -e "  ${CYAN}[3]${RESET} ${ICON_MEDIA} Install DaVinci Dependencies ...... $(get_status_badge $INSTALL_DAVINCI)"
        echo ""
        echo -e "  ${CYAN}[R]${RESET} ▶️  Run Installation with these settings"
        echo -e "  ${CYAN}[B]${RESET} 🔙 Back to Main Menu"
        echo ""
        draw_line "─"
        read -p "  Select option: " -n 1 -r custom_choice
        echo ""
        
        case $custom_choice in
            1) 
                if [[ "$SKIP_AI_TOOLS" == "true" ]]; then SKIP_AI_TOOLS=false; else SKIP_AI_TOOLS=true; fi 
                ;;
            2) 
                if [[ "$SKIP_VSCODE" == "true" ]]; then SKIP_VSCODE=false; else SKIP_VSCODE=true; fi 
                ;;
            3) 
                if [[ "$INSTALL_DAVINCI" == "true" ]]; then INSTALL_DAVINCI=false; else INSTALL_DAVINCI=true; fi 
                ;;
            [Rr])
                run_installation
                return
                ;;
            [Bb])
                return
                ;;
        esac
    done
}

# Edit Blacklist
edit_blacklist() {
    draw_header
    echo ""
    echo -e "  ${BOLD}Package Blacklist Editor${RESET}"
    echo -e "  Packages listed in ${YELLOW}${BLACKLIST_FILE}${RESET} will be skipped."
    echo ""
    if [[ ! -f "$BLACKLIST_FILE" ]]; then
        touch "$BLACKLIST_FILE"
        echo -e "  ${GREEN}Created new blacklist file at ${BLACKLIST_FILE}${RESET}"
        echo -e "  ${DIM}This file tracks packages you want to persistently omit.${RESET}"
        sleep 2
    fi
    
    echo -e "  Opening editor (${EDITOR:-nano})..."
    sleep 1
    ${EDITOR:-nano} "$BLACKLIST_FILE"
    
    # Reload omit list logic handled in run_installation
}

# Run Logic
run_installation() {
    # Prepare Omit List from file
    OMIT_LIST=""
    if [[ -f "$BLACKLIST_FILE" ]]; then
        OMIT_LIST=$(grep -v '^\s*$' "$BLACKLIST_FILE" | tr '\n' ' ')
    fi

    # Build Arguments
    ARGS=()
    if [[ "$SKIP_AI_TOOLS" == "true" ]]; then ARGS+=("--skip-ai-tools"); fi
    if [[ "$INSTALL_DAVINCI" == "true" ]]; then ARGS+=("--install-davinci"); fi
    if [[ "$SKIP_VSCODE" == "true" ]]; then ARGS+=("--skip-vscode-extensions"); fi
    if [[ -n "$OMIT_LIST" ]]; then ARGS+=("--omit-list" "$OMIT_LIST"); fi

    draw_header
    echo -e "${YELLOW}  ${ICON_PKG} Starting Installation...${RESET}"
    echo -e "  ${DIM}Arguments: ${ARGS[*]}${RESET}"
    draw_line "═"
    echo ""
    
    # Run the OS specific script
    case "$OS_NAME" in
      Darwin)
        "$SCRIPT_DIR/macOSBootstrap.sh" "${ARGS[@]}"
        ;;
      Linux)
        "$SCRIPT_DIR/linuxBootstrap.sh" "${ARGS[@]}"
        ;;
      *)
        echo -e "${RED}Unsupported OS: $OS_NAME${RESET}"
        ;;
    esac
    
    EXIT_CODE=$?
    
    echo ""
    draw_line "═"
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "  ${GREEN}${ICON_CHECK} Installation Completed Successfully!${RESET}"
    else
        echo -e "  ${RED}${ICON_WARN} Installation Failed (Exit Code: $EXIT_CODE)${RESET}"
    fi
    echo -e "  ${DIM}Press Enter to return to menu...${RESET}"
    read -r
}

# --- Argument Parsing (CLI Mode) ---
# If args are provided, skip TUI and run directly (headless mode)
if [[ $# -gt 0 ]]; then
    PASSTHROUGH_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --omit)
                # Handle --omit flag by updating the blacklist file
                PACKAGES_TO_OMIT="${2:-}"
                if [[ -z "$PACKAGES_TO_OMIT" || "$PACKAGES_TO_OMIT" =~ ^-- ]]; then
                    echo "Error: --omit requires a package list argument." >&2
                    exit 1
                fi
                shift 2
                
                if [[ ! -f "$BLACKLIST_FILE" ]]; then
                    touch "$BLACKLIST_FILE"
                    echo -e "${GREEN}Created blacklist file at ${BLACKLIST_FILE}${RESET}"
                fi
                
                for pkg in $PACKAGES_TO_OMIT; do
                    if ! grep -q "^$pkg$" "$BLACKLIST_FILE"; then
                        echo "$pkg" >> "$BLACKLIST_FILE"
                        echo -e "${YELLOW}Added '$pkg' to blacklist.${RESET}"
                    fi
                done
                ;;
            *)
                PASSTHROUGH_ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # Read blacklist content to pass as --omit-list to inner scripts
    OMIT_CONTENT=""
    if [[ -f "$BLACKLIST_FILE" ]]; then
        OMIT_CONTENT=$(grep -v '^\s*$' "$BLACKLIST_FILE" | tr '\n' ' ')
    fi
    
    if [[ -n "$OMIT_CONTENT" ]]; then
        PASSTHROUGH_ARGS+=("--omit-list" "$OMIT_CONTENT")
    fi

    # Simple pass-through wrapper logic for headless
    case "$OS_NAME" in
      Darwin)
        exec "$SCRIPT_DIR/macOSBootstrap.sh" "${PASSTHROUGH_ARGS[@]}"
        ;;
      Linux)
        exec "$SCRIPT_DIR/linuxBootstrap.sh" "${PASSTHROUGH_ARGS[@]}"
        ;;
      *)
        echo "Unsupported OS"
        exit 1
        ;;
    esac
    exit 0
fi

# --- Main Loop (TUI Mode) ---
while true; do
    show_main_menu
    read -p "  Selection: " -n 1 -r choice
    echo ""
    
    case $choice in
        1)
            # Standard: Install Everything (Defaults: AI=false (meaning install it), VSCode=false (install it), Davinci=false)
            SKIP_AI_TOOLS=false
            SKIP_VSCODE=false
            # Should Davinci be default? No.
            run_installation
            ;;
        2)
            # No AI
            SKIP_AI_TOOLS=true
            run_installation
            ;;
        3)
            show_custom_menu
            ;;
        4)
            edit_blacklist
            ;;
        [Qq])
            echo -e "\n  ${GREEN}Goodbye!${RESET}"
            exit 0
            ;;
        *)
            # Invalid
            ;;
    esac
done



