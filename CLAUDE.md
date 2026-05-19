# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A chezmoi source tree that deploys a Windows 11 + WSL2 Ubuntu terminal stack (WezTerm, tmux, Starship, zsh, PowerShell `$PROFILE`, Claude Code hooks/settings, modern CLI tools) from one git repo to two operating systems with a single `chezmoi apply`.

There is no build, no test suite, no lint. "Running" the project means applying configs to the host machine.

## The apply workflow (this repo's equivalent of build/test)

Always run chezmoi **from inside WSL** (not from Windows). The post-apply hook needs a POSIX shell and `/mnt/c/...` to exist.

```sh
~/.local/bin/chezmoi diff      # preview pending changes (WSL targets only — see caveat below)
~/.local/bin/chezmoi apply -v  # apply; runs run_after_90-sync-windows.sh at the end
```

To capture a hand-edit that was made directly to the target (not the source):

```sh
chezmoi re-add ~/.zshrc
chezmoi re-add ~/.claude/settings.json
```

There is no CI. Verification is manual — see `INSTALL.md` § Phase 9.

## The architectural twist: one source repo, two operating systems

chezmoi natively only manages `$HOME` on the machine where it runs. We need both Windows `C:\Users\<you>\` and WSL `/home/<you>/`. The solution:

1. **WSL-targeted files** use chezmoi's standard `dot_*` / `dot_config/` / `executable_*` naming at the repo root → applied to WSL `$HOME` normally.
2. **Windows-targeted files** live under `windows/` and are **excluded** from chezmoi's apply by `.chezmoiignore` (`windows/**`).
3. **`run_after_90-sync-windows.sh`** walks `windows/` after each apply and mirrors every file to `/mnt/c/Users/<you>/<same relative path>`, with `.bak.YYYYMMDD[.N]` backups for any overwrite.

Source → destination mapping for the `windows/` subtree is **relative-path-preserving**: `windows/.wezterm.lua` → `/mnt/c/Users/<you>/.wezterm.lua`. To add a new Windows-side file, drop it at the mirror path under `windows/` — no script changes needed. Full mechanism in `docs/cross-side-chezmoi.md`.

**Username resolution.** No source file hard-codes a username:

- WSL-side templates (`*.tmpl` under the chezmoi source root, e.g. `dot_claude/settings.json.tmpl`) use chezmoi's native engine — `{{ .chezmoi.homeDir }}`, `{{ .chezmoi.username }}`.
- Windows-side templates (`*.tmpl` under `windows/`, e.g. `windows/.claude/settings.json.tmpl`) use a literal `__WIN_USER__` token that `run_after_90-sync-windows.sh` substitutes at sync time. The username is resolved from (1) `chezmoi data → windowsUsername` (written by the WSL bootstrap), falling back to (2) `cmd.exe /c echo %USERNAME%` via WSL interop. When you add a new Windows-side templated file, use `__WIN_USER__` — not Go-template syntax.

**Important caveat:** `chezmoi diff` only shows changes to WSL targets. It does NOT show what the `run_after` hook will sync to `/mnt/c/`. To preview Windows-side changes, compare source manually or just run apply and read the `created`/`updated` lines.

## File-management strategies (don't mix them up)

| File | Strategy | Why |
|---|---|---|
| `~/.zshrc` | whole-file | We own every line (oh-my-zsh template + our additions) |
| `~/.claude/settings.json` (both sides) | whole-file | We own it |
| `~/.tmux.conf`, `~/.config/starship.toml` | whole-file | We own it |
| `$PROFILE` (Windows pwsh) | **marker-block** | User has pre-existing personal content; only the `# ---- name-start ----` / `# ---- name-end ----` regions are ours |

If you need to modify `$PROFILE`, edit **only inside an existing marker block** (`starship-stack-*`, `cli-tools-*`) or add a new marker block. Never rewrite the whole file — you'll destroy user personal content. See `docs/decisions.md` § "Why a whole-file `~/.zshrc` and a marker-block `$PROFILE`?".

## Gotchas worth remembering

These are written up at length in `docs/powershell-quirks.md`; the short version:

- **CRLF drift.** Editing a chezmoi-source file via Windows-side tools (the Edit tool when CWD is `C:\DATA\...`) can inject CRLF. The run_after hook will then think the destination differs and back it up unnecessarily. Defensive fix when you've just edited a source file through Windows: `sed -i 's/\r$//' <file>` (from inside WSL).
- **JSON paths in Claude Code hooks must use forward slashes**, not backslashes. Two shell layers strip backslashes; forward slashes survive. See `windows/.claude/settings.json.tmpl` for examples (`C:/Users/__WIN_USER__/.claude/hooks/...`).
- **Tab title for `cc` wrappers uses `wezterm cli set-tab-title`, not OSC 0.** Claude Code's TUI overwrites `pane.title` (OSC) with its conversation slug; `tab.tab_title` is sticky and survives. The `format-tab-title` Lua hook in `windows/.wezterm.lua` checks `tab.tab_title` first.
- **`Enable-TransientPrompt` is guarded with `Get-Command`** because PSReadLine 2.4.5 doesn't export it. Don't remove the guard.

## Backup convention

Any script in this repo that overwrites a user file must write a backup first as `<path>.bak.YYYYMMDD`. If that name already exists (same-day re-run), append `.1`, `.2`, etc. Never clobber a same-day backup. Reference implementation: `run_after_90-sync-windows.sh:28-34`. A Phase 7 incident where this discipline was missing motivated the hardening; see `docs/decisions.md` § "Why two backups".

## Where to look

- `README.md` — what the stack delivers, top-level layout
- `ARCHITECTURE.md` — the cross-side problem and our solution in 30s
- `INSTALL.md` — scripted (Phase 0 → 10) and manual install paths
- `CHANGELOG.md` — curated change history; `git log` is authoritative
- `docs/cross-side-chezmoi.md` — deep dive on the chezmoi + run_after mechanism
- `docs/powershell-quirks.md` — every weird Windows-side workaround with cause and fix
- `docs/decisions.md` — design choices that aren't obvious from the code

## Personal-path note

The source tree carries no hard-coded usernames. The WSL bootstrap prompts for the Windows username (default = interop-detected) and persists it under `[data].windowsUsername` in `~/.config/chezmoi/chezmoi.toml`; the sync hook substitutes it into `windows/**/*.tmpl` files at apply time, and WSL-side templates use chezmoi's native `{{ .chezmoi.homeDir }}`. If you ever see a literal username in a source file, that's a regression — replace it with `__WIN_USER__` (Windows side) or `{{ .chezmoi.homeDir }}` (WSL side, file needs `.tmpl` suffix). The `LICENSE` copyright is the one place a real name remains; update on fork if you care.
