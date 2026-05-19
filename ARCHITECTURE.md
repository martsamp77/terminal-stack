# Architecture

## The cross-side problem

chezmoi natively manages files under `$HOME` on the machine where it runs. On Windows, `$HOME` is `C:\Users\msampson\` and chezmoi can manage it directly. On WSL, `$HOME` is `/home/msampson/` and chezmoi manages that.

Our terminal stack spans both. WezTerm's `.wezterm.lua` lives on the Windows side (because WezTerm runs as a Windows process). zsh's `.zshrc` lives on the WSL side. PowerShell's `$PROFILE` is at `C:\Users\msampson\Documents\PowerShell\...`. zsh's `precmd` and CC's hook scripts need to reach `wezterm.exe` on the Windows side via WSL interop.

We could run chezmoi twice — once on each side, with its own source repo. That doubles the artifact and creates sync problems.

## The cross-side solution

**One chezmoi source repo. chezmoi runs natively in WSL and applies to WSL home directly. A `run_after_` hook script syncs the Windows-targeted files out to `/mnt/c/Users/msampson/` after the WSL apply finishes.**

### Source-tree convention

```
terminal-stack/
├── dot_zshrc                 → ~/.zshrc (WSL)
├── dot_tmux.conf             → ~/.tmux.conf (WSL)
├── dot_config/starship.toml  → ~/.config/starship.toml (WSL)
├── dot_claude/...            → ~/.claude/... (WSL)
└── windows/                  ← NOT applied by chezmoi
    ├── .wezterm.lua          → /mnt/c/Users/msampson/.wezterm.lua
    ├── .config/...           → /mnt/c/Users/msampson/.config/...
    ├── Documents/...         → /mnt/c/Users/msampson/Documents/...
    └── .claude/...           → /mnt/c/Users/msampson/.claude/...
```

`.chezmoiignore` excludes `windows/**` from the normal target-tree apply, so chezmoi never tries to write `~/windows/.wezterm.lua` to your home directory.

### The run_after hook

`run_after_90-sync-windows.sh` runs after every successful `chezmoi apply`. It walks `$CHEZMOI_SOURCE_DIR/windows/`, mirrors every file to `/mnt/c/Users/msampson/<same relative path>`, and:

- **Idempotent**: only touches files whose content differs from what's already at the destination. If `windows/.wezterm.lua` is byte-identical to `/mnt/c/Users/msampson/.wezterm.lua`, it's skipped.
- **Backup-first**: any pre-existing file that gets overwritten is first copied to `<path>.bak.YYYYMMDD`. If that backup name is already taken (you applied twice in one day), the new backup gets a `.N` suffix (`.bak.YYYYMMDD.1`, `.2`, …). The original-day backup is never clobbered.
- **Silent on miss**: if `/mnt/c/Users/msampson/` doesn't exist (running on a non-WSL host like macOS), the script exits cleanly without error.

## Why this shape

- **Single `chezmoi apply` updates both sides.** No "remember to also run X" workflow.
- **Single git history.** Every Windows-side config change shows up in `git log` alongside its WSL-side counterpart. Easy to audit "what did I change last Tuesday".
- **Mac sync works.** On a Mac, `chezmoi apply` will skip the `windows/` subtree (excluded) and skip the run_after hook (it exits cleanly because `/mnt/c/Users/msampson/` doesn't exist). You get just the dot-files that make sense on macOS.
- **Recoverable.** Any time the sync hook overwrites a file, the backup-first behavior preserves the prior state for at least the rest of that day.

## Trade-offs we accepted

- **Two sources of CR-LF drift to watch.** The Edit tool in Windows-side workflows can leave CR-LF endings on files that the WSL chezmoi source has as LF. The first `chezmoi apply` after a Windows-side hand-edit may trip the "differs from chezmoi source" detection on EOL alone and create a backup of the LF-ified version. We use `sed -i 's/\r$//'` on chezmoi-source files defensively whenever we edit through the Windows UNC path.
- **chezmoi `run_after` scripts always appear in `chezmoi diff`.** This is chezmoi's own metadata view, not a real-target diff. The script doesn't actually get *placed* anywhere — it just runs. So the diff output looks noisier than it is.
- **No native chezmoi templating for the Windows-side paths.** chezmoi has `{{ .chezmoi.os }}` etc. that could in principle template-conditionalize where files land, but for our case the `windows/` + `run_after_` pattern is simpler and explicit.

## Other architectural notes

- **PowerShell `$PROFILE` is marker-block-edited, not whole-file-managed.** It contains user-personal content (workspace navigation funcs, `cc` aliases, zoxide env vars) that predates the terminal stack. We use `# ---- name-start ----` / `# ---- name-end ----` blocks to encapsulate our additions and leave everything else untouched. Re-running the deployment replaces *only* the block content if markers exist; otherwise appends.
- **`~/.zshrc` is whole-file-managed.** It was created from scratch by oh-my-zsh during our deployment, so we own the entire file. If you ever hand-edit `~/.zshrc` to enable a plugin, run `chezmoi re-add ~/.zshrc` to capture the change in source.
- **Claude Code `settings.json` is whole-file-managed too** on both sides. If you change a CC preference via `/config` (UI), run `chezmoi re-add ~/.claude/settings.json`.

## Backup discipline

Every overwrite of a user file (not chezmoi-managed apply, but human-or-script overwrites) writes a `.bak.YYYYMMDD` first. If multiple overwrites happen in one day, they get `.1` / `.2` / etc. suffixes. The `run_after_90-sync-windows.sh` script implements this; the bootstrap scripts follow the same convention.

This was added after a Phase 7 incident where the original `$PROFILE.bak.20260519` got clobbered by an unwitting same-day re-run. The recovery file `Microsoft.PowerShell_profile.ps1.bak.20260519.original` (manually restored from the conversation log) exists in `C:\Users\msampson\Documents\PowerShell\` to this day. See `docs/decisions.md` for the full forensic.
