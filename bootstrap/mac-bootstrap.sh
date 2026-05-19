#!/usr/bin/env bash
# mac-bootstrap.sh — install macOS-side prerequisites for the terminal-stack
#
# !! UNTESTED STUB !! - written 05/19/2026 alongside the Windows + WSL bootstrap scripts.
# Will be validated when the stack is first applied to the user's MacBook Pro M5 Pro.
# Treat the brew package IDs as the most likely culprits to need adjustment.
#
# Idempotent: re-run safely.
# See ../INSTALL.md § Scripted for context (Windows/WSL); macOS section is TODO.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(uname -s)" != "Darwin" ]; then
    echo "$WARN This script is for macOS. Detected: $(uname -s). Aborting."
    exit 1
fi

echo "$INFO Terminal stack macOS bootstrap (UNTESTED)"
echo "    Detected: user $USER, home $HOME"

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

# 3. WezTerm (cask)
if ! brew list --cask wezterm >/dev/null 2>&1; then
    echo "$INFO Installing WezTerm cask"
    brew install --cask wezterm
else
    echo "$INFO WezTerm cask already installed"
fi

# 4. JetBrainsMono Nerd Font (cask)
if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    echo "$INFO Installing JetBrainsMono Nerd Font cask"
    brew tap homebrew/cask-fonts 2>/dev/null || true
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

# 7. chezmoi.toml override
# On Mac, you'll clone the terminal-stack repo somewhere (e.g., ~/code/terminal-stack).
# Adjust SOURCE_DIR below to match where you put it.
SOURCE_DIR="$HOME/code/terminal-stack"
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    if [ -d "$SOURCE_DIR" ]; then
        echo "$INFO Writing ~/.config/chezmoi/chezmoi.toml with sourceDir=$SOURCE_DIR"
        mkdir -p "$HOME/.config/chezmoi"
        printf 'sourceDir = "%s"\n' "$SOURCE_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
    else
        echo "$WARN $SOURCE_DIR not found; clone the terminal-stack repo there, then re-run."
    fi
else
    echo "$INFO ~/.config/chezmoi/chezmoi.toml already exists; not overwriting"
fi

echo ""
echo "$INFO macOS bootstrap done (UNTESTED — please report any issues)."
echo "    Next: chezmoi apply -v"
echo "    macOS will skip the windows/** subtree automatically (no /mnt/c/Users/msampson)."
