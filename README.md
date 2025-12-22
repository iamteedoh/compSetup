# Cross-Platform Computer Setup (macOS + Ubuntu/Pop!_OS)

Automate opinionated workstation setup with Ansible. This project provisions platform-appropriate package managers (Homebrew on macOS, apt on Ubuntu/Pop!_OS), optional VS Code extensions, Oh My Zsh, the Powerlevel10k prompt, and the fonts required for beautiful glyphs. It is idempotent and optimized for Apple Silicon (with graceful Intel fallbacks where needed) and Ubuntu/Pop!_OS (including Cosmic desktop specific tooling).

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

### AI Tools Installation
When you run the script, an **interactive menu** will ask if you want to install AI tools (Gemini CLI, Claude Code, Antigravity).
- **Option 1**: Install everything.
- **Option 2**: Install everything **EXCEPT** AI tools.
- **Option 3**: Exit.

**Skip the menu**:
You can skip the interactive menu and automatically skip AI tools by using the `--skip-ai-tools` flag:
```bash
./bootstrap.sh --skip-ai-tools
```

**Help**:
View all available options:
```bash
./bootstrap.sh --help
```

### Optional Roles
You can invoke specific roles using tags. For example, to install DaVinci Resolve dependencies on Pop!_OS:
```bash
ANSIBLE_TAGS=davinci_resolve ./bootstrap.sh
```

## What this does

- **Package Management**:
  - **macOS**: Installs Homebrew, taps, casks, and formulae. Detects Apple Silicon vs Intel.
  - **Linux**: Installs apt packages, adds repositories (NodeSource, Signal, etc.), and Flatpaks.
- **Shell Customization**:
  - Installs Oh My Zsh (if missing).
  - Installs Powerlevel10k theme and configures it.
- **Fonts**:
  - Installs Nerd Fonts (0xProto, Fira Code, Fira Mono) for proper glyph rendering.
- **Neovim (NVChad)**:
  - Bootstraps NVChad with custom configuration.
  - Installs GitHub Copilot for Neovim.
- **Apps**:
  - Installs VS Code and extensions.
  - Installs GUI apps (Signal, etc.) and CLI tools.

## Idempotency and Performance

This project is designed to be **idempotent**, meaning you can run it multiple times without breaking anything. It respects your existing setup:
- **Downloads**: Large files (fonts, keys) are only downloaded if missing.
- **Repositories**: `apt-get update` is only run if a new repository is added or if the cache is old.
- **Packages**:
  - Homebrew casks/formulae are installed only if missing.
  - Apt packages are checked against the current state.
- **Configs**: Configuration files are created or updated only if necessary.

## Post-run steps

1. **Fonts**: Set your terminal’s font to `0xProto Nerd Font Mono` (or FiraCode) in your terminal preferences.
2. **Shell**: Open a new terminal tab or run `exec zsh` to load the new shell.
3. **GitHub Copilot**:
   - Open Neovim (`nvim`).
   - Run `:Copilot setup` and follow the browser authentication steps.
4. **Powerlevel10k**:
   - Run `p10k_setup.py` if you want to re-configure the prompt style.

## Troubleshooting

- **Password Prompt**: If asked for a password again, it means the cached credentials expired. The script tries to keep them alive.
- **Fonts**: If icons look weird, ensure your terminal is using a "Nerd Font".
- **VS Code**: Extensions install only if VS Code CLI (`code`) is found in your PATH.

## Project layout

- `bootstrap.sh`: Main entry point (interactive menu + flags).
- `linuxBootstrap.sh` / `macOSBootstrap.sh`: OS-specific logic.
- `site.yml`: Main Ansible playbook.
- `packages.yml`: List of all packages to install.
- `roles/`: Ansible roles for specific components (zsh, neovim, etc.).

## License

This project is provided under the GNU General Public License v3.0. See [LICENSE](LICENSE).