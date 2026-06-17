#!/usr/bin/env bash
# cc-speak.sh — Claude Code TTS hook (Kokoro / Chatterbox / edge-tts).
# Async by default; set CC_TTS_FOREGROUND=1 for ts-config tts test (blocking).
# Usage: cc-speak.sh <waiting|error> [override-text]

state="${1:-}"
override_text="${2:-}"
[ -z "$WEZTERM_PANE" ] && exit 0
case "$state" in waiting|error) ;; *) exit 0 ;; esac

CONFIG="${HOME}/.claude/tts.json"
[ -f "$CONFIG" ] || exit 0

# ── JSON helpers (jq → python3 → grep fallback) ───────────────────────────────
_cc_json() {
    local key="$1" default="${2:-}"
    if command -v jq >/dev/null 2>&1; then
        jq -r "$key // empty" "$CONFIG" 2>/dev/null || echo "$default"
        return
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$CONFIG" "$key" "$default" <<'PY' 2>/dev/null || echo "$default"
import json, sys
path, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path) as f:
        d = json.load(f)
    for part in key.strip('.').split('.'):
        if isinstance(d, dict):
            d = d.get(part)
        else:
            d = None
            break
    if d is None:
        print(default)
    elif isinstance(d, bool):
        print('true' if d else 'false')
    else:
        print(d)
except Exception:
    print(default)
PY
        return
    fi
    case "$key" in
        .enabled) grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$CONFIG" && echo true || echo false ;;
        *) echo "$default" ;;
    esac
}

_cc_json_events_has() {
    local ev="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -e --arg e "$ev" '.events | index($e) != null' "$CONFIG" >/dev/null 2>&1
        return $?
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$CONFIG" "$ev" <<'PY' >/dev/null 2>&1
import json, sys
with open(sys.argv[1]) as f:
    evs = json.load(f).get('events', [])
sys.exit(0 if sys.argv[2] in evs else 1)
PY
        return $?
    fi
    grep -q "\"$ev\"" "$CONFIG" 2>/dev/null
}

enabled="$(_cc_json .enabled false)"
[ "$enabled" = true ] || exit 0
_cc_json_events_has "$state" || exit 0

# ── Resolve spoken text ────────────────────────────────────────────────────────
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project="$(basename "$project_dir")"
max_chars="$(_cc_json .maxChars 120)"
message_mode="$(_cc_json .messageMode template)"

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
        elif command -v python3 >/dev/null 2>&1 && [ -n "$hook_json" ]; then
            text="$(printf '%s' "$hook_json" | python3 - <<'PY' 2>/dev/null || true
import json, sys
def texts(obj, out):
    if isinstance(obj, dict):
        role = obj.get("role") or obj.get("type")
        if role == "assistant":
            c = obj.get("content") or obj.get("message")
            if isinstance(c, str) and c.strip():
                out.append(c.strip())
            elif isinstance(c, list):
                for p in c:
                    if isinstance(p, dict) and p.get("type") == "text" and p.get("text"):
                        out.append(str(p["text"]).strip())
        for v in obj.values():
            texts(v, out)
    elif isinstance(obj, list):
        for v in obj:
            texts(v, out)
try:
    data = json.load(sys.stdin)
    found = []
    texts(data, found)
    print(found[-1] if found else "")
except Exception:
    print("")
PY
)"
        else
            text=""
        fi
        if [ -z "$text" ]; then
            message_mode=template
        fi
    fi
    if [ "$message_mode" = template ] || [ -z "${text:-}" ]; then
        tpl="$(_cc_json ".templates.$state" "")"
        text="${tpl//\{project\}/$project}"
    fi
    text="${text//$'\n'/ }"
    text="${text//$'\r'/ }"
    if [ "${#text}" -gt "$max_chars" ]; then
        text="${text:0:max_chars}"
    fi
    printf '%s' "$text"
}

text="$(resolve_text)"
[ -n "$text" ] || exit 0

# ── Debounce (skip in foreground test) ─────────────────────────────────────────
debounce="$(_cc_json .debounceSec 5)"
cache_dir="${HOME}/.cache/terminal-stack"
debounce_file="${cache_dir}/cc-tts.last"
lock_file="${cache_dir}/cc-tts.play.lock"
mkdir -p "$cache_dir" 2>/dev/null || true

if [ -z "${CC_TTS_FOREGROUND:-}" ]; then
    now=$(date +%s 2>/dev/null || echo 0)
    if [ -f "$debounce_file" ]; then
        last=$(cat "$debounce_file" 2>/dev/null || echo 0)
        if [ "$((now - last))" -lt "$debounce" ] 2>/dev/null; then
            exit 0
        fi
    fi
    echo "$now" > "$debounce_file" 2>/dev/null || true
fi

# ── Temp output path (WSL → Windows Temp for playback) ─────────────────────────
_cc_temp_media() {
    local ext="${1:-mp3}" base
    if [ -d /mnt/c/Users ] && command -v cmd.exe >/dev/null 2>&1; then
        local winuser
        winuser="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')"
        if [ -n "$winuser" ] && [ -d "/mnt/c/Users/$winuser/AppData/Local/Temp" ]; then
            base="/mnt/c/Users/$winuser/AppData/Local/Temp/cc-tts-$$"
            printf '%s.%s' "$base" "$ext"
            return
        fi
    fi
    mktemp "${TMPDIR:-/tmp}/cc-tts.XXXXXX.${ext}" 2>/dev/null || echo "/tmp/cc-tts-$$.${ext}"
}

# ── Synthesis ──────────────────────────────────────────────────────────────────
_synth_kokoro() {
    local text="$1" out="$2"
    local url voice speed fmt timeout payload
    url="$(_cc_json .kokoro.url 'http://127.0.0.1:8880')"
    voice="$(_cc_json .kokoro.voice am_adam)"
    speed="$(_cc_json .kokoro.speed 1.0)"
    fmt="$(_cc_json .kokoro.format mp3)"
    timeout="$(_cc_json .kokoro.timeoutSec 15)"
    if command -v jq >/dev/null 2>&1; then
        payload="$(jq -n --arg t "$text" --arg v "$voice" --arg f "$fmt" --argjson s "$speed" \
            '{model:"kokoro",input:$t,voice:$v,response_format:$f,speed:$s}')"
    else
        payload="$(python3 - "$text" "$voice" "$fmt" "$speed" <<'PY'
import json, sys
print(json.dumps({"model":"kokoro","input":sys.argv[1],"voice":sys.argv[2],
                  "response_format":sys.argv[3],"speed":float(sys.argv[4])}))
PY
)"
    fi
    curl -sf --max-time "$timeout" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "${url%/}/v1/audio/speech" -o "$out" 2>/dev/null
}

_synth_chatterbox() {
    local text="$1" out="$2"
    local url voice energy cfg temp timeout exag payload
    url="$(_cc_json .chatterbox.url 'http://127.0.0.1:8881')"
    voice="$(_cc_json .chatterbox.voice adam)"
    energy="$(_cc_json .chatterbox.energy 0.25)"
    cfg="$(_cc_json .chatterbox.cfgWeight 0.5)"
    temp="$(_cc_json .chatterbox.temperature 0.6)"
    timeout="$(_cc_json .chatterbox.timeoutSec 60)"
    exag="$(awk -v e="$energy" 'BEGIN { printf "%.2f", 0.25 + e + 0 }')"
    if command -v jq >/dev/null 2>&1; then
        payload="$(jq -n --arg t "$text" --arg v "$voice" \
            --argjson ex "$exag" --argjson cw "$cfg" --argjson tp "$temp" \
            '{input:$t,voice:$v,exaggeration:$ex,cfg_weight:$cw,temperature:$tp}')"
    else
        payload="$(python3 - "$text" "$voice" "$exag" "$cfg" "$temp" <<'PY'
import json, sys
print(json.dumps({"input":sys.argv[1],"voice":sys.argv[2],
                  "exaggeration":float(sys.argv[3]),"cfg_weight":float(sys.argv[4]),
                  "temperature":float(sys.argv[5])}))
PY
)"
    fi
    curl -sf --max-time "$timeout" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "${url%/}/v1/audio/speech" -o "$out" 2>/dev/null
}

_synth_edge() {
    local text="$1" out="$2"
    local voice
    edge_enabled="$(_cc_json .edge.enabled true)"
    [ "$edge_enabled" = true ] || return 1
    voice="$(_cc_json .edge.voice en-US-AndrewMultilingualNeural)"
    command -v edge-tts >/dev/null 2>&1 || return 1
    edge-tts --voice "$voice" --text "$text" --write-media "$out" >/dev/null 2>&1
}

_synth_chain() {
    local text="$1" out="$2" engine ok=1
    engine="$(_cc_json .engine kokoro)"
    case "$engine" in
        kokoro)
            _synth_kokoro "$text" "$out" && ok=0
            ;;
        chatterbox)
            _synth_chatterbox "$text" "$out" && ok=0
            ;;
        auto)
            _synth_kokoro "$text" "$out" && ok=0
            if [ "$ok" -ne 0 ]; then
                _synth_chatterbox "$text" "$out" && ok=0
            fi
            ;;
    esac
    if [ "$ok" -ne 0 ]; then
        _synth_edge "$text" "$out" && ok=0
    elif [ "$engine" = auto ]; then
        # Primary succeeded; no edge fallback unless primary failed
        :
    fi
    return "$ok"
}

# ── Playback ───────────────────────────────────────────────────────────────────
_play_media() {
    local path="$1" player
    player="$(_cc_json .player auto)"
    # WSL / Linux with Windows interop — route audio to Windows headphones.
    if [ "$player" = windows ] || { [ "$player" = auto ] && [ -d /mnt/c/Users ] && command -v pwsh.exe >/dev/null 2>&1; }; then
        local winuser play_ps1=""
        if command -v cmd.exe >/dev/null 2>&1; then
            winuser="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')"
        fi
        if [ -n "$winuser" ] && [ -f "/mnt/c/Users/$winuser/.claude/hooks/cc-speak-play.ps1" ]; then
            play_ps1="/mnt/c/Users/$winuser/.claude/hooks/cc-speak-play.ps1"
        elif [ -f "${HOME}/.claude/hooks/cc-speak-play.ps1" ]; then
            play_ps1="${HOME}/.claude/hooks/cc-speak-play.ps1"
        fi
        if [ -n "$play_ps1" ]; then
            pwsh.exe -NoLogo -NonInteractive -ExecutionPolicy Bypass \
                -File "$play_ps1" -MediaPath "$path" 2>/dev/null && return 0
        fi
    fi
    if command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -hide_banner -loglevel quiet "$path" 2>/dev/null && return 0
    elif command -v ffplay.exe >/dev/null 2>&1; then
        ffplay.exe -nodisp -autoexit -hide_banner -loglevel quiet "$path" 2>/dev/null && return 0
    fi
    if [ "$(uname -s 2>/dev/null)" = Darwin ] && command -v afplay >/dev/null 2>&1; then
        afplay "$path" 2>/dev/null && return 0
    fi
    return 1
}

_worker() {
    local text="$1" out ext ok=1
    ext="$(_cc_json .kokoro.format mp3)"
    out="$(_cc_temp_media "$ext")"
    [ -n "$out" ] || return 1
    if _synth_chain "$text" "$out"; then
        ok=0
    fi
    if [ "$ok" -eq 0 ] && [ -s "$out" ]; then
        # Single-player lock — wait briefly if another speak is playing.
        local i=0
        while [ -f "$lock_file" ] && [ "$i" -lt 30 ]; do
            sleep 0.2
            i=$((i + 1))
        done
        : > "$lock_file" 2>/dev/null || true
        _play_media "$out" || true
        rm -f "$lock_file" 2>/dev/null || true
    fi
    rm -f "$out" 2>/dev/null || true
}

if [ -n "${CC_TTS_FOREGROUND:-}" ]; then
    _worker "$text"
    exit 0
fi

( _worker "$text" ) >/dev/null 2>&1 &
exit 0
