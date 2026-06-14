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
    eza zoxide fzf bat git-delta ripgrep micro glow neovim \
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

# 3b. Zed (cask) — GUI editor.
if ! brew list --cask zed >/dev/null 2>&1; then
    echo "$INFO Installing Zed cask"
    brew install --cask zed
else
    echo "$INFO Zed cask already installed"
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

# 8. Git include — stack aliases + delta config (file lands via chezmoi apply;
# git silently skips missing include files, so ordering is safe).
GIT_INC="$HOME/.config/git/terminal-stack.gitconfig"
if git config --global --get-all include.path 2>/dev/null | grep -qF "terminal-stack.gitconfig"; then
    echo "$INFO git include.path already set"
else
    echo "$INFO Adding git include.path -> $GIT_INC"
    git config --global --add include.path "$GIT_INC"
fi

# 9. Workspace directory for ws/wsp/wspu. Same contract as the Debian-family
# bootstraps: $WORKSPACE_DIR env skips the prompt; the /dev/tty read survives
# curl|bash; the answer persists to ~/.zshrc.local only when it differs from
# the autodetect (the shell-side _ts_workspace() covers the detected case).
WS_DETECTED=""
for d in "$HOME/Documents/Workspace" "$HOME/workspace" "$HOME/Workspace"; do
    [ -d "$d" ] && { WS_DETECTED="$d"; break; }
done
WS_CHOICE="${WORKSPACE_DIR:-}"
if [ -n "$WS_CHOICE" ]; then
    echo "$INFO WORKSPACE_DIR=$WS_CHOICE (from env; skipping prompt)"
else
    if { printf 'Workspace directory [%s]: ' "${WS_DETECTED:-none}" > /dev/tty \
         && read -r WS_CHOICE < /dev/tty; } 2>/dev/null; then :; else WS_CHOICE=""; fi
    WS_CHOICE="${WS_CHOICE:-$WS_DETECTED}"
fi
if [ -z "$WS_CHOICE" ]; then
    echo "$WARN No workspace directory found or chosen."
    echo "    Set one later: export WORKSPACE_DIR=... in ~/.zshrc.local"
elif [ "$WS_CHOICE" = "$WS_DETECTED" ]; then
    echo "$INFO Workspace: $WS_CHOICE (autodetected; no override needed)"
else
    [ -d "$WS_CHOICE" ] || echo "$WARN $WS_CHOICE does not exist (yet) — ws will warn until it does."
    RC="$HOME/.zshrc.local"
    if [ -f "$RC" ] && grep -q '^export WORKSPACE_DIR=' "$RC"; then
        # BSD sed needs the empty '' backup arg.
        sed -i '' "s|^export WORKSPACE_DIR=.*|export WORKSPACE_DIR=\"$WS_CHOICE\"|" "$RC"
        echo "$INFO Updated WORKSPACE_DIR in $RC"
    else
        printf 'export WORKSPACE_DIR="%s"\n' "$WS_CHOICE" >> "$RC"
        echo "$INFO Wrote WORKSPACE_DIR=$WS_CHOICE to $RC"
    fi
fi

# 10. Optional extras (opt-in): tldr + lazydocker via brew. TS_EXTRA_TOOLS=1
# or answer y at the prompt.
EXTRA_ANSWER="${TS_EXTRA_TOOLS:-}"
if [ -z "$EXTRA_ANSWER" ]; then
    if { printf 'Install extra tools (tldr, lazydocker)? [y/N]: ' > /dev/tty \
         && read -r EXTRA_ANSWER < /dev/tty; } 2>/dev/null; then :; else EXTRA_ANSWER=""; fi
fi
case "$EXTRA_ANSWER" in
    1|y|Y|yes|YES)
        echo "$INFO Installing extra tools (tldr, lazydocker)"
        brew install tldr lazydocker
        ;;
    *) echo "$INFO Skipping extra tools (TS_EXTRA_TOOLS=1 to enable)" ;;
esac

echo ""
echo "$INFO macOS bootstrap done."
echo "    Next: chezmoi apply -v"
echo "    macOS skips the windows/** subtree automatically (no /mnt/c/Users/<user>)."
