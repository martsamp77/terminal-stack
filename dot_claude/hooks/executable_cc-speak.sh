#!/usr/bin/env bash
# cc-speak.sh — Claude Code TTS hook. Delegates to cc-tts-notify.sh.
# Usage: cc-speak.sh <waiting|error> [override-text]
set -euo pipefail
state="${1:-}"
case "$state" in waiting|error) ;; *) exit 0 ;; esac
export CC_TTS_SOURCE=claude
exec "$(dirname "$0")/cc-tts-notify.sh" "$state" "${2:-}"
