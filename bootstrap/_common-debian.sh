#!/usr/bin/env bash
# _common-debian.sh — shared installer steps for Debian/Ubuntu-family bootstraps.
# Sourced by wsl-bootstrap.sh (WSL Ubuntu) and linux-bootstrap.sh (native Debian/Ubuntu).
# Each function is idempotent; safe to re-source / re-run.
#
# This file is sourced, not executed. Do not `exit` here — return non-zero instead.

INFO=$'\033[1;34m==>\033[0m'
WARN=$'\033[1;33m!!\033[0m'

common_require_non_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "$WARN Don't run this as root. Run as your normal user; sudo will prompt as needed."
        return 1
    fi
}

common_apt_prereqs() {
    echo "$INFO Installing apt packages (zsh, git, curl, unzip, tmux, CLI tools, JetBrains Mono regular font)"
    sudo apt-get update -qq
    # Core packages — must be in apt on any supported Debian/Ubuntu.
    sudo apt-get install -y \
        zsh git curl unzip tmux \
        zoxide fzf bat ripgrep micro \
        fonts-jetbrains-mono fontconfig \
        >/dev/null
    # Optional — present on Ubuntu 23.10+, missing on 22.04 (jammy). Try, ignore failures;
    # common_install_optional_binaries fills the gap from upstream releases.
    sudo apt-get install -y eza git-delta >/dev/null 2>&1 || true
}

# Fetch the latest release tarball from a GitHub repo for the current arch and
# extract the named binary into ~/.local/bin. Skips if the binary is already on PATH.
# Usage: common_install_github_binary <repo> <binary-name> <asset-grep-pattern>
common_install_github_binary() {
    local repo="$1" bin_name="$2" asset_pattern="$3"
    if command -v "$bin_name" >/dev/null 2>&1; then
        echo "$INFO $bin_name already on PATH ($(command -v "$bin_name"))"
        return 0
    fi
    echo "$INFO Installing $bin_name from $repo (apt didn't have it)"
    mkdir -p "$HOME/.local/bin"
    local tmp_dir asset_url
    tmp_dir="$(mktemp -d)"
    asset_url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
        | cut -d'"' -f4 \
        | grep -E "$asset_pattern" \
        | head -n1)
    if [ -z "$asset_url" ]; then
        echo "$WARN Could not find asset matching '$asset_pattern' in latest $repo release."
        rm -rf "$tmp_dir"
        return 1
    fi
    local archive="$tmp_dir/$(basename "$asset_url")"
    curl -fL --silent --show-error -o "$archive" "$asset_url"
    case "$archive" in
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$tmp_dir" ;;
        *.zip)          unzip -q "$archive" -d "$tmp_dir" ;;
        *)              echo "$WARN Unsupported archive format: $archive"; rm -rf "$tmp_dir"; return 1 ;;
    esac
    local found
    found=$(find "$tmp_dir" -type f -name "$bin_name" -executable | head -n1)
    if [ -z "$found" ]; then
        # Some archives ship the binary not marked +x; try a non-executable match.
        found=$(find "$tmp_dir" -type f -name "$bin_name" | head -n1)
    fi
    if [ -z "$found" ]; then
        echo "$WARN Could not locate '$bin_name' inside extracted archive."
        rm -rf "$tmp_dir"
        return 1
    fi
    install -m 0755 "$found" "$HOME/.local/bin/$bin_name"
    rm -rf "$tmp_dir"
    echo "$INFO Installed ~/.local/bin/$bin_name"
}

# Install eza and git-delta from upstream releases if apt didn't provide them.
common_install_optional_binaries() {
    # eza: tar.gz with a single 'eza' binary at the root.
    common_install_github_binary "eza-community/eza" "eza" "eza_x86_64-unknown-linux-gnu\\.tar\\.gz$" || true
    # git-delta: ships as 'delta'. Asset name pattern: delta-<version>-x86_64-unknown-linux-gnu.tar.gz.
    common_install_github_binary "dandavison/delta" "delta" "delta-.*-x86_64-unknown-linux-gnu\\.tar\\.gz$" || true
}

common_bat_symlink() {
    mkdir -p "$HOME/.local/bin"
    if [ ! -e "$HOME/.local/bin/bat" ]; then
        echo "$INFO Symlinking ~/.local/bin/bat -> /usr/bin/batcat"
        ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    fi
}

common_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "$INFO Installing oh-my-zsh"
        RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            >/dev/null
    else
        echo "$INFO oh-my-zsh already present at ~/.oh-my-zsh"
    fi
}

common_login_shell_zsh() {
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$current_shell" != "/usr/bin/zsh" ] && [ "$current_shell" != "/bin/zsh" ]; then
        echo "$INFO chsh login shell -> /usr/bin/zsh"
        sudo chsh -s /usr/bin/zsh "$USER"
    else
        echo "$INFO Login shell already zsh"
    fi
}

common_chezmoi() {
    if [ ! -x "$HOME/.local/bin/chezmoi" ]; then
        echo "$INFO Installing chezmoi to ~/.local/bin"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" >/dev/null
    else
        echo "$INFO chezmoi already present at ~/.local/bin/chezmoi"
    fi
}

common_starship() {
    if ! command -v starship >/dev/null 2>&1; then
        echo "$INFO Installing Starship to /usr/local/bin"
        sudo curl -sS https://starship.rs/install.sh | sudo sh -s -- -y -b /usr/local/bin
    else
        echo "$INFO Starship already on PATH"
    fi
}

common_nerd_font_jetbrains() {
    if ! fc-list 2>/dev/null | grep -q "JetBrainsMono Nerd Font"; then
        echo "$INFO Downloading JetBrainsMono Nerd Font zip"
        mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
        local tmp_zip
        tmp_zip=$(mktemp /tmp/jbm-nf.XXXXXX.zip)
        curl -fL --silent --show-error \
            -o "$tmp_zip" \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
        # `-o` overwrites without prompting. Without it, a re-run where the
        # files already exist on disk (e.g. fontconfig lost them but the .ttf
        # files survived) prompts "replace ...? [y]es..." on stdin, which is
        # /dev/null under the curl|bash installer flow and aborts the unzip.
        unzip -qo "$tmp_zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/"
        rm -f "$tmp_zip"
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null
    else
        echo "$INFO JetBrainsMono Nerd Font already in fontconfig"
    fi
}

# Prompt helper for curl|bash flows: stdin is the script pipe, so read from
# /dev/tty instead. Falls back to the default (prints nothing) when there is
# no controlling terminal (CI, true non-interactive).
# Usage: common_tty_prompt "Question [default]: " → echoes the answer or "".
common_tty_prompt() {
    local answer=""
    if { printf '%s' "$1" > /dev/tty && read -r answer < /dev/tty; } 2>/dev/null; then
        echo "$answer"
    fi
}

# Workspace directory for the ws/wsp/wspu shell functions.
# $WORKSPACE_DIR env → use without prompting (scripted installs). Otherwise
# prompt on /dev/tty with the autodetected candidate as default. The answer is
# persisted to ~/.zshrc.local ONLY when it differs from the autodetect — the
# shell-side _ts_workspace() covers the detected case on its own.
common_workspace_config() {
    local detected="" d choice
    for d in /mnt/c/DATA/Workspace "$HOME/Documents/Workspace" \
             "$HOME/workspace" "$HOME/Workspace"; do
        [ -d "$d" ] && { detected="$d"; break; }
    done

    choice="${WORKSPACE_DIR:-}"
    if [ -n "$choice" ]; then
        echo "$INFO WORKSPACE_DIR=$choice (from env; skipping prompt)"
    else
        choice="$(common_tty_prompt "Workspace directory [${detected:-none}]: ")"
        choice="${choice:-$detected}"
    fi

    if [ -z "$choice" ]; then
        echo "$WARN No workspace directory found or chosen."
        echo "    Set one later: export WORKSPACE_DIR=... in ~/.zshrc.local"
        return 0
    fi
    [ -d "$choice" ] || echo "$WARN $choice does not exist (yet) — ws will warn until it does."

    if [ "$choice" = "$detected" ]; then
        echo "$INFO Workspace: $choice (autodetected; no override needed)"
        return 0
    fi

    local rc="$HOME/.zshrc.local"
    if [ -f "$rc" ] && grep -q '^export WORKSPACE_DIR=' "$rc"; then
        sed -i "s|^export WORKSPACE_DIR=.*|export WORKSPACE_DIR=\"$choice\"|" "$rc"
        echo "$INFO Updated WORKSPACE_DIR in $rc"
    else
        printf 'export WORKSPACE_DIR="%s"\n' "$choice" >> "$rc"
        echo "$INFO Wrote WORKSPACE_DIR=$choice to $rc"
    fi
}

# Hook the stack's git aliases + delta config into the global gitconfig.
# The included file lands via chezmoi apply (which runs after bootstrap);
# git silently skips missing include files, so ordering is safe.
common_git_include() {
    local inc="$HOME/.config/git/terminal-stack.gitconfig"
    if git config --global --get-all include.path 2>/dev/null | grep -qF "terminal-stack.gitconfig"; then
        echo "$INFO git include.path already set"
    else
        echo "$INFO Adding git include.path -> $inc"
        git config --global --add include.path "$inc"
    fi
}

# Optional extras, opt-in via TS_EXTRA_TOOLS=1 or the /dev/tty prompt:
# tldr always; nvtop only on GPU hosts; lazydocker only where docker exists.
common_install_extra_tools() {
    local answer="${TS_EXTRA_TOOLS:-}"
    if [ -z "$answer" ]; then
        answer="$(common_tty_prompt "Install extra tools (tldr, nvtop on GPU hosts, lazydocker with docker)? [y/N]: ")"
    fi
    case "$answer" in
        1|y|Y|yes|YES) ;;
        *) echo "$INFO Skipping extra tools (TS_EXTRA_TOOLS=1 to enable)"; return 0 ;;
    esac
    echo "$INFO Installing extra tools"
    sudo apt-get install -y tldr >/dev/null 2>&1 || echo "$WARN apt install tldr failed"
    if command -v nvidia-smi >/dev/null 2>&1; then
        sudo apt-get install -y nvtop >/dev/null 2>&1 || echo "$WARN apt install nvtop failed"
    fi
    if command -v docker >/dev/null 2>&1; then
        common_install_github_binary "jesseduffield/lazydocker" "lazydocker" "lazydocker_.*_Linux_x86_64\\.tar\\.gz$" || true
    fi
}

# Run all standard install steps in the order the original WSL bootstrap used.
common_install_all() {
    common_apt_prereqs
    common_install_optional_binaries
    common_bat_symlink
    common_oh_my_zsh
    common_login_shell_zsh
    common_chezmoi
    common_starship
    common_nerd_font_jetbrains
    common_git_include
    common_workspace_config
    common_install_extra_tools
}
