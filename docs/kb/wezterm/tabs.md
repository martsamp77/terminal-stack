# WezTerm — tabs

Tab selection uses **Alt** (no leader needed).

## Select by number
The number matches the tab.

| Key | Tab |
|---|---|
| `Alt+1` … `Alt+9` | tab 1 … 9 |

## Cycle
| Key | Action |
|---|---|
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Ctrl+Space` `t` | **repeatable tab mode** — then `←`/`→` (or `j`/`k`, `n`/`p`) cycle tabs; `Esc` exits |

## Font size (repeatable)
`Ctrl+Space` `f` enters a font-size mode: `↑`/`↓` (or `k`/`j`) grow/shrink, `0` resets, `Esc` exits.

## Appearance
Each tab reads `<number>: <dir>` and tints **green** when Claude is done, **red** on error. The top-right shows the active workspace + current path (and `user@host` — see `doc wezterm/workspace`).
