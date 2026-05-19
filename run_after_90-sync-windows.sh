#!/usr/bin/env bash
# Sync $CHEZMOI_SOURCE_DIR/windows/ to /mnt/c/Users/<windowsUsername>/, mirroring relative paths.
#
# Username resolution order:
#   1. chezmoi data: `windowsUsername` under the [data] section of chezmoi.toml
#   2. Fallback: `cmd.exe /c echo %USERNAME%` via WSL interop
#
# Files ending in `.tmpl` are rendered before copy: occurrences of `__WIN_USER__`
# are replaced with the resolved username, and the `.tmpl` suffix is stripped on
# the destination path.
#
# Idempotent: only writes targets whose content differs.
# Backs up any pre-existing target to <path>.bak.YYYYMMDD[.N] before overwrite.
set -euo pipefail

src_dir="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/windows"

if [ ! -d "$src_dir" ]; then
  exit 0
fi

resolve_win_user() {
  local cz=""
  if command -v chezmoi >/dev/null 2>&1; then
    cz="chezmoi"
  elif [ -x "$HOME/.local/bin/chezmoi" ]; then
    cz="$HOME/.local/bin/chezmoi"
  elif [ -x /usr/local/bin/chezmoi ]; then
    cz="/usr/local/bin/chezmoi"
  fi

  if [ -n "$cz" ]; then
    local u
    u=$("$cz" execute-template '{{ if hasKey . "windowsUsername" }}{{ .windowsUsername }}{{ end }}' 2>/dev/null || true)
    if [ -n "$u" ]; then echo "$u"; return 0; fi
  fi

  if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
    local u
    u=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true)
    if [ -n "$u" ]; then echo "$u"; return 0; fi
  fi

  return 1
}

WIN_USER="$(resolve_win_user || true)"
if [ -z "$WIN_USER" ]; then
  echo "sync-windows: could not resolve Windows username." >&2
  echo "  Add to ~/.config/chezmoi/chezmoi.toml:" >&2
  echo "    [data]" >&2
  echo "    windowsUsername = \"<your-windows-username>\"" >&2
  exit 1
fi

dst_dir="/mnt/c/Users/$WIN_USER"
if [ ! -d "$dst_dir" ]; then
  # Non-WSL host or non-existent user dir; noop cleanly.
  exit 0
fi

today="$(date +%Y%m%d)"
created=0
updated=0
unchanged=0

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

while IFS= read -r -d '' src; do
  rel="${src#"$src_dir"/}"

  if [[ "$rel" == *.tmpl ]]; then
    rel_out="${rel%.tmpl}"
    sed "s|__WIN_USER__|$WIN_USER|g" "$src" > "$rendered"
    effective_src="$rendered"
  else
    rel_out="$rel"
    effective_src="$src"
  fi

  dst="$dst_dir/$rel_out"

  if [ -e "$dst" ]; then
    if cmp -s "$effective_src" "$dst"; then
      unchanged=$((unchanged + 1))
      continue
    fi
    bak="$dst.bak.$today"
    if [ -e "$bak" ]; then
      n=1
      while [ -e "$dst.bak.$today.$n" ]; do n=$((n + 1)); done
      bak="$dst.bak.$today.$n"
    fi
    cp -p -- "$dst" "$bak"
    cp -- "$effective_src" "$dst"
    updated=$((updated + 1))
    printf 'updated  %s  (backup: %s)\n' "$dst" "$bak"
  else
    mkdir -p -- "$(dirname -- "$dst")"
    cp -- "$effective_src" "$dst"
    created=$((created + 1))
    printf 'created  %s\n' "$dst"
  fi
done < <(find "$src_dir" -type f -print0)

printf 'sync-windows: user=%s, %d created, %d updated, %d unchanged\n' "$WIN_USER" "$created" "$updated" "$unchanged"
