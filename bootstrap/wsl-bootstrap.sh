#!/usr/bin/env bash
# wsl-bootstrap.sh — install WSL/Linux-side prerequisites for the terminal-stack
# Idempotent: re-run safely.
# See ../INSTALL.md § Scripted for context.

set -euo pipefail

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

if [ "$(id -u)" -eq 0 ]; then
    echo "$WARN Don't run this as root. Run as your normal user; sudo will prompt as needed."
    exit 1
fi

echo "$INFO Terminal stack WSL bootstrap"
echo "    Detected: user $USER, home $HOME"

# 1. apt prerequisites (need sudo)
echo "$INFO Installing apt packages (zsh, git, curl, unzip, tmux, modern CLI tools, JetBrains Mono regular font)"
sudo apt-get update -qq
sudo apt-get install -y \
    zsh git curl unzip tmux \
    eza zoxide fzf bat git-delta ripgrep \
    fonts-jetbrains-mono \
    >/dev/null

# 2. bat symlink (apt installs as 'batcat')
mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/bat" ]; then
    echo "$INFO Symlinking ~/.local/bin/bat -> /usr/bin/batcat"
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
fi

# 3. oh-my-zsh (unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "$INFO Installing oh-my-zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        >/dev/null
else
    echo "$INFO oh-my-zsh already present at ~/.oh-my-zsh"
fi

# 4. Switch login shell to zsh (skip if already)
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "/usr/bin/zsh" ] && [ "$current_shell" != "/bin/zsh" ]; then
    echo "$INFO chsh login shell -> /usr/bin/zsh"
    sudo chsh -s /usr/bin/zsh "$USER"
else
    echo "$INFO Login shell already zsh"
fi

# 5. chezmoi
if [ ! -x "$HOME/.local/bin/chezmoi" ]; then
    echo "$INFO Installing chezmoi to ~/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" >/dev/null
else
    echo "$INFO chezmoi already present at ~/.local/bin/chezmoi"
fi

# 6. Starship
if ! command -v starship >/dev/null 2>&1; then
    echo "$INFO Installing Starship to /usr/local/bin"
    sudo curl -sS https://starship.rs/install.sh | sudo sh -s -- -y -b /usr/local/bin
else
    echo "$INFO Starship already on PATH"
fi

# 7. JetBrainsMono Nerd Font (user fonts dir)
if ! fc-list 2>/dev/null | grep -q "JetBrainsMono Nerd Font"; then
    echo "$INFO Downloading JetBrainsMono Nerd Font zip"
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    tmp_zip=$(mktemp /tmp/jbm-nf.XXXXXX.zip)
    curl -fL --silent --show-error \
        -o "$tmp_zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -q "$tmp_zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/"
    rm -f "$tmp_zip"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null
else
    echo "$INFO JetBrainsMono Nerd Font already in fontconfig"
fi

# 8. chezmoi.toml override pointing at this repo (only if not already set)
SOURCE_DIR="/mnt/c/DATA/Workspace/terminal-stack"
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    if [ -d "$SOURCE_DIR" ]; then
        echo "$INFO Writing ~/.config/chezmoi/chezmoi.toml with sourceDir=$SOURCE_DIR"
        mkdir -p "$HOME/.config/chezmoi"
        printf 'sourceDir = "%s"\n' "$SOURCE_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
    else
        echo "$WARN $SOURCE_DIR not found; skipping chezmoi.toml. Edit manually if needed."
    fi
else
    echo "$INFO ~/.config/chezmoi/chezmoi.toml already exists; not overwriting"
fi

echo ""
echo "$INFO WSL bootstrap done."
echo "    Next: ~/.local/bin/chezmoi apply -v"
echo "    See INSTALL.md § Scripted for the full sequence."
