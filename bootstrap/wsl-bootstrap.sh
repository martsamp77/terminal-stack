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

# 8. Resolve the Windows username (used by run_after_90-sync-windows.sh to target
#    /mnt/c/Users/<user>/). Try WSL interop first, then prompt for confirmation.
detect_win_user() {
    if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
        /mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true
    fi
}

DETECTED_WIN_USER="$(detect_win_user)"
echo ""
if [ -n "$DETECTED_WIN_USER" ]; then
    printf "Windows username for /mnt/c/Users/<user>/ [%s]: " "$DETECTED_WIN_USER"
else
    printf "Windows username for /mnt/c/Users/<user>/: "
fi
read -r WIN_USER
WIN_USER="${WIN_USER:-$DETECTED_WIN_USER}"

if [ -z "$WIN_USER" ]; then
    echo "$WARN No Windows username provided. The sync hook will retry detection at apply time."
fi

# 9. chezmoi.toml — point sourceDir at this repo and persist windowsUsername under [data].
SOURCE_DIR="${SOURCE_DIR:-/mnt/c/DATA/Workspace/terminal-stack}"
TOML="$HOME/.config/chezmoi/chezmoi.toml"
mkdir -p "$(dirname "$TOML")"

if [ ! -f "$TOML" ]; then
    if [ -d "$SOURCE_DIR" ]; then
        echo "$INFO Writing $TOML"
        {
            printf 'sourceDir = "%s"\n' "$SOURCE_DIR"
            if [ -n "$WIN_USER" ]; then
                printf '\n[data]\nwindowsUsername = "%s"\n' "$WIN_USER"
            fi
        } > "$TOML"
    else
        echo "$WARN $SOURCE_DIR not found; skipping chezmoi.toml. Set SOURCE_DIR env var and re-run, or edit manually."
    fi
else
    echo "$INFO $TOML already exists; not overwriting sourceDir."
    if [ -n "$WIN_USER" ] && ! grep -q 'windowsUsername' "$TOML"; then
        if grep -q '^\[data\]' "$TOML"; then
            echo "$WARN $TOML has a [data] section but no windowsUsername key."
            echo "    Add manually under [data]:  windowsUsername = \"$WIN_USER\""
        else
            printf '\n[data]\nwindowsUsername = "%s"\n' "$WIN_USER" >> "$TOML"
            echo "$INFO Appended [data].windowsUsername = $WIN_USER to $TOML"
        fi
    fi
fi

echo ""
echo "$INFO WSL bootstrap done."
echo "    Next: ~/.local/bin/chezmoi apply -v"
echo "    See INSTALL.md § Scripted for the full sequence."
