# install.ps1 — one-liner Windows installer for the terminal-stack.
# Usage (from a fresh box, PowerShell 7+):
#   irm https://raw.githubusercontent.com/martsamp77/terminal-stack/main/install.ps1 | iex
#
# Optional: override the clone location before invoking.
#   $env:TERMINAL_STACK_DIR = 'D:\dotfiles\terminal-stack'; irm ... | iex
#
# Optional: choose the package manager (default winget). On a host without winget
# (e.g. Windows Server 2019, which has no Microsoft Store), use Chocolatey instead:
#   $env:TERMINAL_STACK_PKGMGR = 'choco'; irm ... | iex
#
# What it does:
#   1. Selects a package manager (winget default; choco via $env:TERMINAL_STACK_PKGMGR).
#   2. Ensures Git is installed (via the selected package manager if missing).
#   3. Clones github.com/martsamp77/terminal-stack to $TERMINAL_STACK_DIR
#      (default: $env:USERPROFILE\terminal-stack). git pull if already cloned.
#   4. Runs bootstrap\windows-bootstrap.ps1 from the clone.
#   5. Prints the WSL one-liner for the next step (chezmoi apply runs in WSL).

$ErrorActionPreference = 'Stop'

Write-Host '==> terminal-stack Windows installer'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Running under PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended; the stack's `$PROFILE` targets pwsh 7. Continuing."
}

# 1. Package-manager selection + preflight.
#    Default winget (Windows 11). $env:TERMINAL_STACK_PKGMGR='choco' forces Chocolatey
#    (the path for Windows Server 2019 and other hosts without winget).
$pkgMgr = $env:TERMINAL_STACK_PKGMGR
if ($pkgMgr) {
    $pkgMgr = $pkgMgr.ToLower()
    if ($pkgMgr -notin @('winget', 'choco')) {
        throw "TERMINAL_STACK_PKGMGR must be 'winget' or 'choco' (got '$pkgMgr')."
    }
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    $pkgMgr = 'winget'
} elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    $pkgMgr = 'choco'
} else {
    $pkgMgr = 'winget'   # nothing detected; fall through to the winget guidance below
}
Write-Host "==> Package manager: $pkgMgr"

if ($pkgMgr -eq 'winget') {
    try { & winget --version | Out-Null } catch {
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run — or on a host without winget (e.g. Windows Server 2019), re-run with `$env:TERMINAL_STACK_PKGMGR='choco' to use Chocolatey instead."
    }
}
# choco preflight (install Chocolatey if missing) is handled by windows-bootstrap.ps1 -PackageManager choco.

# 2. Git (needed to clone) — via the selected package manager.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if ($pkgMgr -eq 'winget') {
        Write-Host '==> Installing Git (winget Git.Git)'
        & winget install --id Git.Git --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 |
            Select-Object -Last 3
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host '==> Installing Git (choco git)'
        & choco install git -y --no-progress 2>&1 | Select-Object -Last 3
    } else {
        # choco mode but Chocolatey isn't installed yet (the repo's installer runs later).
        throw "git is required to clone the repo, but neither git nor Chocolatey is installed. Install git (or install Chocolatey then 'choco install git'), then re-run."
    }
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

# 4. Bootstrap (package-manager installs + binaries)
$bootstrap = Join-Path $targetDir 'bootstrap\windows-bootstrap.ps1'
if (-not (Test-Path $bootstrap)) {
    throw "Expected bootstrap script not found at $bootstrap"
}
Write-Host "==> Running $bootstrap -PackageManager $pkgMgr"
& $bootstrap -PackageManager $pkgMgr

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
