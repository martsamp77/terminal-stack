#!/usr/bin/env bash
# cc-speak.sh — Claude Code TTS hook (WezTerm only). Delegates to cc-tts-notify.sh.
# Usage: cc-speak.sh <waiting|error> [override-text]
set -euo pipefail
state="${1:-}"
[ -z "$WEZTERM_PANE" ] && exit 0
case "$state" in waiting|error) ;; *) exit 0 ;; esac
exec "$(dirname "$0")/cc-tts-notify.sh" "$state" "${2:-}"
