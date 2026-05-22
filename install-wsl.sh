#!/usr/bin/env bash
# install-wsl.sh — one-liner WSL installer for the terminal-stack.
# Usage (from a fresh WSL Ubuntu, after running install.ps1 on Windows):
#   curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-wsl.sh | bash
#
# Optional: override the clone location before piping.
#   TERMINAL_STACK_DIR=/mnt/c/dev/terminal-stack curl -fsSL ... | bash
#
# What it does:
#   1. Ensures git + curl are installed (apt).
#   2. Auto-detects Windows username via cmd.exe interop.
#   3. Clones github.com/martsamp77/terminal-stack to /mnt/c/Users/<WIN_USER>/terminal-stack
#      (or $TERMINAL_STACK_DIR). git pull if already cloned.
#   4. Runs bootstrap/wsl-bootstrap.sh non-interactively (WIN_USER from env).
#   5. Runs chezmoi apply -v.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(id -u)" -eq 0 ]; then
    echo "$WARN Don't run this as root. Run as your normal WSL user; sudo will prompt as needed."
    exit 1
fi

echo "$INFO terminal-stack WSL installer"
echo "    Detected: user $USER, home $HOME"

# 1. apt prereqs
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "$INFO Installing git + curl via apt"
    sudo apt-get update -qq
    sudo apt-get install -y git curl >/dev/null
fi

# 2. Windows username via cmd.exe interop
detect_win_user() {
    if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
        /mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true
    fi
}
WIN_USER="${WIN_USER:-$(detect_win_user)}"
if [ -z "$WIN_USER" ]; then
    echo "$WARN Could not auto-detect Windows username. Set WIN_USER=<name> and re-run."
    exit 1
fi
export WIN_USER
echo "$INFO Windows username: $WIN_USER"

# 3. Clone
REPO_URL='https://github.com/martsamp77/terminal-stack.git'
TARGET_DIR="${TERMINAL_STACK_DIR:-/mnt/c/Users/$WIN_USER/terminal-stack}"

if [ -d "$TARGET_DIR/.git" ]; then
    echo "$INFO Repo already at $TARGET_DIR; git pull"
    git -C "$TARGET_DIR" pull --ff-only
else
    echo "$INFO Cloning $REPO_URL -> $TARGET_DIR"
    mkdir -p "$(dirname -- "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
fi

# 4. Bootstrap (non-interactive thanks to the env WIN_USER guard in wsl-bootstrap.sh)
export SOURCE_DIR="$TARGET_DIR"
BOOTSTRAP="$TARGET_DIR/bootstrap/wsl-bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
    echo "$WARN Expected bootstrap script not found at $BOOTSTRAP"
    exit 1
fi
echo "$INFO Running $BOOTSTRAP"
bash "$BOOTSTRAP"

# 5. chezmoi apply
echo "$INFO Running chezmoi apply -v"
"$HOME/.local/bin/chezmoi" apply -v

echo ""
echo "$INFO WSL install done."
echo "    Clone:  $TARGET_DIR"
echo "    Next:   open a new WezTerm tab (auto-reload picks up .wezterm.lua)."
