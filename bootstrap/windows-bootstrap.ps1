# windows-bootstrap.ps1 — install Windows-side prerequisites for the terminal-stack
# Idempotent: re-run safely. Each install runs only if the package manager reports the package not installed.
# Pass -WhatIf to dry-run.
#
# Package manager: winget (default) or Chocolatey. winget targets Windows 11; choco is the
# fallback for hosts where winget isn't available/supported (e.g. Windows Server 2019, which
# has no Microsoft Store). Select with:
#     .\windows-bootstrap.ps1 -PackageManager choco
# The choco path installs Chocolatey itself if missing (requires an elevated session).
# See ../INSTALL.md § Scripted for context.

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('winget', 'choco')]
    [string]$PackageManager = 'winget',
    [switch]$IncludeOptional
)

$ErrorActionPreference = 'Stop'

# --- winget helpers (unchanged) ---------------------------------------------

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

# --- Chocolatey helpers (alternative package manager) -----------------------

function Test-ChocoAvailable {
    try {
        & choco --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Install-Chocolatey {
    if (Test-ChocoAvailable) {
        Write-Host "==> Chocolatey already present ($((Get-Command choco).Source))"
        return
    }
    if (-not (Test-Administrator)) {
        throw "Chocolatey install requires an elevated PowerShell. Re-run from a 'Run as Administrator' session."
    }
    if ($PSCmdlet.ShouldProcess('Chocolatey', 'install')) {
        Write-Host '==> Installing Chocolatey (community.chocolatey.org/install.ps1)'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol =
            [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        # The installer sets the machine PATH; add choco to the current session too so the
        # installs below work without opening a new shell (same fixup install.ps1 does for git).
        $chocoBin = Join-Path $env:ProgramData 'chocolatey\bin'
        if (Test-Path (Join-Path $chocoBin 'choco.exe')) {
            $env:Path = "$chocoBin;$env:Path"
        }
        if (-not (Test-ChocoAvailable)) {
            throw "choco not on PATH after install. Open a new elevated pwsh window and re-run."
        }
    }
}

function Install-ChocoPackage {
    param([Parameter(Mandatory)][string]$Id)
    if ($PSCmdlet.ShouldProcess($Id, 'choco install')) {
        Write-Host "==> choco install $Id"
        & choco install $Id -y --no-progress 2>&1 | Select-Object -Last 3
        # 0 = ok; 1641/3010 = success but reboot suggested/required. Anything else is a real error.
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1641 -and $LASTEXITCODE -ne 3010) {
            Write-Warning "choco install $Id returned exit code $LASTEXITCODE"
        }
    }
}

# --- Preflight ---------------------------------------------------------------

if ($PackageManager -eq 'winget') {
    if (-not (Test-WingetAvailable)) {
        throw "winget not available. Install App Installer from the Microsoft Store, then re-run."
    }
} else {
    # choco: install Chocolatey itself first if it's missing (needs an elevated session).
    Install-Chocolatey
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Running under PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended. Continuing anyway."
}

Write-Host '==> Terminal stack Windows bootstrap'
Write-Host '    Detected: ' -NoNewline
Write-Host "PowerShell $($PSVersionTable.PSVersion); user $env:USERNAME; package manager $PackageManager"

# --- Core packages -----------------------------------------------------------

# winget IDs.
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
    'ajeetdsouza.zoxide',               # Smarter cd
    'charmbracelet.glow'                # Markdown reader (TUI)
)

# Chocolatey package IDs — parallel to $corePackages above (same order). Keep the two lists in
# sync when adding packages. Note: choco ships WezTerm *stable*, not the nightly winget installs.
$corePackagesChoco = @(
    'wezterm',                          # WezTerm (stable; choco has no nightly channel)
    'nerd-fonts-JetBrainsMono',         # Nerd Font for glyph rendering
    'starship',                         # Shell prompt
    'chezmoi',                          # Dotfile manager (used to apply this repo)
    'eza',                              # Modern ls
    'fzf',                              # Fuzzy finder
    'bat',                              # cat with syntax highlighting
    'delta',                            # git diff pager (git-delta)
    'ripgrep',                          # Fast grep
    'zoxide',                           # Smarter cd
    'glow'                              # Markdown reader (TUI)
)

$packages = if ($PackageManager -eq 'winget') { $corePackages } else { $corePackagesChoco }
foreach ($pkg in $packages) {
    if ($PackageManager -eq 'winget') { Install-WingetPackage -Id $pkg }
    else { Install-ChocoPackage -Id $pkg }
}

# Optional packages — only if -IncludeOptional was passed
if ($IncludeOptional) {
    # winget IDs; none required yet. Add choco equivalents alongside if this grows.
    $optionalPackages = @(
        # Add here as the stack grows. Currently none required.
    )
    foreach ($pkg in $optionalPackages) {
        if ($PackageManager -eq 'winget') { Install-WingetPackage -Id $pkg }
        else { Install-ChocoPackage -Id $pkg }
    }
}

Write-Host ''
Write-Host '==> Windows bootstrap done.'
Write-Host '    Next: run bootstrap\wsl-bootstrap.sh inside WSL Ubuntu, then chezmoi apply.'
Write-Host '    See INSTALL.md § Scripted for the full sequence.'
