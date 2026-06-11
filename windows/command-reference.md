# Command Reference — terminal-stack (Windows / PowerShell)

Everything this stack puts at your fingertips on the Windows side. Type `ref`
to open this file. Machine-specific commands go in
`%USERPROFILE%\command-reference.local.md` — untracked, appended by `ref`
automatically.

---

## WezTerm (leader = `Ctrl+A`, 1.5s window)

| Key | What it does |
|---|---|
| `Ctrl+A \` | split pane side by side |
| `Ctrl+A -` | split pane top/bottom |
| `Ctrl+A h/j/k/l` | move between panes (vim directions) |
| `Ctrl+A w` | workspace picker (fuzzy) |
| `Ctrl+A n` | new named workspace |
| `Ctrl+A o` | pop the current tab out into a new window |
| `Ctrl+A Ctrl+A` | send a literal Ctrl+A through |
| `Alt+L` | launcher menu |
| `Ctrl+V` | paste |

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
| `Ctrl+R` | fzf fuzzy-search command history |
| `Ctrl+T` | fzf fuzzy-find a file, insert its path |
| `rg pattern` | ripgrep — recursive grep, fast |
