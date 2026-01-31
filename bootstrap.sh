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
PACKAGE_SELECTOR_OMIT=""
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
ICON_SYNC=""
ICON_GPU=""
ICON_LAPTOP=""

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

# Print an aligned menu line with dot leader
# Usage: print_menu_line key icon label badge [subtitle]
# All icons are assumed to be 2 display cells wide (standard emoji).
# For 1-cell nerd font icons, pass icon_width=1 as $6 to add padding.
print_menu_line() {
    local key="$1" icon="$2" label="$3" badge="$4" subtitle="${5:-}"
    local icon_width="${6:-2}"
    local icon_pad=""
    if (( icon_width < 2 )); then icon_pad=" "; fi
    local target=35
    local pad=$((target - ${#label}))
    if (( pad < 3 )); then pad=3; fi
    printf -v dots '%*s' "$pad" ''
    dots=${dots// /.}
    echo -e "  ${CYAN}[${key}]${RESET} ${icon}${icon_pad}  ${label} ${DIM}${dots}${RESET} ${badge}"
    if [[ -n "$subtitle" ]]; then
        echo -e "           ${DIM}${subtitle}${RESET}"
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
    echo -e "  ${CYAN}[1]${RESET} 🚀  Install Everything (Standard)"
    echo -e "  ${CYAN}[2]${RESET} 🍃  Install Everything (No AI Tools)"
    if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
        echo -e "  ${CYAN}[3]${RESET} 💻  Install Everything + System76 Support"
        echo -e "  ${CYAN}[4]${RESET} 🎮  Install NVIDIA Drivers Only"
        echo -e "  ${CYAN}[5]${RESET} 🔧  Custom Installation / Configure Options"
        echo -e "  ${CYAN}[6]${RESET} 📝  Edit Package Blacklist"
    else
        echo -e "  ${CYAN}[3]${RESET} 🔧  Custom Installation / Configure Options"
        echo -e "  ${CYAN}[4]${RESET} 📝  Edit Package Blacklist"
    fi
    echo -e "  ${CYAN}[Q]${RESET} ❌  Exit"
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
        print_menu_line "1" "${ICON_AI}" "Skip AI Tools" "$(get_status_badge $SKIP_AI_TOOLS)"
        print_menu_line "2" "${ICON_CODE}" "Skip VS Code Extensions" "$(get_status_badge $SKIP_VSCODE)" "" 1
        local davinci_badge
        if [[ "$INSTALL_DAVINCI" == "true" && -n "$DAVINCI_EDITION" ]]; then
            local edition_label
            if [[ "$DAVINCI_EDITION" == "studio" ]]; then
                edition_label="${PURPLE}Studio${RESET}"
            else
                edition_label="Free"
            fi
            davinci_badge="${GREEN}[ON]${RESET} ${DIM}(${edition_label}${DIM})${RESET}"
        else
            davinci_badge="${DIM}[OFF]${RESET}"
        fi
        print_menu_line "3" "${ICON_MEDIA}" "Install DaVinci Resolve" "$davinci_badge" "" 1
        print_menu_line "4" "${ICON_SYNC}" "Install Synergy (KVM)" "$(get_status_badge $INSTALL_SYNERGY)" "Share keyboard & mouse across computers" 1
        if [[ "$SELECTED_DISTRO" == "fedora" ]]; then
            print_menu_line "5" "${ICON_GPU}" "Install NVIDIA Drivers" "$(get_status_badge $INSTALL_NVIDIA)" "Auto-detects GPU generation" 1
            print_menu_line "6" "${ICON_LAPTOP}" "Install System76 Support" "$(get_status_badge $INSTALL_SYSTEM76)" "System76 firmware, power, DKMS" 1
        fi
        echo ""
        local pkg_badge
        if [[ -n "$PACKAGE_SELECTOR_OMIT" ]]; then
            local deselected_count
            deselected_count=$(echo "$PACKAGE_SELECTOR_OMIT" | wc -w | tr -d ' ')
            pkg_badge="${YELLOW}[${deselected_count} deselected]${RESET}"
        else
            pkg_badge="${DIM}[All selected]${RESET}"
        fi
        print_menu_line "P" "${ICON_PKG}" "Customize Package Selection" "$pkg_badge" "" 1
        echo ""
        echo -e "  ${CYAN}[R]${RESET}    Run Installation with these settings"
        echo -e "  ${CYAN}[B]${RESET}    Back to Main Menu"
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
                            run_installation
                            return
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
                                run_installation
                                return
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
            [Pp])
                run_package_selector
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
BLACKLIST_HEADER='# Package Blacklist
#
# Packages listed here will be permanently skipped during installation.
# Add one package name per line. These are matched against the "name"
# field in packages.yml (e.g. "discord", "slack", "obs-studio").
#
# This file is persistent — packages listed here are excluded on every
# run of bootstrap.sh, unlike the Package Selector [P] which only
# applies to a single session.
#
# Lines starting with # are comments and are ignored.
# Blank lines are ignored.
'

edit_blacklist() {
    draw_header
    echo ""
    echo -e "  ${BOLD}Package Blacklist Editor${RESET}"
    echo -e "  Packages listed in ${YELLOW}${BLACKLIST_FILE}${RESET} will be skipped."
    echo ""
    if [[ ! -f "$BLACKLIST_FILE" ]]; then
        echo -n "$BLACKLIST_HEADER" > "$BLACKLIST_FILE"
        echo ""
        echo -e "  ${GREEN}${ICON_CHECK} Created new blacklist file at ${RESET}${BOLD}${BLACKLIST_FILE}${RESET}"
        echo ""
        sleep 2
    elif ! head -1 "$BLACKLIST_FILE" | grep -q '^# Package Blacklist'; then
        # Existing file missing the header — prepend it
        local existing
        existing=$(cat "$BLACKLIST_FILE")
        echo -n "$BLACKLIST_HEADER" > "$BLACKLIST_FILE"
        echo "$existing" >> "$BLACKLIST_FILE"
    fi

    local bl_editor="${EDITOR:-nano}"
    # Prefer nvim if available
    if command -v nvim &>/dev/null; then
        bl_editor="nvim"
    fi
    echo -e "  Opening editor (${bl_editor})..."
    sleep 1
    $bl_editor "$BLACKLIST_FILE"

    # Reload omit list logic handled in run_installation
}

# Package Selector
run_package_selector() {
    local os_flag=""
    case "$SELECTED_DISTRO" in
        fedora) os_flag="fedora" ;;
        ubuntu) os_flag="ubuntu" ;;
        macos)  os_flag="macos" ;;
    esac

    local result
    result=$(python3 "$SCRIPT_DIR/scripts/package_selector.py" \
        --packages-file "$SCRIPT_DIR/packages.yml" \
        --os "$os_flag" \
        --blacklist-file "$BLACKLIST_FILE")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Parse tagged output lines
        local deselected_line="" remove_bl_line=""
        while IFS= read -r line; do
            case "$line" in
                DESELECTED*)   deselected_line="${line#DESELECTED }" ;;
                REMOVE_FROM_BLACKLIST*) remove_bl_line="${line#REMOVE_FROM_BLACKLIST }" ;;
            esac
        done <<< "$result"

        # Trim leading/trailing whitespace
        deselected_line=$(echo "$deselected_line" | sed 's/^ *//;s/ *$//')
        remove_bl_line=$(echo "$remove_bl_line" | sed 's/^ *//;s/ *$//')

        PACKAGE_SELECTOR_OMIT="$deselected_line"

        # Handle blacklist removals (user chose "Remove from blacklist permanently")
        if [[ -n "$remove_bl_line" && -f "$BLACKLIST_FILE" ]]; then
            local removed=0
            for pkg in $remove_bl_line; do
                if grep -q "^${pkg}$" "$BLACKLIST_FILE" 2>/dev/null; then
                    grep -v "^${pkg}$" "$BLACKLIST_FILE" > "${BLACKLIST_FILE}.tmp" \
                        && mv "${BLACKLIST_FILE}.tmp" "$BLACKLIST_FILE"
                    ((removed++))
                fi
            done
            if (( removed > 0 )); then
                draw_header
                echo ""
                echo -e "  ${GREEN}${ICON_CHECK} Removed ${removed} package(s) from the permanent blacklist.${RESET}"
                echo ""
                echo -e "  ${DIM}Press Enter to continue...${RESET}"
                read -r
            fi
        fi

        # Load current blacklist to filter the "add to blacklist?" prompt
        local current_blacklist=""
        if [[ -f "$BLACKLIST_FILE" ]]; then
            current_blacklist=$(grep -v '^\s*#' "$BLACKLIST_FILE" | grep -v '^\s*$')
        fi

        # Determine newly deselected packages (not already in blacklist)
        local newly_deselected=""
        if [[ -n "$deselected_line" ]]; then
            for pkg in $deselected_line; do
                if ! echo "$current_blacklist" | grep -q "^${pkg}$" 2>/dev/null; then
                    newly_deselected="$newly_deselected $pkg"
                fi
            done
            newly_deselected=$(echo "$newly_deselected" | sed 's/^ *//;s/ *$//')
        fi

        # If there are newly deselected packages, offer to add them to the blacklist
        if [[ -n "$newly_deselected" ]]; then
            local deselected_count
            deselected_count=$(echo "$newly_deselected" | wc -w | tr -d ' ')
            draw_header
            echo ""
            echo -e "  ${BOLD}${deselected_count} newly deselected package(s):${RESET}"
            echo ""
            for pkg in $newly_deselected; do
                echo -e "    ${DIM}-${RESET} $pkg"
            done
            echo ""
            echo -e "  ${YELLOW}Would you like these packages to ${BOLD}always${RESET}${YELLOW} be skipped?${RESET}"
            echo -e "  ${DIM}This adds them to your permanent blacklist at${RESET}"
            echo -e "  ${DIM}${BLACKLIST_FILE}${RESET}"
            echo ""
            echo -e "  ${CYAN}[Y]${RESET}  Yes, always skip these packages"
            echo -e "  ${CYAN}[N]${RESET}  No, skip only for this session"
            echo ""
            draw_line "─"
            while true; do
                read -p "  Selection: " -n 1 -r bl_choice
                echo ""
                case $bl_choice in
                    [Yy])
                        # Ensure blacklist file exists with header
                        if [[ ! -f "$BLACKLIST_FILE" ]]; then
                            echo -n "$BLACKLIST_HEADER" > "$BLACKLIST_FILE"
                        fi
                        local added=0
                        for pkg in $newly_deselected; do
                            if ! grep -q "^${pkg}$" "$BLACKLIST_FILE" 2>/dev/null; then
                                echo "$pkg" >> "$BLACKLIST_FILE"
                                ((added++))
                            fi
                        done
                        echo ""
                        echo -e "  ${GREEN}${ICON_CHECK} Added ${added} package(s) to the permanent blacklist.${RESET}"
                        echo -e "  ${DIM}You can edit it later with the Blacklist Editor from the menu.${RESET}"
                        echo ""
                        echo -e "  ${DIM}Press Enter to continue...${RESET}"
                        read -r
                        break
                        ;;
                    [Nn])
                        break
                        ;;
                    *)
                        echo -e "  ${DIM}Press Y or N${RESET}"
                        ;;
                esac
            done
        fi

        # Post-confirm summary with option to install now
        local total_deselected=0
        if [[ -n "$deselected_line" ]]; then
            total_deselected=$(echo "$deselected_line" | wc -w | tr -d ' ')
        fi
        draw_header
        echo ""
        echo -e "  ${GREEN}${ICON_CHECK} Package selection saved${RESET}"
        echo ""
        if (( total_deselected > 0 )); then
            echo -e "  ${DIM}${total_deselected} package(s) will be skipped${RESET}"
        else
            echo -e "  ${DIM}All packages selected${RESET}"
        fi
        echo ""
        draw_line "─"
        echo ""
        echo -e "  ${CYAN}[R]${RESET}  ${BOLD}Run installation now${RESET} with these settings"
        echo -e "  ${CYAN}[C]${RESET}  Continue configuring other options"
        echo ""
        while true; do
            read -p "  Selection: " -n 1 -r post_confirm_choice
            echo ""
            case $post_confirm_choice in
                [Rr])
                    run_installation
                    return
                    ;;
                [Cc])
                    return
                    ;;
                *)
                    echo -e "  ${DIM}Press R or C${RESET}"
                    ;;
            esac
        done
    elif [[ $exit_code -ne 2 ]]; then
        # exit_code 2 = cancelled by user, anything else is an error
        draw_header
        echo ""
        echo -e "  ${RED}${ICON_WARN} Package selector failed (exit code: $exit_code)${RESET}"
        echo ""
        echo -e "  ${DIM}To see the full error, run:${RESET}"
        echo -e "  ${DIM}  python3 $SCRIPT_DIR/scripts/package_selector.py --packages-file $SCRIPT_DIR/packages.yml --os $os_flag${RESET}"
        echo ""
        echo -e "  ${DIM}Press Enter to continue...${RESET}"
        read -r
    fi
}

# Run Logic
run_installation() {
    # Prepare Omit List from file
    OMIT_LIST=""
    if [[ -f "$BLACKLIST_FILE" ]]; then
        OMIT_LIST=$(grep -v '^\s*#' "$BLACKLIST_FILE" | grep -v '^\s*$' | tr '\n' ' ')
    fi

    # Merge package selector deselections
    if [[ -n "$PACKAGE_SELECTOR_OMIT" ]]; then
        OMIT_LIST="$OMIT_LIST $PACKAGE_SELECTOR_OMIT"
    fi
    # Deduplicate
    OMIT_LIST=$(echo "$OMIT_LIST" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//')

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
        OMIT_CONTENT=$(grep -v '^\s*#' "$BLACKLIST_FILE" | grep -v '^\s*$' | tr '\n' ' ')
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

# Work Computer Warning
show_work_computer_warning() {
    draw_header
    echo ""
    echo -e "  ${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${RED}${BOLD}  ${ICON_WARN}  WARNING  ${ICON_WARN}${RESET}"
    echo -e "  ${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${YELLOW}If you are installing this on a ${BOLD}work computer${RESET}${YELLOW}, it is${RESET}"
    echo -e "  ${YELLOW}suggested that you choose the custom installation and${RESET}"
    echo -e "  ${YELLOW}select which packages you'd like installed explicitly${RESET}"
    echo -e "  ${YELLOW}so that packages that could violate your employer's${RESET}"
    echo -e "  ${YELLOW}policy are not installed accidentally.${RESET}"
    echo ""
    echo -e "  ${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${CYAN}[P]${RESET}  Go to ${BOLD}Package Customization${RESET} now"
    echo -e "  ${CYAN}[M]${RESET}  Continue to the ${BOLD}Main Menu${RESET}"
    echo ""
    draw_line "─"
    while true; do
        read -p "  Selection: " -n 1 -r warn_choice
        echo ""
        case $warn_choice in
            [Pp])
                run_package_selector
                return
                ;;
            [Mm])
                return
                ;;
            *)
                echo -e "  ${DIM}Press P or M${RESET}"
                ;;
        esac
    done
}

# --- Main Loop (TUI Mode) ---
show_distro_menu
show_work_computer_warning

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



