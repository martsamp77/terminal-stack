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

## Why `tab_bar_at_bottom = true` with `use_fancy_tab_bar = true`?

The fancy tab bar usually goes at the top (matches browser conventions). We override to put it at the bottom because:
- That's where my eyes are when reading terminal output (the cursor sits low).
- It pairs cleanly with the right-status (workspace · cwd · time) which renders in the same bar.
- WezTerm's `tab_bar_at_bottom` does respect fancy mode (verified during deployment).

If a future WezTerm release breaks fancy + bottom, fall back to simple mode (`use_fancy_tab_bar = false`) which loses the smaller frame font but keeps the bottom position.

## Why `window_background_opacity = 1.0` (no transparency)?

Originally `0.97` (slight transparency). User rejected after seeing it — the slight bleed-through from background apps hurt readability of code/output. Switched to fully opaque.

If you want transparency back, change to `0.95` or so. Don't go below `0.85` — JetBrainsMono Nerd Font glyphs start to look fuzzy on real-world backgrounds.

## Why local-only chezmoi git (no remote yet)?

Originally pushed to nowhere. User chose local-first during the repo-promotion step. Adding a private GitHub remote is a follow-up: `git remote add origin git@github.com:msampson/terminal-stack.git && git push -u origin main`.

The Mac sync mentioned at project kickoff is enabled once a remote exists. Until then, manual file copies or local clones over the network.

## Why MIT license?

Standard, permissive, well-understood. The stack contains nothing proprietary. If you fork it for a different user, just edit the personal paths (search the repo for `msampson`) and update the copyright line in `LICENSE`.

## Why not just use a single GUI tool like Microsoft Terminal?

Microsoft Terminal is fine, but:
- WezTerm has better Lua-based programmability.
- WezTerm's fancy tab bar with custom format hooks beats MT's tab UI.
- WezTerm has better support for WSL launching with shell-specific args (the `launch_menu` entries).
- WezTerm renders better on high-DPI displays (subjective).

If MT is what you actually want, this repo's chezmoi side will still mostly work — you'd just skip the `.wezterm.lua` deployment and accept that MT's config (in `settings.json` under `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_...`) is a separate concern.
