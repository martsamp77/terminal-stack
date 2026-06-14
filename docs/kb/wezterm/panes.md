# WezTerm — pane management

Leader: **Ctrl+Space** — tap, release, then press the next key within 1.5s.
"`Ctrl+Space` `h`" means leader **then** `h`.

## Split — local
| Key | Action |
|---|---|
| `Ctrl+Space` `h` | split down (new pane below, stacked) |
| `Ctrl+Space` `v` | split right (new pane to the side) |

## Split — into a domain
Shift = "remote": fuzzy-pick a domain (local, WSL, `SSH:*`…), then split it.

| Key | Action |
|---|---|
| `Ctrl+Space` `H` | pick domain → split down |
| `Ctrl+Space` `V` | pick domain → split right |

## Navigate / resize
Resize uses the uppercase key (hold Shift), 5-unit steps.

| Move | Resize |
|---|---|
| `Ctrl+Space` `j` left | `Ctrl+Space` `J` expand left |
| `Ctrl+Space` `k` right | `Ctrl+Space` `K` expand right |
| `Ctrl+Space` `i` up | `Ctrl+Space` `I` expand up |
| `Ctrl+Space` `m` down | `Ctrl+Space` `M` expand down |

## Zoom, pop & close
| Key | Action |
|---|---|
| `Ctrl+Space` `z` | toggle zoom (fill window; again to restore) |
| `Ctrl+Space` `o` | pop pane into its own window |
| `Ctrl+Shift+O` | pop to window (no leader) |
| `Ctrl+Space` `x` | close pane (confirms first) |

## Grid — 3 across × 2 down
`F1`–`F6` (also `Ctrl+Space` `1`–`6`): press to **build** that cell, or **focus** it if it already exists; `Shift+F#` opens the new cell in a domain. `F1` also maximizes the window. Columns fill to even thirds, rows to even halves as you build.

> macOS: free `Ctrl+Space` and the F-row from the OS first — see `doc macos/wezterm`.
