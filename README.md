# Cross-Platform Computer Setup (macOS + Ubuntu/Pop!_OS + Fedora/RPM)

Automate opinionated workstation setup with Ansible. This project provisions platform-appropriate package managers (Homebrew on macOS, apt on Ubuntu/Pop!_OS, dnf on Fedora/RPM), optional VS Code extensions, Oh My Zsh, the Powerlevel10k prompt, and the fonts required for beautiful glyphs. It is idempotent and optimized for Apple Silicon (with graceful Intel fallbacks where needed) and Linux desktops (GNOME/Cosmic).

## Getting Started (Fresh Install)

If you have just logged into a brand new computer, follow these steps to get everything running.

### 1. Open your Terminal
- **macOS**: Press `Command + Space`, type "Terminal", and hit Enter.
- **Ubuntu/Pop!_OS**: Press `Super` (Windows key), type "Terminal", and hit Enter.

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
By default, running `./bootstrap.sh` launches a **beautiful interactive menu**:
- **🚀 Standard Install**: Everything except DaVinci Resolve dependencies.
- **🍃 No AI Tools**: Skip Gemini CLI, Claude Code, and Antigravity.
- **⚙️ Custom Installation**: Toggle specific options (Skip AI, Skip VS Code, Install DaVinci) with real-time status badges.
- **📝 Blacklist Editor**: Opens your default editor to manage `~/.install_blacklist`.
- **Real-time Monitoring**: The installation output is streamed directly within the program pane.

### Command Line Flags (Headless Mode)
You can skip the TUI for automation or specific tasks:
```bash
./bootstrap.sh --skip-ai-tools           # Skip AI tools
./bootstrap.sh --skip-vscode-extensions  # Skip VS Code extensions
./bootstrap.sh --install-davinci         # Install DaVinci deps (Linux)
./bootstrap.sh --omit "pkg1 pkg2"        # Add specific packages to blacklist
```

### Persistent Package Blacklist
Avoid installing specific tools by adding them to your blacklist.
- **Location**: `~/.install_blacklist` (created in your Home directory).
- **Git Safety**: This file is kept locally and is never tracked by git.
- **Feedback**: 
  - ${ESC}[38;5;214mOrange${RESET} text confirms when a package is newly added.
  - ${ESC}[35mPurple${RESET} text confirms if a package was already blacklisted.

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
- **Media**: `vlc`, `handbrake`, `obs-studio`, `davinci-resolve` (deps)
- **Comm**: `signal-desktop`, `discord`, `slack`, `element`, `session`
- **Infrastructure**: `docker`, `podman-desktop`, `minikube`, `helm`

### Appearance & Shell
- **Fonts**: `0xProto Nerd Font` (default), `FiraCode`, `FiraMono`
- **Shell**: Oh My Zsh + Powerlevel10k (p10k)

## Idempotency and Performance
- **Optimized Cache**: `apt` and `dnf` caches are only updated when repositories change or after 1 hour.
- **Smart Downloads**: Fonts and keys are only fetched if they are missing from the system.
- **Cross-Platform**: Intelligent detection for Apple Silicon (M1/M2/M3), Intel Mac, and various Linux distributions (Debian, Ubuntu, Pop!_OS, Fedora, and other RPM-based systems).

## Post-run steps
1. **Fonts**: Change your terminal font to `0xProto Nerd Font Mono`.
2. **Shell**: Restart your terminal or run `exec zsh`.
3. **Copilot**: Run `:Copilot setup` in `nvim` to authenticate.

## License
GNU General Public License v3.0. See [LICENSE](LICENSE).
