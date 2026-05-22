#!/usr/bin/env bash
# install-linux.sh — one-liner native-Linux installer for the terminal-stack.
# Targets Debian/Ubuntu-family hosts. Idempotent: re-run safely.
# Usage (from a fresh Debian/Ubuntu box):
#   curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-linux.sh | bash
#
# Optional: override the clone location before piping.
#   TERMINAL_STACK_DIR=~/dotfiles/ts curl -fsSL ... | bash
#
# What it does:
#   1. Ensures git + curl are installed (apt).
#   2. Clones github.com/martsamp77/terminal-stack to ~/code/terminal-stack
#      (or $TERMINAL_STACK_DIR). git pull if already cloned.
#   3. Runs bootstrap/linux-bootstrap.sh.
#   4. Runs chezmoi apply -v. The post-apply hook self-no-ops without /mnt/c/Users/.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(id -u)" -eq 0 ]; then
    echo "$WARN Don't run this as root. Run as your normal user; sudo will prompt as needed."
    exit 1
fi

echo "$INFO terminal-stack Linux installer"
echo "    Detected: user $USER, home $HOME"

# 1. apt prereqs
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "$INFO Installing git + curl via apt"
    sudo apt-get update -qq
    sudo apt-get install -y git curl >/dev/null
fi

# 2. Clone
REPO_URL='https://github.com/martsamp77/terminal-stack.git'
TARGET_DIR="${TERMINAL_STACK_DIR:-$HOME/code/terminal-stack}"

if [ -d "$TARGET_DIR/.git" ]; then
    echo "$INFO Repo already at $TARGET_DIR; git pull"
    git -C "$TARGET_DIR" pull --ff-only
else
    echo "$INFO Cloning $REPO_URL -> $TARGET_DIR"
    mkdir -p "$(dirname -- "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
fi

# 3. Bootstrap
export SOURCE_DIR="$TARGET_DIR"
BOOTSTRAP="$TARGET_DIR/bootstrap/linux-bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
    echo "$WARN Expected bootstrap script not found at $BOOTSTRAP"
    exit 1
fi
echo "$INFO Running $BOOTSTRAP"
bash "$BOOTSTRAP"

# 4. chezmoi apply
echo "$INFO Running chezmoi apply -v"
"$HOME/.local/bin/chezmoi" apply -v

echo ""
echo "$INFO Linux install done."
echo "    Clone:  $TARGET_DIR"
echo "    Next:   open a new terminal and confirm Starship prompt + Nerd Font glyphs."
