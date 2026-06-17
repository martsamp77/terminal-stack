#!/usr/bin/env bash
# cursor-tts.sh — Cursor Agent stop hook → local Kokoro TTS (same config as Claude Code).
# Reads stop-event JSON from stdin; speaks on completed/error; returns {} immediately.
set -euo pipefail

input="$(cat 2>/dev/null || true)"
state=waiting

if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
    case "$(printf '%s' "$input" | jq -r '.status // "completed"')" in
        error)   state=error ;;
        aborted) printf '{}\n'; exit 0 ;;
        *)       state=waiting ;;
    esac
fi

notify="${HOME}/.claude/hooks/cc-tts-notify.sh"
if [ ! -f "$notify" ]; then
    printf '{}\n'
    exit 0
fi

export CC_TTS_HOOK_JSON="$input"
"$notify" "$state" &
printf '{}\n'
exit 0
