#!/usr/bin/env bash
# linux-bootstrap.sh — install native-Linux prerequisites for the terminal-stack.
# Targets Debian/Ubuntu-family distros. Idempotent: re-run safely.
# See ../INSTALL.md § Linux for context.
#
# Difference vs wsl-bootstrap.sh: no Windows-username prompt, default SOURCE_DIR
# points at ~/code/terminal-stack instead of /mnt/c/DATA/Workspace/terminal-stack.
# The post-apply hook (run_after_90-sync-windows.sh) self-no-ops when /mnt/c/Users/
# is absent, so no extra gating is required here.

set -euo pipefail

# shellcheck source=_common-debian.sh
. "$(dirname -- "$0")/_common-debian.sh"

common_require_non_root

echo "$INFO Terminal stack Linux bootstrap"
echo "    Detected: user $USER, home $HOME"

common_install_all

# chezmoi.toml — point sourceDir at this repo. No windowsUsername on native Linux.
SOURCE_DIR="${SOURCE_DIR:-$HOME/code/terminal-stack}"
TOML="$HOME/.config/chezmoi/chezmoi.toml"
mkdir -p "$(dirname "$TOML")"

if [ ! -f "$TOML" ]; then
    if [ -d "$SOURCE_DIR" ]; then
        echo "$INFO Writing $TOML"
        printf 'sourceDir = "%s"\n' "$SOURCE_DIR" > "$TOML"
    else
        echo "$WARN $SOURCE_DIR not found; skipping chezmoi.toml. Set SOURCE_DIR env var and re-run, or edit manually."
    fi
else
    echo "$INFO $TOML already exists; not overwriting sourceDir."
fi

echo ""
echo "$INFO Linux bootstrap done."
echo "    Next: ~/.local/bin/chezmoi apply -v"
echo "    See INSTALL.md § Linux for the full sequence."
