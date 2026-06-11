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
    'ajeetdsouza.zoxide',               # Smarter cd
    'charmbracelet.glow'                # Markdown reader (TUI)
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

# Git include — stack aliases + delta config. The included file lands at
# %USERPROFILE%\.config\git\terminal-stack.gitconfig via sync-windows.ps1
# (which runs after this bootstrap); git silently skips missing includes,
# so ordering is safe. Forward slashes: git accepts them on Windows and they
# survive .gitconfig escaping.
$gitInclude = ($env:USERPROFILE -replace '\\', '/') + '/.config/git/terminal-stack.gitconfig'
$existingIncludes = & git config --global --get-all include.path 2>$null
if ($existingIncludes -match 'terminal-stack\.gitconfig') {
    Write-Host '==> git include.path already set'
} elseif ($PSCmdlet.ShouldProcess($gitInclude, 'git config --global --add include.path')) {
    Write-Host "==> Adding git include.path -> $gitInclude"
    & git config --global --add include.path $gitInclude
}

# Workspace directory for the ws/wsp/wspu profile functions. Same contract as
# the WSL/Linux/Mac bootstraps: $env:WORKSPACE_DIR skips the prompt; the
# answer persists to profile.local.ps1 ONLY when it differs from the
# autodetect (Get-TsWorkspace in $PROFILE covers the detected case).
$wsDetected = $null
foreach ($d in @(
    'C:\DATA\Workspace',
    (Join-Path $env:USERPROFILE 'workspace'),
    (Join-Path $env:USERPROFILE 'Documents\Workspace')
)) {
    if (Test-Path $d) { $wsDetected = $d; break }
}
$wsChoice = $env:WORKSPACE_DIR
if ($wsChoice) {
    Write-Host "==> WORKSPACE_DIR=$wsChoice (from env; skipping prompt)"
} else {
    $promptDefault = if ($wsDetected) { $wsDetected } else { 'none' }
    $answer = Read-Host "Workspace directory [$promptDefault]"
    $wsChoice = if ($answer) { $answer } else { $wsDetected }
}
if (-not $wsChoice) {
    Write-Warning 'No workspace directory found or chosen. Set one later: $env:WORKSPACE_DIR in profile.local.ps1'
} elseif ($wsChoice -eq $wsDetected) {
    Write-Host "==> Workspace: $wsChoice (autodetected; no override needed)"
} else {
    if (-not (Test-Path $wsChoice)) { Write-Warning "$wsChoice does not exist (yet) — ws will warn until it does." }
    # pwsh 7's $PROFILE is Documents\PowerShell\...; resolve via MyDocuments so
    # this works even when the bootstrap itself runs under Windows PowerShell 5.
    $localProfile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.local.ps1'
    if ($PSCmdlet.ShouldProcess($localProfile, "persist WORKSPACE_DIR=$wsChoice")) {
        New-Item -ItemType Directory -Force -Path (Split-Path $localProfile) | Out-Null
        $line = "`$env:WORKSPACE_DIR = '$wsChoice'"
        if ((Test-Path $localProfile) -and (Get-Content $localProfile | Where-Object { $_ -match '^\s*\$env:WORKSPACE_DIR\s*=' })) {
            (Get-Content $localProfile) -replace '^\s*\$env:WORKSPACE_DIR\s*=.*', $line | Set-Content $localProfile
            Write-Host "==> Updated WORKSPACE_DIR in $localProfile"
        } else {
            Add-Content -Path $localProfile -Value $line
            Write-Host "==> Wrote WORKSPACE_DIR=$wsChoice to $localProfile"
        }
    }
}

Write-Host ''
Write-Host '==> Windows bootstrap done.'
Write-Host '    Next: run bootstrap\wsl-bootstrap.sh inside WSL Ubuntu, then chezmoi apply.'
Write-Host '    See INSTALL.md § Scripted for the full sequence.'
