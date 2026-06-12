#!/usr/bin/env bash
# Claude Code statusLine command — two-line, cross-platform (bash + python3).
# Receives session JSON on stdin. Writes two coloured lines to stdout.
#
# Line 1: <cwd> | <branch> <●/✓> | <owner/repo>
# Line 2: <model> | ctx: <pct>% [████░░░░░░] | <user@host>

raw=$(cat)

# Detect Python: python3 on Linux/Mac; python on Windows (where python3 may be an
# unhelpful Microsoft Store stub). Both are Python 3 in practice.
_py=""
if python3 -c "import sys" >/dev/null 2>&1; then _py=python3
elif python  -c "import sys" >/dev/null 2>&1; then _py=python
fi

# json_get <dot.path> — pipes $raw through Python; no jq, no temp files.
# $1 is always a safe dot-path (e.g. model.display_name) so inlining it is fine.
json_get() {
    [ -z "$_py" ] && { echo ""; return; }
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

# ── JSON fields ───────────────────────────────────────────────────────────────
cwd=$(json_get workspace.current_dir)
[ -z "$cwd" ] && cwd=$(json_get cwd)
[ -z "$cwd" ] && cwd="$PWD"

model=$(json_get model.display_name)
ctx_window=$(json_get model.context_window)
in_tok=$(json_get stats.input_tokens)
out_tok=$(json_get stats.output_tokens)
cr_tok=$(json_get stats.cache_read_tokens)
cc_tok=$(json_get stats.cache_creation_tokens)
repo_owner=$(json_get workspace.repo.owner)
repo_name=$(json_get workspace.repo.name)

# ── Git branch + dirty status ─────────────────────────────────────────────────
branch=""
git_sym=""
if command -v git &>/dev/null && [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -n "$branch" ]; then
        if git -C "$cwd" status --porcelain 2>/dev/null | grep -q .; then
            git_sym="●"
        else
            git_sym="✓"
        fi
    fi
fi

# ── Context bar ───────────────────────────────────────────────────────────────
R=$'\033[0m'
ctx_str="?"
if [ -n "$ctx_window" ] && [ "$ctx_window" -gt 0 ] 2>/dev/null; then
    used=$(( ${in_tok:-0} + ${out_tok:-0} + ${cr_tok:-0} + ${cc_tok:-0} ))
    pct=$(( used * 100 / ctx_window ))
    [ "$pct" -gt 100 ] && pct=100
    filled=$(( pct * 10 / 100 ))
    [ "$filled" -gt 10 ] && filled=10
    empty=$(( 10 - filled ))
    bar=""
    i=0; while [ $i -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
    i=0; while [ $i -lt "$empty"  ]; do bar="${bar}░"; i=$(( i + 1 )); done
    if   [ "$pct" -ge 90 ]; then c=$'\033[1;31m'
    elif [ "$pct" -ge 70 ]; then c=$'\033[1;33m'
    else                          c=$'\033[1;32m'
    fi
    ctx_str="${pct}% ${c}[${bar}]${R}"
fi

# ── Hostname ──────────────────────────────────────────────────────────────────
host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "?")
user=$(whoami 2>/dev/null || id -un 2>/dev/null || echo "?")

# ── Assemble lines ────────────────────────────────────────────────────────────
SEP=" | "

line1="$cwd"
[ -n "$branch" ] && line1="${line1}${SEP}${branch} ${git_sym}"
[ -n "$repo_owner" ] && [ -n "$repo_name" ] && line1="${line1}${SEP}${repo_owner}/${repo_name}"

line2="${model:-?}${SEP}ctx: ${ctx_str}${SEP}${user}@${host}"

printf '%s\n%s\n' "$line1" "$line2"
