# WezTerm — pane management

Leader: **Ctrl+Space** — tap, release, then press the next key. It **waits** (no
timeout): the cursor turns peach and a `⌨ LEADER` badge shows; `Ctrl+Space` `Esc`
cancels. "`Ctrl+Space` `h`" means leader **then** `h`.

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

## Move / resize / rotate — repeatable modes
Arrows after the leader **enter a repeatable mode** (a coloured badge shows in the
right-status). Inside a mode, plain arrows **or** `j/k/i/m` keep going — no need to
re-press the leader.

| Enter | Mode | Repeat | Exit |
|---|---|---|---|
| `Ctrl+Space` `←/→/↑/↓` | **move** focus between panes | arrows or `j/k/i/m` | any other key · ~1s idle · `Esc` |
| `Ctrl+Space` `Shift+←/→/↑/↓` | **resize** (3 cells/press) | arrows (or `Shift+`) or `j/k/i/m` | `Esc` / `Enter` — **sticky**, stays until you exit |
| `Ctrl+Space` `Ctrl+←/→/↑/↓` | **rotate** panes through their slots (`←`/`↑` = counter-clockwise, `→`/`↓` = clockwise) | arrows or `j/k/i/m` | any other key · `Esc` |

e.g. `Ctrl+Space ← ← ←` moves focus left three panes; `Ctrl+Space Shift+→ → →`
grows the pane right 9 cells, then `Esc`.

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
