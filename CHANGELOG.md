# Changelog

All notable changes captured here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Dates are MM/DD/YYYY for display, `git log` is authoritative.

## [Unreleased]

## [1.0.0] — 05/19/2026

Initial terminal stack — single-day deployment across 14+ chezmoi commits. The original work was scoped Phase 0 → Phase 10 (environment detection through final verification). Summary of the resulting capabilities:

### Added — Windows side

- **WezTerm nightly** (`20260331-040028-577474d8`) installed via `winget`, replaces the stale `20240203` stable. Per-pane WebGPU rendering, 120fps cap, 50k scrollback.
- **`.wezterm.lua`** at `%USERPROFILE%\.wezterm.lua` with:
  - JetBrainsMono Nerd Font primary, CaskaydiaCove + Cascadia Code fallbacks
  - Catppuccin Mocha color scheme, 100% opaque (changed from 0.97 after testing)
  - Fancy tab bar at the bottom, `tab_max_width = 120`, `window_frame.font_size = 11.0`
  - LEADER key `Ctrl+A` with tmux-style pane splits and navigation
  - `Ctrl+V` rebound to `PasteFrom 'Clipboard'` so Wispr Flow's synthetic Ctrl+V works in Claude Code (see issue [#38620](https://github.com/anthropics/claude-code/issues/38620))
  - Right-status: workspace · cwd · 12-hour time
  - `format-tab-title` uses `wezterm.truncate_right(title, max_width - 2)` to fit dynamically
- **JetBrainsMono Nerd Font** v3.3.0 installed machine-wide via `winget`
- **Starship 1.25.1** (pre-existing); not modified
- **Modern CLI tools** installed via winget: `eza`, `fzf`, `bat`, `delta`, `ripgrep`
- **PowerShell `$PROFILE`** at `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`:
  - Marker block `# ---- starship-stack-start ----` with starship init, `Enable-TransientPrompt` guarded by `Get-Command` (works on PSReadLine 2.4.5 which doesn't export it), `Invoke-Starship-PreCommand` emitting OSC 7 (cwd hint) and OSC 0 (tab title with tilde-abbreviated path)
  - Marker block `# ---- cli-tools-start ----` with guarded zoxide init (replaces the previously unframed init line)
  - `Set-WezTabTitle` helper using `wezterm.exe cli set-tab-title` (sticky `tab.tab_title`, survives Claude Code's OSC overrides)
  - `cc` / `ccc` / `ccd` / `ccdc` / `cca` Claude Code wrappers that set `cc • <project>` before launching, clear on exit via `try/finally`
  - UTF-8 console restore at prompt time (heals the `Γ¥»` CP437-decode mojibake Claude Code leaves behind on exit)
- **Claude Code hooks** at `%USERPROFILE%\.claude\hooks\wez-tab-status.ps1`:
  - `UserPromptSubmit` → tab title becomes `cc ⏳ <project>` (thinking)
  - `Stop` → `cc ✓ <project>` (waiting for input)
  - `StopFailure` → `cc ✗ <project>` (error)
  - Commands in `settings.json` use forward slashes in the script path (`C:/Users/...`) to bypass CC's POSIX-style shell layer stripping backslashes

### Added — WSL side

- **zsh** 5.9 installed, set as login shell for `msampson`
- **oh-my-zsh** installed unattended, `ZSH_THEME=""` so Starship owns the prompt, `plugins=(git)` untouched
- **chezmoi** 2.70.3 installed to `~/.local/bin/chezmoi` via the official curl installer
- **Starship 1.25.1** installed in `/usr/local/bin/starship`
- **JetBrains Mono** (regular variant) via `apt`; Nerd Font variant downloaded from `ryanoasis/nerd-fonts` releases into `~/.local/share/fonts/JetBrainsMonoNerdFont/`
- **Modern CLI tools** via apt: `eza`, `zoxide`, `fzf`, `bat` (symlinked from `batcat`), `git-delta`, `ripgrep`
- **`~/.zshrc`**: oh-my-zsh template + marker blocks for Starship, terminal helpers (`precmd` OSC 0 setter, `ccs`, `ssht`), and CLI tool inits
- **`~/.tmux.conf`** with mouse on, base-index 1, `allow-passthrough on`, `extended-keys on` for `xterm*` and `wezterm*` (needed for Claude Code Shift+Enter)
- **`~/.config/starship.toml`** shared with the Windows side: branch symbol, git status `! ?` indicators (reverted from Nerd Font glyphs after user testing), command-duration, cloud-provider modules disabled
- **Claude Code hooks** at `~/.claude/hooks/wez-tab-status.sh` (executable via chezmoi `executable_` prefix), same three states as Windows side; calls `wezterm.exe` via WSL interop

### Added — Cross-side / repo

- **chezmoi source repo** with 14 commits (now living in this repo at `C:\DATA\Workspace\terminal-stack`)
- **`.chezmoiignore`** excluding `windows/**` from chezmoi's standard apply
- **`run_after_90-sync-windows.sh`** post-apply hook that mirrors `windows/` to `/mnt/c/Users/msampson/`, with `.bak.YYYYMMDD[.N]` backups for any overwrite (hardened against same-day clobber after a Phase 7 incident)
- **WSL git identity** mirrored from Windows-side global config

### Fixed (during the same session)

- **`Γ¥»` mojibake** after Claude Code exits — restored UTF-8 console encoding at prompt time in `Invoke-Starship-PreCommand`
- **Wispr Flow paste failing** in Claude Code — bound `Ctrl+V` to `PasteFrom 'Clipboard'` in WezTerm (default only binds `Ctrl+Shift+V`)
- **`Enable-TransientPrompt` not available** on PSReadLine 2.4.5 — wrapped in `Get-Command` guard
- **Hook backslashes stripped by POSIX shell layer** — switched Windows hook paths in `settings.json` to forward slashes (PowerShell accepts them via `-File`)
- **Tab title for `cc` overwritten by Claude Code** — switched from OSC 0 (pane.title) to `wezterm cli set-tab-title` (tab.tab_title, which our `format-tab-title` checks first)

## [Pre-1.0]

Stack didn't exist. WezTerm was on the stale `20240203` stable, PowerShell `$PROFILE` had just the user's workspace navigation funcs and zoxide init, no chezmoi, no oh-my-zsh, no Starship in WSL, no Nerd Font.
