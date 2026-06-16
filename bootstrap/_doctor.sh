#!/usr/bin/env bash
# _doctor.sh — diagnose + repair the terminal-stack install. Sourced by the bash
# entry ts-doctor.sh, by the installers (post-apply health check), and by ts-update.
# Depends on _config.sh (sourceDir helpers) and _cleanup.sh (clone discovery).
#
# This file is sourced, not executed. Do not `exit`; return non-zero instead.

if ! command -v ts_chezmoi_bin >/dev/null 2>&1; then
    _ts_doctor_dir="$(dirname -- "${BASH_SOURCE[0]}")"
    # shellcheck source=_config.sh
    [ -f "$_ts_doctor_dir/_config.sh" ] && . "$_ts_doctor_dir/_config.sh"
fi
if ! command -v ts_find_old_clones >/dev/null 2>&1; then
    _ts_doctor_dir="$(dirname -- "${BASH_SOURCE[0]}")"
    # shellcheck source=_cleanup.sh
    [ -f "$_ts_doctor_dir/_cleanup.sh" ] && . "$_ts_doctor_dir/_cleanup.sh"
fi
: "${INFO:=$'\033[1;34m==>\033[0m'}"
: "${WARN:=$'\033[1;33m!!\033[0m'}"

# Diagnose. Prints a checklist; returns 0 when healthy, 1 when issues are found.
# Set TS_DOCTOR_QUIET=1 to suppress the per-check "ok" lines (warnings still show).
ts_doctor() {
    local issues=0 cz src others t
    local quiet="${TS_DOCTOR_QUIET:-}"
    _ok()  { [ "$quiet" = "1" ] || echo "  ok  $1"; }
    _bad() { echo "  $WARN $1"; issues=$((issues + 1)); }

    [ "$quiet" = "1" ] || echo "$INFO terminal-stack doctor"

    if ! cz="$(ts_chezmoi_bin)"; then
        _bad "chezmoi binary not found (~/.local/bin/chezmoi or PATH)"
        echo "$WARN $issues issue(s) found."; return 1
    fi
    _ok "chezmoi: $cz"

    src="$("$cz" source-path 2>/dev/null || true)"
    if [ -z "$src" ]; then
        _bad "chezmoi has no source dir (chezmoi.toml missing sourceDir)"
    elif [ ! -d "$src/.git" ]; then
        _bad "sourceDir '$src' is not a git clone"
    elif ! ts_is_stack_clone "$src"; then
        _bad "sourceDir '$src' is a git repo but not a terminal-stack clone"
    else
        _ok "sourceDir: $src"
    fi

    if [ -f "$HOME/.zshrc" ]; then
        if grep -q 'terminal-stack-zsh-start' "$HOME/.zshrc" 2>/dev/null; then
            _ok "~/.zshrc has the terminal-stack block"
        else
            _bad "~/.zshrc missing the terminal-stack block (stale or not applied)"
        fi
        if grep -q 'doc-start' "$HOME/.zshrc" 2>/dev/null; then
            _ok "~/.zshrc has the 'doc' command"
        else
            _bad "~/.zshrc has no 'doc' command (source may predate the doc feature)"
        fi
    else
        _bad "~/.zshrc not found (chezmoi apply not run yet?)"
    fi

    for t in zsh starship; do
        if command -v "$t" >/dev/null 2>&1; then _ok "$t on PATH"; else _bad "$t not on PATH"; fi
    done

    # Leftover clones are advisory, not a health failure — note them without
    # counting an issue, so a working install still reports "all checks passed".
    others="$(ts_find_old_clones "${src:-$HOME/code/terminal-stack}" 2>/dev/null)"
    if [ -n "$others" ]; then
        echo "  note: other terminal-stack clones present (ts-doctor --repair can clean them up):"
        echo "$others" | sed 's/^/        /'
    fi

    unset -f _ok _bad 2>/dev/null || true
    if [ "$issues" -eq 0 ]; then [ "$quiet" = "1" ] || echo "$INFO all checks passed."; return 0; fi
    echo "$WARN $issues issue(s) found — run 'ts-doctor --repair' to fix."
    return 1
}

# Repair. <desired-clone> (optional) is the clone that should be canonical; when
# omitted we keep the current valid sourceDir, else auto-pick the only clone found.
# Confirms before repointing/applying and before any cleanup.
ts_repair() {
    local desired="${1:-}" cz src ans
    cz="$(ts_chezmoi_bin)" || { echo "$WARN chezmoi not found; cannot repair."; return 1; }
    src="$("$cz" source-path 2>/dev/null || true)"

    if [ -z "$desired" ]; then
        if [ -n "$src" ] && ts_is_stack_clone "$src"; then
            desired="$src"
        else
            local found="" cnt=0 c
            while IFS= read -r c; do found="$c"; cnt=$((cnt + 1)); done < <(ts_find_old_clones "/nonexistent" 2>/dev/null)
            if [ "$cnt" -eq 1 ]; then desired="$found"
            elif [ "$cnt" -gt 1 ]; then
                echo "$WARN multiple clones found and none is active. Re-run the installer or set TERMINAL_STACK_DIR, then retry."
                ts_find_old_clones "/nonexistent" 2>/dev/null | sed 's/^/        /'
                return 1
            else
                echo "$WARN no terminal-stack clone found. Re-run the install one-liner."
                return 1
            fi
        fi
    fi

    if [ "$src" != "$desired" ]; then
        ans="$(ts_tty_prompt "Repoint chezmoi sourceDir from '${src:-<unset>}' to '$desired'? [Y/n]: ")"
        case "$ans" in
            n|N|no|NO) echo "$INFO left sourceDir unchanged." ;;
            *) ts_ensure_source_dir "$desired"
               echo "$INFO re-applying from $desired…"
               "$cz" apply && echo "$INFO chezmoi apply done — run 'exec zsh -l' to reload your shell." ;;
        esac
    else
        echo "$INFO sourceDir already correct ($desired)."
    fi

    ts_cleanup_menu "$desired"
}
