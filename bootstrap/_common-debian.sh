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
        zoxide fzf bat ripgrep \
        fonts-jetbrains-mono \
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
        unzip -q "$tmp_zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/"
        rm -f "$tmp_zip"
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null
    else
        echo "$INFO JetBrainsMono Nerd Font already in fontconfig"
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
}
