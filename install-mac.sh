#!/usr/bin/env bash
# install-mac.sh — one-liner macOS installer for the terminal-stack.
# Targets macOS (Apple Silicon or Intel) via Homebrew. Idempotent: re-run safely.
# Usage (from a fresh Mac):
#   curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-mac.sh | bash
#
# Optional: override the clone location before piping.
#   TERMINAL_STACK_DIR=~/dotfiles/ts curl -fsSL ... | bash
#
# What it does:
#   1. Verifies Darwin.
#   2. Installs Homebrew if absent.
#   3. brew install git if absent.
#   4. Clones github.com/martsamp77/terminal-stack to ~/code/terminal-stack
#      (or $TERMINAL_STACK_DIR). git pull if already cloned.
#   5. Runs bootstrap/mac-bootstrap.sh.
#   6. Runs chezmoi apply -v. The post-apply hook self-no-ops without /mnt/c/Users/.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(uname -s)" != "Darwin" ]; then
    echo "$WARN This script is for macOS. Detected: $(uname -s). Aborting."
    exit 1
fi

echo "$INFO terminal-stack macOS installer"
echo "    Detected: user $USER, home $HOME, arch $(uname -m)"

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "$INFO Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available for the rest of this script (path varies by Apple Silicon vs Intel).
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 2. Git
if ! command -v git >/dev/null 2>&1; then
    echo "$INFO brew install git"
    brew install git
fi

# 3. Clone
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

# 4. Bootstrap
export SOURCE_DIR="$TARGET_DIR"
BOOTSTRAP="$TARGET_DIR/bootstrap/mac-bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
    echo "$WARN Expected bootstrap script not found at $BOOTSTRAP"
    exit 1
fi
echo "$INFO Running $BOOTSTRAP"
bash "$BOOTSTRAP"

# 5. chezmoi apply
echo "$INFO Running chezmoi apply -v"
chezmoi apply -v

echo ""
echo "$INFO macOS install done."
echo "    Clone:  $TARGET_DIR"
echo "    Next:   quit and relaunch WezTerm so JetBrainsMono Nerd Font picks up; confirm Starship glyphs render."
