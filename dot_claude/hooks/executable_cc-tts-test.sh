#!/usr/bin/env bash
# cc-tts-test.sh — end-to-end TTS test (synth + play).
# Usage: cc-tts-test.sh [--source claude|cursor|test] ["optional phrase"]
set -euo pipefail

source=test
phrase=""
while [ $# -gt 0 ]; do
    case "$1" in
        --source|-s)
            source="${2:-test}"
            shift 2
            ;;
        *)
            phrase="$1"
            shift
            ;;
    esac
done

notify="${HOME}/.claude/hooks/cc-tts-notify.sh"
LIB="${HOME}/.claude/hooks/cc-tts-lib.sh"
[ -f "$notify" ] || { echo "cc-tts-test: $notify not found (chezmoi apply)" >&2; exit 1; }
[ -f "$LIB" ] && . "$LIB"

if [ -z "$phrase" ] && [ -f "$LIB" ]; then
    cc_tts_init_config
    phrase="$(cc_tts_build_speech "$source" waiting "$(basename "${PWD}")" "")"
fi
[ -n "$phrase" ] || phrase="Terminal stack TTS test."

echo "cc-tts-test: source=$source phrase=$phrase" >&2
export CC_TTS_VERBOSE=1
export CC_TTS_SOURCE="$source"
CC_TTS_FOREGROUND=1 "$notify" waiting "$phrase"
