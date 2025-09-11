#!/usr/bin/env python3
import os
import shutil
import subprocess
from pathlib import Path

HOME = Path.home()
ZSHRC = HOME / ".zshrc"
P10K_DEST = HOME / ".p10k.zsh"
# Prefer Apple Silicon Homebrew share if present, otherwise fallback to Intel prefix
DEFAULT_SRC_CANDIDATES = [
    Path("/opt/homebrew/share/p10k_default.zsh"),
    Path("/usr/local/share/p10k_default.zsh"),
]

def _detect_default_src() -> Path | None:
    for candidate in DEFAULT_SRC_CANDIDATES:
        if candidate.exists():
            return candidate
    return None

def ensure_zshrc_sources_p10k():
    ZSHRC.parent.mkdir(parents=True, exist_ok=True)
    ZSHRC.touch(exist_ok=True)
    line = '[ -f ~/.p10k.zsh ] && source ~/.p10k.zsh'
    with ZSHRC.open("r", encoding="utf-8") as f:
        content = f.read()
    if line not in content:
        with ZSHRC.open("a", encoding="utf-8") as f:
            f.write(("\n" if not content.endswith("\n") else "") + line + "\n")
        print("Added source line to ~/.zshrc")
    else:
        print("~/.zshrc already set to source ~/.p10k.zsh")

def backup_existing_p10k():
    if P10K_DEST.exists():
        bkp = P10K_DEST.with_suffix(".zsh.bak")
        shutil.copy2(P10K_DEST, bkp)
        print(f"Backed up existing {P10K_DEST} to {bkp}")

def use_default():
    default_src = _detect_default_src()
    if not default_src:
        print("Default p10k configuration not found at /opt/homebrew/share or /usr/local/share.\n"
              "Make sure your Ansible role copied it (set p10k_default_src) or run the wizard.")
        return
    backup_existing_p10k()
    shutil.copy2(default_src, P10K_DEST)
    print(f"Copied default config from {default_src} to {P10K_DEST}")

def run_wizard():
    # Ensure theme & oh-my-zsh are installed and ZSH_THEME is set by the role.
    print("Launching Powerlevel10k configuration wizard inside a zsh shell...")
    # -i: interactive; -c: run command; we use -i to ensure p10k can prompt.
    # If it doesn't auto-launch, we explicitly run `p10k configure`.
    subprocess.run(['zsh', '-ic', 'p10k configure || true'])

def load_custom():
    src = input("Enter the full path to your .p10k.zsh: ").strip()
    if not src:
        print("No path provided. Aborting.")
        return
    src_path = Path(src).expanduser()
    if not src_path.exists():
        print(f"File not found: {src_path}")
        return
    backup_existing_p10k()
    shutil.copy2(src_path, P10K_DEST)
    print(f"Copied {src_path} to {P10K_DEST}")

def main():
    print("\nPowerlevel10k configurator\n")
    print("1) Would you like to use the default available p10k.zsh file?")
    print("2) Would you like to go through the setup of the p10k.zsh file?")
    print("3) Would you like to load your own p10k.zsh file?")
    choice = input("\nSelect 1, 2, or 3: ").strip()

    if choice == "1":
        use_default()
    elif choice == "2":
        run_wizard()
    elif choice == "3":
        load_custom()
    else:
        print("Invalid choice. Please run again and select 1, 2, or 3.")
        return

    ensure_zshrc_sources_p10k()
    print("\nAll set! Open a new terminal tab/window or run: exec zsh\n")

if __name__ == "__main__":
    main()
