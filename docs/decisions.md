# Design decisions

Notes on choices made during the original deployment that aren't obvious from reading the code. Order is roughly chronological.

## Why oh-my-zsh with `ZSH_THEME=""`?

oh-my-zsh provides plugin loading (`plugins=(git ...)`), aliases, and a theme. Themes set `PROMPT` directly. Starship sets `PROMPT` to its own callback. The two would compete.

We disable oh-my-zsh's theme by setting `ZSH_THEME=""`, which makes omz a no-op for the prompt. omz still handles plugins (currently just `git`, providing git-aware completions and aliases). Starship owns the prompt.

Alternative considered: drop oh-my-zsh entirely and use raw zsh + zinit/zplug. Rejected because oh-my-zsh is a well-known known-quantity in this codebase, and we're not pushing zsh performance limits.

## Why chezmoi over a plain git dotfiles repo with symlinks?

Plain dotfiles repos with `stow` or symlinks have a problem: they assume your target is `$HOME`. They don't help with the cross-side Windows/WSL issue — you'd need two dotfiles repos or weird symlink chains across `/mnt/c`.

chezmoi gives us:
- Templates (we don't use them yet, but they're available for OS-conditional content).
- Encrypted source files (we don't use, but useful for secrets).
- A `run_after_` script slot that's perfect for our cross-side mirror hook.
- A canonical `chezmoi diff` view of pending changes.
- Built-in `executable_` prefix that handles +x bits without separate scripts.

The cost is one extra concept (`source` vs `target`) but the benefits more than pay for it.

## Why a whole-file `~/.zshrc` and a marker-block `$PROFILE`?

Both files have user content. `~/.zshrc` is created from scratch by oh-my-zsh during our deployment — we own every line. `$PROFILE` predates the terminal stack with user-personal content (workspace navigation funcs, zoxide init, `cc` aliases that have evolved over time).

We use whole-file management for `~/.zshrc` because:
- We have the canonical template content.
- Re-running deployment doesn't lose anything (we're the only writer).
- `chezmoi diff` shows the full intended state.

We use marker-block injection for `$PROFILE` because:
- The user has custom code that should not be touched.
- Re-running the deployment should *only* affect the bracketed block.
- The user can always inspect `git diff` of the file and see what we added vs what was theirs.

If you ever take whole-file management of `$PROFILE`, you'd lose the safety of "I can rerun without nuking my custom stuff". Don't.

## Why per-tab `cc • <project>` instead of one big tab name?

Initial implementation set the tab title to the conversation slug (whatever Claude Code emits via OSC 2). Found this in practice: all CC tabs end up with conversation-slug titles that are hard to map back to "which project is this".

Project-leaf-based titles win for human navigation. When you have five CC sessions across five projects, `cc • netsuite-customizations` / `cc • frontend-app` / `cc • slide-decks` is instantly scannable. Conversation titles like `distinguish-claude-code-tabs-pwsh` look meaningful in isolation but are visually similar across tabs.

The thinking/waiting indicator (`⏳` / `✓`) layered on top via CC hooks gives you state without losing the project signal.

## Why forward slashes in JSON paths?

See `powershell-quirks.md` § "Backslashes in JSON paths get stripped twice". The short version: it's the simplest fix that doesn't depend on knowing which shell layer is eating which characters. Forward slashes are inert in JSON, in POSIX shells, in PowerShell. Backslashes are special in all three.

## Why `wezterm cli set-tab-title` and not OSC 0?

Setting tab titles via OSC 0/2 (the standard terminal way) writes to `pane.title`. Claude Code also writes to `pane.title` (with its conversation slug). Last writer wins. We can't synchronize.

`wezterm cli set-tab-title` writes to `tab.tab_title` (a different WezTerm-internal field). Our `format-tab-title` Lua hook checks `tab.tab_title` first and only falls back to `pane.title` if `tab.tab_title` is empty. So once we set `tab.tab_title`, no OSC stream can dislodge it.

The tradeoff: `tab.tab_title` is sticky. It doesn't automatically reset when CC exits. We handle that in the `cc` pwsh wrapper's `try/finally`, which clears `tab.tab_title` (`Set-WezTabTitle ""`) on CC exit, allowing the formatter to fall through to `pane.title` (which by then is `pwsh • <leaf>` from the next prompt cycle).

## Why two backups (`bak.20260519` and `bak.20260519.original`) for `$PROFILE`?

The `.bak.20260519` backup is the state of `$PROFILE` immediately *before* the most recent overwrite. The `.bak.20260519.original` backup is the original-original pre-deployment state, recovered manually after a Phase 7 incident clobbered the first-day backup.

Going forward, the run_after script's hardened backup logic (see `cross-side-chezmoi.md` § "Backup hardening") prevents this from happening again. New same-day overwrites get `.bak.YYYYMMDD.1`, `.2`, etc.

If you want to clean up the doubled backup name in `$PROFILE`'s directory, delete `.bak.20260519` (the post-Phase-7 state, which is also captured in git history) and leave `.bak.20260519.original` (which is unique).

## Why is `tab_max_width = 120` and not bigger?

Tested at 80 (too tight for tilde-paths in subprojects), 120 (current — fits most paths comfortably), and "infinite via 999" (rejected because it makes WezTerm shrink all tabs proportionally when many are open, defeating readability).

120 cells gives ~14ch margin over the longest expected title (`cc ⏳ ap-bill-automation-standalone`) and leaves room for project name to be the dominant visual signal.

## Why `window_background_opacity = 1.0` (no transparency)?

Originally `0.97` (slight transparency). User rejected after seeing it — the slight bleed-through from background apps hurt readability of code/output. Switched to fully opaque.

If you want transparency back, change to `0.95` or so. Don't go below `0.85` — JetBrainsMono Nerd Font glyphs start to look fuzzy on real-world backgrounds.

## Why `INTEGRATED_BUTTONS|RESIZE` for `window_decorations`?

The original value was `'RESIZE'`, which draws only a resizable border — no OS title bar, and therefore *no* minimize/maximize/close buttons anywhere. That's a clean look but leaves no obvious way to close the window with the mouse. `'INTEGRATED_BUTTONS|RESIZE'` keeps the title-bar-less look but folds the standard window controls into the right edge of the **fancy** tab bar (so `use_fancy_tab_bar = true` is a hard requirement). The buttons (`integrated_title_buttons` defaults to `{ 'Hide', 'Maximize', 'Close' }`, right-aligned) render natively per platform — Windows-style on Windows, the native traffic-lights on macOS — so we set no `integrated_title_button_*` overrides. Applied to both `windows/.wezterm.lua` and `dot_wezterm.lua`.

## Why `LEADER o` to detach a tab instead of dragging it out?

WezTerm has no native mouse "tear-off": you cannot drag a tab off the bar to spawn a new window (long-standing limitation — see GH discussion #4080 and issue #549). The supported equivalent is the Lua `pane:move_to_new_window()`, which we bind to `LEADER o` (`Ctrl+A` then `o`) via `wezterm.action_callback`. `o` was the obvious free letter among the existing leader bindings (`w n \ - h l k j`) and mnemonic for "out". For ad-hoc use without a keybinding, the CLI does the same thing: `wezterm cli move-pane-to-new-tab --new-window`. Bound in both WezTerm configs.

## Why local-only chezmoi git (no remote yet)?

Originally pushed to nowhere. User chose local-first during the repo-promotion step. Adding a private GitHub remote is a follow-up: `git remote add origin git@github.com:<you>/terminal-stack.git && git push -u origin main`.

The Mac sync mentioned at project kickoff is enabled once a remote exists. Until then, manual file copies or local clones over the network.

## Why MIT license?

Standard, permissive, well-understood. The stack contains nothing proprietary. If you fork it for personal use, the source carries no hard-coded usernames (the sync hook resolves the Windows user at apply time — see `cross-side-chezmoi.md` § "Username resolution"). You may want to update the copyright line in `LICENSE`.

## Why `.gitattributes` with `eol=lf` instead of trusting developer git config?

Windows installers typically enable `core.autocrlf=true` at the system level. Without a `.gitattributes`, every git checkout on Windows rewrites every text file in the working tree as CRLF, which then propagates through chezmoi to the WSL home directory. Symptoms on first apply: `zsh ~/.zshrc:N: command not found: ^M` errors on every line, `run_after_90-sync-windows.sh` failing because `#!/usr/bin/env bash\r` is not an executable name, spurious `.bak` files on every subsequent apply because the source and destination differ on phantom line endings.

`* text=auto eol=lf` in `.gitattributes` overrides `core.autocrlf` at the repo level, so cloning is correct regardless of the developer's global config. Binary markers (`*.jpg binary`, etc.) protect non-text files from being touched.

Trade-off: PowerShell `*.ps1` files end up LF too. pwsh accepts both encodings natively, so this is fine. The only consumers that care about CRLF specifically are some legacy `cmd.exe` batch parsers, which we don't ship.

## Why single-source the starship config across Windows and WSL?

Originally there were two divergent `starship.toml` files — `dot_config/starship.toml` had the rounded-frame two-line prompt, `windows/.config/starship.toml` had a stripped-down single-line variant. Maintaining both meant any glyph or layout change had to be made twice and stayed out of sync until someone noticed.

The two sides have always wanted the same prompt structure — only the OS glyph differs at render time (starship auto-detects). So we collapsed to one canonical config at `dot_config/starship.toml` and a byte-identical mirror at `windows/.config/starship.toml`. Both deploy through their respective paths (chezmoi for WSL, `run_after_90-sync-windows.sh` for Windows). Edit `dot_config/starship.toml`, `cp` to the windows mirror, apply.

Trade-off: nothing automatic enforces the mirror — a CI check or pre-commit hook could, but for a single-maintainer repo this hasn't been worth wiring up yet.

## Why P/Invoke for the UTF-8 console codepage, not `[Console]::OutputEncoding`?

The .NET `[Console]::OutputEncoding` property is a cached value. When you set it, .NET calls `SetConsoleOutputCP()` under the hood. When you read it, .NET returns the cached value — it does NOT re-query Win32 to see whether something else (e.g., a native child process like Claude Code) changed the underlying codepage out from under it.

Native console TUIs routinely call `SetConsoleOutputCP()` directly to change the OS-level codepage during runtime, and don't always restore it on exit. After such a child process exits, .NET's cached `OutputEncoding` says "UTF-8" while the OS console is actually at CP437 — and any conditional fix that checks the .NET cache short-circuits as "already UTF-8", skipping the reset, leaving the user staring at `Γ¥»` mojibake.

The P/Invoke version (`Native.ConsoleCP::GetConsoleOutputCP()`) asks the OS directly. It runs once per prompt, costs a few microseconds, and is the authoritative source.

## Why OpenGL front_end instead of WezTerm's default WebGpu?

WebGpu is the default and generally faster on a discrete GPU, but on some Intel iGPU drivers (we've reproduced on the local Windows 11 setup) it has an output-buffer queueing behavior where rapid post-redirect output from a child process (Claude Code starting up, large `cat` of a colored log, etc.) doesn't trigger an immediate redraw. The buffer flushes only when WezTerm processes the next input event — which manifests as "type `ccd`, hit Enter, nothing happens, hit space, Claude Code's whole intro screen suddenly appears."

`OpenGL` doesn't have this problem on the same hardware. The trade-off is slightly less polished animation/scrolling under heavy load. For an interactive terminal workflow that's the right call. If a future user is on a discrete GPU and wants WebGpu back, change `config.front_end = 'OpenGL'` to `'WebGpu'` and restore the `webgpu_power_preference` + `max_fps` lines.

## Why not just use a single GUI tool like Microsoft Terminal?

Microsoft Terminal is fine, but:
- WezTerm has better Lua-based programmability.
- WezTerm's fancy tab bar with custom format hooks beats MT's tab UI.
- WezTerm has better support for WSL launching with shell-specific args (the `launch_menu` entries).
- WezTerm renders better on high-DPI displays (subjective).

If MT is what you actually want, this repo's chezmoi side will still mostly work — you'd just skip the `.wezterm.lua` deployment and accept that MT's config (in `settings.json` under `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_...`) is a separate concern.

## Why guard `ws*` on `/mnt/c` existence rather than `$WSL_INTEROP`?

The five zsh workspace-nav functions (`ws`, `wsp`, `wspu`, `wscalibra`, `wsnetsuite`) only make sense on WSL where the Windows-side workspace tree is mounted at `/mnt/c/DATA/Workspace*`. The same `dot_zshrc` ships unchanged to native Debian/Ubuntu servers via `bootstrap/linux-bootstrap.sh`, where `/mnt/c` doesn't exist. Three plausible guards:

1. `grep -qi microsoft /proc/version` — detects WSL kernel.
2. `[[ -n "$WSL_INTEROP" ]]` — detects WSL with Windows interop enabled.
3. `[[ -d /mnt/c/DATA/Workspace ]]` — detects the actual path the functions would `cd` into.

We use (3). It's the loosest filter on platform identity but the tightest on *what could go wrong*: if WSL is present yet the workspace tree happens to live elsewhere (fresh clone of the dotfiles onto a new WSL distro before the workspace is laid down, or a coworker forking the repo whose layout differs), (1) and (2) would still define functions that error on call. (3) only defines them when calling them will actually work.

The cost is one stat at shell startup. On WSL with `/mnt/c` cached it's microseconds; on native Linux it's a quick negative result. Cheap enough that the same pattern should be the default for any future Windows-path shortcut we port to zsh — guard on the specific path, not on platform.

## Why convert zsh `cc*` from aliases to functions just for the tab title?

Aliases can't run code around the wrapped command. Setting and clearing the WezTerm tab title requires a pre-step and a post-step around the `claude` invocation. Either we (a) leave zsh as plain aliases and accept that only the PowerShell side gets the `cc • <leaf>` tab title, or (b) promote zsh to functions matching the PowerShell try/finally pattern. We chose (b) for the same reason the PowerShell side does it: when you have four or five Claude panes open in WezTerm under WSL, the tab title is what tells you which project each pane is for. Without it the tabs are all just `pwsh` / `zsh` and you have to click each one to remember. The cost is a one-line helper (`_wez_tab_title`) and a small amount of bookkeeping (`local rc=$?; ... return $rc`) since zsh has no `try/finally` — that bookkeeping matters because without it the function would always exit 0 and mask Claude's exit code from scripts that wrap it.

The `cc • <leaf>` text and the per-prompt clearing behavior are covered separately under "Why per-tab `cc • <project>` instead of one big tab name?" and "Why `wezterm cli set-tab-title` and not OSC 0?" — this entry is just about *why functions, not aliases*.

## Why the Windows settings template tracks the claude-obsidian + gitkraken plugins

`~/.claude/settings.json` is managed whole-file (see "Why a whole-file `~/.zshrc` and a marker-block `$PROFILE`?"), and on the Windows side it's produced from `windows/.claude/settings.json.tmpl` by the sync hook. Claude Code enables a plugin by writing `enabledPlugins` + `extraKnownMarketplaces` keys into that same file — but those writes happen *live* (via the `/plugin` UI), so they drift out of the tracked template. The first `chezmoi apply` after enabling a plugin overwrites the live file with the template and silently **disables every plugin** — here, both `claude-obsidian` and GitKraken's `gitkraken-hooks`.

So the template now carries both blocks. The gitkraken marketplace path uses `__WIN_USER__` and stays user-portable. The claude-obsidian marketplace is a `directory` source pointing at a local clone (`C:/DATA/Workspace_Public/claude-obsidian`) — a machine-specific path, and the one place besides `LICENSE` where a non-tokenizable local path appears in the tracked tree. That's a deliberate trade-off: there is no username to tokenize and no "local override" merge for a whole-file JSON config, so preserving the plugin across applies means committing the path. On a fork or another machine that one marketplace simply won't resolve — which is harmless, Claude Code skips a missing marketplace; update or drop the path there.

Alternative considered: marker-block management of `settings.json` (like `$PROFILE`) so live plugin writes survive untouched. Rejected — `settings.json` is strict JSON with no comment syntax to anchor markers, and we own the rest of the file anyway. Whole-file plus tracked plugin blocks is simpler. The companion machine-state cleanup (the GitKraken AI-hook log flood, the 0-byte `gk.exe` symlink) is documented in `powershell-quirks.md` § "GitKraken `gk ai hook` plugin".

## Why a separate `dot_wezterm.lua` for macOS

WezTerm reads `~/.wezterm.lua` from the home directory of whatever machine the GUI runs on. On Windows that's `C:\Users\<you>\.wezterm.lua`, deployed from `windows/.wezterm.lua` by the sync hook. On WSL the GUI is still the *Windows* WezTerm, so WSL's Linux home gets no WezTerm config at all — correct, because nothing there would read it. On macOS, WezTerm runs natively and reads the macOS home directory, so the Mac genuinely needs its own `~/.wezterm.lua`.

Three ways to produce it:

1. **Sync `windows/.wezterm.lua` to the Mac too.** Rejected — that file hardcodes `default_prog = { 'pwsh.exe' }` and a `launch_menu` with `wsl.exe`. Neither exists on macOS; WezTerm would error or spawn nothing.
2. **One `.tmpl` that forks on `.chezmoi.os`.** Workable, but the Windows file isn't chezmoi-managed at all (it lives under `windows/` and ships via the sync hook), so there's no single file to template — the Windows and non-Windows copies travel different roads by design.
3. **A standalone `dot_wezterm.lua`** at the chezmoi root, applied only on macOS.

We chose (3). The new file mirrors `windows/.wezterm.lua`'s visual settings (font stack, Catppuccin Mocha, fancy tab bar, leader key, pane keys, `format-tab-title` / `update-right-status`, `front_end = 'OpenGL'`) and intentionally diverges in exactly two places: it omits `default_prog`/`launch_menu` (macOS defaults to the login shell), and its final font fallback is `Menlo` instead of `Cascadia Code` because Menlo ships with macOS and Cascadia does not.

Native-Linux hosts in this stack are headless (reached over ssh/PuTTY) and run no WezTerm GUI, so applying `~/.wezterm.lua` there would just litter the home directory with a dead file. To prevent that, `.chezmoiignore` — which chezmoi evaluates as a template — gained a `{{ if ne .chezmoi.os "darwin" }} .wezterm.lua {{ end }}` block. The file is therefore applied on macOS only. The gate keys off the built-in `.chezmoi.os`, not `[data].os`, so it works even when the bootstrap-written `chezmoi.toml` omits the `[data]` section.

Trade-off: like the single-sourced `starship.toml`, nothing automatic keeps `dot_wezterm.lua` and `windows/.wezterm.lua` visually in sync — a shared change has to be made in both. `dot_wezterm.lua`'s header comment says so.

## Why a Chocolatey option for the Windows bootstrap (winget kept as the default)

The Windows bootstrap installs its binaries through winget, which is the right call on the primary target (Windows 11): winget ships with the OS via App Installer, needs no extra install, and carries the WezTerm *nightly* channel the stack prefers. But winget is **not supported on Windows Server 2019** — Server has no Microsoft Store, and getting winget there means manually sideloading the App Installer `.msixbundle` plus its `VCLibs`/`UI.Xaml` dependencies, an unsupported and version-fragile dance. The stack is genuinely useful on a server (Starship prompt, the CLI tools, the pwsh `$PROFILE`, the Claude Code hooks all work headless), so cutting off every winget-less host was too blunt.

`bootstrap/windows-bootstrap.ps1` gained a `-PackageManager winget|choco` switch (and `install.ps1` an `$env:TERMINAL_STACK_PKGMGR` env var that feeds it). **winget stays the default** — the Windows 11 path is byte-for-byte unchanged. The choco path is purely additive: a parallel package-name list (`$corePackagesChoco`, kept in the same order as the winget `$corePackages`), an `Install-Chocolatey` helper that installs Chocolatey itself on first use (requires an elevated session), and `choco install` in place of `winget install`. Chocolatey is well-supported on Server 2019 and ships every tool the stack needs.

Two deliberate compromises on the choco side: it installs WezTerm **stable**, not nightly (Chocolatey has no nightly channel) — fine, since a server rarely runs the WezTerm GUI anyway; and Chocolatey is a machine-wide package manager that the choco path installs if absent, so the first run must be elevated. We did *not* add a third package manager (scoop) — two is enough to cover "has winget" and "doesn't", and scoop's per-user model doesn't match the machine-scope installs the rest of the path assumes.

Alternative considered: auto-detect and silently fall back to choco whenever winget is missing. Rejected as the *default* behavior — silently installing a machine-wide package manager is too surprising for an `irm | iex` one-liner. Instead the fallback is explicit (`$env:TERMINAL_STACK_PKGMGR='choco'`), and the winget-missing error message now points at it. (`install.ps1` *will* auto-pick choco if it is already installed, but it never installs choco behind your back.)

A caveat that bites on a *shared or production* server, independent of package manager: `scripts/sync-windows.ps1` (and the bash `run_after_90-sync-windows.sh`) deploy the pwsh `$PROFILE` **whole-file** (with a `.bak.<date>` backup), not via marker-block merge — so an account that already has a `$PROFILE` has it replaced, not merged. That contradicts the "marker-block `$PROFILE`" framing under "Why a whole-file `~/.zshrc` and a marker-block `$PROFILE`?", which describes how the *source* file is authored, not how the Windows-native sync writes it. On a server, back up and diff the target profile before applying.
