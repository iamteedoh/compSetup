# Cross-Platform Computer Setup (macOS + Ubuntu/Pop!_OS + Fedora/RPM)

Automate opinionated workstation setup with Ansible. This project provisions platform-appropriate package managers (Homebrew on macOS, apt on Ubuntu/Pop!_OS, dnf on Fedora/RPM), optional VS Code extensions, Oh My Zsh, the Powerlevel10k prompt, and the fonts required for beautiful glyphs. It is idempotent and optimized for Apple Silicon (with graceful Intel fallbacks where needed) and Linux desktops (GNOME/Cosmic).

## Getting Started (Fresh Install)

If you have just logged into a brand new computer, follow these steps to get everything running.

### 1. Open your Terminal
- **macOS**: Press `Command + Space`, type "Terminal", and hit Enter.
- **Ubuntu/Pop!_OS**: Press `Super` (Windows key), type "Terminal", and hit Enter.
- **Fedora**: Press `Super` (Windows key), type "Terminal", and hit Enter.

### 2. Install Git
You need `git` to download this repository.

**macOS**:
Running `git` will trigger the install prompt if it's missing.
```bash
git --version
```

**Ubuntu / Pop!_OS**:
```bash
sudo apt update && sudo apt install -y git curl
```

**Fedora / RPM**:
```bash
sudo dnf install -y git curl
```

### 3. Download and Run
```bash
git clone https://github.com/iamteedoh/compSetup.git ~/git/compSetup
cd ~/git/compSetup
chmod +x bootstrap.sh
./bootstrap.sh
```

## Usage

### TUI (Text User Interface)
By default, running `./bootstrap.sh` launches an interactive menu. On launch you first select your OS/distribution (Fedora, Ubuntu/Pop!_OS, or macOS). The main menu adapts based on your selection:

**All platforms:**
- **[1] Install Everything (Standard)**: Full install including Synergy.
- **[2] Install Everything (No AI Tools)**: Skip Gemini CLI, Claude Code, and Antigravity while still installing everything else including Synergy.

**Fedora-specific options:**
- **[3] Install Everything + System76 Support**: Full install plus NVIDIA drivers, System76 firmware/power daemons, and DKMS modules.
- **[4] Install NVIDIA Drivers Only**: Auto-detects GPU generation (modern vs legacy Kepler) and installs the appropriate `akmod-nvidia` packages.
- **[5] Custom Installation**: Toggle individual options with real-time status badges.
- **[6] Edit Package Blacklist**: Opens your default editor to manage `~/.install_blacklist`.

**Non-Fedora platforms:**
- **[3] Custom Installation**: Toggle individual options with real-time status badges.
- **[4] Edit Package Blacklist**: Opens your default editor to manage `~/.install_blacklist`.

**Custom Installation toggles:**
| Toggle | Description |
|--------|-------------|
| Skip AI Tools | Omit Gemini CLI, Claude Code, Antigravity |
| Skip VS Code Extensions | Do not install VS Code extensions |
| Install DaVinci Resolve | Download and install DaVinci Resolve (Free or Studio). Selecting an edition auto-starts installation |
| Install Synergy (KVM) | Install Synergy for sharing keyboard/mouse across machines |
| Install NVIDIA Drivers | Auto-detect GPU and install proprietary drivers (Fedora only) |
| Install System76 Support | Firmware daemon, power management, DKMS modules (Fedora only) |
| Install Fix Audio (Douk DAC) | USB DAC recovery script + WirePlumber config (Fedora only) |
| Customize Package Selection | Interactive TUI to cherry-pick which packages to install (filters by OS) |

### Command Line Flags (Headless Mode)
You can skip the TUI for automation or specific tasks:
```bash
./bootstrap.sh --skip-ai-tools             # Skip AI tools
./bootstrap.sh --skip-vscode-extensions    # Skip VS Code extensions
./bootstrap.sh --install-davinci           # Download and install DaVinci Resolve
./bootstrap.sh --install-synergy           # Install Synergy (KVM)
./bootstrap.sh --install-nvidia            # Install NVIDIA drivers (Fedora)
./bootstrap.sh --install-system76          # Install System76 support (Fedora)
./bootstrap.sh --install-fix-audio         # Install Fix Audio / Douk DAC (Fedora)
./bootstrap.sh --omit "pkg1 pkg2"          # Add specific packages to blacklist
```

Flags can be combined:
```bash
./bootstrap.sh --install-nvidia --install-system76 --install-synergy
```

### Persistent Package Blacklist
The blacklist lets you permanently exclude packages from installation. Unlike the Package Selector (`[P]`), which only applies to the current session, blacklisted packages are skipped on **every** future run of `bootstrap.sh` until you remove them from the file.

- **Location**: `~/.install_blacklist` (one package name per line, matching the `name` field in `packages.yml`).
- **How to edit**: Select "Edit Package Blacklist" from the menu. The file opens in your default editor (`$EDITOR`, defaults to `nano` if unset). A comment block at the top of the file explains the format.
- **Example**: To never install Discord and Slack, add them to the file:
  ```
  discord
  slack
  ```
- **Git Safety**: This file is kept locally and is never tracked by git.

## Roles

### NVIDIA Drivers (`nvidia_drivers`)
Automated NVIDIA driver installation for Fedora/RHEL systems.

- Auto-detects NVIDIA GPUs via `lspci`
- Determines GPU generation (Maxwell 2014+ vs legacy Kepler GTX 600/700)
- Enables RPM Fusion Free and Non-Free repositories if needed
- Installs `akmod-nvidia` (modern) or `akmod-nvidia-470xx` (legacy) with CUDA support
- Configures dracut with NVIDIA modules for LUKS-encrypted systems
- Warns about Secure Boot MOK enrollment requirements

### System76 Support (`system76`)
Full System76 hardware support for Fedora systems (e.g., Thelio, Launch keyboard).

- Enables the `szydell/system76` COPR repository
- Installs `system76*`, `firmware-manager`, and DKMS packages (`system76-dkms`, `system76-acpi-dkms`, `system76-io-dkms`)
- Enables and starts `system76-firmware-daemon`, `com.system76.PowerDaemon.service`, `system76-power-wake`, and `dkms`
- Masks `power-profiles-daemon.service` to avoid conflicts with System76 power management
- Adds the current user to the `adm` group for firmware access

### Fix Audio - Douk DAC (`fix_audio`)
Deploys a PipeWire recovery script and WirePlumber configuration for the Douk Audio USB DAC (C-Media "USB HIFI AUDIO").

- Installs `fix-audio.sh` to `~/.local/bin/` — restarts PipeWire, sets the Douk DAC as default sink, and sets volume to 10%
- Deploys `51-douk-audio.conf` to `~/.config/wireplumber/wireplumber.conf.d/` — prevents node suspension and adds USB buffer headroom
- All files are user-space (no root required)
- See [docs/fix-audio.md](docs/fix-audio.md) for full details

### Synergy (`synergy`)
Cross-platform installation of Synergy for sharing a keyboard and mouse across machines.

- macOS: Installs via Homebrew cask
- Linux: Downloads the correct package (RPM or DEB) from the Symless website, extracts a download token from the landing page, and installs via `dnf` or `apt`
- Supports Fedora, Ubuntu, Pop!_OS, and Debian
- Skips installation if Synergy is already present
- Configurable version via `synergy_version` (default: `3.5.1`)

### DaVinci Resolve (`davinci_resolve`)
Automated download and installation of DaVinci Resolve (Free or Studio) across macOS and Linux.

- Installs platform-specific dependencies (apt on Debian/Ubuntu, dnf on Fedora/RHEL)
- Downloads the latest version automatically via Blackmagic Design's public API
- Runs the installer non-interactively (`.run` on Linux, `.pkg` from `.dmg` on macOS)
- Deploys a wrapper script on Fedora to handle Python 3.11 and Wayland (XCB) compatibility
- Skips download and installation if DaVinci Resolve is already installed
- Falls back to manual download instructions if automated install fails
- Supports both Free and Studio editions (Studio requires a valid license key or USB dongle)

### Powerlevel10k (`powerlevel10k`)
Installs and configures the Powerlevel10k zsh prompt theme.

- Clones Powerlevel10k into Oh My Zsh custom themes
- Installs Nerd Fonts via Homebrew (macOS)
- Sets `ZSH_THEME` and sources `~/.p10k.zsh` in `~/.zshrc`
- Deploys a default p10k configuration template
- Installs the `p10k_setup.py` helper script for post-install configuration (see [Post-Install: Powerlevel10k](#post-install-powerlevel10k))

### RPM Packages (`rpmPackages`)
Fedora/RHEL package management with intelligent validation.

- Reads package targets from `packages.yml` (the `dnf` field on each CLI tool, plus `dnf_only` section)
- Separates DNF group installs (prefixed with `@`) from individual packages
- Validates each package against DNF repositories before installing, warning about unavailable packages rather than failing
- Configures the Antigravity RPM repository when needed
- Installs Nerd Fonts, Flatpak apps, and Linux GUI applications

## Supported Tools

### CLI & Development
- **Dev**: `ansible`, `git`, `python3`, `node`, `ruby`, `neovim` (NVChad)
- **Modern CLI**: `ripgrep`, `fd`, `bat`, `lsd`, `htop`, `ncdu`
- **AI**: `gemini-cli`, `claude-code`
- **Utilities**: `ffmpeg`, `graphviz`, `unzip`, `wget`, `curl`, `trash-cli`

### GUI Applications
- **Browsers**: `google-chrome`, `brave`
- **Editors**: `visual-studio-code` (with extensions), `typora`, `ghostty`
- **Privacy/Mail**: `proton-mail`, `proton-pass`, `bitwarden-cli`
- **Media**: `vlc`, `handbrake`, `obs-studio`, `davinci-resolve`
- **Comm**: `signal-desktop`, `discord`, `slack`, `element`, `session`
- **Infrastructure**: `docker`, `podman-desktop`, `minikube`, `helm`
- **KVM**: `synergy` (optional, cross-platform)

### Appearance & Shell
- **Fonts**: `0xProto Nerd Font` (default), `FiraCode`, `FiraMono`
- **Shell**: Oh My Zsh + Powerlevel10k (p10k)

## Idempotency and Performance
- **Optimized Cache**: `apt` and `dnf` caches are only updated when repositories change or after 1 hour.
- **Smart Downloads**: Fonts and keys are only fetched if they are missing from the system.
- **Package Validation**: On Fedora, each package is checked against DNF repositories before install. Unavailable packages are warned about, not failed on.
- **Cross-Platform**: Intelligent detection for Apple Silicon (M1/M2/M3), Intel Mac, and various Linux distributions (Debian, Ubuntu, Pop!_OS, Fedora, and other RPM-based systems).

## Post-Install

### Powerlevel10k
If Powerlevel10k has not been configured yet (no `~/.p10k.zsh` file), a banner is displayed after installation reminding you to configure your prompt. Run the helper script:
```bash
p10k_setup.py
```
This offers three options:
1. **Use the default theme** — applies the bundled p10k configuration
2. **Run the interactive wizard** — launches `p10k configure` for full customization
3. **Load a custom file** — copies your own `.p10k.zsh` from a path you specify

The script backs up any existing `~/.p10k.zsh` to `~/.p10k.zsh.bak` before making changes.

### Conditional Reboot Prompt
On Linux, the bootstrap script checks whether a reboot is needed after installation:
- **NVIDIA drivers installed** — the kernel module requires a reboot to load
- **Kernel upgraded** — the running kernel differs from the latest installed kernel

If either condition is detected, you are shown the specific reason(s) and prompted to reboot. If neither applies, no reboot prompt is shown. macOS does not prompt for reboot.

### Other Steps
1. **Fonts**: Change your terminal font to `0xProto Nerd Font Mono`.
2. **Shell**: Restart your terminal or run `exec zsh`.
3. **Copilot**: Run `:Copilot setup` in `nvim` to authenticate.

## License
GNU General Public License v3.0. See [LICENSE](LICENSE).
