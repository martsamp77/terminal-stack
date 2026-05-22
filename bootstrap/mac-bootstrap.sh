#!/usr/bin/env bash
# mac-bootstrap.sh — install macOS-side prerequisites for the terminal-stack.
# Targets macOS (Apple Silicon or Intel) via Homebrew. Idempotent: re-run safely.
# See ../INSTALL.md § macOS for the full sequence.
#
# macOS skips the windows/** subtree automatically (no /mnt/c/Users/<user>): the
# post-apply hook (run_after_90-sync-windows.sh) self-no-ops when that path is absent.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(uname -s)" != "Darwin" ]; then
    echo "$WARN This script is for macOS. Detected: $(uname -s). Aborting."
    exit 1
fi

echo "$INFO Terminal stack macOS bootstrap"
echo "    Detected: user $USER, home $HOME, arch $(uname -m)"

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "$INFO Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "$INFO Homebrew already installed"
fi

# Make brew available for the rest of the script (path varies by Apple Silicon vs Intel)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 2. Core packages via brew
echo "$INFO Installing brew formulae and casks"
brew install \
    zsh git tmux \
    eza zoxide fzf bat git-delta ripgrep \
    starship chezmoi

# 3. WezTerm (cask) — nightly, matching the Windows side.
# The plain `wezterm` cask is pinned to the stale 20240203 stable; this stack
# expects a current build (see INSTALL.md Phase 0).
if ! brew list --cask wezterm@nightly >/dev/null 2>&1; then
    echo "$INFO Installing WezTerm nightly cask"
    brew install --cask wezterm@nightly
else
    echo "$INFO WezTerm nightly cask already installed"
fi

# 4. JetBrainsMono Nerd Font (cask)
# Font casks moved into homebrew/cask in 2024; the old homebrew/cask-fonts tap is gone.
if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    echo "$INFO Installing JetBrainsMono Nerd Font cask"
    brew install --cask font-jetbrains-mono-nerd-font
else
    echo "$INFO JetBrainsMono Nerd Font cask already installed"
fi

# 5. oh-my-zsh (unattended) — same as WSL path
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "$INFO Installing oh-my-zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        >/dev/null
else
    echo "$INFO oh-my-zsh already present"
fi

# 6. Login shell -> zsh (macOS ships with zsh by default since Catalina, but check anyway)
current_shell="$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')"
brew_zsh="$(brew --prefix)/bin/zsh"
if [ "$current_shell" != "$brew_zsh" ] && [ "$current_shell" != "/bin/zsh" ]; then
    echo "$INFO chsh login shell -> $brew_zsh"
    # Add brew zsh to /etc/shells if not present
    if ! grep -qFx "$brew_zsh" /etc/shells; then
        echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$brew_zsh"
else
    echo "$INFO Login shell already zsh"
fi

# 7. chezmoi.toml — point sourceDir at this repo.
# Default: the repo this script lives in (bootstrap/ is one level below the root).
# Override by exporting SOURCE_DIR before running.
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
TOML="$HOME/.config/chezmoi/chezmoi.toml"
if [ ! -f "$TOML" ]; then
    if [ -d "$SOURCE_DIR" ]; then
        echo "$INFO Writing $TOML with sourceDir=$SOURCE_DIR"
        mkdir -p "$(dirname "$TOML")"
        printf 'sourceDir = "%s"\n' "$SOURCE_DIR" > "$TOML"
    else
        echo "$WARN $SOURCE_DIR not found; set SOURCE_DIR and re-run, or edit $TOML manually."
    fi
else
    echo "$INFO $TOML already exists; not overwriting sourceDir."
fi

echo ""
echo "$INFO macOS bootstrap done."
echo "    Next: chezmoi apply -v"
echo "    macOS skips the windows/** subtree automatically (no /mnt/c/Users/<user>)."
