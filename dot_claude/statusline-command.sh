#!/usr/bin/env bash
# Claude Code statusLine command — three-line, cross-platform (bash + python3).
# Receives session JSON on stdin. Writes three coloured lines to stdout.
#
# Line 1: <cwd> | <branch> <✓|●> [↑N][↓N] | <owner/repo>
# Line 2: <model> | ctx: <pct>% <bar> | <used_k>/<total_M> tokens
# Line 3: <user@host> | 5h: <pct>% • 7d: <pct>% | cost: $X.XX | +N/-M lines | Nm

raw=$(cat)

# ── Python detection ─────────────────────────────────────────────────────────
# python3 on Linux/Mac; python on Windows (where python3 may be the App Store stub).
_py=""
if python3 -c "import sys" >/dev/null 2>&1; then _py=python3
elif python  -c "import sys" >/dev/null 2>&1; then _py=python
fi

# json_get <dot.path> — portable, no jq required.
json_get() {
    [ -z "$_py" ] && { printf ''; return; }
    printf '%s' "$raw" | "$_py" -c "
import json,sys
try:
    v=json.load(sys.stdin)
    for k in '$1'.split('.'):
        v=v.get(k) if isinstance(v,dict) else None
        if v is None: break
    print('' if v is None else v)
except: print('')
" 2>/dev/null
}

# ── Extract JSON fields ───────────────────────────────────────────────────────
cwd=$(json_get cwd)
[ -z "$cwd" ] && cwd=$(json_get workspace.current_dir)
[ -z "$cwd" ] && cwd="$PWD"

model=$(json_get model.display_name)

ctx_window=$(json_get context_window.context_window_size)
ctx_used_pct=$(json_get context_window.used_percentage)
ctx_total_tok=$(json_get context_window.total_input_tokens)

cost_usd=$(json_get cost.total_cost_usd)
lines_added=$(json_get cost.total_lines_added)
lines_removed=$(json_get cost.total_lines_removed)
duration_ms=$(json_get cost.total_duration_ms)

five_hr_pct=$(json_get rate_limits.five_hour.used_percentage)
seven_day_pct=$(json_get rate_limits.seven_day.used_percentage)

repo_owner=$(json_get workspace.repo.owner)
repo_name=$(json_get workspace.repo.name)

# ── Git: branch + dirty + ahead/behind ───────────────────────────────────────
branch=""; git_sym=""; git_extra=""
if command -v git &>/dev/null && [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -n "$branch" ]; then
        porcelain=$(git -C "$cwd" status --porcelain=v2 --branch 2>/dev/null || true)
        if printf '%s\n' "$porcelain" | grep -qE '^[12u?]'; then
            git_sym="●"
        else
            git_sym="✓"
        fi
        # Parse "# branch.ab +N -M" — portable (no grep -P)
        ab=$(printf '%s\n' "$porcelain" | grep '^# branch.ab' | head -1)
        if [ -n "$ab" ]; then
            set -- $ab           # split on whitespace: $3=+N $4=-M
            ahead=${3#+}; behind=${4#-}
            [ "${ahead:-0}" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↑${ahead}"
            [ "${behind:-0}" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↓${behind}"
        fi
    fi
fi

# ── Context bar ───────────────────────────────────────────────────────────────
R=$'\033[0m'
ctx_str="?"
if [ -n "$ctx_used_pct" ] && [ "$ctx_used_pct" -ge 0 ] 2>/dev/null; then
    pct=$ctx_used_pct
    [ "$pct" -gt 100 ] && pct=100
    filled=$(( pct * 10 / 100 ))
    [ "$filled" -gt 10 ] && filled=10
    empty=$(( 10 - filled ))
    bar=""; i=0
    while [ $i -lt "$filled" ]; do bar="${bar}█"; i=$(( i+1 )); done
    i=0
    while [ $i -lt "$empty"  ]; do bar="${bar}░"; i=$(( i+1 )); done
    if   [ "$pct" -ge 90 ]; then c=$'\033[1;31m'
    elif [ "$pct" -ge 70 ]; then c=$'\033[1;33m'
    else                          c=$'\033[1;32m'
    fi
    ctx_str="${pct}% ${c}${bar}${R}"
fi

# ── Token display (e.g. 205k/1M tokens) ──────────────────────────────────────
token_str=""
if [ -n "$ctx_total_tok" ] && [ -n "$ctx_window" ] && [ "$ctx_window" -gt 0 ] 2>/dev/null; then
    used_k=$(( ctx_total_tok / 1000 ))
    if [ "$ctx_window" -ge 1000000 ] 2>/dev/null; then
        total_m=$(( ctx_window / 1000000 ))
        token_str="${used_k}k/${total_m}M tokens"
    else
        total_k=$(( ctx_window / 1000 ))
        token_str="${used_k}k/${total_k}k tokens"
    fi
fi

# ── Cost ──────────────────────────────────────────────────────────────────────
cost_str=""
if [ -n "$cost_usd" ] && [ -n "$_py" ]; then
    cost_str=$(printf '%s' "$cost_usd" | "$_py" -c "
import sys
try: print('\$%.2f' % float(sys.stdin.read().strip()))
except: print('')
" 2>/dev/null)
fi

# ── Lines delta ───────────────────────────────────────────────────────────────
lines_str=""
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
    lines_str="+${lines_added:-0}/-${lines_removed:-0} lines"
fi

# ── Session duration ──────────────────────────────────────────────────────────
dur_str=""
if [ -n "$duration_ms" ] && [ "$duration_ms" -gt 0 ] 2>/dev/null; then
    mins=$(( duration_ms / 60000 ))
    dur_str="${mins}m"
fi

# ── Rate limits ───────────────────────────────────────────────────────────────
limits_str=""
if [ -n "$five_hr_pct" ] && [ -n "$seven_day_pct" ]; then
    limits_str="5h: ${five_hr_pct}% • 7d: ${seven_day_pct}%"
fi

# ── Identity ──────────────────────────────────────────────────────────────────
host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "?")
user=$(whoami 2>/dev/null || id -un 2>/dev/null || echo "?")

# ── Assemble ──────────────────────────────────────────────────────────────────
SEP=" | "

line1="$cwd"
if [ -n "$branch" ]; then
    line1="${line1}${SEP}${branch} ${git_sym}${git_extra}"
fi
[ -n "$repo_owner" ] && [ -n "$repo_name" ] && line1="${line1}${SEP}${repo_owner}/${repo_name}"

line2="${model:-?}${SEP}ctx: ${ctx_str}"
[ -n "$token_str" ] && line2="${line2}${SEP}${token_str}"

line3="${user}@${host}"
[ -n "$limits_str" ] && line3="${line3}${SEP}${limits_str}"
[ -n "$cost_str"   ] && line3="${line3}${SEP}cost: ${cost_str}"
[ -n "$lines_str"  ] && line3="${line3}${SEP}${lines_str}"
[ -n "$dur_str"    ] && line3="${line3}${SEP}${dur_str}"

printf '%s\n%s\n%s\n' "$line1" "$line2" "$line3"
