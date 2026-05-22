# install.ps1 — one-liner Windows installer for the terminal-stack.
# Usage (from a fresh box, PowerShell 7+):
#   irm https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install.ps1 | iex
#
# Optional: override the clone location before invoking.
#   $env:TERMINAL_STACK_DIR = 'D:\dotfiles\terminal-stack'; irm ... | iex
#
# What it does:
#   1. Verifies winget is available (App Installer).
#   2. Ensures Git is installed (winget Git.Git if missing).
#   3. Clones github.com/martsamp77/terminal-stack to $TERMINAL_STACK_DIR
#      (default: $env:USERPROFILE\terminal-stack). git pull if already cloned.
#   4. Runs bootstrap\windows-bootstrap.ps1 from the clone.
#   5. Prints the WSL one-liner for the next step (chezmoi apply runs in WSL).

$ErrorActionPreference = 'Stop'

Write-Host '==> terminal-stack Windows installer'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Running under PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended; the stack's `$PROFILE` targets pwsh 7. Continuing."
}

# 1. winget preflight
try { & winget --version | Out-Null } catch {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

# 2. Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '==> Installing Git (winget Git.Git)'
    & winget install --id Git.Git --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 |
        Select-Object -Last 3
    # Add Git to current session PATH so the clone below works without a new shell.
    $gitDir = Join-Path $env:ProgramFiles 'Git\cmd'
    if (Test-Path (Join-Path $gitDir 'git.exe')) {
        $env:Path = "$gitDir;$env:Path"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git not on PATH after install. Open a new pwsh window and re-run the installer."
    }
} else {
    Write-Host "==> git already present ($((Get-Command git).Source))"
}

# 3. Clone
$repoUrl = 'https://github.com/martsamp77/terminal-stack.git'
$targetDir = if ($env:TERMINAL_STACK_DIR) {
    $env:TERMINAL_STACK_DIR
} else {
    Join-Path $env:USERPROFILE 'terminal-stack'
}

if (Test-Path (Join-Path $targetDir '.git')) {
    Write-Host "==> Repo already at $targetDir; git pull"
    & git -C $targetDir pull --ff-only
} else {
    Write-Host "==> Cloning $repoUrl -> $targetDir"
    & git clone $repoUrl $targetDir
}

# 4. Bootstrap (winget packages + binaries)
$bootstrap = Join-Path $targetDir 'bootstrap\windows-bootstrap.ps1'
if (-not (Test-Path $bootstrap)) {
    throw "Expected bootstrap script not found at $bootstrap"
}
Write-Host "==> Running $bootstrap"
& $bootstrap

# 5. Sync windows/** to %USERPROFILE% (PowerShell-native equivalent of the WSL
#    run_after hook). Lands $PROFILE, .wezterm.lua, .claude\settings.json, etc.
#    without needing WSL.
$sync = Join-Path $targetDir 'scripts\sync-windows.ps1'
if (Test-Path $sync) {
    Write-Host "==> Running $sync"
    & $sync -SourceDir $targetDir
} else {
    Write-Warning "$sync not found; Windows-side dotfiles were not applied."
}

# 6. Next-step hint
Write-Host ''
Write-Host '==> Windows install done.'
Write-Host "    Clone: $targetDir"
Write-Host '    Update later from any pwsh window:  ts-update'
Write-Host ''
Write-Host '    If you also use WSL Ubuntu, apply the WSL-side dotfiles too:'
Write-Host '        curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-wsl.sh | bash'
Write-Host ''
Write-Host '    For native Linux / macOS hosts (run on that machine instead):'
Write-Host '        curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-linux.sh | bash'
Write-Host '        curl -fsSL https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install-mac.sh | bash'
