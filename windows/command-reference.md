# Command Reference — terminal-stack (Windows / PowerShell)

Everything this stack puts at your fingertips on the Windows side. Type `ref`
to open this file. Machine-specific commands go in
`%USERPROFILE%\command-reference.local.md` — untracked, appended by `ref`
automatically. The same content also ships as
`%USERPROFILE%\command-reference.html` (open in a browser) and
`%USERPROFILE%\command-reference.txt` (plain text) — regenerated whenever this
file changes.

---

## WezTerm (leader = `Ctrl+Space`, 1.5s window)

| Key | What it does |
|---|---|
| `Ctrl+Space h` | split pane top/bottom (new pane below) |
| `Ctrl+Space v` | split pane side by side (new pane on the right) |
| `Ctrl+Space H` | pick a domain (local / WSL / SSH…) and split it below |
| `Ctrl+Space V` | pick a domain and split it on the right |
| `Ctrl+Space j/k/i/m` | move between panes (left/right/up/down) |
| `Ctrl+Space J/K/I/M` | resize active pane (5 cells) |
| `Ctrl+Space z` | zoom/unzoom active pane (fullscreen within tab) |
| `Ctrl+Space x` | close the active pane (asks to confirm) |
| `F1`…`F6` | build-or-focus a cell of a 3×2 grid — F1 F2 F3 top row, F4 F5 F6 bottom; creates the pane if missing, else focuses it |
| `Shift+F1`…`Shift+F6` | build the cell with its new pane opened in a fuzzy-picked domain |
| `Ctrl+Space 1`…`Ctrl+Space 6` | same as F1–F6 (fallback if F-keys are captured by the OS) |
| `Ctrl+Space w` | workspace picker (fuzzy) |
| `Ctrl+Space n` | new named workspace |
| `Ctrl+Space R` | rename the current workspace |
| `Ctrl+Space X` | close every pane in the current workspace ("delete" it) |
| `Ctrl+Space o` | pop the current pane out into a new window |
| `Ctrl+Shift+O` | pop the current pane out (quick access, no leader) |
| `Ctrl+Space r` | reload the WezTerm configuration (after editing .wezterm.lua or pane_grid.lua etc.) |
| `Alt+1` … `Alt+9` | switch directly to tab 1–9 — no leader; the number matches the tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Ctrl+Space Ctrl+Space` | send a literal Ctrl+Space through |
| `Alt+L` | launcher menu (includes TABS and WORKSPACES) |
| `Ctrl+V` | paste |

**Recommended model (one WezTerm OS window):** Use WezTerm *workspaces* (Ctrl+Space, w fuzzy picker, Ctrl+Space, n to create) as the unit of "what I'm working on" (Project-Alpha vs Project-Beta). Inside a workspace use *panes* (Ctrl+Space, h / v to split, j/k/i/m to move, J/K/I/M to resize, z to zoom, F1-F6 / Ctrl+Space 1-6 to build-or-focus a 3×2 grid) for things you want to watch simultaneously. Need a remote shell beside your work? Ctrl+Space, H (below) or V (right) opens a domain picker — choose an SSH or WSL domain and it splits that in. Tabs are cheap full-screen flips within a workspace; jump straight to one with Alt+1…9. Each tab is labelled with its number and directory (e.g. `2: terminal-stack`) and tints green when Claude finishes / red on error; the top-right shows the active workspace and current path. This replaces the need for multiple top-level WezTerm windows.

**Managing workspaces:** rename the current one with `Ctrl+Space R`; "delete" a live one with `Ctrl+Space X` (closes all its panes).

---

## git

### Shell functions (typed bare)

| Function | Full command | Note |
|---|---|---|
| `gst` | `git status` | it's `gst`, not `gs` |
| `gp` | `git pull` | stack convention — gp always means PULL |
| `gl` | `git log --oneline --graph --decorate -10` | gl always means LOG |
| `gco` | `git checkout` | |
| `gf` | `git fetch` | |
| `gd` | `git diff` | |
| `ga` | `git add` | |
| `gb` | `git branch` | |

### git-config aliases (work as `git <alias>`, from the stack's git include)

| Alias | Full command |
|---|---|
| `git st` | `git status` |
| `git lg` | `git log --oneline --graph --decorate -10` |
| `git lga` | `git log --oneline --graph --decorate --all` |
| `git br` | `git branch` |
| `git co` | `git checkout` |
| `git cm` | `git commit` |

`git diff` pages through **delta** — wired by the include at
`%USERPROFILE%\.config\git\terminal-stack.gitconfig`.

---

## Claude Code helpers

| Function | Full command | What it does |
|---|---|---|
| `cc` | `claude` | launch Claude Code (sets WezTerm tab title) |
| `ccc` | `claude --continue` | continue last conversation |
| `ccd` | `claude --dangerously-skip-permissions` | no permission prompts |
| `ccdc` | `claude --dangerously-skip-permissions --continue` | both |
| `ccr` | `claude --resume` | pick a past session to resume |
| `ccdr` | `claude --dangerously-skip-permissions --resume` | both |
| `cca` | `claude agents` | agents view |

---

## Stack management

| Command | What it does |
|---|---|
| `ts-update` | fetch + show incoming commits, record rollback point, pull, re-apply |
| `ts-rollback` | undo the last ts-update: reset the clone to the recorded SHA, re-apply |
| `ref` | this file (+ `command-reference.local.md` if present) |
| `plain` | vanilla pwsh, no profile (no starship/zoxide/aliases) — `exit` to return |

---

## Workspace navigation

| Command | What it does |
|---|---|
| `ws` | cd to the workspace — `$env:WORKSPACE_DIR` if set in `profile.local.ps1`, else autodetected |
| `wsp` | cd to the `*_Personal` / `*-Personal` sibling |
| `wspu` | cd to the `*_Public` / `*-Public` sibling |
| `z dirname` | zoxide — jump to any directory you've visited |
| `zi` | zoxide interactive picker |
| `zoxide-prune` | drop dead paths from zoxide's database |

---

## Files & search

| Command | What it does |
|---|---|
| `ls` / `ll` / `la` | eza — icons, git status, dirs first (long / hidden+long) |
| `lt` | eza tree view |
| `bat file` | cat with syntax highlighting |
| `glow file.md` | render markdown in the terminal (`glow .` for a browser) |
| `npp file` | open file(s) in Notepad++ (launches the GUI; `npp` alone opens it empty) |
| `Ctrl+R` | fzf fuzzy-search command history |
| `Ctrl+T` | fzf fuzzy-find a file, insert its path |
| `rg pattern` | ripgrep — recursive grep, fast |
