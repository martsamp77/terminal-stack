#!/usr/bin/env bash
# cc-tts-synth.sh — synthesize speech to a file (Kokoro / Chatterbox / edge).
# Usage: cc-tts-synth.sh "<text>" [output-path]
set -euo pipefail
LIB="$(dirname "$0")/cc-tts-lib.sh"
# shellcheck source=cc-tts-lib.sh
. "$LIB"

text="${1:-}"
out="${2:-}"
[ -n "$text" ] || { echo "usage: cc-tts-synth.sh \"<text>\" [output-path]" >&2; exit 2; }
[ -f "$CONFIG" ] || { echo "cc-tts-synth: missing $CONFIG" >&2; exit 1; }

if [ -z "$out" ]; then
    out="$(cc_tts_temp_media "$(cc_tts_json .kokoro.format mp3)")"
fi

if cc_tts_synth "$text" "$out" && [ -s "$out" ]; then
    cc_tts_log "wrote $out ($(wc -c < "$out") bytes)"
    printf '%s\n' "$out"
    exit 0
fi
echo "cc-tts-synth: synthesis failed" >&2
exit 1
