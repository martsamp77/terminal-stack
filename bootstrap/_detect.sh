#!/usr/bin/env bash
# _detect.sh — environment detection for the POSIX bootstraps (headless vs GUI).
# Sourced by _common-debian.sh (WSL/Linux) and mac-bootstrap.sh after _config.sh
# and _wizard.sh (it uses ts_tty_prompt for the confirm prompt).
#
# A "headless" host is a server with no graphical session — typically reached
# over ssh/PuTTY. On such hosts the stack should NOT download the Nerd Font (no
# GUI terminal renders it) and should NOT ask the WezTerm leader-key question
# (WezTerm is a GUI app that isn't installed there). tmux/starship/zsh/CLI tools
# are still installed — those are the genuinely useful headless pieces.
#
# This file is sourced, not executed. Do not `exit`; return non-zero instead.

: "${INFO:=$'\033[1;34m==>\033[0m'}"
: "${WARN:=$'\033[1;33m!!\033[0m'}"

# Best-effort auto-detection. Returns 0 (headless) / 1 (graphical desktop).
_ts_headless_autodetect() {
    # WSL is never headless: it renders in a Windows GUI terminal (WezTerm /
    # Windows Terminal) on the Windows side, which needs the font there.
    if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        return 1
    fi
    # An X or Wayland display means a local graphical session.
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        return 1
    fi
    # macOS desktop always has a window server (Aqua); only headless when SSH'd
    # into a Mac with no console session — fall through to the SSH check.
    # An SSH session with no display is the canonical headless case.
    if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        return 0
    fi
    # systemd default target: multi-user → server, graphical → desktop.
    if command -v systemctl >/dev/null 2>&1; then
        case "$(systemctl get-default 2>/dev/null)" in
            multi-user.target|multi-user) return 0 ;;
            graphical.target|graphical)   return 1 ;;
        esac
    fi
    # macOS with a console but no SSH: treat as graphical.
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        return 1
    fi
    # No display, no SSH hint, no systemd answer: assume headless (server-class).
    return 0
}

# Resolve TS_HEADLESS_RESOLVED to 1 (headless) or 0 (graphical). Honors an
# explicit TS_HEADLESS env override; otherwise auto-detects.
ts_detect_headless() {
    case "${TS_HEADLESS:-}" in
        1|y|Y|yes|YES|true|TRUE)  TS_HEADLESS_RESOLVED=1; return 0 ;;
        0|n|N|no|NO|false|FALSE)  TS_HEADLESS_RESOLVED=0; return 0 ;;
    esac
    if _ts_headless_autodetect; then TS_HEADLESS_RESOLVED=1; else TS_HEADLESS_RESOLVED=0; fi
}

# True when the resolved environment is headless (detects lazily on first use).
ts_is_headless() {
    [ -n "${TS_HEADLESS_RESOLVED:-}" ] || ts_detect_headless
    [ "${TS_HEADLESS_RESOLVED:-0}" = "1" ]
}

# Print the detection and, unless forced via TS_HEADLESS, let the user flip it on
# the controlling terminal. Sets TS_HEADLESS_RESOLVED. Safe under curl|bash.
# Call this once, early in the bootstrap, before the font/wizard steps.
ts_confirm_headless() {
    ts_detect_headless
    local forced=0
    case "${TS_HEADLESS:-}" in ?*) forced=1 ;; esac

    if ts_is_headless; then
        echo "$INFO Environment: headless server (no graphical session detected)"
    else
        echo "$INFO Environment: graphical desktop"
    fi

    if [ "$forced" = "1" ]; then
        echo "$INFO (forced via TS_HEADLESS=$TS_HEADLESS)"
        return 0
    fi

    local ans
    if ts_is_headless; then
        echo "    Headless mode skips the Nerd Font download and the WezTerm leader-key prompt."
        ans="$(ts_tty_prompt 'Treat this as a headless server? [Y/n]: ')"
        case "$ans" in n|N|no|NO) TS_HEADLESS_RESOLVED=0; echo "$INFO Treating as a graphical desktop." ;; esac
    else
        ans="$(ts_tty_prompt 'Treat this as a headless server (skip font + WezTerm prompts)? [y/N]: ')"
        case "$ans" in y|Y|yes|YES) TS_HEADLESS_RESOLVED=1; echo "$INFO Treating as a headless server." ;; esac
    fi
}
