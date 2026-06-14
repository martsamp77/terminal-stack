# sync-windows.ps1 — PowerShell port of run_after_90-sync-windows.sh.
# Mirrors <SourceDir>\windows\** to %USERPROFILE%\<relative path>, with the
# same .tmpl __WIN_USER__ substitution and .bak.yyyyMMdd[.N] backup convention
# as the bash hook. Lets Windows-only users (no WSL) update the stack via
# install.ps1 or Update-TerminalStack without ever invoking chezmoi.
#
# The bash hook (run_after_90-sync-windows.sh) is still the source of truth
# when chezmoi apply runs from WSL — this script is a parallel Windows-native
# code path, not a replacement.
#
# Idempotent: only writes targets whose bytes differ.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceDir,
    [string]$WinUser = $env:USERNAME
)

$ErrorActionPreference = 'Stop'

$srcRoot = Join-Path $SourceDir 'windows'
if (-not (Test-Path -LiteralPath $srcRoot -PathType Container)) {
    Write-Warning "sync-windows: $srcRoot not found; nothing to sync."
    return
}

if ([string]::IsNullOrWhiteSpace($WinUser)) {
    throw "sync-windows: -WinUser is empty and `$env:USERNAME is unset."
}

$dstRoot = $env:USERPROFILE
if (-not $dstRoot -or -not (Test-Path -LiteralPath $dstRoot -PathType Container)) {
    throw "sync-windows: `$env:USERPROFILE ($dstRoot) is not a valid directory."
}

# Load the saved config (leader/theme tokens). Falls back to defaults when the
# config helper or config.json is absent (clone predating the wizard).
$cfgHelper = Join-Path $SourceDir 'bootstrap\_config.ps1'
if (Test-Path -LiteralPath $cfgHelper) { . $cfgHelper }
$tsCfg = if (Get-Command Get-TsConfig -ErrorAction SilentlyContinue) { Get-TsConfig } else { $null }
$tok = @{
    '__LEADER_KEY__'     = if ($tsCfg.leaderKey)          { $tsCfg.leaderKey }          else { 'phys:Space' }
    '__LEADER_MODS__'    = if ($tsCfg.leaderMods)         { $tsCfg.leaderMods }         else { 'CTRL' }
    '__THEME_MODE__'     = if ($tsCfg.themeMode)          { $tsCfg.themeMode }          else { 'dark' }
    '__THEME_RESOLVED__' = if ($tsCfg.resolvedTheme)      { $tsCfg.resolvedTheme }      else { 'dark' }
    '__TMUX_PREFIX__'    = if ($tsCfg.tmuxPrefixResolved) { $tsCfg.tmuxPrefixResolved } else { 'C-b' }
}

$today = Get-Date -Format 'yyyyMMdd'
$created = 0
$updated = 0
$unchanged = 0

function Get-BackupPath([string]$dst, [string]$stamp) {
    $bak = "$dst.bak.$stamp"
    if (-not (Test-Path -LiteralPath $bak)) { return $bak }
    $n = 1
    while (Test-Path -LiteralPath "$dst.bak.$stamp.$n") { $n++ }
    return "$dst.bak.$stamp.$n"
}

Get-ChildItem -LiteralPath $srcRoot -Recurse -File | ForEach-Object {
    $src = $_.FullName
    $rel = $src.Substring($srcRoot.Length).TrimStart('\','/')

    # Render .tmpl files to a temp file with all tokens substituted.
    if ($rel.EndsWith('.tmpl')) {
        $relOut = $rel.Substring(0, $rel.Length - 5)
        $rendered = [IO.Path]::GetTempFileName()
        $content = (Get-Content -LiteralPath $src -Raw) -replace '__WIN_USER__', $WinUser
        foreach ($k in $tok.Keys) { $content = $content -replace $k, $tok[$k] }
        $content | Set-Content -LiteralPath $rendered -NoNewline -Encoding utf8
        $effectiveSrc = $rendered
    } else {
        $relOut = $rel
        $effectiveSrc = $src
    }

    $dst = Join-Path $dstRoot $relOut
    $dstDir = Split-Path -Parent $dst

    try {
        if (Test-Path -LiteralPath $dst -PathType Leaf) {
            $srcHash = (Get-FileHash -LiteralPath $effectiveSrc -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
            if ($srcHash -eq $dstHash) {
                $unchanged++
                return
            }
            $bak = Get-BackupPath -dst $dst -stamp $today
            Copy-Item -LiteralPath $dst -Destination $bak -Force
            Copy-Item -LiteralPath $effectiveSrc -Destination $dst -Force
            $updated++
            Write-Host "updated  $dst  (backup: $bak)"
        } else {
            if (-not (Test-Path -LiteralPath $dstDir -PathType Container)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $effectiveSrc -Destination $dst -Force
            $created++
            Write-Host "created  $dst"
        }
    } finally {
        if ($rel.EndsWith('.tmpl') -and (Test-Path -LiteralPath $effectiveSrc)) {
            Remove-Item -LiteralPath $effectiveSrc -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "sync-windows: user=$WinUser, $created created, $updated updated, $unchanged unchanged"
