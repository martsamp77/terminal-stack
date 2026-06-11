# Install

Two paths. Pick the one matching how much trust you have in the scripts.

## Scripted (fastest)

### Quick install (one-liner per environment)

The fastest path: a single command per environment, runnable from a fresh box. Installs prereqs, clones the repo, runs the bootstrap, and ends with `chezmoi apply`. Idempotent.

```powershell
# Windows 11 — PowerShell 7+
irm https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install.ps1 | iex
```

```sh
# WSL Ubuntu — run after the Windows one-liner
curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-wsl.sh | bash

# Native Debian/Ubuntu
curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-linux.sh | bash

# macOS
curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-mac.sh | bash
```

Defaults: Windows clones to `%USERPROFILE%\terminal-stack` (WSL sees it as `/mnt/c/Users/<you>/terminal-stack`); Linux/macOS clone to `~/code/terminal-stack`. Override with `$env:TERMINAL_STACK_DIR` (PowerShell) or `TERMINAL_STACK_DIR=…` (bash). The WSL installer auto-detects your Windows username via `cmd.exe` interop, so it runs without prompts under `curl | bash`.

**Install-time questions.** The bootstraps ask two questions, each skippable via env var (so scripted installs stay non-interactive — the prompts read `/dev/tty` directly and degrade to their defaults when no terminal is attached):

- **Workspace directory** — pre-filled with the autodetected candidate (`C:\DATA\Workspace` / `~/Documents/Workspace` / `~/workspace` / `~/Workspace`). Press Enter to accept. The answer is persisted to `~/.zshrc.local` (zsh) or `Documents\PowerShell\profile.local.ps1` (pwsh) *only* when it differs from the autodetect — the shells re-detect standard locations on their own. Skip with `WORKSPACE_DIR=/path` / `$env:WORKSPACE_DIR`.
- **Extra tools** (`tldr` always; `nvtop` on GPU hosts; `lazydocker` where docker exists) — default No. Skip with `TS_EXTRA_TOOLS=1` to force-install. Not offered on Windows.

If you want to walk through each step instead (recommended for first-time inspection, or when chezmoi would clobber an existing hand-edited dotfile), keep reading.

### Step-by-step (same end result, with intermediate stops)

For a fresh Windows 11 + WSL2 machine, follow sections 1 → 4 below. For a native Linux box (Debian/Ubuntu), skip sections 1–2 and follow section 2L (Linux) → 3 → 4. For a macOS host, skip sections 1–2 and follow section 2M (macOS) → 3 → 4. The WSL bootstrap will prompt for your Windows username (it pre-fills the value reported by `cmd.exe` via interop, so usually you can just press Enter); the Linux and macOS bootstraps have no Windows-side prompts.

### 1. Windows side

Open PowerShell 7 (`pwsh`) and run (adjust the path if you cloned elsewhere — the default for the one-liner installer is `$env:USERPROFILE\terminal-stack`):

```powershell
cd $env:USERPROFILE\terminal-stack
.\bootstrap\windows-bootstrap.ps1
```

This installs:
- WezTerm nightly (`wez.wezterm.nightly`)
- JetBrainsMono Nerd Font (`DEVCOM.JetBrainsMonoNerdFont`)
- Starship (`Starship.Starship`)
- chezmoi (`twpayne.chezmoi`)
- eza, fzf, bat, delta, ripgrep, zoxide (one winget each)

Pass `-WhatIf` to preview without installing. UAC prompts on machine-scope installs; approve each.

### 2. WSL side

Open WSL Ubuntu (substitute your Windows username for `<you>`):

```sh
wsl -d Ubuntu
cd /mnt/c/Users/<you>/terminal-stack
bash ./bootstrap/wsl-bootstrap.sh
```

This installs:
- zsh + git + curl + unzip
- oh-my-zsh (unattended)
- Sets login shell to zsh for current user
- chezmoi (curl installer to `~/.local/bin/`)
- Starship (curl installer to `/usr/local/bin/`)
- `fonts-jetbrains-mono` (regular variant) + Nerd Font variant zip
- eza, zoxide, fzf, bat (with `batcat` → `bat` symlink), git-delta, ripgrep
- tmux

Re-run as needed; the script is idempotent.

### 2L. Linux side (native Debian/Ubuntu, instead of WSL)

For any native Debian/Ubuntu host:

```sh
git clone <repo-url> ~/code/terminal-stack    # or your chosen path
cd ~/code/terminal-stack
bash ./bootstrap/linux-bootstrap.sh
```

Installs the same toolchain as the WSL bootstrap (zsh, oh-my-zsh, chezmoi, Starship, Nerd Font, modern CLI tools), writes `~/.config/chezmoi/chezmoi.toml` with `sourceDir` pointing at the clone, and skips all Windows-side handling. The post-apply sync hook self-no-ops when `/mnt/c/Users/` is absent, so `chezmoi apply` Just Works.

Override the source path via env var if you cloned elsewhere:

```sh
SOURCE_DIR=/srv/dotfiles/terminal-stack bash ./bootstrap/linux-bootstrap.sh
```

Re-run as needed; the script is idempotent.

### 2M. macOS side (instead of WSL/Linux)

For a MacBook or any macOS host:

```sh
git clone <repo-url> ~/code/terminal-stack    # or your chosen path
cd ~/code/terminal-stack
bash ./bootstrap/mac-bootstrap.sh
```

Installs via Homebrew (installing Homebrew itself first if absent):
- zsh, git, tmux
- oh-my-zsh (unattended)
- chezmoi, Starship
- eza, zoxide, fzf, bat, git-delta, ripgrep
- WezTerm nightly (`--cask wezterm@nightly`) and JetBrainsMono Nerd Font (`--cask font-jetbrains-mono-nerd-font`)

The plain `wezterm` cask is pinned to the stale `20240203` stable; the stack uses the `wezterm@nightly` cask so macOS matches the WezTerm nightly installed on the Windows side.

It also writes `~/.config/chezmoi/chezmoi.toml` with `sourceDir` pointing at the
clone (auto-detected from the script's own location). macOS keeps the system
`/bin/zsh` as the login shell; the Windows-side `windows/**` subtree is skipped
automatically because `/mnt/c/Users/` doesn't exist.

Override the source path via env var if you cloned elsewhere:

```sh
SOURCE_DIR=~/dotfiles/terminal-stack bash ./bootstrap/mac-bootstrap.sh
```

Re-run as needed; the script is idempotent.

### 3. Apply chezmoi

The WSL bootstrap already wrote `~/.config/chezmoi/chezmoi.toml` with `sourceDir` and `[data].windowsUsername`. Just apply:

```sh
# Inside WSL
~/.local/bin/chezmoi apply -v
```

The Linux and macOS bootstraps likewise write `~/.config/chezmoi/chezmoi.toml`
(no `windowsUsername` — there's no Windows side). If you skipped the bootstrap,
write it by hand — chezmoi expands a leading `~` but **not** `$HOME`, so use a
tilde or an absolute path:

```sh
mkdir -p ~/.config/chezmoi
echo 'sourceDir = "~/code/terminal-stack"' > ~/.config/chezmoi/chezmoi.toml  # adjust path
chezmoi apply -v
```

(macOS and native Linux skip the Windows side automatically: the `run_after` hook's `/mnt/c/Users/<user>/` existence check noops when the path doesn't exist.)

For per-machine overrides (peer-sync helpers, server-role aliases, anything that shouldn't propagate via the shared repo), copy `~/.zshrc.local.example` to `~/.zshrc.local` and edit. `dot_zshrc` sources it at the end if present.

### 4. Reopen WezTerm

Open a new WezTerm tab — auto-reload picks up the new `.wezterm.lua`. Open a pwsh tab and a `Alt-L → WSL zsh` tab to confirm starship renders correctly with the Nerd Font.

On macOS, quit and relaunch WezTerm so it sets JetBrainsMono Nerd Font from the freshly-applied `~/.wezterm.lua`, then open a new tab and confirm the Starship two-line prompt renders with glyphs. WezTerm itself must be set to a Nerd Font for the launch-window prompt; the config does that automatically.

## Manual

For when you want to understand each step. Every command is annotated; numbered headings just keep the steps ordered.

### Phase 0 — Detect environment

Confirm versions and existing state:

```powershell
$PSVersionTable.PSVersion                # expect 7.6+
wsl -l -v                                # confirm Ubuntu present
winget --version                         # confirm winget available
```

```sh
# Inside WSL
cat /etc/os-release | grep PRETTY_NAME   # confirm Ubuntu 26.04 or similar
```

### Phase 0.5 — WSL prereqs

```sh
sudo apt-get update
sudo apt-get install -y zsh git curl unzip
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s /usr/bin/zsh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
```

Log out and back in (or close/reopen the WSL terminal) so the new login shell takes effect.

### Phase 1 — WezTerm nightly (Windows)

```powershell
winget install --id wez.wezterm.nightly --exact --silent
wezterm.exe --version    # expect 2025+ build, not 20240203
```

### Phase 2 — `.wezterm.lua`

Will land via `chezmoi apply` in step "Apply chezmoi" at the bottom of this manual path.

### Phase 3 — JetBrainsMono Nerd Font

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --silent
```

```sh
# WSL — both apt regular and the Nerd Font zip from upstream
sudo apt-get install -y fonts-jetbrains-mono
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fL -o /tmp/jbm-nf.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -q /tmp/jbm-nf.zip -d ~/.local/share/fonts/JetBrainsMonoNerdFont/
rm /tmp/jbm-nf.zip
fc-cache -f
```

### Phase 4 — tmux

Will land via `chezmoi apply`. Install the binary first:

```sh
sudo apt-get install -y tmux
```

### Phase 5 — Starship + shell hookups

```powershell
winget install --id Starship.Starship --exact --silent
```

```sh
sudo curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin
```

`.zshrc` (full file) and `$PROFILE` (marker-block injection) will be handled by `chezmoi apply`.

### Phase 6 — Shell helpers

Lands via `chezmoi apply` (zsh `ccs` / `ssht`).

### Phase 7 — Modern CLI tools

```powershell
winget install --id eza-community.eza --exact --silent
winget install --id junegunn.fzf --exact --silent
winget install --id sharkdp.bat --exact --silent
winget install --id dandavison.delta --exact --silent
winget install --id BurntSushi.ripgrep.MSVC --exact --silent
# zoxide if not already from Chocolatey:
# winget install --id ajeetdsouza.zoxide --exact --silent
```

```sh
sudo apt-get install -y eza zoxide fzf bat git-delta ripgrep
mkdir -p ~/.local/bin
ln -sf /usr/bin/batcat ~/.local/bin/bat
```

### Phase 8 — Apply chezmoi

```sh
# Detect your Windows username (or hard-code it below)
WIN_USER=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | tr -d '\r\n')
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<EOF
sourceDir = "/mnt/c/Users/${WIN_USER}/terminal-stack"

[data]
windowsUsername = "$WIN_USER"
EOF
~/.local/bin/chezmoi diff      # preview what will change (WSL targets only)
~/.local/bin/chezmoi apply -v
```

You'll see one creation summary plus a `sync-windows: user=<you>, …` line confirming the run_after hook ran.

If you skip the `[data].windowsUsername` line, the sync hook will fall back to `cmd.exe /c echo %USERNAME%` via interop and use that — explicitly setting it just makes the value stable across machine renames.

### Phase 9 — Verify

```powershell
wezterm.exe --version
starship --version
pwsh -c '$PSVersionTable.PSVersion'
```

```sh
zsh --version
tmux -V
eza --version | head -1
zoxide --version
fzf --version
bat --version
delta --version
rg --version | head -1
chezmoi doctor | head -5
```

Open WezTerm, confirm tab status bar shows workspace · cwd. Open a zsh pane, confirm Starship prompt with the branch glyph renders. Open a pwsh pane, run `cc` from a project dir, confirm tab title flips to `cc • <project>`.

### Phase 10 — Done

`git log --oneline` shows the prior history. Any subsequent changes you make should land as new commits with marker blocks where they belong.
