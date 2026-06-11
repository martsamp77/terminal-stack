#!/usr/bin/env bash
# render-command-reference.sh — regenerate the .txt and .html twins of the two
# command-reference markdown sources, so the same content can be opened as a
# webpage (browser), plain text (console), or markdown (Obsidian, `ref`):
#
#   command-reference.md.tmpl    → command-reference.txt.tmpl
#                                → command-reference.html.tmpl
#   windows/command-reference.md → windows/command-reference.txt
#                                → windows/command-reference.html
#
# It also regenerates the committed per-OS previews under
# docs/command-reference/ — the *final* post-template content each platform
# receives, browsable in-repo (see docs/command-reference/README.md):
#
#   linux/command-reference.{md,txt,html}    .chezmoi.os = "linux" (≡ WSL)
#   macos/command-reference.{md,txt,html}    .chezmoi.os = "darwin"
#   windows/command-reference.{md,txt,html}  byte-copies of windows/*
#
# The previews resolve the chezmoi conditionals with the embedded
# resolve_template awk filter — a deliberate, minimal shadow of chezmoi that
# supports exactly the {{ if eq/ne .chezmoi.os "..." }} / {{ end }} forms the
# file uses and FAILS LOUDLY on anything else, so a new template construct
# can never produce silently-wrong previews.
#
# The .txt twin is a byte-identical copy of the markdown (markdown is already
# readable plain text, and a copy cannot drift in content). The .html twin is
# rendered by the embedded awk converter, which handles exactly the markdown
# subset these files use — h1/h2/h3, pipe tables with \| escapes, --- rules,
# > quotes, paragraphs, `code`, **bold**, *italic* — and passes chezmoi
# {{ ... }} template lines through verbatim so the per-OS sections still
# resolve at apply time. The .html head embeds a "source-sha256:" comment with
# the hash of the markdown source; freshness checks compare against it.
#
# The markdown is the only hand-edited source. Run this script after every
# edit and commit all four derived files; never edit a .txt/.html twin by
# hand. run_after_10-check-command-reference.sh (POSIX-side apply) and
# scripts/sync-windows.ps1 (Windows-native sync) warn when the twins are
# stale, but never auto-fix.
#
# Portability: POSIX awk only (works under gawk, mawk, BSD awk), bash, cmp.
#
# Usage:
#   scripts/render-command-reference.sh           # regenerate in place
#   scripts/render-command-reference.sh --check   # report stale twins, exit 1
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-render}"
case "$mode" in
  render|--check) ;;
  *) echo "usage: ${0##*/} [--check]" >&2; exit 2 ;;
esac

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{ print $1 }'
  else
    shasum -a 256 -- "$1" | awk '{ print $1 }'   # macOS
  fi
}

# Markdown-to-HTML-body converter for the command-reference subset.
# Single-quoted on purpose: the program must contain no apostrophes.
MD2HTML='
BEGIN { SEP1 = sprintf("%c", 1) }   # placeholder protecting \| during cell splits

function esc(s) {
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  return s
}

# Bold then italic on an already-escaped, non-code text segment.
function span(s,  out) {
  out = ""
  while (match(s, /\*\*[^*]+\*\*/)) {
    out = out substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>"
    s = substr(s, RSTART + RLENGTH)
  }
  s = out s
  out = ""
  while (match(s, /\*[^*]+\*/)) {
    out = out substr(s, 1, RSTART - 1) "<em>" substr(s, RSTART + 1, RLENGTH - 2) "</em>"
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}

# Inline markdown: escape, then split on backticks — even segments are code
# spans (verbatim), odd segments get bold/italic treatment.
function inline(s,  n, parts, i, out) {
  s = esc(s)
  n = split(s, parts, /`/)
  out = ""
  for (i = 1; i <= n; i++) {
    if (i % 2 == 0) out = out "<code>" parts[i] "</code>"
    else out = out span(parts[i])
  }
  return out
}

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# Split a |-delimited row into cells, honoring \| escapes. Returns the field
# count; cells[1] (and cells[n] when the row ends with |) are the empty ends.
function row_cells(row, cells,  tmp, n, i) {
  tmp = row
  gsub(/\\\|/, SEP1, tmp)
  n = split(tmp, cells, /\|/)
  for (i = 1; i <= n; i++) {
    gsub(SEP1, "|", cells[i])
    cells[i] = trim(cells[i])
  }
  return n
}

function is_sep_row(row,  c, n, last, i) {
  n = row_cells(row, c)
  if (n < 3) return 0
  last = (c[n] == "") ? n - 1 : n
  for (i = 2; i <= last; i++) if (c[i] !~ /^:?-+:?$/) return 0
  return 1
}

function emit_row(row, tag,  c, n, last, i, out) {
  n = row_cells(row, c)
  last = (c[n] == "") ? n - 1 : n
  out = "  <tr>"
  for (i = 2; i <= last; i++) out = out "<" tag ">" inline(c[i]) "</" tag ">"
  print out "</tr>"
}

function flush_para(  i, out) {
  if (pn == 0) return
  out = inline(para[1])
  for (i = 2; i <= pn; i++) out = out "\n" inline(para[i])
  print "<p>" out "</p>"
  pn = 0
}

function flush_bq(  i, out) {
  if (bn == 0) return
  out = inline(bq[1])
  for (i = 2; i <= bn; i++) out = out "\n" inline(bq[i])
  print "<blockquote><p>" out "</p></blockquote>"
  bn = 0
}

function flush_table(  i, start) {
  if (tn == 0) return
  print "<table>"
  start = 1
  if (tn >= 2 && is_sep_row(trows[2])) {
    print " <thead>"
    emit_row(trows[1], "th")
    print " </thead>"
    start = 3
  }
  print " <tbody>"
  for (i = start; i <= tn; i++) if (!is_sep_row(trows[i])) emit_row(trows[i], "td")
  print " </tbody>"
  print "</table>"
  tn = 0
}

function flush_all() { flush_para(); flush_bq(); flush_table() }

{
  line = $0
  sub(/\r$/, "", line)

  # chezmoi template directives pass through verbatim (and close any open block
  # first — in the source a {{ if }} can directly follow a table row).
  if (line ~ /^[ \t]*[{][{].*[}][}][ \t]*$/) { flush_all(); print line; next }

  if (line ~ /^\|/) { flush_para(); flush_bq(); trows[++tn] = line; next }
  flush_table()

  if (line ~ /^[ \t]*$/)     { flush_all(); next }
  if (line ~ /^### /)        { flush_all(); print "<h3>" inline(substr(line, 5)) "</h3>"; next }
  if (line ~ /^## /)         { flush_all(); print "<h2>" inline(substr(line, 4)) "</h2>"; next }
  if (line ~ /^# /)          { flush_all(); print "<h1>" inline(substr(line, 3)) "</h1>"; next }
  if (line ~ /^---+[ \t]*$/) { flush_all(); print "<hr>"; next }
  if (line ~ /^>/)           { flush_para(); sub(/^> ?/, "", line); bq[++bn] = line; next }

  para[++pn] = line
}
END { flush_all() }
'

# Minimal chezmoi-template resolver for the per-OS previews. Supports exactly
# the directive forms command-reference.md.tmpl uses, each on its own line:
#   {{ if eq .chezmoi.os "<os>" }} / {{ if ne .chezmoi.os "<os>" }} / {{ end }}
# Output matches Go text/template line behavior: a true block keeps its body
# and turns each directive line into a blank line; a false block collapses
# entirely (if-line through end-line) to a single blank line. Any other
# {{ ... }} construct is a hard error — extend this resolver before extending
# the template. Single-quoted on purpose: no apostrophes inside.
RESOLVE_OS='
function fail(msg, l) {
  printf "resolve_template: %s: %s\n", msg, l > "/dev/stderr"
  bad = 1
  exit 1
}
{
  line = $0
  sub(/\r$/, "", line)
  if (line !~ /[{][{]/) {
    if (!in_block || keep) out[++on] = line
    next
  }
  if (line ~ /^[ \t]*[{][{] end [}][}][ \t]*$/) {
    if (!in_block) fail("unexpected {{ end }}", line)
    out[++on] = ""
    in_block = 0
    keep = 0
    next
  }
  if (line ~ /^[ \t]*[{][{] if (eq|ne) \.chezmoi\.os "[a-z]+" [}][}][ \t]*$/) {
    if (in_block) fail("nested {{ if }} not supported", line)
    split(line, q, "\"")
    if (line ~ / if eq /) keep = (os == q[2]); else keep = (os != q[2])
    in_block = 1
    if (keep) out[++on] = ""
    next
  }
  fail("unsupported template construct", line)
}
END {
  if (bad) exit 1
  if (in_block) {
    printf "resolve_template: unterminated {{ if }} block\n" > "/dev/stderr"
    exit 1
  }
  # Buffered so the last record can match the source byte-for-byte: a source
  # with no final newline (a directive emits nothing there in Go templates)
  # must not gain one from awk print.
  for (i = 1; i < on; i++) print out[i]
  if (on > 0) {
    if (nofinalnl) printf "%s", out[on]
    else print out[on]
  }
}
'

resolve_template() {  # $1 = template file, $2 = os value; resolved markdown on stdout
  local nofinal=0
  [ -n "$(tail -c 1 "$1")" ] && nofinal=1
  awk -v os="$2" -v nofinalnl="$nofinal" "$RESOLVE_OS" "$1"
}

emit_html() {  # $1 = markdown source, $2 = display name for the head comment
  local src="$1" display="$2" title hash
  title="$(awk '/^# / { sub(/^# /, ""); print; exit }' "$src")"
  title="$(printf '%s' "$title" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  hash="$(hash_file "$src")"
  cat <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<!-- Generated from $display by scripts/render-command-reference.sh - do not edit by hand. -->
<!-- source-sha256: $hash -->
<style>
:root { color-scheme: light dark; }
body {
  margin: 0;
  font: 16px/1.55 system-ui, "Segoe UI", sans-serif;
  background: #ffffff;
  color: #1f2328;
}
main { max-width: 60rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
h1 { font-size: 1.65rem; margin: 0 0 1rem; padding-bottom: .4rem; border-bottom: 2px solid #d0d7de; }
h2 { font-size: 1.25rem; margin: 2rem 0 .6rem; padding-bottom: .25rem; border-bottom: 1px solid #d0d7de; }
h3 { font-size: 1.05rem; margin: 1.4rem 0 .5rem; }
p { margin: .6rem 0; }
code {
  font-family: ui-monospace, "Cascadia Mono", Consolas, "JetBrains Mono", monospace;
  font-size: .92em;
  background: #eff1f3;
  padding: .1em .35em;
  border-radius: 4px;
}
table { border-collapse: collapse; width: 100%; margin: .8rem 0 1.2rem; }
th, td { border: 1px solid #d0d7de; padding: .35rem .6rem; text-align: left; vertical-align: top; }
th { background: #f6f8fa; }
tbody tr:nth-child(even) { background: #fafbfc; }
blockquote { margin: .8rem 0; padding: .05rem 1rem; border-left: 4px solid #d0d7de; color: #59636e; }
hr { border: 0; border-top: 1px solid #d0d7de; margin: 2rem 0; }
@media (prefers-color-scheme: dark) {
  body { background: #0d1117; color: #e6edf3; }
  h1, h2, hr { border-color: #30363d; }
  code { background: #21262d; }
  th, td { border-color: #30363d; }
  th { background: #161b22; }
  tbody tr:nth-child(even) { background: #131920; }
  blockquote { border-color: #30363d; color: #9198a1; }
}
</style>
</head>
<body>
<main>
EOF
  awk "$MD2HTML" "$src"
  cat <<'EOF'
</main>
</body>
</html>
EOF
}

stale=0
install_or_check() {  # $1 = tmp file holding fresh content, $2 = destination
  local new="$1" dst="$2" rel="${2#"$repo_root"/}"
  if [ "$mode" = "--check" ]; then
    if [ ! -f "$dst" ] || ! cmp -s -- "$new" "$dst"; then
      echo "stale: $rel" >&2
      stale=1
    fi
    return 0
  fi
  if [ -f "$dst" ] && cmp -s -- "$new" "$dst"; then
    echo "unchanged  $rel"
  else
    cp -- "$new" "$dst"
    echo "rendered   $rel"
  fi
}

tmp="$(mktemp)"
resolved="$(mktemp)"
trap 'rm -f "$tmp" "$resolved"' EXIT

render_set() {  # $1 = markdown source, $2 = txt twin, $3 = html twin
  install_or_check "$1" "$2"
  emit_html "$1" "$(basename "$1")" > "$tmp"
  install_or_check "$tmp" "$3"
}

render_set "$repo_root/command-reference.md.tmpl" \
           "$repo_root/command-reference.txt.tmpl" \
           "$repo_root/command-reference.html.tmpl"
render_set "$repo_root/windows/command-reference.md" \
           "$repo_root/windows/command-reference.txt" \
           "$repo_root/windows/command-reference.html"

# Per-OS previews: the final post-template content, committed for in-repo
# browsing. docs/command-reference/README.md documents the folder.
preview_dir="$repo_root/docs/command-reference"

render_preview() {  # $1 = .chezmoi.os value, $2 = preview subfolder
  local dir="$preview_dir/$2"
  [ "$mode" = "--check" ] || mkdir -p -- "$dir"
  resolve_template "$repo_root/command-reference.md.tmpl" "$1" > "$resolved"
  install_or_check "$resolved" "$dir/command-reference.md"
  install_or_check "$resolved" "$dir/command-reference.txt"
  emit_html "$resolved" "command-reference.md.tmpl (resolved for $1)" > "$tmp"
  install_or_check "$tmp" "$dir/command-reference.html"
}

render_preview linux  linux   # byte-identical for WSL and native Linux
render_preview darwin macos

# Windows needs no resolution — previews are byte-copies of the source and
# its committed twins (regenerated just above, so always current here).
[ "$mode" = "--check" ] || mkdir -p -- "$preview_dir/windows"
for ext in md txt html; do
  install_or_check "$repo_root/windows/command-reference.$ext" \
                   "$preview_dir/windows/command-reference.$ext"
done

if [ "$mode" = "--check" ] && [ "$stale" -ne 0 ]; then
  echo "regenerate with: bash scripts/render-command-reference.sh (then commit)" >&2
  exit 1
fi
