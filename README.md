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
Follow the prompts to install the "Command Line Developer Tools".

**Ubuntu / Pop!_OS**:
```bash
sudo apt update
sudo apt install -y git curl
```

**Fedora / RPM**:
```bash
sudo dnf install -y git curl
```

### 3. Download and Run
Copy and paste these commands into your terminal:

```bash
# Clone the repository
git clone https://github.com/iamteedoh/compSetup.git ~/git/compSetup

# Enter the directory
cd ~/git/compSetup

# Make the script executable
chmod +x bootstrap.sh

# Run the setup
./bootstrap.sh
```

The script will prompt you for your `sudo` password once and handle the rest.

## Usage

Run the bootstrap script from the repo root:

```bash
./bootstrap.sh
```

### Interactive Menu & Flags
When you run the script, an **interactive menu** will guide you. You can also use flags to skip the menu or customize the install:

```bash
# Skip AI tools (Gemini, Claude, Antigravity)
./bootstrap.sh --skip-ai-tools

# Skip VS Code Extensions
./bootstrap.sh --skip-vscode-extensions

# Install DaVinci Resolve dependencies (Linux only)
./bootstrap.sh --install-davinci

# Omit specific packages (space-separated list)
./bootstrap.sh --omit "google-chrome cyberduck"

# Combine flags
./bootstrap.sh --skip-ai-tools --skip-vscode-extensions
```

### Omit / Blacklist Packages
You can persistently blacklist packages you never want to install.
- Using `--omit "pkg1 pkg2"` creates or updates a `.install_blacklist` file in the repo.
- If this file exists, future runs will automatically skip the listed packages.
- Example: `./bootstrap.sh --omit "google-chrome"` will add Chrome to the blacklist and skip it.

## Supported Tools

### CLI Tools
- `ansible`, `git`, `curl`, `wget`, `unzip`, `gnupg`, `htop`
- `neovim` (configured with NVChad), `python3`, `node`, `ruby`
- `ripgrep`, `fd`, `bat`, `lsd` (modern replacements for grep, find, cat, ls)
- `ffmpeg`, `graphviz`, `ncdu`, `trash-cli`, `watch`, `wakeonlan`
- **AI Tools**: `gemini-cli` (@google/gemini-cli), `claude-code` (@anthropic-ai/claude-code)

### GUI Applications
- **Browsers**: `google-chrome`, `brave`, `firefox` (via system default)
- **Editors**: `visual-studio-code` (with extensions), `typora`, `ghostty`
- **Productivity**: `obsidian`, `joplin`, `standardnotes`, `proton-mail`, `proton-pass`
- **Media**: `vlc`, `handbrake`, `gimp`, `obs-studio`, `davinci-resolve` (deps)
- **Comm**: `signal-desktop`, `discord`, `slack`, `element` (riot), `session`
- **Dev/Ops**: `docker`, `podman-desktop`, `minikube`, `helm`, `cyberduck`

### Fonts
- **Default**: `0xProto Nerd Font`
- **Extras**: `FiraCode Nerd Font`, `FiraMono Nerd Font`

### VS Code Extensions
- GitHub Copilot & Chat
- Language support: Python (Pylance), Go, Rust (rust-analyzer), Ansible, YAML
- Docker, Kubernetes tools
- Vim keybindings

## What this does

- **Package Management**:
  - **macOS**: Installs Homebrew, taps, casks, and formulae. Detects Apple Silicon vs Intel.
  - **Linux (Debian/Ubuntu/Pop)**: Installs apt packages, adds repositories (NodeSource, Signal, etc.), and Flatpaks.
  - **Linux (Fedora/RPM)**: Installs dnf packages and Flatpaks.
- **Shell Customization**:
  - Installs Oh My Zsh (if missing).
  - Installs Powerlevel10k theme and configures it.
- **Neovim (NVChad)**:
  - Bootstraps NVChad with custom configuration.
  - Installs GitHub Copilot for Neovim.

## Idempotency and Performance

This project is designed to be **idempotent**, meaning you can run it multiple times without breaking anything. It respects your existing setup:
- **Downloads**: Large files (fonts, keys) are only downloaded if missing.
- **Repositories**: Cache is updated only if repositories change.
- **Packages**: Only missing items are installed.
- **Blacklist**: Respects your `.install_blacklist` file.

## Post-run steps

1. **Fonts**: Set your terminal’s font to `0xProto Nerd Font Mono` (or FiraCode).
2. **Shell**: Open a new terminal tab or run `exec zsh`.
3. **GitHub Copilot**:
   - Open Neovim (`nvim`).
   - Run `:Copilot setup` and authenticate.
4. **Powerlevel10k**:
   - Run `p10k_setup.py` if needed.

## Troubleshooting

- **Password Prompt**: If asked for a password again, the cached sudo session expired.
- **RPM Support**: On Fedora/RPM systems, some apt-specific packages might be skipped if the name differs significantly, but standard tools (git, neovim, etc.) and Flatpaks will install.

## Project layout

- `bootstrap.sh`: Main entry point (interactive menu + flags).
- `site.yml`: Main Ansible playbook.
- `packages.yml`: List of all packages.
- `roles/aptPackages`: Debian/Ubuntu specific logic.
- `roles/rpmPackages`: Fedora/RPM specific logic.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
