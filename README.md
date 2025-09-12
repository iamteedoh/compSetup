# macOS Computer Setup (Ansible + Homebrew)

Automate opinionated macOS setup with Ansible. This project provisions Homebrew packages (formulae and casks), optional VS Code extensions, Oh My Zsh, the Powerlevel10k prompt, and the fonts required for beautiful glyphs. It is idempotent and optimized for Apple Silicon (with graceful Intel fallbacks where needed).

## What this does

- Homebrew management via the `brewPackages` role
  - Detects Apple Silicon vs Intel and uses the correct `brew` prefix
  - Installs taps, casks, and formulae
  - Idempotent cask installs (skips already-installed casks)
  - Installs VS Code extensions (optional)
  - Falls back to Intel Homebrew with Rosetta only when ARM install fails
- Shell customization
  - Installs Oh My Zsh only if missing
  - Installs Powerlevel10k theme and sets `ZSH_THEME="powerlevel10k/powerlevel10k"`
  - Ensures `~/.p10k.zsh` is sourced
  - Installs `p10k_setup.py` helper into the proper Homebrew `bin` directory:
    - Apple Silicon: `/opt/homebrew/bin/p10k_setup.py`
    - Intel: `/usr/local/bin/p10k_setup.py`
  - Sets script owner/group to the invoking user and adds compatibility symlinks if needed
- Fonts (for glyphs)
  - Installs Nerd Fonts idempotently via Homebrew casks
  - Default font: 0xProto Nerd Font (`font-0xproto-nerd-font`)
  - Also installs Fira Code and Fira Mono Nerd Fonts by default
  - Optionally install additional Nerd Fonts
- Sensible bootstrap UX
  - Single sudo prompt; credentials are cached for the entire run
  - Ansible becomes non-interactive (password is passed securely via a temp vars file)
  - Verbose logs saved to `bootstrap.log`

## Prerequisites (first run)

You need Homebrew and Git to clone this repo. Use this one-liner (Apple Silicon and Intel supported):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; else eval "$(/usr/local/bin/brew shellenv)"; fi; \
brew install git; \
cd "$HOME"; \
git clone <REPO_URL> "$HOME/git/personal/compSetup"; \
cd "$HOME/git/personal/compSetup"; \
./macOSBootstrap.sh
```

- Replace `<REPO_URL>` with your repository URL.
- The script will prompt for your macOS password once and won’t prompt again during the run.

## Usage

- Run the bootstrap script from the repo root:

```bash
./macOSBootstrap.sh
```

- The script:
  - Validates and caches sudo
  - Installs/repairs Homebrew if necessary
  - Ensures Rosetta 2 on Apple Silicon (only if needed)
  - Installs Ansible and required collections
  - Detects whether VS Code is installed to decide on extension install
  - Executes `ansible-playbook site.yml`

## Options and configuration

- Homebrew packages: edit `brewPackages.yml` in the repo root
  - Keys (all optional): `brew_taps`, `brew_casks`, `brew_formulae`, `vscode_extensions`
- VS Code extensions:
  - The bootstrap auto-detects VS Code and sets `install_vscode_extensions=true|false`
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
  A[Start ./macOSBootstrap.sh] --> B[Prompt once for sudo\ncache credentials]
  B --> C[Install Homebrew if missing\nsetup shellenv]
  C --> D[Homebrew health check\nupdate/upgrade if needed]
  D --> E{Apple Silicon?}
  E -- Yes --> F[Ensure Rosetta 2 if needed]
  E -- No --> G[Skip Rosetta]
  F --> H[Xcode Command Line Tools check]
  G --> H[Xcode Command Line Tools check]
  H --> I[Install Ansible]
  I --> J[Install Ansible collections]
  J --> K[Detect VS Code CLI]
  K --> L[ansible-playbook site.yml\n(pass become pwd via temp vars file)]
  L --> M[Role: brewPackages\n(taps, casks, formulae, VS Code extensions)]
  M --> N[Role: ohmyzsh\n(install if missing)]
  N --> O[Role: powerlevel10k\n(clone theme, set ZSH_THEME, p10k_setup.py, fonts)]
  O --> P[Done]
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

This project is provided under the MIT License. See `LICENSE`.

