$env:_ZO_ECHO = '1'
$env:_ZO_EXCLUDE_DIRS = 'C:\Windows\*;*\node_modules\*;*\.git\*;*\target\*;*\dist\*;*\build\*'

function zoxide-prune {
  zoxide query -l | Where-Object { -not (Test-Path $_) } | ForEach-Object { zoxide remove $_ }
}

function ws { Set-Location C:\DATA\Workspace }
function wsp { Set-Location C:\DATA\Workspace_Personal }
function wspu { Set-Location C:\DATA\Workspace_Public }
function wscalibra { Set-Location C:\DATA\Workspace\md-validator }
function wsnetsuite { Set-Location C:\DATA\Workspace\netsuite-customizations }

function Set-WezTabTitle([string]$title) {
    if ($env:WEZTERM_PANE) {
        & wezterm.exe cli set-tab-title $title 2>$null
    }
}

function cc    { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude @args } finally { Set-WezTabTitle "" } }
function ccc   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --continue @args } finally { Set-WezTabTitle "" } }
function ccd   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions @args } finally { Set-WezTabTitle "" } }
function ccdc  { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions --continue @args } finally { Set-WezTabTitle "" } }
function ccr   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --resume @args } finally { Set-WezTabTitle "" } }
function ccdr  { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions --resume @args } finally { Set-WezTabTitle "" } }
function cca   { Set-WezTabTitle "cc • agents"; try { claude agents } finally { Set-WezTabTitle "" } }

# ---- starship-stack-start ----

# Native console children (Claude Code, etc.) can SetConsoleOutputCP back to 437 on exit; [Console]::OutputEncoding caches and won't catch it, so probe the OS codepage directly.
if (-not ('Native.ConsoleCP' -as [type])) {
    Add-Type -Namespace Native -Name ConsoleCP -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint GetConsoleOutputCP();
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern bool SetConsoleOutputCP(uint wCodePageID);
'@ | Out-Null
}
[Native.ConsoleCP]::SetConsoleOutputCP(65001) | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

Invoke-Expression (&starship init powershell)
if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) { Enable-TransientPrompt }

function Invoke-Starship-PreCommand {
    if ([Native.ConsoleCP]::GetConsoleOutputCP() -ne 65001) {
        [Native.ConsoleCP]::SetConsoleOutputCP(65001) | Out-Null
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    }
    $loc = $executionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq 'FileSystem') {
        Write-Host -NoNewline "`e]7;file://localhost/$($loc.Path)`a"
        $leaf = Split-Path -Leaf $loc.Path
        if ([string]::IsNullOrEmpty($leaf)) { $leaf = $loc.Path }
        Write-Host -NoNewline "`e]0;pwsh • $leaf`a"
    }
}
# ---- starship-stack-end ----

# ---- cli-tools-start ----
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    # Built-in `ls` is an alias to Get-ChildItem; remove before redefining as a function.
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons=always --git --group-directories-first @args }
    function ll { eza -l --icons=always --git --group-directories-first @args }
    function la { eza -la --icons=always --git --group-directories-first @args }
    function lt { eza --tree --icons=always --git --group-directories-first @args }
}
# ---- cli-tools-end ----

# ---- terminal-stack-update-start ----
function Update-TerminalStack {
    [CmdletBinding()]
    param([string]$SourceDir)

    if (-not $SourceDir) { $SourceDir = $env:TERMINAL_STACK_DIR }
    if (-not $SourceDir -and (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        $SourceDir = (& chezmoi source-path 2>$null | Select-Object -First 1)
    }
    if (-not $SourceDir) { $SourceDir = Join-Path $env:USERPROFILE 'terminal-stack' }

    if (-not (Test-Path (Join-Path $SourceDir '.git'))) {
        Write-Warning "terminal-stack clone not found at $SourceDir. Re-run install.ps1 first."
        return
    }
    Write-Host "==> git -C $SourceDir pull --ff-only"
    & git -C $SourceDir pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git pull failed; not applying."
        return
    }
    $sync = Join-Path $SourceDir 'scripts\sync-windows.ps1'
    if (Test-Path $sync) {
        & $sync -SourceDir $SourceDir
    } else {
        Write-Warning "$sync not found; Windows-side dotfiles not applied."
    }
}
Set-Alias -Name ts-update -Value Update-TerminalStack
# ---- terminal-stack-update-end ----
