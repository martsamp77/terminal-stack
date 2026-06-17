# _config.ps1 — terminal-stack configuration store (Windows side).
# Dot-sourced by windows-bootstrap.ps1, sync-windows.ps1, and the pwsh ts-config.
#
# Windows has no chezmoi.toml, so the store is a JSON mirror at
# %LOCALAPPDATA%\terminal-stack\config.json (next to rollback-sha). In a combined
# Windows+WSL setup the WSL run_after hook is authoritative and also writes this
# file; the pwsh side is for Windows-standalone installs. The chord→binding and
# theme mapping here mirror .chezmoi.toml.tmpl / bootstrap/_config.sh.

# ── App catalog (winget ids) ─────────────────────────────────────────────────────
# Required prerequisites (WezTerm, Nerd Font, Starship, chezmoi, Git) are always
# installed and not listed here. tmux/tldr/nvtop/lazydocker are WSL/Linux-only.
$script:TsWingetIds = @{
    eza     = 'eza-community.eza'
    fzf     = 'junegunn.fzf'
    bat     = 'sharkdp.bat'
    delta   = 'dandavison.delta'
    ripgrep = 'BurntSushi.ripgrep.MSVC'
    zoxide  = 'ajeetdsouza.zoxide'
    glow    = 'charmbracelet.glow'
    micro   = 'zyedidia.micro'
    neovim  = 'Neovim.Neovim'
    zed     = 'Zed.Zed'
}
$script:TsAppsRecommended = @('eza','fzf','bat','delta','ripgrep','zoxide','glow','micro','neovim')
$script:TsAppsOptional    = @('zed')
$script:TsAppsAll         = $script:TsAppsRecommended + $script:TsAppsOptional

function Get-TsAppDesc([string]$id) {
    switch ($id) {
        'eza'     { 'modern ls (icons, git status)' }
        'fzf'     { 'fuzzy finder (Ctrl+R, Ctrl+T)' }
        'bat'     { 'cat with syntax highlighting' }
        'delta'   { 'git diff pager' }
        'ripgrep' { 'fast recursive grep (rg)' }
        'zoxide'  { 'smarter cd (z)' }
        'glow'    { 'terminal markdown renderer' }
        'micro'   { 'nano-like terminal editor' }
        'neovim'  { 'neovim editor (nvim)' }
        'zed'     { 'Zed GUI editor' }
        default   { '' }
    }
}

# ── chord / theme mapping ────────────────────────────────────────────────────────
function ConvertTo-TsLeader([string]$chord) {
    if (-not $chord) { $chord = 'ctrl-space' }
    $parts = $chord.Split('-')
    $key = $parts[-1]
    $mods = @()
    if ($parts.Count -gt 1) {
        foreach ($m in $parts[0..($parts.Count - 2)]) {
            switch ($m.ToLower()) {
                'ctrl'  { $mods += 'CTRL' }
                'alt'   { $mods += 'ALT' }
                'shift' { $mods += 'SHIFT' }
                'super' { $mods += 'SUPER' }
                'win'   { $mods += 'SUPER' }
                'cmd'   { $mods += 'SUPER' }
            }
        }
    }
    $wkey = if ($key.ToLower() -eq 'space') { 'phys:Space' } else { $key }
    return @{ key = $wkey; mods = ($mods -join '|') }
}

function ConvertTo-TsTmuxPrefix([string]$chord) {
    if (-not $chord) { $chord = 'ctrl-b' }
    $parts = $chord.Split('-')
    $key = $parts[-1]
    $pre = ''
    if ($parts.Count -gt 1) {
        foreach ($m in $parts[0..($parts.Count - 2)]) {
            switch ($m.ToLower()) {
                'ctrl'  { $pre += 'C-' }
                'alt'   { $pre += 'M-' }
                'shift' { $pre += 'S-' }
            }
        }
    }
    $k = if ($key.ToLower() -eq 'space') { 'Space' } else { $key }
    return "$pre$k"
}

function Get-TsResolvedTheme([string]$mode) {
    switch ($mode) {
        'light' { return 'light' }
        'dark'  { return 'dark' }
    }
    # follow: read the Windows apps theme; default dark on any failure.
    try {
        $v = Get-ItemPropertyValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
             -Name AppsUseLightTheme -ErrorAction Stop
        if ($v -eq 1) { return 'light' } else { return 'dark' }
    } catch { return 'dark' }
}

# ── store I/O ────────────────────────────────────────────────────────────────────
function Get-TsConfigPath { Join-Path $env:LOCALAPPDATA 'terminal-stack\config.json' }

function Get-TsConfig {
    $p = Get-TsConfigPath
    if (Test-Path $p) {
        try { return (Get-Content $p -Raw | ConvertFrom-Json) } catch {}
    }
    return [pscustomobject]@{
        leaderChord = 'ctrl-space'; themeMode = 'dark'; tmuxPrefix = 'ctrl-b'; apps = @()
    }
}

function Save-TsConfig {
    param(
        [string]$LeaderChord = 'ctrl-space',
        [string]$ThemeMode   = 'dark',
        [string]$TmuxPrefix  = 'ctrl-b',
        [string[]]$Apps      = @()
    )
    $l = ConvertTo-TsLeader $LeaderChord
    $obj = [ordered]@{
        leaderChord        = $LeaderChord
        leaderKey          = $l.key
        leaderMods         = $l.mods
        themeMode          = $ThemeMode
        resolvedTheme      = (Get-TsResolvedTheme $ThemeMode)
        tmuxPrefix         = $TmuxPrefix
        tmuxPrefixResolved = (ConvertTo-TsTmuxPrefix $TmuxPrefix)
        apps               = @($Apps)
    }
    $p = Get-TsConfigPath
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    ($obj | ConvertTo-Json) | Set-Content -Encoding UTF8 $p
    return $obj
}

# ── Wizard prompts (env vars TS_LEADER / TS_THEME / TS_APPS skip each) ──────────
function Read-TsLeader {
    if ($env:TS_LEADER) { return $env:TS_LEADER }
    Write-Host ''
    Write-Host 'Leader key (WezTerm) — prefix for pane / tab / workspace commands:'
    Write-Host '  1) Ctrl+Space  (recommended)'
    Write-Host '  2) Ctrl+A'
    Write-Host '  3) Ctrl+B'
    Write-Host '  4) custom (type a chord like ctrl-x or alt-space)'
    switch (Read-Host 'Choose [1]') {
        '2'     { 'ctrl-a' }
        '3'     { 'ctrl-b' }
        '4'     { $c = Read-Host 'Enter chord (mod-key, e.g. ctrl-x)'; if ($c) { $c } else { 'ctrl-space' } }
        default { 'ctrl-space' }
    }
}
function Read-TsTheme {
    if ($env:TS_THEME) { return $env:TS_THEME }
    Write-Host ''
    Write-Host 'Theme:'
    Write-Host '  1) dark   (Catppuccin Mocha, recommended)'
    Write-Host '  2) light  (Catppuccin Latte)'
    Write-Host '  3) follow OS appearance'
    switch (Read-Host 'Choose [1]') {
        '2'     { 'light' }
        '3'     { 'follow' }
        default { 'dark' }
    }
}
function Read-TsApps {
    if ($env:TS_APPS) {
        switch ($env:TS_APPS) {
            'recommended' { return $script:TsAppsRecommended }
            'all'         { return $script:TsAppsAll }
            'none'        { return @() }
            default       { return ($env:TS_APPS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        }
    }
    Write-Host ''
    Write-Host 'Optional CLI tools (WezTerm, font, Starship, chezmoi — always installed):'
    Write-Host '  Note: winget may prompt for administrator elevation.'
    Write-Host ('  1) Install recommended set: ' + ($script:TsAppsRecommended -join ', '))
    Write-Host '  2) Customize (choose each)'
    Write-Host '  3) Skip all optional apps'
    switch (Read-Host 'Choose [1]') {
        '2' {
            $sel = @()
            foreach ($id in $script:TsAppsAll) {
                $def = if ($script:TsAppsRecommended -contains $id) { 'Y' } else { 'n' }
                $a = Read-Host ('  install {0} — {1}? [{2}]' -f $id, (Get-TsAppDesc $id), $def)
                if (-not $a) { $a = $def }
                if ($a -match '^(y|yes)$') { $sel += $id }
            }
            return $sel
        }
        '3' { return @() }
        default { return $script:TsAppsRecommended }
    }
}

# Install the selected toggleable apps via winget (catalog id -> winget id).
function Install-TsApps([string[]]$Apps) {
    if (-not $Apps -or $Apps.Count -eq 0) {
        Write-Host '==> No optional apps selected; skipping app install'
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget not available; recorded selection only.'
        return
    }
    foreach ($id in $Apps) {
        if ($script:TsWingetIds.ContainsKey($id)) {
            $wid = $script:TsWingetIds[$id]
            Write-Host "==> winget install $wid"
            & winget install --id $wid --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 |
                Select-Object -Last 2
        }
    }
}

# Refresh only resolvedTheme from the live OS theme (used by ts-update for follow).
function Update-TsResolvedTheme {
    $c = Get-TsConfig
    Save-TsConfig -LeaderChord $c.leaderChord -ThemeMode $c.themeMode `
                  -TmuxPrefix $c.tmuxPrefix -Apps @($c.apps) | Out-Null
}
