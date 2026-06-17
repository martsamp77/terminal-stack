#!/usr/bin/env bash
# cc-tts-lib.sh — shared helpers for Claude Code TTS hooks (sourced, not executed).
CONFIG="${CC_TTS_CONFIG:-${HOME}/.claude/tts.json}"

cc_tts_json() {
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

cc_tts_log() {
    [ -n "${CC_TTS_VERBOSE:-}" ] && echo "cc-tts: $*" >&2
}

cc_tts_wsl_win_path() {
    local p="$1"
    if command -v wslpath >/dev/null 2>&1; then
        wslpath -w "$p" 2>/dev/null || printf '%s' "$p"
    else
        printf '%s' "$p"
    fi
}

cc_tts_temp_media() {
    local ext="${1:-mp3}"
    if [ -d /mnt/c/Users ] && command -v cmd.exe >/dev/null 2>&1; then
        local winuser
        winuser="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')"
        if [ -n "$winuser" ] && [ -d "/mnt/c/Users/$winuser/AppData/Local/Temp" ]; then
            printf '/mnt/c/Users/%s/AppData/Local/Temp/cc-tts-%s.%s' "$winuser" "$$" "$ext"
            return
        fi
    fi
    mktemp "${TMPDIR:-/tmp}/cc-tts.XXXXXX.${ext}" 2>/dev/null || echo "/tmp/cc-tts-$$.${ext}"
}

cc_tts_synth_kokoro() {
    local text="$1" out="$2"
    local url voice speed fmt timeout payload
    url="$(cc_tts_json .kokoro.url 'http://127.0.0.1:8880')"
    voice="$(cc_tts_json .kokoro.voice am_adam)"
    speed="$(cc_tts_json .kokoro.speed 1.0)"
    fmt="$(cc_tts_json .kokoro.format mp3)"
    timeout="$(cc_tts_json .kokoro.timeoutSec 15)"
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
        "${url%/}/v1/audio/speech" -o "$out"
}

cc_tts_synth_chatterbox() {
    local text="$1" out="$2"
    local url voice energy cfg temp timeout exag payload
    url="$(cc_tts_json .chatterbox.url 'http://127.0.0.1:8881')"
    voice="$(cc_tts_json .chatterbox.voice adam)"
    energy="$(cc_tts_json .chatterbox.energy 0.25)"
    cfg="$(cc_tts_json .chatterbox.cfgWeight 0.5)"
    temp="$(cc_tts_json .chatterbox.temperature 0.6)"
    timeout="$(cc_tts_json .chatterbox.timeoutSec 60)"
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
        "${url%/}/v1/audio/speech" -o "$out"
}

cc_tts_synth_edge() {
    local text="$1" out="$2" voice
    [ "$(cc_tts_json .edge.enabled true)" = true ] || return 1
    voice="$(cc_tts_json .edge.voice en-US-AndrewMultilingualNeural)"
    command -v edge-tts >/dev/null 2>&1 || return 1
    edge-tts --voice "$voice" --text "$text" --write-media "$out" >/dev/null 2>&1
}

cc_tts_synth() {
    local text="$1" out="$2" engine ok=1
    engine="$(cc_tts_json .engine kokoro)"
    case "$engine" in
        kokoro)     cc_tts_synth_kokoro "$text" "$out" && ok=0 ;;
        chatterbox) cc_tts_synth_chatterbox "$text" "$out" && ok=0 ;;
        auto)
            cc_tts_synth_kokoro "$text" "$out" && ok=0
            [ "$ok" -ne 0 ] && cc_tts_synth_chatterbox "$text" "$out" && ok=0
            ;;
    esac
    [ "$ok" -ne 0 ] && cc_tts_synth_edge "$text" "$out" && ok=0
    return "$ok"
}

cc_tts_win_play_ps1() {
    local winuser=""
    if command -v cmd.exe >/dev/null 2>&1; then
        winuser="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')"
    fi
    if [ -n "$winuser" ] && [ -f "/mnt/c/Users/$winuser/.claude/hooks/cc-tts-play.ps1" ]; then
        echo "/mnt/c/Users/$winuser/.claude/hooks/cc-tts-play.ps1"
    elif [ -f "${HOME}/.claude/hooks/cc-tts-play.ps1" ]; then
        echo "${HOME}/.claude/hooks/cc-tts-play.ps1"
    elif [ -n "$winuser" ] && [ -f "/mnt/c/Users/$winuser/.claude/hooks/cc-speak-play.ps1" ]; then
        echo "/mnt/c/Users/$winuser/.claude/hooks/cc-speak-play.ps1"
    fi
}

cc_tts_play() {
    local path="$1" player play_ps1
    [ -f "$path" ] && [ -s "$path" ] || return 1
    player="$(cc_tts_json .player auto)"

    # WSL: route to Windows speakers (same headphones as Hermes).
    if [ "$player" = windows ] || { [ "$player" = auto ] && [ -d /mnt/c/Users ]; }; then
        if command -v ffplay.exe >/dev/null 2>&1; then
            cc_tts_log "play ffplay.exe $(cc_tts_wsl_win_path "$path")"
            ffplay.exe -nodisp -autoexit -hide_banner -loglevel quiet "$(cc_tts_wsl_win_path "$path")" && return 0
        fi
        play_ps1="$(cc_tts_win_play_ps1)"
        if [ -n "$play_ps1" ] && command -v pwsh.exe >/dev/null 2>&1; then
            cc_tts_log "play pwsh $(cc_tts_wsl_win_path "$play_ps1")"
            pwsh.exe -NoLogo -NonInteractive -ExecutionPolicy Bypass \
                -File "$(cc_tts_wsl_win_path "$play_ps1")" \
                -MediaPath "$(cc_tts_wsl_win_path "$path")" && return 0
        fi
        if [ "$player" = auto ] && [ -d /mnt/c/Users ]; then
            cc_tts_log "WSL: no ffplay.exe or pwsh play script — install Gyan.FFmpeg on Windows"
        fi
    fi

    if [ "$(uname -s 2>/dev/null)" = Darwin ] && command -v afplay >/dev/null 2>&1; then
        cc_tts_log "play afplay $path"
        afplay "$path" && return 0
    fi
    if command -v ffplay >/dev/null 2>&1; then
        cc_tts_log "play ffplay $path"
        ffplay -nodisp -autoexit -hide_banner -loglevel quiet "$path" && return 0
    fi
    return 1
}
