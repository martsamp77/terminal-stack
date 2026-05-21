# Install

Two paths. Pick the one matching how much trust you have in the scripts.

## Scripted (fastest)

For a fresh Windows 11 + WSL2 machine. The WSL bootstrap will prompt for your Windows username (it pre-fills the value reported by `cmd.exe` via interop, so usually you can just press Enter).

### 1. Windows side

Open PowerShell 7 (`pwsh`) and run:

```powershell
cd C:\DATA\Workspace\terminal-stack
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

Open WSL Ubuntu:

```sh
wsl -d Ubuntu
cd /mnt/c/DATA/Workspace/terminal-stack
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

### 3. Apply chezmoi

The WSL bootstrap already wrote `~/.config/chezmoi/chezmoi.toml` with `sourceDir` and `[data].windowsUsername`. Just apply:

```sh
# Inside WSL
~/.local/bin/chezmoi apply -v
```

Or, on a Mac (no Windows side to sync):

```sh
# Inside Terminal / iTerm
mkdir -p ~/.config/chezmoi
echo 'sourceDir = "$HOME/code/terminal-stack"' > ~/.config/chezmoi/chezmoi.toml  # adjust path
chezmoi apply -v
```

(macOS skips the Windows side automatically: the `run_after` hook's `/mnt/c/Users/<user>/` existence check noops when the path doesn't exist.)

### 4. Reopen WezTerm

Open a new WezTerm tab — auto-reload picks up the new `.wezterm.lua`. Open a pwsh tab and a `Alt-L → WSL zsh` tab to confirm starship renders correctly with the Nerd Font.

## Manual

For when you want to understand each step. Mirrors the Phase 0 → Phase 10 sequence the stack was originally built with.

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
sourceDir = "/mnt/c/DATA/Workspace/terminal-stack"

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
