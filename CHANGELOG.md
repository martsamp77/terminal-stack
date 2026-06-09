# Changelog

All notable changes captured here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Dates are MM/DD/YYYY for display, `git log` is authoritative.

## [Unreleased] — 06/05/2026

### Added

- **Chocolatey as an alternative Windows package manager.** `bootstrap/windows-bootstrap.ps1` gains `-PackageManager winget|choco` (default `winget`); `install.ps1` honors `$env:TERMINAL_STACK_PKGMGR=choco` and the winget-missing error now points at it. The choco path installs Chocolatey itself on first use (elevated), then installs the same toolchain via `choco install` — the fallback for hosts without winget, notably **Windows Server 2019** (no Microsoft Store, no supported winget). winget remains the unchanged default for the Windows 11 path; the choco list installs WezTerm *stable* (Chocolatey has no nightly channel). See `docs/decisions.md` § "Why a Chocolatey option for the Windows bootstrap (winget kept as the default)" and `INSTALL.md` § 1.
- **WezTerm config degrades gracefully to the `20240203` stable.** `windows/.wezterm.lua` and `dot_wezterm.lua` previously assumed a nightly build: `window_decorations = 'INTEGRATED_BUTTONS|RESIZE'` and the `LEADER o` `pane:move_to_new_window()` binding don't exist on the last stable (`20240203`, what choco and other winget-less hosts get). Both are now gated on `wezterm.version`'s build date — nightly keeps the integrated buttons + detach-tab; the stable build falls back to a plain `RESIZE` border and a no-op `LEADER o`, so it loads without a config-error overlay. Lets the Chocolatey `wezterm` package work without requiring a manual nightly download.
- **`WEZTERM_FRONT_END` env override.** `front_end` still defaults to `OpenGL`, but reads `$env:WEZTERM_FRONT_END` first, so a host with no usable GPU (over RDP / headless server, where `OpenGL` fails with *"OpenGL too old to work with glium"* and the GUI never starts) can override per-machine without editing tracked config — the WezTerm analogue of `~/.zshrc.local`. On Windows over RDP the working value is **`WebGpu`** (it falls back to the WARP software D3D adapter); `Software` does *not* help there, as the stable build routes it through OpenGL too. See `docs/decisions.md` § "Why the WezTerm config tolerates the 20240203 stable".
- **Chocolatey tab-completion block carried in the tracked pwsh `$PROFILE`.** The choco installer appends an `Import-Module …chocolateyProfile.psm1` block to `$PROFILE`, which the whole-file `sync-windows.ps1` would clobber on the next apply. The profile now ships a guarded `# ---- chocolatey-* ----` block that imports the module only when present (no-op without choco, LF-clean).
- **GitKraken + claude-obsidian plugin enablement tracked in `windows/.claude/settings.json.tmpl`.** Claude Code writes plugin marketplaces and enable-flags directly into `~/.claude/settings.json`, which this repo manages whole-file — so the next `chezmoi apply` would have silently wiped both the `claude-obsidian` and `gitkraken-hooks` plugins. The template now carries `extraKnownMarketplaces` + `enabledPlugins` (the gitkraken marketplace path is tokenized with `__WIN_USER__`; the claude-obsidian `directory` source is a deliberately machine-specific local path). See `docs/decisions.md` § "Why the Windows settings template tracks the claude-obsidian + gitkraken plugins". The companion diagnosis of the GitKraken AI-hook log flood and the 0-byte `gk.exe` symlink red herring is written up in `docs/powershell-quirks.md` § "GitKraken `gk ai hook` plugin".
- **`.gitattributes`** enforcing `* text=auto eol=lf` plus binary markers for image/archive types. Overrides Windows' `core.autocrlf=true` (which is on at the system level by default) so fresh clones get LF in the working tree on every platform. Without this, every chezmoi-source file was being silently rewritten as CRLF on Windows checkout, then propagated through chezmoi to WSL — symptoms: `~/.zshrc:3: command not found: ^M`, `run_after_90-sync-windows.sh` failing with `env: $'bash\r': No such file or directory`, and spurious `.bak` files on every apply. See `docs/decisions.md` § "Why `.gitattributes` with `eol=lf`".
- **Cross-platform Nerd Font glyphs in `starship.toml`**: folder ( U+F07B), octocat ( U+F408) + git-branch ( U+E725), clock ( U+F017), per-distro OS logos (Ubuntu , Debian , Arch , Alpine , Fedora , macOS , Windows , and ~15 others). Both `dot_config/starship.toml` and `windows/.config/starship.toml` are now byte-identical and produce the rounded-frame two-line prompt from `context/bestprompt.jpg` on both sides — only the OS glyph differs by platform.
- **eza-backed `ls/ll/la/lt` functions** in the pwsh `cli-tools` marker block, matching the Linux `dot_zshrc` alias (`eza --icons=always --git --group-directories-first`). The built-in `ls` alias is removed first since pwsh pre-aliases it to `Get-ChildItem`. `ll` adds long-form (`-l`), `la` adds hidden+long (`-la`), `lt` switches to tree view (`--tree`).
- **Glow** (`charmbracelet.glow`) added to the Windows winget core packages for in-terminal markdown rendering. `glow README.md` renders a single file with the WezTerm Nerd Font glyphs; `glow .` opens a TUI file browser. No profile wrapper — winget puts it on PATH and the defaults are sensible.
- **`ccr` / `ccdr` resume shortcuts** on both shells. `ccr` runs `claude --resume`, `ccdr` runs `claude --dangerously-skip-permissions --resume`. PowerShell wraps each call in the existing `Set-WezTabTitle` try/finally pattern; zsh wraps via a new `_wez_tab_title` helper. Closes the gap where neither shell had a one-keystroke way to resume the previous Claude session.
- **`ws` / `wsp` / `wspu` / `wscalibra` / `wsnetsuite` workspace nav on zsh.** Mirrors the existing PowerShell functions that cd into `C:\DATA\Workspace*`. The zsh versions target `/mnt/c/DATA/Workspace*` and are guarded by `[[ -d /mnt/c/DATA/Workspace ]]` so the same `dot_zshrc` stays correct on native Linux — the guard fails and no `ws*` functions are defined, instead of defining ones that would error on call. See `docs/decisions.md` § "Why guard `ws*` on `/mnt/c` existence rather than `$WSL_INTEROP`?".
- **macOS support, validated end to end.** The stack now applies cleanly on macOS (Apple Silicon and Intel). `bootstrap/mac-bootstrap.sh` is no longer an untested stub — it installs the toolchain via Homebrew (zsh, git, tmux, eza, zoxide, fzf, bat, git-delta, ripgrep, Starship, chezmoi, the `wezterm@nightly` cask, the JetBrainsMono Nerd Font cask), installs oh-my-zsh, and writes `~/.config/chezmoi/chezmoi.toml` with `sourceDir` auto-detected from the script's own location. The `wezterm@nightly` cask is used deliberately — the plain `wezterm` cask is pinned to the stale `20240203` stable. The `run_after` Windows-sync hook self-no-ops on macOS exactly as it does on native Linux. New `INSTALL.md` § 2M documents the path.
- **`dot_wezterm.lua`** — a macOS WezTerm config, the chezmoi-managed counterpart of `windows/.wezterm.lua`. Same font stack (JetBrainsMono Nerd Font → CaskaydiaCove → Menlo), Catppuccin Mocha, fancy tab bar, `Ctrl+A` leader with tmux-style pane splits/navigation, `format-tab-title` / `update-right-status` hooks, and `front_end = 'OpenGL'`. Drops the Windows-only `default_prog`/`launch_menu` (macOS defaults to the login shell). Gated to darwin via a now-templated `.chezmoiignore` so WSL and native-Linux homes don't get a dead `~/.wezterm.lua`. See `docs/decisions.md` § "Why a separate `dot_wezterm.lua` for macOS".
- **Integrated window buttons in the WezTerm tab bar** — `window_decorations` changed from `'RESIZE'` to `'INTEGRATED_BUTTONS|RESIZE'` in both `windows/.wezterm.lua` and `dot_wezterm.lua`. Previously `'RESIZE'` drew a resize border with no title bar and *no* minimize/maximize/close controls at all; the fancy tab bar now carries the standard Min/Max/Close set in its upper-right (native-styled per platform — `Windows` on Windows, `MacOsNative` on macOS). Requires `use_fancy_tab_bar = true`, already set.
- **`LEADER o` pops the current tab into a new window** in both WezTerm configs. WezTerm has no native mouse drag-to-detach (GH discussion #4080, issue #549); this binds `Ctrl+A o` to a `pane:move_to_new_window()` callback as the supported equivalent. `o` was free among the existing leader bindings (`w n \ - h l k j`). For ad-hoc use the CLI equivalent is `wezterm cli move-pane-to-new-tab --new-window`.

### Fixed

- **Claude Code tab-status hook was dead on macOS.** `dot_claude/hooks/wez-tab-status.sh` hardcoded `wezterm.exe`, which only exists on WSL via Windows interop — on macOS the binary is plain `wezterm`. The hook now prefers `wezterm` and falls back to `wezterm.exe`, so the `cc ⏳/✓/✗ <project>` tab indicator works on macOS and WSL alike.
- **Deeper `Γ¥»` mojibake** — Claude Code and other native console children call `SetConsoleOutputCP()` and can leave the OS-level console codepage as 437 on exit. The previous fix (commit `116087d`) only consulted `[Console]::OutputEncoding.CodePage`, which is a .NET-side cached value that does NOT reflect direct Win32 codepage changes. The conditional short-circuited as "already UTF-8" while the underlying console was actually 437 → next prompt's `❯` decoded as `Γ¥»`. New approach: P/Invoke `kernel32!GetConsoleOutputCP` / `SetConsoleOutputCP(65001)` in `Invoke-Starship-PreCommand`, probing OS state authoritatively each prompt.
- **All `os.symbols` empty in `starship.toml`** — the Private-Use-Area Nerd Font glyphs had been silently stripped at some prior write, leaving every entry as `""`. The OS module emitted only a trailing space. `bestprompt.jpg` predates the strip. Restored with explicit visible glyphs; comment warns future edits not to round-trip the file through tools that drop PUA characters (U+E000–U+F8FF).
- **`OpenSUSE` rejected by starship's variant parser** — correct casing is `openSUSE`. The parse error silently disabled the entire `[os.symbols]` table on Windows, falling back to starship's emoji defaults (which render as `?` in most Nerd Fonts).
- **WezTerm Claude-Code startup render stall** — switched `front_end` from `WebGpu` to `OpenGL`. The post-Enter output-buffer stall ("type `ccd`, Claude doesn't draw until I press a key") is a known WebGpu behavior on certain Intel iGPU drivers. Also dropped `webgpu_power_preference` (no longer applies) and `max_fps = 120` (default 60 matches typical panel refresh, avoids wasted frames).

### Changed

- **Starship config now single-sourced.** `dot_config/starship.toml` is canonical; `windows/.config/starship.toml` is a byte-identical copy maintained via `run_after_90-sync-windows.sh`. To edit, change `dot_config/starship.toml`, then `cp dot_config/starship.toml windows/.config/starship.toml`.
- **`Invoke-Starship-PreCommand` UTF-8 restore** (in `$PROFILE`) is now the P/Invoke version described under "Fixed". The old `[Console]::OutputEncoding.CodePage` check is gone.
- **zsh `cc*` are functions, not aliases.** Previously plain `alias cc="claude"` etc.; now each invocation sets the WezTerm tab title to `cc • <leaf>` while claude runs and clears it on exit, matching the PowerShell side. Zsh has no `try/finally`, so the new pattern captures the claude exit code via `local rc=$?` before clearing the title and `return $rc` — without that, the function would always exit 0 and mask failures. Leaf computed via zsh's `${PWD:t}` (PowerShell uses `Split-Path -Leaf $PWD`). The `[[ -n "$WEZTERM_PANE" ]]` guard inside `_wez_tab_title` keeps these safe under PuTTY/ssh/native Linux terminals where WezTerm isn't the host.
- **`bootstrap/mac-bootstrap.sh` hardened from its stub state.** `SOURCE_DIR` now auto-detects the repo from the script's own location (`bootstrap/` is one level below the root) with an env-var override, instead of assuming `~/code/terminal-stack`. Dropped the `brew tap homebrew/cask-fonts` call — that tap was deprecated when font casks moved into `homebrew/cask` in 2024. Removed the "UNTESTED STUB" banner now that the path is validated.
- **`.chezmoiignore` is now a template.** It gains a `{{ if ne .chezmoi.os "darwin" }}` block that ignores `.wezterm.lua` everywhere except macOS. chezmoi has always evaluated `.chezmoiignore` as a template; this is the first entry in this repo to use that.
- **`ws` / `wspu` zsh functions now have a macOS branch.** The `ws*` block was guarded solely on `[[ -d /mnt/c/DATA/Workspace ]]`, so macOS got no workspace-nav functions. Added an `elif [[ -d "$HOME/Documents/Workspace" ]]` branch defining `ws` (→ `~/Documents/Workspace`) and `wspu` (→ `~/Documents/Workspace-Public`; the macOS dir uses a hyphen where the WSL side uses `Workspace_Public`). Same per-path guard philosophy as the WSL branch — see `docs/decisions.md` § "Why guard `ws*` on `/mnt/c` existence rather than `$WSL_INTEROP`?".

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
