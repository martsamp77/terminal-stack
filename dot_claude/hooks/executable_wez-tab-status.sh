#!/usr/bin/env bash
state="${1:-}"
[ -z "$WEZTERM_PANE" ] && exit 0
case "$state" in
    thinking) glyph='⏳' ;;
    working)  glyph='⚙'  ;;
    waiting)  glyph='✓'  ;;
    error)    glyph='✗'  ;;
    *) exit 0 ;;
esac
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project=$(basename "$project_dir")
# wezterm on Mac/native-Linux; wezterm.exe via interop on WSL.
if command -v wezterm >/dev/null 2>&1; then
    wezterm cli set-tab-title "cc $glyph $project" 2>/dev/null || true
elif command -v wezterm.exe >/dev/null 2>&1; then
    wezterm.exe cli set-tab-title "cc $glyph $project" 2>/dev/null || true
fi

# ── Per-pane background tint by Claude state (OSC 11; this pane only) ─────────
# Each WezTerm pane is its own terminal, so OSC 11 colours only THIS pane. Written
# to the controlling TTY (the hook's stdout is captured by Claude Code); DCS-wrapped
# for tmux passthrough (needs allow-passthrough on). Catppuccin-accent dark tints —
# tune the hexes to taste. Reset to base happens in the cc() wrapper on exit.
case "$state" in
    thinking|working) _bg='#2a2420' ;;   # warm/peach — working
    waiting)          _bg='#1f2a20' ;;   # green — your turn / done
    error)            _bg='#2e1e24' ;;   # red — failed / needs attention
    *)                _bg='' ;;
esac
if [ -n "$_bg" ]; then
    _seq=$(printf '\033]11;%s\007' "$_bg")
    [ -n "$TMUX" ] && _seq=$(printf '\033Ptmux;\033%s\033\\' "$_seq")
    printf '%s' "$_seq" > /dev/tty 2>/dev/null || true
fi

# ── Per-pane Claude state as a WezTerm user var (read by format-tab-title) ───
# OSC 1337 SetUserVar (base64). `wezterm cli set-user-var` doesn't exist in this
# build, so emit the escape to the pane TTY (DCS-wrapped under tmux). Cleared by
# the cc() wrapper on exit.
case "$state" in
    thinking|working) _cc='working' ;;
    waiting)          _cc='done' ;;
    error)            _cc='error' ;;
    *)                _cc='' ;;
esac
_uv=$(printf '\033]1337;SetUserVar=cc_state=%s\007' "$(printf '%s' "$_cc" | base64 | tr -d '\n')")
[ -n "$TMUX" ] && _uv=$(printf '\033Ptmux;\033%s\033\\' "$_uv")
printf '%s' "$_uv" > /dev/tty 2>/dev/null || true

# Toast notification — fires for 'waiting' (done) and 'error' if sentinel file exists.
# Toggle: ccnotify on / ccnotify off
if [ "$state" = "waiting" ] || [ "$state" = "error" ]; then
    if [ -f "$HOME/.claude/.toast-notify" ]; then
        _msg="Done: $project"
        [ "$state" = "error" ] && _msg="Error: $project"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Claude Code" "$_msg" 2>/dev/null || true
        elif command -v osascript >/dev/null 2>&1; then
            osascript -e "display notification \"$_msg\" with title \"Claude Code\"" 2>/dev/null || true
        fi
    fi
fi
