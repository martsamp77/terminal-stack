#!/usr/bin/env bash
# Sync $CHEZMOI_SOURCE_DIR/windows/ to /mnt/c/Users/msampson/, mirroring relative paths.
# Idempotent: only writes targets whose content differs.
# Backs up any pre-existing target to <path>.bak.YYYYMMDD before overwrite.
set -euo pipefail

src_dir="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/windows"
dst_dir="/mnt/c/Users/msampson"

if [ ! -d "$src_dir" ]; then
  exit 0
fi

today="$(date +%Y%m%d)"
created=0
updated=0
unchanged=0

while IFS= read -r -d '' src; do
  rel="${src#"$src_dir"/}"
  dst="$dst_dir/$rel"

  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
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
    cp -- "$src" "$dst"
    updated=$((updated + 1))
    printf 'updated  %s  (backup: %s)\n' "$dst" "$bak"
  else
    mkdir -p -- "$(dirname -- "$dst")"
    cp -- "$src" "$dst"
    created=$((created + 1))
    printf 'created  %s\n' "$dst"
  fi
done < <(find "$src_dir" -type f -print0)

printf 'sync-windows: %d created, %d updated, %d unchanged\n' "$created" "$updated" "$unchanged"
