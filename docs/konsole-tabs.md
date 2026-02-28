# Konsole Tab Styling

Deploys a custom CSS stylesheet for KDE Konsole that highlights the active tab with a muted green background, making it easy to identify at a glance.

## What it does

Installs a Qt stylesheet at `~/.config/konsole/tabbar.css` that styles:

- **Active tab** — muted forest green background (`rgb(58, 90, 64)`) with light text and bold weight
- **Inactive tabs** — dark background (`rgb(45, 45, 45)`) with dimmed text

## Post-install setup

After installation, you need to enable the stylesheet in Konsole:

1. Open **Settings > Configure Konsole > Tab Bar**
2. Check **"Use user-defined stylesheet"**
3. Point it to `~/.config/konsole/tabbar.css`
4. Restart Konsole

## Installation

Deployed automatically by the `konsole_tabs` Ansible role in compSetup. Enable it via the Custom Installation menu (option 8 on Linux) or pass `--install-konsole-tabs` on the command line.

Files installed:
- `~/.config/konsole/tabbar.css` — tab bar stylesheet (mode 0644)
