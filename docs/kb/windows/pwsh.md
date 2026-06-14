# Windows — PowerShell extras

Most shortcuts are shared — see `doc common/git`, `doc common/claude-code`,
`doc common/workspace-nav`, `doc common/files-disk`, `doc common/search-history`.
Windows-specific bits:

| Command | What it does |
|---|---|
| `npp file` | open file(s) in Notepad++ (GUI; `npp` alone opens it empty) |
| `glow file.md` | render markdown (`glow .` for a browser) |
| `zoxide-prune` | drop dead paths from zoxide's database |
| `ll` / `la` / `lt` | eza long / hidden+long / tree |
| `Ctrl+R` / `Ctrl+T` | fzf history / file finder |
| `Ctrl+V` | paste (rebound so synthetic paste — Wispr Flow etc. — reaches Claude Code) |

## Recommended WezTerm model (one OS window)
Use WezTerm **workspaces** (`Ctrl+Space w` picker, `Ctrl+Space n` to create) as the
unit of "what I'm working on". Inside a workspace use **panes** (`Ctrl+Space h`/`v`
to split, `j/k/i/m` move, `J/K/I/M` resize, `z` zoom, `F1`–`F6` / `Ctrl+Space 1`–`6`
build-or-focus a 3×2 grid) for things you watch simultaneously. Need a remote shell
beside your work? `Ctrl+Space H`/`V` opens a domain picker (SSH/WSL) and splits it in.
Tabs are cheap full-screen flips within a workspace — `Alt+1`…`9` to jump. This
replaces needing multiple top-level WezTerm windows. Full keys: `doc wezterm/panes`,
`doc wezterm/tabs`, `doc wezterm/workspace`.
