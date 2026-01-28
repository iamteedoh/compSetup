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
DAVINCI_EDITION=""
INSTALL_SYNERGY=false
INSTALL_NVIDIA=false
INSTALL_SYSTEM76=false
SKIP_VSCODE=false
OMIT_LIST=""
SELECTED_DISTRO=""    # "fedora", "ubuntu", or "" (macOS)

# --- Colors & Styles ---
ESC=$(printf '\033')
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
ORANGE="${ESC}[38;5;214m"
PURPLE="${ESC}[35m"
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

# OS / Distro Selection
validate_os_choice() {
    local choice="$1"
    case "$choice" in
        fedora|ubuntu)
            if [[ "$OS_NAME" != "Linux" ]]; then
                echo ""
                echo -e "  ${RED}${ICON_WARN} Mismatch: You selected a Linux distribution but this system is ${OS_NAME}.${RESET}"
                echo -e "  ${DIM}  Please select the correct OS for this machine.${RESET}"
                echo ""
                sleep 2
                return 1
            fi
            ;;
        macos)
            if [[ "$OS_NAME" != "Darwin" ]]; then
                echo ""
                echo -e "  ${RED}${ICON_WARN} Mismatch: You selected macOS but this system is ${OS_NAME}.${RESET}"
                echo -e "  ${DIM}  Please select the correct OS for this machine.${RESET}"
                echo ""
                sleep 2
                return 1
            fi
            ;;
    esac
    return 0
}

show_distro_menu() {
    while true; do
        draw_header
        echo ""
        echo -e "  ${BOLD}Which OS are you running this installation on?${RESET}"
        echo -e "  ${DIM}  Detected: ${OS_NAME}${RESET}"
        echo ""
        echo -e "  ${CYAN}[1]${RESET} 🐧 Fedora"
        echo -e "  ${CYAN}[2]${RESET} 🐧 Ubuntu / Pop!_OS"
        echo -e "  ${CYAN}[3]${RESET} 🍎 macOS"
        echo -e "  ${CYAN}[Q]${RESET} ❌ Exit"
        echo ""
        draw_line "─"
        read -p "  Selection: " -n 1 -r distro_choice
        echo ""
        case $distro_choice in
            1)
                if validate_os_choice "fedora"; then
                    SELECTED_DISTRO="fedora"
                    return
                fi
                ;;
            2)
                if validate_os_choice "ubuntu"; then
                    SELECTED_DISTRO="ubuntu"
                    return
                fi
                ;;
            3)
                if validate_os_choice "macos"; then
                    SELECTED_DISTRO="macos"
                    return
                fi
                ;;
            [Qq])
                echo -e "\n  ${GREEN}Goodbye!${RESET}"
                exit 0
                ;;
        esac
    done
}

# Main Menu
show_main_menu() {
    draw_header
    echo ""
    echo -e "  ${BOLD}Select an action:${RESET}"
    echo ""
    echo -e "  ${CYAN}[1]${RESET} 🚀 Install Everything (Standard)"
    echo -e "  ${CYAN}[2]${RESET} 🍃 Install Everything (No AI Tools)"
    if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
        echo -e "  ${CYAN}[3]${RESET} 🖥️  Install Everything + System76 Support"
        echo -e "  ${CYAN}[4]${RESET} 🎮 Install NVIDIA Drivers Only"
        echo -e "  ${CYAN}[5]${RESET} ⚙️  Custom Installation / Configure Options"
        echo -e "  ${CYAN}[6]${RESET} 📝 Edit Package Blacklist"
    else
        echo -e "  ${CYAN}[3]${RESET} ⚙️  Custom Installation / Configure Options"
        echo -e "  ${CYAN}[4]${RESET} 📝 Edit Package Blacklist"
    fi
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
        if [[ "$INSTALL_DAVINCI" == "true" && -n "$DAVINCI_EDITION" ]]; then
            local edition_label
            if [[ "$DAVINCI_EDITION" == "studio" ]]; then
                edition_label="${PURPLE}Studio${RESET}"
            else
                edition_label="Free"
            fi
            echo -e "  ${CYAN}[3]${RESET} ${ICON_MEDIA} Install DaVinci Resolve ........... ${GREEN}[ON]${RESET} ${DIM}(${edition_label}${DIM})${RESET}"
        else
            echo -e "  ${CYAN}[3]${RESET} ${ICON_MEDIA} Install DaVinci Resolve ........... ${DIM}[OFF]${RESET}"
        fi
        echo -e "  ${CYAN}[4]${RESET} 🖥️  Install Synergy (KVM) .............. $(get_status_badge $INSTALL_SYNERGY)"
        echo -e "      ${DIM}Share keyboard & mouse across computers${RESET}"
        if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
            echo -e "  ${CYAN}[5]${RESET} 🎮 Install NVIDIA Drivers ............ $(get_status_badge $INSTALL_NVIDIA)"
            echo -e "      ${DIM}Auto-detects GPU generation${RESET}"
            echo -e "  ${CYAN}[6]${RESET} 💻 Install System76 Support .......... $(get_status_badge $INSTALL_SYSTEM76)"
            echo -e "      ${DIM}System76 firmware, power, DKMS${RESET}"
        fi
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
                if [[ "$INSTALL_DAVINCI" == "true" ]]; then
                    INSTALL_DAVINCI=false
                    DAVINCI_EDITION=""
                else
                    echo ""
                    echo -e "  ${BOLD}Select DaVinci Resolve edition:${RESET}"
                    echo ""
                    echo -e "  ${CYAN}[1]${RESET} DaVinci Resolve (Free)"
                    echo -e "  ${CYAN}[2]${RESET} DaVinci Resolve Studio (Paid)"
                    echo -e "  ${CYAN}[B]${RESET} Cancel"
                    echo ""
                    read -p "  Edition: " -n 1 -r edition_choice
                    echo ""
                    case $edition_choice in
                        1)
                            INSTALL_DAVINCI=true
                            DAVINCI_EDITION="free"
                            ;;
                        2)
                            echo ""
                            echo -e "  ${YELLOW}${ICON_WARN} DaVinci Resolve Studio requires a valid license from Blackmagic Design.${RESET}"
                            echo -e "  ${DIM}  You must own a license key or USB dongle to activate Studio.${RESET}"
                            echo ""
                            read -p "  Continue with Studio? [y/N]: " -n 1 -r studio_confirm
                            echo ""
                            if [[ "$studio_confirm" =~ ^[Yy]$ ]]; then
                                INSTALL_DAVINCI=true
                                DAVINCI_EDITION="studio"
                            fi
                            ;;
                        [Bb])
                            ;;
                    esac
                fi
                ;;
            4)
                if [[ "$INSTALL_SYNERGY" == "true" ]]; then INSTALL_SYNERGY=false; else INSTALL_SYNERGY=true; fi
                ;;
            5)
                if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                    if [[ "$INSTALL_NVIDIA" == "true" ]]; then INSTALL_NVIDIA=false; else INSTALL_NVIDIA=true; fi
                fi
                ;;
            6)
                if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                    if [[ "$INSTALL_SYSTEM76" == "true" ]]; then INSTALL_SYSTEM76=false; else INSTALL_SYSTEM76=true; fi
                fi
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
        echo ""
        echo -e "  ${GREEN}${ICON_CHECK} Created new blacklist file at ${RESET}${BOLD}${BLACKLIST_FILE}${RESET}"
        echo -e "  ${DIM}This file tracks packages you want to persistently omit.${RESET}"
        echo ""
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
    if [[ -n "$DAVINCI_EDITION" ]]; then ARGS+=("--davinci-edition" "$DAVINCI_EDITION"); fi
    if [[ "$INSTALL_SYNERGY" == "true" ]]; then ARGS+=("--install-synergy"); fi
    if [[ "$INSTALL_NVIDIA" == "true" ]]; then ARGS+=("--install-nvidia"); fi
    if [[ "$INSTALL_SYSTEM76" == "true" ]]; then ARGS+=("--install-system76"); fi
    if [[ "$SKIP_VSCODE" == "true" ]]; then ARGS+=("--skip-vscode-extensions"); fi
    if [[ -n "$OMIT_LIST" ]]; then ARGS+=("--omit-list" "$OMIT_LIST"); fi

    draw_header
    echo ""
    echo -e "${YELLOW}  ${ICON_PKG} Starting Installation...${RESET}"
    echo -e "  ${DIM}Arguments: ${ARGS[*]:-}${RESET}"
    echo ""
    draw_line "═"
    echo ""
    
    # Run the OS specific script
    case "$OS_NAME" in
      Darwin)
        "$SCRIPT_DIR/macOSBootstrap.sh" "${ARGS[@]:-}"
        ;;
      Linux)
        "$SCRIPT_DIR/linuxBootstrap.sh" "${ARGS[@]:-}"
        ;;
      *)
        echo -e "${RED}Unsupported OS: $OS_NAME${RESET}"
        ;;
    esac
    
    EXIT_CODE=$?
    
    echo ""
    draw_line "═"
    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "  ${GREEN}${ICON_CHECK} Installation Completed Successfully!${RESET}"
    else
        echo -e "  ${RED}${ICON_WARN} Installation Failed (Exit Code: $EXIT_CODE)${RESET}"
    fi
    echo ""
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
                    echo ""
                    echo -e "${GREEN}${ICON_CHECK} Created blacklist file at ${RESET}${BOLD}${BLACKLIST_FILE}${RESET}"
                    echo ""
                fi
                
                for pkg in $PACKAGES_TO_OMIT; do
                    if ! grep -q "^$pkg$" "$BLACKLIST_FILE"; then
                        echo "$pkg" >> "$BLACKLIST_FILE"
                        echo -e "${ORANGE}Added '$pkg' to blacklist.${RESET}"
                    else
                        echo -e "${PURPLE}Package '$pkg' is already in the blacklist.${RESET}"
                    fi
                done
                echo ""
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
        exec "$SCRIPT_DIR/macOSBootstrap.sh" "${PASSTHROUGH_ARGS[@]:-}"
        ;;
      Linux)
        exec "$SCRIPT_DIR/linuxBootstrap.sh" "${PASSTHROUGH_ARGS[@]:-}"
        ;;
      *)
        echo "Unsupported OS"
        exit 1
        ;;
    esac
    exit 0
fi

# --- Main Loop (TUI Mode) ---
show_distro_menu

while true; do
    show_main_menu
    read -p "  Selection: " -n 1 -r choice
    echo ""

    case $choice in
        1)
            # Standard: Install Everything
            SKIP_AI_TOOLS=false
            SKIP_VSCODE=false
            INSTALL_SYNERGY=true
            run_installation
            ;;
        2)
            # No AI
            SKIP_AI_TOOLS=true
            INSTALL_SYNERGY=true
            run_installation
            ;;
        3)
            if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                # Everything + System76 Support
                SKIP_AI_TOOLS=false
                SKIP_VSCODE=false
                INSTALL_SYNERGY=true
                INSTALL_NVIDIA=true
                INSTALL_SYSTEM76=true
                run_installation
            else
                show_custom_menu
            fi
            ;;
        4)
            if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                # NVIDIA Drivers Only
                INSTALL_NVIDIA=true
                run_installation
            else
                edit_blacklist
            fi
            ;;
        5)
            if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                show_custom_menu
            fi
            ;;
        6)
            if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
                edit_blacklist
            fi
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



