#!/usr/bin/env bash
# cc-tts-test.sh — end-to-end TTS test (synth + play). No WezTerm / hook guards.
# Usage: cc-tts-test.sh ["optional phrase"]
set -euo pipefail

phrase="${1:-Terminal stack TTS test.}"
notify="${HOME}/.claude/hooks/cc-tts-notify.sh"

echo "cc-tts-test: phrase=$phrase" >&2
[ -f "$notify" ] || { echo "cc-tts-test: $notify not found (chezmoi apply)" >&2; exit 1; }

export CC_TTS_VERBOSE=1
CC_TTS_FOREGROUND=1 "$notify" waiting "$phrase"
