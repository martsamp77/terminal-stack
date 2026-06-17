#!/usr/bin/env bash
# cc-tts-test.sh — end-to-end TTS test (synth + play). No WezTerm / hook guards.
# Usage: cc-tts-test.sh ["optional phrase"]
set -euo pipefail
LIB="$(dirname "$0")/cc-tts-lib.sh"
# shellcheck source=cc-tts-lib.sh
. "$LIB"

phrase="${1:-Terminal stack TTS test.}"
export CC_TTS_VERBOSE=1

echo "cc-tts-test: config $CONFIG" >&2
[ -f "$CONFIG" ] || { echo "cc-tts-test: run chezmoi apply first" >&2; exit 1; }

kurl="$(cc_tts_json .kokoro.url 'http://127.0.0.1:8880')"
if curl -sf --max-time 2 "${kurl%/}/health" >/dev/null 2>&1; then
    echo "cc-tts-test: kokoro up ($kurl)" >&2
else
    echo "cc-tts-test: kokoro not reachable at $kurl" >&2
fi

if [ -d /mnt/c/Users ]; then
    if command -v ffplay.exe >/dev/null 2>&1; then
        echo "cc-tts-test: player ffplay.exe (Windows audio)" >&2
    elif play_ps1="$(cc_tts_win_play_ps1)" && [ -n "$play_ps1" ]; then
        echo "cc-tts-test: player pwsh $play_ps1" >&2
    else
        echo "cc-tts-test: WSL — install Windows ffplay or sync cc-tts-play.ps1" >&2
    fi
fi

out="$(cc_tts_temp_media "$(cc_tts_json .kokoro.format mp3)")"
trap 'rm -f "$out" 2>/dev/null || true' EXIT

echo "cc-tts-test: synthesizing…" >&2
cc_tts_synth "$phrase" "$out" || { echo "cc-tts-test: synthesis failed" >&2; exit 1; }
echo "cc-tts-test: wrote $out ($(wc -c < "$out") bytes)" >&2

echo "cc-tts-test: playing…" >&2
cc_tts_play "$out" || { echo "cc-tts-test: playback failed" >&2; exit 1; }
echo "cc-tts-test: done." >&2
