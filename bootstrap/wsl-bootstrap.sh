#!/usr/bin/env bash
# wsl-bootstrap.sh — install WSL/Linux-side prerequisites for the terminal-stack.
# Idempotent: re-run safely.
# See ../INSTALL.md § Scripted for context.

set -euo pipefail

# shellcheck source=_common-debian.sh
. "$(dirname -- "$0")/_common-debian.sh"

common_require_non_root

echo "$INFO Terminal stack WSL bootstrap"
echo "    Detected: user $USER, home $HOME"

common_install_all

# Resolve the Windows username (used by run_after_90-sync-windows.sh to target
# /mnt/c/Users/<user>/). Try WSL interop first, then prompt for confirmation.
detect_win_user() {
    if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
        /mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true
    fi
}

DETECTED_WIN_USER="$(detect_win_user)"
echo ""
# Honor WIN_USER from env (set by install-wsl.sh wrapper for non-interactive curl|bash flow);
# only prompt when running interactively from a clone.
if [ -z "${WIN_USER:-}" ]; then
    if [ -n "$DETECTED_WIN_USER" ]; then
        printf "Windows username for /mnt/c/Users/<user>/ [%s]: " "$DETECTED_WIN_USER"
    else
        printf "Windows username for /mnt/c/Users/<user>/: "
    fi
    read -r WIN_USER
    WIN_USER="${WIN_USER:-$DETECTED_WIN_USER}"
else
    echo "$INFO WIN_USER=$WIN_USER (from env; skipping prompt)"
fi

if [ -z "$WIN_USER" ]; then
    echo "$WARN No Windows username provided. The sync hook will retry detection at apply time."
fi

# chezmoi.toml — point sourceDir at this repo and persist windowsUsername under [data].
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
