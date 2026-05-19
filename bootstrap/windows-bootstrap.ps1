# windows-bootstrap.ps1 — install Windows-side prerequisites for the terminal-stack
# Idempotent: re-run safely. Each install runs only if winget reports the package not installed.
# Pass -WhatIf to dry-run.
# See ../INSTALL.md § Scripted for context.

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludeOptional
)

$ErrorActionPreference = 'Stop'

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if ($PSCmdlet.ShouldProcess($Id, 'winget install')) {
        Write-Host "==> winget install $Id"
        & winget install --id $Id --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 |
            Select-Object -Last 3
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
            # -1978335189 = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (already at latest)
            Write-Warning "winget install $Id returned exit code $LASTEXITCODE"
        }
    }
}

function Test-WingetAvailable {
    try {
        & winget --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Preflight
if (-not (Test-WingetAvailable)) {
    throw "winget not available. Install App Installer from the Microsoft Store, then re-run."
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Running under PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended. Continuing anyway."
}

Write-Host '==> Terminal stack Windows bootstrap'
Write-Host '    Detected: ' -NoNewline
Write-Host "PowerShell $($PSVersionTable.PSVersion); user $env:USERNAME"

# Core packages
$corePackages = @(
    'wez.wezterm.nightly',              # WezTerm nightly (preferred over stale stable)
    'DEVCOM.JetBrainsMonoNerdFont',     # Nerd Font for glyph rendering
    'Starship.Starship',                # Shell prompt
    'twpayne.chezmoi',                  # Dotfile manager (used to apply this repo)
    'eza-community.eza',                # Modern ls
    'junegunn.fzf',                     # Fuzzy finder
    'sharkdp.bat',                      # cat with syntax highlighting
    'dandavison.delta',                 # git diff pager
    'BurntSushi.ripgrep.MSVC',          # Fast grep
    'ajeetdsouza.zoxide'                # Smarter cd
)

foreach ($pkg in $corePackages) {
    Install-WingetPackage -Id $pkg
}

# Optional packages — only if -IncludeOptional was passed
if ($IncludeOptional) {
    $optionalPackages = @(
        # Add here as the stack grows. Currently none required.
    )
    foreach ($pkg in $optionalPackages) {
        Install-WingetPackage -Id $pkg
    }
}

Write-Host ''
Write-Host '==> Windows bootstrap done.'
Write-Host '    Next: run bootstrap\wsl-bootstrap.sh inside WSL Ubuntu, then chezmoi apply.'
Write-Host '    See INSTALL.md § Scripted for the full sequence.'
