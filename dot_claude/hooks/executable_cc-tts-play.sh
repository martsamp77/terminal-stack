#!/usr/bin/env bash
# cc-tts-play.sh — play an audio file on the local audible device.
# WSL routes through Windows (ffplay.exe or cc-tts-play.ps1) so headphones work.
# Usage: cc-tts-play.sh <media-path>
set -euo pipefail
LIB="$(dirname "$0")/cc-tts-lib.sh"
# shellcheck source=cc-tts-lib.sh
. "$LIB"

path="${1:-}"
[ -n "$path" ] || { echo "usage: cc-tts-play.sh <media-path>" >&2; exit 2; }
[ -f "$CONFIG" ] || true

if cc_tts_play "$path"; then
    exit 0
fi
echo "cc-tts-play: no player worked for $path" >&2
echo "  WSL: winget install Gyan.FFmpeg  (ffplay.exe on Windows PATH)" >&2
echo "  or ensure ~/.claude/hooks/cc-tts-play.ps1 exists (chezmoi apply / sync)" >&2
exit 1
