# terminal-stack

A reproducible Windows 11 + WSL2 Ubuntu (+ macOS, stubbed) terminal-development stack: WezTerm + tmux + Starship + Claude Code wrappers + Nerd Font + modern CLI tools, with a single-source-of-truth chezmoi repo that manages config files on both sides of the Windows/Linux divide.

Built incrementally on 05/19/2026 over a single working session. Every commit is canonical change history; see `CHANGELOG.md` for curated highlights and `git log` for the raw record.

## What you get

- **WezTerm nightly** with a fancy tab bar at the bottom, JetBrainsMono Nerd Font at 11.5pt, 12-hour clock in the right-status, `Ctrl+V` rebound for synthetic-paste compatibility (Wispr Flow, etc.).
- **PowerShell 7 `$PROFILE`** with Starship prompt, OSC 7 cwd hint, tilde-abbreviated tab title, UTF-8 console restore (heals Claude-Code `Γ¥»` mojibake), and `cc`/`ccc`/`ccd`/`ccdc`/`cca` wrappers that set per-tab project titles.
- **WSL zsh** with oh-my-zsh, theme cleared so Starship owns the prompt, a `precmd` that sets tab titles, and `ccs` / `ssht` helpers for tmux-attached Claude Code and SSH sessions.
- **Claude Code hooks** that flip the WezTerm tab title to `cc ⏳ <project>` while Claude is thinking and `cc ✓ <project>` when it's waiting for your input — symmetric across Windows pwsh and WSL bash.
- **Modern CLI tools**: eza, zoxide, fzf, bat, git-delta, ripgrep — installed on both sides.
- **tmux** configured for Claude Code passthrough, extended keys, and mouse mode.

## Architecture in 30 seconds

This is a chezmoi repo with a twist: chezmoi natively manages WSL home (`~/.zshrc`, `~/.tmux.conf`, `~/.config/starship.toml`, `~/.claude/*`), but Windows-side files live in a `windows/` subdirectory excluded from chezmoi's normal apply via `.chezmoiignore`. A `run_after_90-sync-windows.sh` hook then mirrors `windows/` to `/mnt/c/Users/<user>/` on every `chezmoi apply`, with same-day `.bak.YYYYMMDD[.N]` backups for any file it overwrites.

Single source of truth, single `chezmoi apply`, two operating systems updated. See `ARCHITECTURE.md` for the long version.

## Install

Two paths, pick one:

- **Scripted bootstrap** — `bootstrap/windows-bootstrap.ps1` then `bootstrap/wsl-bootstrap.sh` then `chezmoi init --apply <local-path-or-remote>`. Fastest on a fresh machine. See `INSTALL.md` § Scripted.
- **Manual walkthrough** — follow `INSTALL.md` § Manual. Mirrors the Phase 0–10 sequence the stack was originally built with. Slower, but every step is documented with its "why".

For an existing machine with chezmoi already pointed elsewhere, just clone this repo and write `~/.config/chezmoi/chezmoi.toml` with `sourceDir = "<absolute path to your clone>"`.

## Layout

```
terminal-stack/
├── README.md             # this file
├── ARCHITECTURE.md       # cross-side chezmoi, run_after hook, sync semantics
├── CHANGELOG.md          # curated change history
├── INSTALL.md            # manual + scripted install paths
├── LICENSE               # MIT
├── bootstrap/            # one-shot installers for fresh machines
│   ├── windows-bootstrap.ps1
│   ├── wsl-bootstrap.sh
│   └── mac-bootstrap.sh  # UNTESTED stub
├── docs/                 # design-decision documentation
│   ├── cross-side-chezmoi.md
│   ├── powershell-quirks.md
│   └── decisions.md
├── dot_zshrc             # ↘ chezmoi-managed (WSL home)
├── dot_tmux.conf         #
├── dot_config/           #
├── dot_claude/           #
├── windows/              # ↘ NOT chezmoi-managed; synced by run_after hook
│   ├── .wezterm.lua      #
│   ├── .config/          #
│   ├── Documents/        #
│   └── .claude/          #
└── run_after_90-sync-windows.sh
```

## Repeatability

The work was done on Windows 11 Pro 26200 + WSL2 Ubuntu 26.04 LTS + PowerShell 7.6.1. The repo carries no hard-coded usernames: the WSL bootstrap prompts for your Windows username (defaulting to whatever `cmd.exe` reports via interop) and persists it under `[data].windowsUsername` in `~/.config/chezmoi/chezmoi.toml`. The sync hook substitutes that value into `windows/**/*.tmpl` files (e.g., `windows/.claude/settings.json.tmpl`) at apply time, and WSL-side templates use chezmoi's native `{{ .chezmoi.homeDir }}`. See `ARCHITECTURE.md` § "Username resolution" for the resolution order.

## License

MIT. See `LICENSE`.
