#!/usr/bin/env bash
state="${1:-}"
[ -z "$WEZTERM_PANE" ] && exit 0
case "$state" in
    thinking) glyph='⏳' ;;
    waiting)  glyph='✓' ;;
    error)    glyph='✗' ;;
    *) exit 0 ;;
esac
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project=$(basename "$project_dir")
wezterm.exe cli set-tab-title "cc $glyph $project" 2>/dev/null || true
