#!/usr/bin/env python3
"""Interactive package selector TUI for CompSetup.

Reads packages.yml and presents a categorized checkbox interface
filtered by the selected OS. Outputs deselected package names
(space-separated) on stdout for integration with the OMIT_LIST pipeline.

All UI rendering goes to stderr so stdout stays clean for pipe integration.

Exit codes:
    0 - Confirmed selection (deselected names on stdout)
    2 - Cancelled by user (no output)
"""

import argparse
import os
import sys
import termios
import tty

# ---------------------------------------------------------------------------
# YAML parsing
# ---------------------------------------------------------------------------

try:
    import yaml

    def load_yaml(path):
        with open(path, "r") as fh:
            return yaml.safe_load(fh)

except ImportError:
    # Minimal fallback parser for the flat structure of packages.yml.
    # Handles the subset of YAML used by this project: mappings, sequences
    # of strings, and sequences of mappings with scalar values.

    def _parse_scalar(val):
        """Convert a YAML scalar string to a Python type."""
        if val in ("true", "True", "yes"):
            return True
        if val in ("false", "False", "no"):
            return False
        if val in ("null", "~", ""):
            return None
        try:
            return int(val)
        except ValueError:
            pass
        try:
            return float(val)
        except ValueError:
            pass
        return val

    def load_yaml(path):
        with open(path, "r") as fh:
            lines = fh.readlines()

        root = {}
        # stack entries: (container, indent, parent_dict, parent_key)
        # parent_dict and parent_key allow replacing a dict with a list
        # when we discover list items under a mapping key.
        stack = [(root, -1, None, None)]

        for raw_line in lines:
            stripped = raw_line.rstrip("\n")

            # skip blank lines and comments
            if not stripped.strip() or stripped.strip().startswith("#"):
                continue

            indent = len(stripped) - len(stripped.lstrip())
            content = stripped.strip()

            # Pop stack to correct nesting level
            while len(stack) > 1 and indent <= stack[-1][1]:
                stack.pop()

            current, _, _, _ = stack[-1]

            # Handle list item
            if content.startswith("- "):
                item_content = content[2:].strip()

                # If current is a dict placeholder (empty dict created for a
                # key with no inline value), convert it to a list on the parent
                if isinstance(current, dict) and len(current) == 0:
                    _, s_indent, parent, pkey = stack[-1]
                    if parent is not None and pkey is not None:
                        new_list = []
                        parent[pkey] = new_list
                        stack[-1] = (new_list, s_indent, parent, pkey)
                        current = new_list

                if isinstance(current, list):
                    target_list = current
                else:
                    continue

                if ":" in item_content:
                    # item is a mapping  e.g. "- name: foo"
                    new_map = {}
                    key, _, val = item_content.partition(":")
                    key = key.strip()
                    val = val.strip()
                    if val:
                        new_map[key] = _parse_scalar(val)
                    target_list.append(new_map)
                    stack.append((new_map, indent, None, None))
                else:
                    target_list.append(_parse_scalar(item_content))

            elif ":" in content:
                key, _, val = content.partition(":")
                key = key.strip()
                val = val.strip()

                if val:
                    if isinstance(current, dict):
                        current[key] = _parse_scalar(val)
                else:
                    # Key with no value -> placeholder dict (may become list)
                    if isinstance(current, dict):
                        current[key] = {}
                        stack.append((current[key], indent, current, key))

        return root


# ---------------------------------------------------------------------------
# Terminal helpers
# ---------------------------------------------------------------------------

def eprint(*args, **kwargs):
    """Print to stderr."""
    print(*args, file=sys.stderr, **kwargs)


def getch():
    """Read a single character from stdin (raw mode)."""
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    return ch


def read_line_from_tty():
    """Read a line of input in raw mode, echoing to stderr.

    Supports backspace and returns on Enter.
    """
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    buf = []
    try:
        tty.setraw(fd)
        while True:
            ch = sys.stdin.read(1)
            if ch in ("\r", "\n"):
                sys.stderr.write("\r\n")
                sys.stderr.flush()
                break
            elif ch in ("\x7f", "\x08"):  # backspace / delete
                if buf:
                    buf.pop()
                    sys.stderr.write("\b \b")
                    sys.stderr.flush()
            elif ch == "\x03":  # Ctrl-C
                raise KeyboardInterrupt
            elif ch.isprintable():
                buf.append(ch)
                sys.stderr.write(ch)
                sys.stderr.flush()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    return "".join(buf)


# ---------------------------------------------------------------------------
# Colors (stderr only)
# ---------------------------------------------------------------------------

ESC = "\033"
RESET = f"{ESC}[0m"
BOLD = f"{ESC}[1m"
DIM = f"{ESC}[2m"
RED = f"{ESC}[31m"
GREEN = f"{ESC}[32m"
YELLOW = f"{ESC}[33m"
CYAN = f"{ESC}[36m"
WHITE = f"{ESC}[37m"


# ---------------------------------------------------------------------------
# Package filtering by OS
# ---------------------------------------------------------------------------

PACKAGE_DESCRIPTIONS = {
    # CLI Tools
    "ansible": "IT automation engine for configuration management, app deployment, and orchestration",
    "bitwarden-cli": "Command-line interface for the Bitwarden password manager",
    "ffmpeg": "Universal multimedia toolkit for converting, streaming, and recording audio/video",
    "git": "Distributed version control system",
    "gnupg": "GNU Privacy Guard -- encryption and signing tool for secure communication",
    "gotop": "Terminal-based graphical activity monitor inspired by gtop and vtop",
    "graphviz": "Graph visualization software for creating diagrams from textual descriptions",
    "helm": "Kubernetes package manager for deploying and managing applications",
    "htop": "Interactive process viewer and system monitor for the terminal",
    "locateme": "macOS command-line tool to find your geographic location",
    "minikube": "Local Kubernetes cluster runner for development and testing",
    "ncdu": "Disk usage analyzer with ncurses interface for finding large files",
    "neovim": "Hyperextensible Vim-based text editor",
    "node": "JavaScript runtime built on Chrome's V8 engine",
    "pyvim": "Python bindings for Neovim, enabling Python-based Neovim plugins",
    "ripgrep": "Blazing fast recursive grep alternative that respects .gitignore",
    "sha3sum": "Compute and verify SHA-3 message digests",
    "wakeonlan": "Send magic packets to wake up machines on a network",
    "wget": "Network downloader supporting HTTP, HTTPS, and FTP protocols",
    "curl": "Command-line tool for transferring data with URL syntax",
    "fd": "Fast and user-friendly alternative to the find command",
    "unzip": "Extraction utility for ZIP archives",
    "python3": "High-level general-purpose programming language",
    "ruby": "Dynamic, object-oriented programming language focused on simplicity",
    "lsd": "Modern replacement for ls with color, icons, and tree view",
    "watch": "Execute a program periodically and display the output in the terminal",
    "trash": "Command-line tool to move files to the trash instead of permanently deleting",
    "claude-code": "Anthropic's AI coding assistant for the command line",
    "gemini-cli": "Google's Gemini AI assistant for the command line",
    # GUI Apps
    "cyberduck": "Cloud storage browser for FTP, SFTP, S3, and more",
    "visual-studio-code": "Extensible source code editor by Microsoft",
    "proton-pass": "End-to-end encrypted password manager by Proton",
    "proton-mail": "End-to-end encrypted email service by Proton",
    "docker": "Container platform for building, sharing, and running applications",
    "google-chrome": "Web browser by Google built on the Chromium engine",
    "ghostty": "Fast, feature-rich, native terminal emulator",
    "handbrake": "Open-source video transcoder for converting video formats",
    "qownnotes": "Plain-text markdown note-taking app with Nextcloud integration",
    "typora": "Minimal markdown editor with live preview",
    "signal-desktop": "End-to-end encrypted messaging app focused on privacy",
    "antigravity": "Open-source AI assistant desktop application",
    # Fonts
    "font-0xproto-nerd-font": "0xProto monospace font patched with Nerd Font icons",
    "font-fira-code-nerd-font": "Fira Code font with ligatures patched with Nerd Font icons",
    "font-fira-mono-nerd-font": "Fira Mono font patched with Nerd Font icons",
    # Flatpak Apps
    "com.brave.Browser": "Privacy-focused web browser based on Chromium with built-in ad blocker",
    "com.getmailspring.Mailspring": "Modern email client with unified inbox and snooze features",
    "com.discordapp.Discord": "Voice, video, and text communication platform for communities",
    "com.google.Chrome": "Web browser by Google built on the Chromium engine",
    "com.slack.Slack": "Team communication and collaboration platform",
    "com.vixalien.sticky": "Sticky notes app for the GNOME desktop",
    "im.riot.Riot": "Element -- decentralized, encrypted messaging client using the Matrix protocol",
    "io.github.pwr_solaar.solaar": "Device manager for Logitech wireless peripherals",
    "md.obsidian.Obsidian": "Knowledge base and note-taking app using local Markdown files",
    "me.proton.Pass": "End-to-end encrypted password manager by Proton",
    "net.cozic.joplin_desktop": "Open-source note-taking and to-do app with sync support",
    "network.loki.Session": "End-to-end encrypted messenger using decentralized servers",
    "org.raspberrypi.rpi-imager": "Raspberry Pi imaging tool for writing OS images to SD cards",
    "org.standardnotes.standardnotes": "End-to-end encrypted notes app with extensible editors",
    "org.videolan.VLC": "Free cross-platform multimedia player supporting most formats",
    "com.obsproject.Studio": "Free open-source software for live streaming and screen recording",
    "io.podman_desktop.PodmanDesktop": "Desktop GUI for managing Podman containers",
    "org.kde.kasts": "Podcast player for KDE and the Linux desktop",
    "org.kde.kmymoney": "Personal finance manager for KDE",
    "org.gimp.GIMP": "GNU Image Manipulation Program -- free raster graphics editor",
    "org.jupyter.JupyterLab": "Interactive development environment for notebooks and code",
    "com.vscodium.codium": "Community-driven, telemetry-free build of VS Code",
    "org.localsend.localsend_app": "Share files to nearby devices over local Wi-Fi without internet",
    "org.signal.Signal": "End-to-end encrypted messaging app focused on privacy",
    # VS Code Extensions
    "github.copilot": "AI pair programmer that suggests code completions",
    "github.copilot-chat": "AI chat interface for GitHub Copilot inside VS Code",
    "golang.go": "Rich Go language support including IntelliSense and debugging",
    "ms-azuretools.vscode-docker": "Docker container management and Dockerfile support",
    "ms-kubernetes-tools.vscode-kubernetes-tools": "Kubernetes cluster explorer and manifest editing",
    "ms-python.python": "Python language support with IntelliSense and debugging",
    "ms-python.vscode-pylance": "Fast, feature-rich Python language server for VS Code",
    "redhat.ansible": "Ansible playbook and role authoring support",
    "redhat.vscode-yaml": "YAML language support with schema validation",
    "rust-lang.rust-analyzer": "Rust language support with completion, diagnostics, and refactoring",
    "vscodevim.vim": "Vim emulation for Visual Studio Code",
    # System Packages (apt_only / dnf_only common)
    "build-essential": "Meta-package providing C/C++ compiler and standard build tools",
    "python3-pip": "Python package installer for managing third-party libraries",
    "python3-venv": "Python module for creating lightweight virtual environments",
    "gnome-keyring": "GNOME secure credential storage for passwords and keys",
    "seahorse": "GNOME application for managing encryption keys and passwords",
    "libsecret-tools": "Command-line tools for accessing the Secret Service API",
    "flatpak": "Framework for distributing sandboxed desktop applications on Linux",
    "gnome-software-plugin-flatpak": "GNOME Software plugin enabling Flatpak app installation",
    "fontconfig": "Library for configuring and customizing font access",
    "docker-compose": "Tool for defining and running multi-container Docker applications",
    "tree": "Recursive directory listing command producing a tree-style output",
    "bat": "Cat clone with syntax highlighting, line numbers, and Git integration",
    "gh": "GitHub CLI for managing repositories, issues, and pull requests from the terminal",
    "software-properties-common": "Scripts for managing APT repository sources",
    "@development-tools": "DNF group providing C/C++ compiler and standard build tools",
}


def _build_details(pkg_data, os_name):
    """Build a detail dict for a package entry."""
    details = {}
    if isinstance(pkg_data, dict):
        if pkg_data.get("brew_formula"):
            details["brew_formula"] = pkg_data["brew_formula"]
        if pkg_data.get("brew_cask"):
            details["brew_cask"] = pkg_data["brew_cask"]
        if pkg_data.get("apt"):
            details["apt"] = pkg_data["apt"]
        if pkg_data.get("dnf"):
            details["dnf"] = pkg_data["dnf"]
        linux = pkg_data.get("linux")
        if isinstance(linux, dict):
            if linux.get("type"):
                details["linux_type"] = linux["type"]
            if linux.get("package"):
                details["linux_package"] = linux["package"]
            if linux.get("url"):
                details["linux_url"] = linux["url"]
            if linux.get("dest"):
                details["linux_dest"] = linux["dest"]
            if linux.get("installed_path"):
                details["installed_path"] = linux["installed_path"]
    return details


def filter_packages(manifest, os_name):
    """Return a list of (category_name, [(display_name, identifier, details), ...])."""
    categories = []

    # --- CLI Tools ---
    cli = []
    for tool in manifest.get("cli_tools", []):
        name = tool.get("name", "")
        if not name:
            continue
        if os_name == "macos":
            if tool.get("brew_formula") or tool.get("brew_cask"):
                cli.append((name, name, _build_details(tool, os_name)))
        elif os_name == "ubuntu":
            if tool.get("apt"):
                cli.append((name, name, _build_details(tool, os_name)))
            elif isinstance(tool.get("linux"), dict):
                ltype = tool["linux"].get("type", "")
                if ltype in ("apt", "deb", "npm"):
                    cli.append((name, name, _build_details(tool, os_name)))
        elif os_name == "fedora":
            if tool.get("dnf"):
                cli.append((name, name, _build_details(tool, os_name)))
            elif isinstance(tool.get("linux"), dict):
                ltype = tool["linux"].get("type", "")
                if ltype == "npm":
                    cli.append((name, name, _build_details(tool, os_name)))
    if cli:
        categories.append(("CLI Tools", cli))

    # --- GUI Apps ---
    gui = []
    for app in manifest.get("gui_apps", []):
        name = app.get("name", "")
        if not name:
            continue
        if os_name == "macos":
            if app.get("brew_cask"):
                gui.append((name, name, _build_details(app, os_name)))
        elif os_name in ("ubuntu", "fedora"):
            if isinstance(app.get("linux"), dict):
                ltype = app["linux"].get("type", "")
                if os_name == "ubuntu" and ltype in ("apt", "deb"):
                    gui.append((name, name, _build_details(app, os_name)))
                elif os_name == "fedora" and ltype in ("deb",):
                    gui.append((name, name, _build_details(app, os_name)))
            elif os_name == "ubuntu" and app.get("apt"):
                gui.append((name, name, _build_details(app, os_name)))
            elif os_name == "fedora" and app.get("dnf"):
                gui.append((name, name, _build_details(app, os_name)))
    if gui:
        categories.append(("GUI Apps", gui))

    # --- Flatpak Apps (Linux only) ---
    if os_name in ("ubuntu", "fedora"):
        flatpak = []
        for fp in manifest.get("flatpak_apps", []):
            if isinstance(fp, str):
                flatpak.append((fp, fp, {"flatpak_id": fp}))
        if flatpak:
            categories.append(("Flatpak Apps", flatpak))

    # --- Fonts (all platforms) ---
    fonts = []
    for font in manifest.get("fonts", []):
        name = font.get("name", "")
        if not name:
            continue
        if os_name == "macos":
            if font.get("brew_cask"):
                fonts.append((name, name, _build_details(font, os_name)))
        elif os_name in ("ubuntu", "fedora"):
            if isinstance(font.get("linux"), dict) and font["linux"].get("url"):
                fonts.append((name, name, _build_details(font, os_name)))
    if fonts:
        categories.append(("Fonts", fonts))

    # --- VS Code Extensions (all platforms) ---
    vscode = []
    for ext in manifest.get("vscode_extensions", []):
        if isinstance(ext, str):
            vscode.append((ext, ext, {"extension_id": ext}))
    if vscode:
        categories.append(("VS Code Extensions", vscode))

    # --- System Packages (apt_only / dnf_only common) ---
    sys_pkgs = []
    if os_name == "ubuntu":
        for pkg in manifest.get("apt_only", {}).get("common", []):
            if isinstance(pkg, str):
                sys_pkgs.append((pkg, pkg, {"apt": pkg}))
    elif os_name == "fedora":
        for pkg in manifest.get("dnf_only", {}).get("common", []):
            if isinstance(pkg, str):
                sys_pkgs.append((pkg, pkg, {"dnf": pkg}))
    if sys_pkgs:
        categories.append(("System Packages", sys_pkgs))

    return categories


# ---------------------------------------------------------------------------
# TUI
# ---------------------------------------------------------------------------

PAGE_SIZE = 20


def parse_toggle_input(text):
    """Parse user input into a list of 1-based package numbers.

    Supports:
        "4"         -> [4]
        "3-7"       -> [3, 4, 5, 6, 7]
        "1, 3, 9"   -> [1, 3, 9]
        "1,3-7,9"   -> [1, 3, 4, 5, 6, 7, 9]
    """
    numbers = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            halves = part.split("-", 1)
            try:
                lo = int(halves[0].strip())
                hi = int(halves[1].strip())
                numbers.extend(range(lo, hi + 1))
            except (ValueError, IndexError):
                pass
        else:
            try:
                numbers.append(int(part))
            except ValueError:
                pass
    return numbers


def show_package_info(item):
    """Display detailed info about a package and wait for keypress."""
    eprint(f"\033[2J\033[H", end="")
    eprint("")
    eprint(f"  {BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
    eprint(f"  {BOLD}  Package Info{RESET}")
    eprint(f"  {BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
    eprint("")
    eprint(f"  {BOLD}Name:{RESET}        {item['display']}")
    eprint(f"  {BOLD}Category:{RESET}    {item['cat']}")
    eprint(f"  {BOLD}Status:{RESET}      {GREEN}Selected{RESET}" if item["sel"] else f"  {BOLD}Status:{RESET}      {YELLOW}Deselected{RESET}")

    desc = PACKAGE_DESCRIPTIONS.get(item["id"], "")
    if desc:
        eprint(f"  {BOLD}Description:{RESET} {desc}")

    eprint("")

    details = item.get("details", {})
    if details:
        eprint(f"  {BOLD}{CYAN}Platform Details:{RESET}")
        label_map = {
            "brew_formula": "Brew Formula",
            "brew_cask": "Brew Cask",
            "apt": "APT Package",
            "dnf": "DNF Package",
            "linux_type": "Linux Install Type",
            "linux_package": "Linux Package",
            "linux_url": "Linux URL",
            "linux_dest": "Linux Dest",
            "installed_path": "Installed Path",
            "flatpak_id": "Flatpak ID",
            "extension_id": "Extension ID",
        }
        for key, label in label_map.items():
            if key in details:
                val = details[key]
                eprint(f"    {DIM}{label}:{RESET}  {val}")
    else:
        eprint(f"  {DIM}No additional details available.{RESET}")

    eprint("")
    eprint(f"  {DIM}Press any key to return...{RESET}")
    try:
        getch()
    except (KeyboardInterrupt, EOFError):
        pass


def run_selector(categories, os_label):
    """Run the interactive selector. Returns list of deselected identifiers or None if cancelled."""
    # Flatten into ordered list
    items = []
    for cat_name, pkgs in categories:
        for display, ident, details in pkgs:
            items.append({"cat": cat_name, "display": display, "id": ident,
                          "sel": True, "details": details})

    if not items:
        eprint(f"\n  No packages found for {os_label}.\n")
        return None

    total = len(items)
    page = 0
    total_pages = max(1, (total + PAGE_SIZE - 1) // PAGE_SIZE)

    while True:
        # Render
        start = page * PAGE_SIZE
        end = min(start + PAGE_SIZE, total)
        page_items = items[start:end]

        lines = []
        lines.append("")
        lines.append(f"  {BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
        lines.append(f"  {BOLD}  Package Selector - {os_label}{RESET}")
        lines.append(f"  {BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
        lines.append("")

        current_cat = None
        for idx_offset, item in enumerate(page_items):
            global_idx = start + idx_offset + 1  # 1-based display number
            if item["cat"] != current_cat:
                current_cat = item["cat"]
                lines.append(f"  {BOLD}{CYAN}{current_cat}{RESET}")

            check = f"{GREEN}x{RESET}" if item["sel"] else " "
            num_str = f"{global_idx:>3}"
            lines.append(f"    [{check}] {DIM}{num_str}.{RESET} {item['display']}")

        lines.append("")
        sel_count = sum(1 for i in items if i["sel"])
        desel_count = total - sel_count
        lines.append(f"  {DIM}Page {page + 1}/{total_pages}  |  "
                      f"{sel_count} selected, {desel_count} deselected  |  "
                      f"{total} total{RESET}")
        lines.append("")
        lines.append(f"  {BOLD}{DIM}Legend:{RESET}")
        lines.append("")
        lines.append(f"  {CYAN}[A]{RESET} Select All   {CYAN}[D]{RESET} Deselect All")
        lines.append(f"  {CYAN}[N]{RESET} Next Page    {CYAN}[P]{RESET} Prev Page")
        lines.append(f"  {CYAN}[I]{RESET} Package Info {CYAN}[Q]{RESET} Cancel")
        lines.append(f"  {CYAN}[C]{RESET} Confirm")
        lines.append("")
        lines.append(f"  Toggle: {BOLD}4{RESET}  range: {BOLD}3-7{RESET}  multi: {BOLD}1,3,9{RESET}  pkg info: {BOLD}i5{RESET}")
        lines.append("")
        lines.append(f"  {BOLD}>{RESET} ")

        # Clear screen and draw
        eprint(f"\033[2J\033[H", end="")
        for line in lines[:-1]:
            eprint(line)
        eprint(lines[-1], end="")
        sys.stderr.flush()

        # Read input
        try:
            user_input = read_line_from_tty().strip()
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input:
            continue

        low = user_input.lower()

        if low == "q":
            return None
        elif low == "c":
            deselected = [i["id"] for i in items if not i["sel"]]
            return deselected
        elif low == "a":
            for i in items:
                i["sel"] = True
        elif low == "d":
            for i in items:
                i["sel"] = False
        elif low == "n":
            if page < total_pages - 1:
                page += 1
        elif low == "p":
            if page > 0:
                page -= 1
        elif low.startswith("i") and low[1:].strip().isdigit():
            # Info command: "i5", "i 5", "I12"
            num = int(low[1:].strip())
            idx = num - 1
            if 0 <= idx < total:
                show_package_info(items[idx])
        else:
            # Try parsing as toggle numbers (single, range, comma-separated, mixed)
            nums = parse_toggle_input(user_input)
            for num in nums:
                idx = num - 1
                if 0 <= idx < total:
                    items[idx]["sel"] = not items[idx]["sel"]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Interactive package selector for CompSetup")
    parser.add_argument("--packages-file", required=True, help="Path to packages.yml")
    parser.add_argument("--os", required=True, choices=["macos", "ubuntu", "fedora"],
                        help="Target OS to filter packages")
    args = parser.parse_args()

    if not os.path.isfile(args.packages_file):
        eprint(f"Error: packages file not found: {args.packages_file}")
        sys.exit(1)

    data = load_yaml(args.packages_file)
    manifest = data.get("package_manifest", data)

    os_label = {"macos": "macOS", "ubuntu": "Ubuntu", "fedora": "Fedora"}[args.os]
    categories = filter_packages(manifest, args.os)

    result = run_selector(categories, os_label)

    if result is None:
        sys.exit(2)

    # Output deselected packages space-separated on stdout
    if result:
        print(" ".join(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
