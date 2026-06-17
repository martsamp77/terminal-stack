#!/usr/bin/env bash
# cc-speak.sh — Claude Code TTS hook. Async; synthesize + cc-tts-play.sh.
# Usage: cc-speak.sh <waiting|error> [override-text]
set -euo pipefail
LIB="$(dirname "$0")/cc-tts-lib.sh"
# shellcheck source=cc-tts-lib.sh
. "$LIB"

state="${1:-}"
override_text="${2:-}"
[ -z "$WEZTERM_PANE" ] && exit 0
case "$state" in waiting|error) ;; *) exit 0 ;; esac
[ -f "$CONFIG" ] || exit 0
[ "$(cc_tts_json .enabled false)" = true ] || exit 0

cc_tts_json_events_has() {
    local ev="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -e --arg e "$ev" '.events | index($e) != null' "$CONFIG" >/dev/null 2>&1
        return $?
    fi
    grep -q "\"$ev\"" "$CONFIG" 2>/dev/null
}
cc_tts_json_events_has "$state" || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project="$(basename "$project_dir")"
max_chars="$(cc_tts_json .maxChars 120)"
message_mode="$(cc_tts_json .messageMode template)"

resolve_text() {
    local tpl text hook_json
    if [ -n "$override_text" ]; then
        text="$override_text"
    elif [ "$message_mode" = hook ]; then
        hook_json="$(cat 2>/dev/null || true)"
        if command -v jq >/dev/null 2>&1 && [ -n "$hook_json" ]; then
            text="$(printf '%s' "$hook_json" | jq -r '
                [.. | objects
                 | select(.role? == "assistant" or .type? == "assistant")
                 | (.content // .message // empty)
                 | if type == "array" then
                     [ .[] | select(.type? == "text") | .text ] | join(" ")
                   elif type == "string" then .
                   else empty end
                ] | last // empty' 2>/dev/null || true)"
        fi
        [ -z "${text:-}" ] && message_mode=template
    fi
    if [ "$message_mode" = template ] || [ -z "${text:-}" ]; then
        tpl="$(cc_tts_json ".templates.$state" "")"
        text="${tpl//\{project\}/$project}"
    fi
    text="${text//$'\n'/ }"
    text="${text//$'\r'/ }"
    [ "${#text}" -gt "$max_chars" ] && text="${text:0:max_chars}"
    printf '%s' "$text"
}

text="$(resolve_text)"
[ -n "$text" ] || exit 0

cache_dir="${HOME}/.cache/terminal-stack"
debounce_file="${cache_dir}/cc-tts.last"
lock_file="${cache_dir}/cc-tts.play.lock"
mkdir -p "$cache_dir" 2>/dev/null || true

debounce="$(cc_tts_json .debounceSec 5)"
now=$(date +%s 2>/dev/null || echo 0)
if [ -f "$debounce_file" ]; then
    last=$(cat "$debounce_file" 2>/dev/null || echo 0)
    if [ "$((now - last))" -lt "$debounce" ] 2>/dev/null; then
        exit 0
    fi
fi
echo "$now" > "$debounce_file" 2>/dev/null || true

_hooks="$(dirname "$0")"
_worker() {
    local out ext ok=1
    ext="$(cc_tts_json .kokoro.format mp3)"
    out="$(cc_tts_temp_media "$ext")"
    [ -n "$out" ] || return 1
    cc_tts_synth "$text" "$out" && ok=0
    if [ "$ok" -eq 0 ] && [ -s "$out" ]; then
        local i=0
        while [ -f "$lock_file" ] && [ "$i" -lt 30 ]; do sleep 0.2; i=$((i + 1)); done
        : > "$lock_file" 2>/dev/null || true
        CC_TTS_CONFIG="$CONFIG" "$_hooks/cc-tts-play.sh" "$out" || true
        rm -f "$lock_file" 2>/dev/null || true
    fi
    rm -f "$out" 2>/dev/null || true
}

( _worker ) >/dev/null 2>&1 &
exit 0
