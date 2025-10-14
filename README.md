# Cross-Platform Computer Setup (macOS + Ubuntu/Pop!_OS)

Automate opinionated workstation setup with Ansible. This project provisions platform-appropriate package managers (Homebrew on macOS, apt on Ubuntu/Pop!_OS), optional VS Code extensions, Oh My Zsh, the Powerlevel10k prompt, and the fonts required for beautiful glyphs. It is idempotent and optimized for Apple Silicon (with graceful Intel fallbacks where needed) and Ubuntu/Pop!_OS (including Cosmic desktop specific tooling).

## What this does

- Homebrew management via the `brewPackages` role
  - Detects Apple Silicon vs Intel and uses the correct `brew` prefix
  - Installs taps, casks, and formulae (CLI tools like `lsd` replace legacy `colorls`)
  - Installs VS Code extensions where VS Code CLI is available
  - Falls back to Intel Homebrew with Rosetta only when ARM install fails
- Shell customization
  - Installs Oh My Zsh only if missing
  - Installs Powerlevel10k theme and sets `ZSH_THEME="powerlevel10k/powerlevel10k"`
  - Ensures `~/.p10k.zsh` is sourced and redraws cleanly on terminal resize
  - Installs `p10k_setup.py` helper into the proper Homebrew `bin` directory:
    - Apple Silicon: `/opt/homebrew/bin/p10k_setup.py`
    - Intel: `/usr/local/bin/p10k_setup.py`
  - Adds convenience helpers such as `apt-upgrade-report` and `full-upgrade`
- Fonts (for glyphs)
  - Installs Nerd Fonts idempotently via Homebrew casks on macOS and Flatpak-friendly downloads on Linux
  - Default font: 0xProto Nerd Font (`font-0xproto-nerd-font`)
  - Also installs Fira Code and Fira Mono Nerd Fonts by default
  - Optionally install additional Nerd Fonts
- Sensible bootstrap UX
  - Single sudo prompt; credentials are cached for the entire run
  - Ansible becomes non-interactive (password is passed securely via a temp vars file)
  - Verbose logs saved to `bootstrap.log` with color-preserved stdout (use `less -R bootstrap.log`)

## Prerequisites (first run)

### macOS

You need Homebrew and Git to clone this repo. Use this one-liner (Apple Silicon and Intel supported):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; else eval "$(/usr/local/bin/brew shellenv)"; fi; \
brew install git; \
cd "$HOME"; \
git clone <REPO_URL> "$HOME/git/personal/compSetup"; \
cd "$HOME/git/personal/compSetup"; \
./bootstrap.sh
```

### Ubuntu / Pop!_OS (Cosmic)

Ensure you have git, curl, and sudo privileges available (the bootstrap will install other dependencies automatically).

```bash
sudo apt update
sudo apt install -y git curl
git clone <REPO_URL> "$HOME/git/personal/compSetup"
cd "$HOME/git/personal/compSetup"
./bootstrap.sh
```

- Replace `<REPO_URL>` with your repository URL.
- The script will prompt for your password as needed by `sudo`.

## Usage

- Run the bootstrap script from the repo root:

```bash
./bootstrap.sh
```

- The script:
  - Detects the host operating system (macOS or Linux)
  - Validates and caches sudo (macOS)
  - Installs platform dependencies (Homebrew on macOS, apt packages on Ubuntu/Pop!_OS)
  - Installs Ansible, required collections, and VS Code extensions when applicable
  - Streams colored Ansible output while teeing to `bootstrap.log`
  - Executes `ansible-playbook site.yml`
- Optional roles can be invoked with tags. Examples:

  ```bash
  ANSIBLE_TAGS=davinci_resolve ./bootstrap.sh             # run Pop!_OS DaVinci dependencies
  ansible-playbook site.yml --tags davinci_resolve --ask-become-pass
  ```

### apt-upgrade-report helper

The ohmyzsh role installs `/usr/local/bin/apt-upgrade-report`, a convenience wrapper for maintaining apt upgrades and generating changelog reports. Usage:

```bash
apt-upgrade-report            # apt update && apt upgrade -y, report last 1 day
apt-upgrade-report --md       # same, plus Markdown copy
apt-upgrade-report --no-upgrade --days 7  # skip upgrade, report last 7 days
```

## Options and configuration

- Package manifest: edit `packages.yml`
  - `brew_taps`: Homebrew taps to enable
  - `cli_tools`: shared CLI tools with `brew_formula` and/or `apt` (e.g., `lsd` replaces `colorls`)
  - `gui_apps`: Homebrew casks and Linux installers (apt, deb, Flatpak)
  - `fonts`: Nerd fonts installed via Homebrew casks / Linux downloads
  - `apt_only`: apt-specific packages (common/by distribution/by desktop) including GNOME keyring helpers
  - `vscode_extensions`: extensions installed when the VS Code CLI is present
- Role variables (Powerlevel10k)
  - `p10k_install_ohmyzsh_if_missing` (default: true)
  - `p10k_script_dest` (default: arch-aware Homebrew bin path)
  - `p10k_python_script_src` (custom helper script source)
  - `p10k_default_src` (custom default `.p10k.zsh` content source)
  - `set_zsh_default` (default: false)
  - Fonts (all default true/values):
    - `p10k_install_fonts: true`
    - `p10k_font_cask: font-0xproto-nerd-font` (default font choice)
    - `p10k_install_fira_fonts: true`
    - `p10k_fira_font_casks: ['font-fira-code-nerd-font','font-fira-mono-nerd-font']`
    - `p10k_extra_font_casks: ['font-0xproto-nerd-font']` (extend this list as needed)

## Flowchart (execution overview)

```mermaid
flowchart TD
  A[Start ./bootstrap.sh] --> B{macOS?}
  B -- Yes --> C1[Prompt once for sudo<br/>cache credentials]
  C1 --> D1[Install/repair Homebrew]
  D1 --> E1[Apple Silicon?]
  E1 -- Yes --> F1[Ensure Rosetta 2]
  E1 -- No --> G1[Skip Rosetta]
  F1 --> H1[Install macOS prerequisites]
  G1 --> H1
  B -- No --> C2[Install apt prerequisites]
  C2 --> H2[Install apt packages]
  H1 --> I[Install Ansible + collections]
  H2 --> I
  B --> C[Install Homebrew if missing<br/>setup shellenv]
  C --> D[Homebrew health check<br/>update/upgrade if needed]
  D --> E{Apple Silicon?}
  E -- Yes --> F[Ensure Rosetta 2 if needed]
  E -- No --> G[Skip Rosetta]
  F --> H[Xcode Command Line Tools check]
  G --> H[Xcode Command Line Tools check]
  H --> I[Install Ansible]
  I --> J[Install Ansible collections]
  J --> K[Detect VS Code CLI]
  K --> L[Run ansible-playbook<br/>pass become password via temp vars]
  L --> M[Role: brewPackages<br/>taps, casks, formulae, VS Code extensions]
  M --> N[Role: ohmyzsh + apt-upgrade-report helper]
  N --> O[Role: powerlevel10k<br/>clone theme, set ZSH_THEME, fonts, prompt resize handler]
  O --> P[Optional roles (nvchad, iterm2, davinci_resolve)]
  P --> Q[Done]
```

## Post-run steps

- Set your terminal’s font to a Nerd Font for glyphs (default installed: 0xProto Nerd Font Mono)
  - Terminal.app: Preferences → Profiles → Text → Font
  - iTerm2: Preferences → Profiles → Text → Font
- Open a new terminal tab/window or run `exec zsh` to reload shell
- Optional: Run the helper to configure Powerlevel10k

```bash
p10k_setup.py
```

- Choices in helper:
  - Use the bundled default `.p10k.zsh`
  - Run the interactive `p10k configure` wizard
  - Load your own `.p10k.zsh`

Note: Powerlevel10k config uses the `POWERLEVEL9K_*` variable namespace by design for backward compatibility. This is expected.

## Idempotency and performance notes

- Casks: only missing items are installed (skips already-installed)
- Formulae: only missing items are installed (skips already-installed)
- Fonts: installed via Homebrew casks with `state: present` (idempotent)
- Powerlevel10k and Oh My Zsh: installed only if missing

## Troubleshooting

- Become password prompt reappears
  - Ensure the initial sudo prompt succeeded; the bootstrap caches and forwards the password to Ansible
- Fonts don’t render correctly
  - Ensure your terminal profile uses a Nerd Font (e.g., 0xProto Nerd Font Mono)
- VS Code extensions aren’t installed
  - Ensure VS Code is installed before the run or re-run with VS Code installed
- Powerlevel10k not active
  - Ensure `ZSH_THEME="powerlevel10k/powerlevel10k"` is present in `~/.zshrc`
  - Open a new terminal or run `exec zsh`

## Project layout (key files)

- `macOSBootstrap.sh`: entrypoint; handles sudo, Homebrew, Ansible invocation
- `site.yml`: main playbook
- `brewPackages.yml`: declare desired taps/casks/formulae and VS Code extensions
- `roles/brewPackages`: Homebrew and VS Code automation
- `roles/ohmyzsh`: installs Oh My Zsh (only if missing)
- `roles/powerlevel10k`:
  - `tasks/main.yml`: theme install, config wiring, helper script, fonts
  - `files/p10k_setup.py`: optional Powerlevel10k setup helper
  - `templates/p10k_default_src.j2`: bundled default `.p10k.zsh` (templating disabled via `{% raw %}`)

## Security

- The bootstrap prompts once for your password and caches it for the run
- Ansible receives the become password through a secure temporary vars file (deleted immediately after use)
- The helper script is installed with ownership set to the invoking user

## Compatibility

- macOS (Apple Silicon and Intel)
- Requires network access to GitHub/Homebrew sources

## License

This project is provided under the GNU General Public License v3.0. See [LICENSE](LICENSE).

