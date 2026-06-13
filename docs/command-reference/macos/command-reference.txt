# Command Reference — terminal-stack

Everything this stack puts at your fingertips. Type `ref` to open this file.
Machine-specific commands (peer servers, GPU tools, service stacks) go in
`~/command-reference.local.md` — untracked, appended by `ref` automatically.
The same content also ships as `~/command-reference.html` (open in a browser)
and `~/command-reference.txt` (plain text) — regenerated whenever this file
changes.

---

## tmux

| Command | What it does |
|---|---|
| `tmux new -s name` | start a new named session |
| `tmux new -A -s name` | attach if it exists, else create (best default) |
| `tmux ls` | list running sessions |
| `tmux attach -t name` | reattach to an existing session |
| `tmux a -t name` | same thing, shorthand |
| `tmux attach -d -t name` | reattach, kicking off any other client |
| `tmux kill-session -t name` | kill a named session |
| `tmux kill-server` | kill all sessions |

| Key | What it does |
|---|---|
| `Ctrl-b d` | detach (leaves session running) |
| `Ctrl-b s` | switch between sessions (picker) |
| `Ctrl-b %` | split pane side by side (vertical) |
| `Ctrl-b "` | split pane top/bottom (horizontal) |
| `Ctrl-b arrow` | move between panes |
| `Ctrl-b x` | close current pane |
| `Ctrl-b z` | zoom current pane fullscreen (toggle) — great for logs |
| `Ctrl-b [` | scroll mode (q to quit) |
| `Ctrl-b c` | new window |
| `Ctrl-b n` / `Ctrl-b p` | next / previous window |
| `Ctrl-b 0-9` | jump to window by number |

---

## WezTerm (leader = `Ctrl+Space`, 1.5s window)

| Key | What it does |
|---|---|
| `Ctrl+Space h` | split pane side by side (new pane on the right) |
| `Ctrl+Space v` | split pane top/bottom (new pane below) |
| `Ctrl+Space H` | pick a domain (local / WSL / SSH…) and split it on the right |
| `Ctrl+Space V` | pick a domain and split it below |
| `Ctrl+Space j/k/i/m` | move between panes (left/right/up/down) |
| `Ctrl+Space J/K/I/M` | resize active pane (5 cells) |
| `Ctrl+Space z` | zoom/unzoom active pane (fullscreen within tab) |
| `Ctrl+Space x` | close the active pane (asks to confirm) |
| `F1` / `F2` / `F3` / `F4` | jump to pane: top-left / top-right / bottom-left / bottom-right |
| `Ctrl+Space 1/2/3/4` | same as F1–F4 (fallback if F-keys are captured by the OS) |
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

Tab labels read `<number>: <dir>` and tint **green** when Claude is done / **red** on error; the top-right shows the active workspace and current path.

---

## git

### Shell aliases (typed bare)

| Alias | Full command | Note |
|---|---|---|
| `gst` | `git status` | it's `gst`, not `gs` — `gs` is Ghostscript |
| `gp` | `git pull` | stack override — plain oh-my-zsh makes this *push* |
| `gl` | `git log --oneline --graph --decorate -10` | stack override — plain oh-my-zsh makes this *pull* |
| `gco` | `git checkout` | |
| `gf` | `git fetch` | |
| `gd` | `git diff` | |
| `ga` | `git add` | |
| `gb` | `git branch` | |
| `gcm` | `git checkout <main branch>` | figures out main vs master |

### git-config aliases (work as `git <alias>`, from the stack's git include)

| Alias | Full command |
|---|---|
| `git st` | `git status` |
| `git lg` | `git log --oneline --graph --decorate -10` |
| `git lga` | `git log --oneline --graph --decorate --all` |
| `git br` | `git branch` |
| `git co` | `git checkout` |
| `git cm` | `git commit` |

`git diff` pages through **delta** (side-by-side syntax-highlighted diffs) — wired
by the same include at `~/.config/git/terminal-stack.gitconfig`.

---

## Claude Code helpers

| Alias | Full command | What it does |
|---|---|---|
| `cc` | `claude` | launch Claude Code (sets WezTerm tab title) |
| `ccc` | `claude --continue` | continue last conversation |
| `ccd` | `claude --dangerously-skip-permissions` | no permission prompts |
| `ccdc` | `claude --dangerously-skip-permissions --continue` | both |
| `ccr` | `claude --resume` | pick a past session to resume |
| `ccdr` | `claude --dangerously-skip-permissions --resume` | both |
| `cca` | `claude agents` | agents view |
| `ccs name` | tmux session `cc-name` running `claude --name name` | Claude in tmux — survives disconnects; defaults to current dir name |

---

## Stack management

| Command | What it does |
|---|---|
| `ts-update` | fetch + show incoming commits, record rollback point, pull, re-apply configs |
| `ts-rollback` | undo the last ts-update: reset the clone to the recorded SHA, re-apply |
| `ref` | this file (+ `~/command-reference.local.md` if present) |
| `plain` | vanilla zsh, no rc files (no oh-my-zsh/starship/aliases) — `exit` to return |
| `chezmoi diff` | preview pending config changes before an apply |
| `chezmoi re-add ~/.zshrc` | capture a hand-edit of a managed file back into the repo |

---

## Workspace navigation

| Command | What it does |
|---|---|
| `ws` | cd to the workspace — `$WORKSPACE_DIR` if set in `~/.zshrc.local`, else autodetected |
| `wsp` | cd to the `*_Personal` / `*-Personal` sibling |
| `wspu` | cd to the `*_Public` / `*-Public` sibling |
| `z dirname` | zoxide — jump to any directory you've visited, from anywhere |
| `zi` | zoxide interactive picker when there are multiple matches |

---

## Files & disk

| Command | What it does |
|---|---|
| `ls` | aliased to **eza** — icons, git status, dirs first (`-l`, `-la` as usual) |
| `ls -T` | eza tree view |
| `cat file` | aliased to **bat** — syntax highlighting, line numbers |
| `df -h` / `du -sh *` | the classics |

---

## Search & history

| Key/Command | What it does |
|---|---|
| `Ctrl-R` | fzf fuzzy-search shell history — replaces `history \| grep` |
| `Ctrl-T` | fzf fuzzy-find a file, insert its path into the command line |
| `Alt-C` | fzf fuzzy-find a directory and cd into it |
| `ESC ESC` | prepend `sudo` to the current/previous command (oh-my-zsh sudo plugin) |
| `rg pattern` | ripgrep — recursive grep, fast, skips .git/node_modules |
| `curl -s … \| jq .` | pretty-print / query JSON |

---

## SSH

| Command | What it does |
|---|---|
| `ssht host [session]` | SSH + remote tmux attach/create in one shot (defaults to session `main`) |
| `rsync -av file host:~/` | copy a file to a remote home |

---

## Homebrew (macOS)

| Command | What it does |
|---|---|
| `brew update` | refresh the package index |
| `brew upgrade` | upgrade everything installed |
| `brew upgrade --cask wezterm@nightly` | upgrade WezTerm (pinned to the nightly cask — plain `wezterm` is stale) |
| `brew cleanup` | remove old versions and stale downloads |
| `brew doctor` | diagnose a broken brew setup |
| `brew list` | what's installed (`--cask` for GUI apps) |
| `brew info formula` | version, deps, install status |

---

## macOS utilities

| Command | What it does |
|---|---|
| `cmd \| pbcopy` | pipe command output to the clipboard |
| `pbpaste` | clipboard to stdout — `pbpaste \| jq .` etc. |
| `open .` | current directory in Finder |
| `open -a "App" file` | open a file with a specific app |
| `mdfind query` | Spotlight search from the CLI (`-name file.txt` for filenames) |
| `caffeinate -i cmd` | keep the Mac awake while a command runs |

