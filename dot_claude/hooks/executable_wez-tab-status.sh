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
